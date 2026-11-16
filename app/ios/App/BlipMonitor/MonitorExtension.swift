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
        let cap = name == "daily" ? lastM + (now - lastT) / 60 + 5 : max(lastM + (now - lastT) / 60 + 15, sinceMidnight + 5)
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
