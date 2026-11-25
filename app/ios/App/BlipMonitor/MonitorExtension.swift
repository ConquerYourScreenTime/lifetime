import DeviceActivity
import FamilyControls
import WidgetKit
import Foundation

// Runs in the background, separately from the app. iOS calls eventDidReachThreshold each
// time the day's total screen time passes another 5 minutes ("m5", "m10", ...).
// We keep only the highest step for the day, in the shared App Group, on this phone.
class MonitorExtension: DeviceActivityMonitor {
    let defaults = UserDefaults(suiteName: "group.io.github.gamesbyvidal.lifetime")

    private func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // TestFlight "Screen Time check": when each step arrived, kept on this phone with the daily totals (same 8-day purge).
    private func log(_ what: String) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        let key = "log-" + today()
        var list = defaults?.stringArray(forKey: key) ?? []
        list.append(f.string(from: Date()) + " " + what)
        if list.count > 1500 { list.removeFirst(list.count - 1500) }
        defaults?.set(list, forKey: key)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log(activity.rawValue + " end")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log(activity.rawValue + " start (monitor)")
        // Safety net: if the counter isn't running when another watcher starts (midnight or a restart), start it again here,
        // so a day still counts even if Blip isn't opened (Nov 15: daily was missing from midnight until Blip was opened).
        // Blip friends game: "fclock" wakes us at midnight to send yesterday's points total. Its watchers never restart Classic's counter.
        if activity == DeviceActivityName("fclock") { friendsMidnight(); return }
        if activity.rawValue.hasPrefix("tier-") { return }
        if activity != DeviceActivityName("daily"), !DeviceActivityCenter().activities.contains(DeviceActivityName("daily")) { restartDaily() }
        let key = "minutes-" + today()
        if defaults?.object(forKey: key) == nil { defaults?.set(0, forKey: key) }
        purgeOld()
    }

    // Keep about a week of daily totals (same rule as ScreenTimePlugin.purgeOld).
    private func purgeOld() {
        guard let d = defaults, let cutoff = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else { return }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let oldest = f.string(from: cutoff)
        for key in d.dictionaryRepresentation().keys {
            if key.hasPrefix("minutes-"), String(key.dropFirst(8)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("log-"), String(key.dropFirst(4)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("diag-"), String(key.dropFirst(5)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("hours-"), String(key.dropFirst(6)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("at-"), let day = key.split(separator: "-", maxSplits: 2).last, String(day) < oldest { d.removeObject(forKey: key) }
        }
    }

    // iOS 26 sometimes fires a burst of steps that can't be real (Nov 8: 12h 30m; Nov 12: 130m jumped to 940m within two
    // minutes while iPhone said about 3h 30m). Screen time can't grow faster than the clock: a new high is accepted only if
    // it is at most the last accepted high + the minutes since then + 5. Re-sent steps at or below the high are never affected.
    private func possible(_ m: Int, name: String) -> Bool {
        let now = Date().timeIntervalSince1970
        let atKey = "at-" + name + "-" + today()
        var rec = defaults?.dictionary(forKey: atKey) as? [String: Double] ?? [:]
        let lastM = rec["m"] ?? 0
        let lastT = rec["t"] ?? Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        // Logged-only watchers (picked, all, web: 15-minute steps) re-send a whole day's steps after a restart, out of order,
        // so for them the cap is the minutes since midnight. The scored counter ("daily") keeps the strict rule.
        let sinceMidnight = (now - Calendar.current.startOfDay(for: Date()).timeIntervalSince1970) / 60
        let cap = name.hasPrefix("tier-") ? lastM + (now - lastT) / 60 + 15 : name == "daily" ? lastM + (now - lastT) / 60 + 5 : max(lastM + (now - lastT) / 60 + 15, sinceMidnight + 5)
        if Double(m) > cap {
            let minute = floor(now / 60)
            if rec["warned"] != minute { rec["warned"] = minute; defaults?.set(rec, forKey: atKey); log(name + " jump to \(m)m ignored (faster than the clock)") }
            return false
        }
        rec["m"] = Double(m); rec["t"] = now
        defaults?.set(rec, forKey: atKey)
        return true
    }

    // TestFlight check: minutes gained in each hour of the day by a counter ("daily-14" = 2 PM), to compare with the
    // hourly bars in iPhone Settings. Logged only. REMOVE before App Store submission.
    private func addHour(_ name: String, _ gained: Int) {
        guard gained > 0 else { return }
        let key = "hours-" + today()
        var h = defaults?.dictionary(forKey: key) as? [String: Int] ?? [:]
        let k = name + "-\(Calendar.current.component(.hour, from: Date()))"
        h[k] = (h[k] ?? 0) + gained
        defaults?.set(h, forKey: key)
    }

    // Same counter as ScreenTimePlugin.startMonitor (picked categories + apps, one event per 5 minutes, whole day, repeating).
    private func restartDaily() {
        guard let data = defaults?.data(forKey: "selection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { log("counter missing, no selection to restart it"); return }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in stride(from: 5, through: 16 * 60, by: 5) {
            if #available(iOS 17.4, *) {
                events[DeviceActivityEvent.Name("m\(m)")] = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens, webDomains: [], threshold: DateComponents(minute: m), includesPastActivity: true)
            } else {
                events[DeviceActivityEvent.Name("m\(m)")] = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens, webDomains: [], threshold: DateComponents(minute: m))
            }
        }
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        do { try DeviceActivityCenter().startMonitoring(DeviceActivityName("daily"), during: schedule, events: events); log("counter was missing, restarted (monitor)") }
        catch { log("counter was missing, restart failed: " + error.localizedDescription) }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // TestFlight check: per-category steps ("c3_45" = category #3 passed 45 minutes). Logged only, never counted.
        if activity == DeviceActivityName("cats") { log("cat " + event.rawValue.dropFirst().replacingOccurrences(of: "_", with: ": ") + "m"); return }
        // TestFlight check: websites-only ("web45"), build 20 way ("picked45") and no-filter ("all45") watchers. Logged only, never counted.
        // TestFlight quick test ("qt-..." activities, "t7" = 7 minutes since the test started). New highs only.
        if activity.rawValue.hasPrefix("qt-") {
            guard let m = Int(event.rawValue.dropFirst()) else { return }
            let name = String(activity.rawValue.dropFirst(3))
            var best = defaults?.dictionary(forKey: "qt-best") as? [String: Int] ?? [:]
            if m > (best[name] ?? 0) { best[name] = m; defaults?.set(best, forKey: "qt-best"); log("test " + name + " \(m)m") }
            return
        }
        // Only new highs are logged: every app open makes iOS re-send all of today's steps, which flooded the log.
        if ["web", "apps", "picked", "all"].contains(activity.rawValue) {
            guard let m = Int(event.rawValue.drop(while: { $0.isLetter })) else { return }
            let key = "diag-" + today()
            var best = defaults?.dictionary(forKey: key) as? [String: Int] ?? [:]
            guard m > (best[activity.rawValue] ?? 0) else { return }
            guard possible(m, name: activity.rawValue) else { return }
            if activity.rawValue == "all" { addHour("all", m - (best["all"] ?? 0)) }
            best[activity.rawValue] = m; defaults?.set(best, forKey: key); log(activity.rawValue + " \(m)m")
            return
        }
        // Blip friends game: highest 15-minute step per tier today ("fmin-red-2026-11-25").
        if activity.rawValue.hasPrefix("tier-") {
            guard let m = Int(event.rawValue.dropFirst()) else { return }
            let tier = String(activity.rawValue.dropFirst(5))
            let key = "fmin-" + tier + "-" + today()
            guard m > (defaults?.integer(forKey: key) ?? 0), possible(m, name: activity.rawValue) else { return }
            defaults?.set(m, forKey: key)
            return
        }
        guard let m = Int(event.rawValue.dropFirst()) else { return }
        let key = "minutes-" + today()
        let before = defaults?.integer(forKey: key) ?? 0
        guard m > before else { return }
        guard possible(m, name: "daily") else { return }
        addHour("daily", m - before)
        defaults?.set(m, forKey: key); log("\(m)m")
        WidgetCenter.shared.reloadAllTimelines() // Blip's widget shows the new step
    }
}

// ---------- Blip friends game: midnight send ----------
// Keep this copy of Friends identical to the one in ScreenTimePlugin.swift (the app and this extension can't share a file).
enum Friends {
    static let tiers = ["red", "orange", "yellow"]
    static let cost = ["red": 40, "orange": 20, "yellow": 10]   // points per 15 minutes, the same for every player
    static let bank = 1000
    static let step = 15
    static let maxMinutes = 16 * 60
    static let keepDays = 31   // the plan keeps daily totals 30 days

    static func dayString(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func points(red: Int, orange: Int, yellow: Int) -> Int {
        let spent = (red / step) * cost["red"]! + (orange / step) * cost["orange"]! + (yellow / step) * cost["yellow"]!
        return max(0, bank - spent)
    }
    static func selection(_ d: UserDefaults?, _ tier: String) -> FamilyActivitySelection? {
        guard let data = d?.data(forKey: "tier-" + tier) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
    // A tier change made after setup waits until the next day ("tier-next-..."), so nothing can change mid-day.
    static func applyPending(_ d: UserDefaults?) -> Bool {
        guard let d = d, let day = d.string(forKey: "tier-next-day"), day < dayString() else { return false }
        for t in tiers { if let data = d.data(forKey: "tier-next-" + t) { d.set(data, forKey: "tier-" + t); d.removeObject(forKey: "tier-next-" + t) } }
        d.removeObject(forKey: "tier-next-day")
        return true
    }
    // Starts (or replaces) one watcher per tier plus "fclock", which only wakes BlipMonitor at midnight to send yesterday's total.
    static func startWatchers(_ d: UserDefaults?) throws {
        let center = DeviceActivityCenter()
        // Blip Classic / Nomad watchers are not used by this game: stop them (iOS allows only 20 at once).
        let mine = Set((tiers.map { "tier-" + $0 } + ["fclock"]).map { DeviceActivityName($0) })
        center.stopMonitoring(center.activities.filter { !mine.contains($0) })
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        for t in tiers {
            let name = DeviceActivityName("tier-" + t)
            guard let sel = selection(d, t), !(sel.applicationTokens.isEmpty && sel.categoryTokens.isEmpty) else { center.stopMonitoring([name]); continue }
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for m in stride(from: step, through: maxMinutes, by: step) {
                let n = DeviceActivityEvent.Name("m\(m)")
                if #available(iOS 17.4, *) {
                    events[n] = DeviceActivityEvent(applications: sel.applicationTokens, categories: sel.categoryTokens, webDomains: [], threshold: DateComponents(minute: m), includesPastActivity: true)
                } else {
                    events[n] = DeviceActivityEvent(applications: sel.applicationTokens, categories: sel.categoryTokens, webDomains: [], threshold: DateComponents(minute: m))
                }
            }
            // Same lesson as Blip's counter: replace without stopping first, stop+start only if iOS refuses.
            do { try center.startMonitoring(name, during: schedule, events: events) }
            catch { center.stopMonitoring([name]); try center.startMonitoring(name, during: schedule, events: events) }
        }
        let clock = DeviceActivityName("fclock")
        do { try center.startMonitoring(clock, during: schedule) }
        catch { center.stopMonitoring([clock]); try center.startMonitoring(clock, during: schedule) }
        d?.set(true, forKey: "friends-ready")
        if d?.string(forKey: "friends-since") == nil { d?.set(dayString(), forKey: "friends-since") }  // first day that counts
    }
    static func purge(_ d: UserDefaults?) {
        guard let d = d, let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) else { return }
        let oldest = dayString(cutoff)
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("fmin-") || key.hasPrefix("fsent-") || key.hasPrefix("at-tier-") {
            let day = key.split(separator: "-").suffix(3).joined(separator: "-")
            if day < oldest { d.removeObject(forKey: key) }
        }
    }
}

extension MonitorExtension {
    // Just after midnight: apply tier changes picked yesterday, keep the watchers running, and send yesterday's points total.
    // The only data that leaves the phone is that one number (plus the anonymous player ID and match code it belongs to).
    func friendsMidnight() {
        if Friends.applyPending(defaults) { try? Friends.startWatchers(defaults); log("friends: tier changes applied") }
        else {
            let running = Set(DeviceActivityCenter().activities.map { $0.rawValue })
            if Friends.tiers.contains(where: { Friends.selection(defaults, $0) != nil && !running.contains("tier-" + $0) }) { try? Friends.startWatchers(defaults) }
        }
        Friends.purge(defaults)
        guard let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        let day = Friends.dayString(y)
        guard let since = defaults?.string(forKey: "friends-since"), day >= since else { return }
        guard defaults?.bool(forKey: "fsent-" + day) != true, let s = defaults?.dictionary(forKey: "friends-sync") as? [String: String],
              let key = s["apiKey"], let project = s["projectId"], let refresh = s["refreshToken"], let uid = s["uid"], let match = s["match"] else { return }
        let m = Friends.tiers.map { defaults?.integer(forKey: "fmin-" + $0 + "-" + day) ?? 0 }
        let points = Friends.points(red: m[0], orange: m[1], yellow: m[2])
        if sendPoints(apiKey: key, project: project, refresh: refresh, uid: uid, match: match, day: day, points: points) {
            defaults?.set(true, forKey: "fsent-" + day); log("friends: sent \(day)")
        } else { log("friends: send failed, the app will retry when opened") }
    }

    // Blocking (the extension may be ended as soon as this callback returns), at most about 25 seconds in all.
    private func request(_ req: URLRequest) -> [String: Any]? {
        let sem = DispatchSemaphore(value: 0)
        var out: [String: Any]?
        var r = req; r.timeoutInterval = 12
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data = data {
                out = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 13)
        return out
    }
    func sendPoints(apiKey: String, project: String, refresh: String, uid: String, match: String, day: String, points: Int) -> Bool {
        guard let tokenURL = URL(string: "https://securetoken.googleapis.com/v1/token?key=" + apiKey) else { return false }
        var t = URLRequest(url: tokenURL); t.httpMethod = "POST"
        t.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let enc = refresh.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refresh
        t.httpBody = ("grant_type=refresh_token&refresh_token=" + enc).data(using: .utf8)
        guard let tok = request(t), let id = tok["id_token"] as? String else { return false }
        let path = "https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/matches/\(match)/days/\(day)_\(uid)"
        guard let url = URL(string: path) else { return false }
        var p = URLRequest(url: url); p.httpMethod = "PATCH"
        p.setValue("Bearer " + id, forHTTPHeaderField: "Authorization")
        p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let iso = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = ["fields": ["uid": ["stringValue": uid], "day": ["stringValue": day],
                                              "points": ["integerValue": String(points)], "at": ["timestampValue": iso]]]
        p.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request(p) != nil
    }
}
