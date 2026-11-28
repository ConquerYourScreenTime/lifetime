import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications

// Conquer's weapons against screen time (design handoff sections 18 to 20). This one file is compiled into the app,
// BlipMonitor and both shield extensions, so the lock rules live in one place.
// Everything stays on this phone, in the App Group. No weapon ever changes points or who wins.
// Locks use only what the player picked for the weapons ("wlist": apps, categories, websites), never anything picked for
// them, so the wrong apps never get locked (Matthew 2026-11-28). Scoring still uses the Red and Orange tiers.
enum Weapons {
    static let group = "group.io.github.gamesbyvidal.lifetime"
    static var d: UserDefaults? { UserDefaults(suiteName: group) }

    static func selection(_ key: String) -> FamilyActivitySelection? {
        guard let data = d?.data(forKey: key), let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
              !(s.applicationTokens.isEmpty && s.categoryTokens.isEmpty) else { return nil }
        return s
    }
    static var red: FamilyActivitySelection? { selection("tier-red") }
    // What a weapon locks. One shared list for now ("wlist"); a weapon's own list ("wlist-<weapon>") wins if one is ever saved.
    // weapon: "wall" (Fortress), "cease", "banish", "treasury", "sentry".
    static let listMax = 50
    static let weaponNames = ["wall", "cease", "banish", "treasury", "sentry"]
    static func targets(_ weapon: String) -> FamilyActivitySelection? {
        for key in (weapon.isEmpty ? ["wlist"] : ["wlist-" + weapon, "wlist"]) {
            if let data = d?.data(forKey: key), let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
               !(s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty) { return s }
        }
        return nil
    }
    // Counts for the page: apps, categories, websites, and whether the weapon has its own list (nil = the shared list).
    static func listInfo(_ weapon: String?) -> [String: Any] {
        let t = targets(weapon ?? "")
        return ["apps": t?.applicationTokens.count ?? 0, "cats": t?.categoryTokens.count ?? 0, "webs": t?.webDomainTokens.count ?? 0, "max": listMax,
                "own": weapon.map { d?.data(forKey: "wlist-" + $0) != nil } ?? false]
    }
    // Build 13 locked whole Red categories (Messages and WhatsApp got caught). Once, lift any such lock; settings are kept.
    static func migrateToList() {
        guard d?.bool(forKey: "wlist-migrated") != true else { return }
        for n in ["banish", "cease", "treasury", "wall"] { unlock(n) }
        d?.removeObject(forKey: "banish-until"); d?.removeObject(forKey: "wall-until"); d?.removeObject(forKey: "treasury-out"); d?.removeObject(forKey: "cease-on")
        DeviceActivityCenter().stopMonitoring([DeviceActivityName("banish"), DeviceActivityName("wall"), DeviceActivityName("treasury")])
        d?.set(true, forKey: "wlist-migrated")
    }
    // After the list changes: locks that are on right now switch to the new list, and Treasury counts the new list.
    static func relockActive() {
        if banishUntil > 0, let t = targets("banish") { lock("banish", t) }
        if ceaseActive, let t = targets("cease") { lock("cease", t) }
        if treasuryOut, let t = targets("treasury") { lock("treasury", t) }
        if fortressUntil > 0, let t = targets("wall") { lock("wall", t) }
        startTreasury()
        applySentry()
    }
    static func store(_ name: String) -> ManagedSettingsStore { ManagedSettingsStore(named: ManagedSettingsStore.Name(name)) }

    static func lock(_ name: String, _ s: FamilyActivitySelection, except: Set<ApplicationToken> = [], exceptCats: Set<ActivityCategoryToken> = []) {
        let st = store(name)
        let apps = s.applicationTokens.subtracting(except), cats = s.categoryTokens.subtracting(exceptCats)
        st.shield.applications = apps.isEmpty ? nil : apps
        st.shield.applicationCategories = cats.isEmpty ? nil : .specific(cats, except: except)
        st.shield.webDomainCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        st.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }
    static func unlock(_ name: String) { store(name).clearAllSettings() }

    // Sentry waits and passes are kept per app ("a:...") or, when the lock came from a whole category, per category ("c:...").
    static func tokenKey(_ t: ApplicationToken) -> String { "a:" + ((try? JSONEncoder().encode(t))?.base64EncodedString() ?? "") }
    static func tokenKey(_ t: ActivityCategoryToken) -> String { "c:" + ((try? JSONEncoder().encode(t))?.base64EncodedString() ?? "") }
    static func appToken(_ key: String) -> ApplicationToken? {
        guard key.hasPrefix("a:"), let data = Data(base64Encoded: String(key.dropFirst(2))) else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }
    static func catToken(_ key: String) -> ActivityCategoryToken? {
        guard key.hasPrefix("c:"), let data = Data(base64Encoded: String(key.dropFirst(2))) else { return nil }
        return try? JSONDecoder().decode(ActivityCategoryToken.self, from: data)
    }
    static func dayString(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func clock(_ t: Double) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "h:mm a"
        return f.string(from: Date(timeIntervalSince1970: t))
    }
    // A one-off interval from just before now until `end`. iOS needs at least 15 minutes, so a shorter one is stretched;
    // the app also tidies up when opened.
    static func startOnce(_ name: String, until end: Date) {
        let cal = Calendar.current, parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let start = Date().addingTimeInterval(-60)
        let stop = max(end, start.addingTimeInterval(16 * 60))
        let center = DeviceActivityCenter(), n = DeviceActivityName(name)
        center.stopMonitoring([n])
        try? center.startMonitoring(n, during: DeviceActivitySchedule(intervalStart: cal.dateComponents(parts, from: start),
                                                                     intervalEnd: cal.dateComponents(parts, from: stop), repeats: false))
    }
    static func now() -> Double { Date().timeIntervalSince1970 }
    // Watchers that belong to the weapons; the game's watcher restart must leave them running.
    static func keeps(_ n: DeviceActivityName) -> Bool { n.rawValue.hasPrefix("cease-") || ["wall", "banish", "treasury", "sentry-pass"].contains(n.rawValue) }

    // ---------- The Sentry: a 5-second pause before a guarded app, then a 15-minute pass ----------
    // "sentry-mode": "one" (free: the one app in "sentry-sel") or "all" (Dynasty: every app on the weapons list). Anything else is off.
    static let passMinutes = 15.0
    static func sentryTarget() -> FamilyActivitySelection? {
        switch d?.string(forKey: "sentry-mode") {
        case "one": return selection("sentry-sel")
        case "all": return targets("sentry")
        default: return nil
        }
    }
    static func passes() -> [String: Double] { (d?.dictionary(forKey: "sentry-passes") as? [String: Double] ?? [:]).filter { $0.value > now() } }
    static func applySentry() {
        let live = passes()
        d?.set(live, forKey: "sentry-passes")
        guard let t = sentryTarget() else { unlock("sentry"); return }
        lock("sentry", t, except: Set(live.keys.compactMap(appToken)), exceptCats: Set(live.keys.compactMap(catToken)))
    }
    // A wait older than 10 minutes starts over.
    static func sentryWaitStarted(_ key: String) -> Double { let t = (d?.dictionary(forKey: "sentry-wait") as? [String: Double])?[key] ?? 0; return t > now() - 600 ? t : 0 }
    static func sentryStartWait(_ key: String) {
        var w = (d?.dictionary(forKey: "sentry-wait") as? [String: Double] ?? [:]).filter { $0.value > now() - 600 }
        w[key] = now(); d?.set(w, forKey: "sentry-wait")
    }
    static func sentryPass(_ key: String) {
        var w = d?.dictionary(forKey: "sentry-wait") as? [String: Double] ?? [:]
        w.removeValue(forKey: key); d?.set(w, forKey: "sentry-wait")
        var p = passes(); let until = now() + passMinutes * 60
        p[key] = until; d?.set(p, forKey: "sentry-passes")
        applySentry()
        startOnce("sentry-pass", until: Date(timeIntervalSince1970: (p.values.max() ?? until)))
    }

    // ---------- Fortress mode (Dynasty): Red apps locked for 1, 2 or 4 hours ----------
    static var fortressUntil: Double { let u = d?.double(forKey: "wall-until") ?? 0; return u > now() ? u : 0 }

    // ---------- Banish (Dynasty): Red apps locked now until morning; can't be undone ----------
    static var morningMinutes: Int { let m = d?.object(forKey: "banish-morning") as? Int ?? 420; return min(max(m, 240), 720) }
    static func nextMorning() -> Date {
        let cal = Calendar.current, m = morningMinutes
        var day = cal.startOfDay(for: Date()).addingTimeInterval(Double(m) * 60)
        if day <= Date() { day = cal.date(byAdding: .day, value: 1, to: day) ?? day }
        return day
    }
    static var banishUntil: Double { let u = d?.double(forKey: "banish-until") ?? 0; return u > now() ? u : 0 }
    static func banish() -> Double {
        guard let r = targets("banish") else { return 0 }
        let until = nextMorning()
        lock("banish", r); d?.set(until.timeIntervalSince1970, forKey: "banish-until")
        startOnce("banish", until: until)
        return until.timeIntervalSince1970
    }
    static func endBanish() { unlock("banish"); d?.removeObject(forKey: "banish-until"); DeviceActivityCenter().stopMonitoring([DeviceActivityName("banish")]) }

    // ---------- Ceasefire (Dynasty): Red apps lock at set times each day ----------
    // "cease-list": [{"name","start","end","days":"all"|"weekdays","on"}], minutes from midnight. Changes start the next day:
    // a new list waits in "cease-next" until "cease-next-day" has passed.
    static func ceaseList() -> [[String: Any]] { d?.array(forKey: "cease-list") as? [[String: Any]] ?? [] }
    static func applyCeasePending() -> Bool {
        guard let day = d?.string(forKey: "cease-next-day"), day < dayString(), let next = d?.array(forKey: "cease-next") else { return false }
        d?.set(next, forKey: "cease-list"); d?.removeObject(forKey: "cease-next"); d?.removeObject(forKey: "cease-next-day")
        return true
    }
    // One repeating interval per piece: a window past midnight is split in two, a weekday window gets one per weekday.
    static func startCeasefires() {
        let center = DeviceActivityCenter()
        center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix("cease-") })
        for (i, w) in ceaseList().enumerated() where (w["on"] as? Bool) == true {
            guard let s = w["start"] as? Int, let e = w["end"] as? Int, s != e else { continue }
            let pieces = s < e ? [(s, e)] : [(s, 24 * 60), (0, e)]
            let days: [Int?] = (w["days"] as? String) == "weekdays" ? [2, 3, 4, 5, 6] : [nil]
            for (p, piece) in pieces.enumerated() where piece.1 - piece.0 >= 15 {
                for wd in days {
                    // A window past midnight on weekdays: its morning half belongs to the next weekday.
                    let day = wd.map { p == 1 ? ($0 % 7) + 1 : $0 }
                    var a = DateComponents(hour: piece.0 / 60, minute: piece.0 % 60), b = piece.1 >= 24 * 60 ? DateComponents(hour: 23, minute: 59, second: 59) : DateComponents(hour: piece.1 / 60, minute: piece.1 % 60)
                    a.weekday = day; b.weekday = day
                    let name = DeviceActivityName("cease-\(i)-\(p)-\(day ?? 0)")
                    try? center.startMonitoring(name, during: DeviceActivitySchedule(intervalStart: a, intervalEnd: b, repeats: true))
                }
            }
        }
    }
    // When the current ceasefire ends (minutes from midnight), for the shield's text.
    static func ceaseEndsAt() -> Double? {
        let cal = Calendar.current, nowM = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        let wd = cal.component(.weekday, from: Date()), weekday = (2...6).contains(wd)
        for w in ceaseList() where (w["on"] as? Bool) == true {
            guard let s = w["start"] as? Int, let e = w["end"] as? Int else { continue }
            if (w["days"] as? String) == "weekdays" && !weekday && s < e { continue }
            let inside = s < e ? (nowM >= s && nowM < e) : (nowM >= s || nowM < e)
            if inside {
                var end = cal.startOfDay(for: Date()).addingTimeInterval(Double(e) * 60)
                if end <= Date() { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
                return end.timeIntervalSince1970
            }
        }
        return nil
    }
    static func ceaseStarted(_ name: String) {
        var on = Set(d?.stringArray(forKey: "cease-on") ?? []); on.insert(name); d?.set(Array(on), forKey: "cease-on")
        if let r = targets("cease") { lock("cease", r) }
    }
    static func ceaseEnded(_ name: String) {
        var on = Set(d?.stringArray(forKey: "cease-on") ?? []); on.remove(name); d?.set(Array(on), forKey: "cease-on")
        if on.isEmpty { unlock("cease") }
    }
    static var ceaseActive: Bool { !(d?.stringArray(forKey: "cease-on") ?? []).isEmpty }

    // ---------- Treasury (Dynasty): a daily allowance for Red apps; they lock until midnight when it runs out ----------
    // "treasury-min": 30, 60 or 120 (0 = off). Changes start the next day ("treasury-next" / "treasury-next-day").
    static var treasuryMinutes: Int { d?.integer(forKey: "treasury-min") ?? 0 }
    static func applyTreasuryPending() -> Bool {
        guard let day = d?.string(forKey: "treasury-next-day"), day < dayString(), let next = d?.object(forKey: "treasury-next") as? Int else { return false }
        d?.set(next, forKey: "treasury-min"); d?.removeObject(forKey: "treasury-next"); d?.removeObject(forKey: "treasury-next-day")
        return true
    }
    static func startTreasury() {
        let center = DeviceActivityCenter(), n = DeviceActivityName("treasury")
        let m = treasuryMinutes
        guard m > 0, let r = targets("treasury") else { center.stopMonitoring([n]); unlock("treasury"); return }
        let ev: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            ev = DeviceActivityEvent(applications: r.applicationTokens, categories: r.categoryTokens, webDomains: r.webDomainTokens, threshold: DateComponents(minute: m), includesPastActivity: true)
        } else {
            ev = DeviceActivityEvent(applications: r.applicationTokens, categories: r.categoryTokens, webDomains: r.webDomainTokens, threshold: DateComponents(minute: m))
        }
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        do { try center.startMonitoring(n, during: schedule, events: [DeviceActivityEvent.Name("spent"): ev]) }
        catch { center.stopMonitoring([n]); try? center.startMonitoring(n, during: schedule, events: [DeviceActivityEvent.Name("spent"): ev]) }
    }
    static func treasurySpent() {
        guard treasuryMinutes > 0, let r = targets("treasury") else { return }
        lock("treasury", r); d?.set(dayString(), forKey: "treasury-out")
    }
    static func treasuryNewDay() { unlock("treasury"); d?.removeObject(forKey: "treasury-out") }
    static var treasuryOut: Bool { d?.string(forKey: "treasury-out") == dayString() }

    // ---------- Herald (Dynasty): a midday check-in with the player's own points left ----------
    // The notification is replaced whenever the points change, so it always says the latest number.
    // It never mentions a rival, a result, a price or Dynasty.
    static let heraldID = "conquer-herald"
    static func scheduleHerald(points: Int) {
        let c = UNUserNotificationCenter.current()
        guard d?.bool(forKey: "herald-on") == true else { c.removePendingNotificationRequests(withIdentifiers: [heraldID]); return }
        let at = d?.object(forKey: "herald-at") as? Int ?? 720
        let cal = Calendar.current
        var when = cal.startOfDay(for: Date()).addingTimeInterval(Double(at) * 60)
        var pts = points
        if when <= Date() { when = cal.date(byAdding: .day, value: 1, to: when) ?? when; pts = 1000 }
        let content = UNMutableNotificationContent()
        content.title = "Midday report from your Herald"
        content.body = pts >= 1000 ? "You have all \(pts) points. Hold the line until dinner." : "You have \(pts) points left. Hold the line until dinner."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: when), repeats: false)
        c.add(UNNotificationRequest(identifier: heraldID, content: content, trigger: trigger))
    }

    // Records which hours Red minutes were used in ("fhour-red-2026-11-27" = {"14": 15}), for Royal Advisor and Missions.
    static func addHour(_ tier: String, _ gained: Int) {
        guard gained > 0 else { return }
        let key = "fhour-" + tier + "-" + dayString()
        var h = d?.dictionary(forKey: key) as? [String: Int] ?? [:]
        let k = String(Calendar.current.component(.hour, from: Date()))
        h[k] = (h[k] ?? 0) + gained
        d?.set(h, forKey: key)
        if tier == "red" { d?.set(now(), forKey: "fred-last") }
    }

    // Which lock is showing on an app right now, for the shield's words. Hard locks come before the Sentry.
    enum Why { case fortress(Double), ceasefire(Double?), banish(Double), treasury, sentry }
    static func why(_ app: ApplicationToken?, category: ActivityCategoryToken? = nil) -> Why {
        let onRed: Bool = { guard let r = targets("wall") ?? targets("banish") else { return false }; return (app.map { r.applicationTokens.contains($0) } ?? false) || (category.map { r.categoryTokens.contains($0) } ?? false) }()
        if onRed {
            if fortressUntil > 0 { return .fortress(fortressUntil) }
            if banishUntil > 0 { return .banish(banishUntil) }
            if ceaseActive { return .ceasefire(ceaseEndsAt()) }
            if treasuryOut { return .treasury }
        }
        return .sentry
    }
}
