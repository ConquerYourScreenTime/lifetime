import Foundation
import Capacitor
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings
import UserNotifications
import WidgetKit
import ActivityKit

// Bridge between the game (index.html) and Apple's Screen Time API.
// Only "the day's total passed N minutes" comes back; never which apps were used.
@objc(ScreenTimePlugin)
public class ScreenTimePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ScreenTimePlugin"
    public let jsName = "ScreenTime"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authorize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pickApps", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "minutesFor", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkLog", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "quickTest", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resync", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "remindOn", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "remindOff", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "env", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "widget", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "liveStart", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "liveEnd", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "nomadWidget", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "lastStep", returnType: CAPPluginReturnPromise),
        // Blip friends game (build 1)
        CAPPluginMethod(name: "tierPick", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tierStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "friendsStart", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "friendsResync", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "friendsMinutes", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "friendsSync", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "friendsWipe", returnType: CAPPluginReturnPromise)
    ]

    static let group = "group.io.github.gamesbyvidal.lifetime"
    static let selectionKey = "selection"
    static let stepMinutes = 5
    static let maxMinutes = 16 * 60

    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.group) }

    @objc func status(_ call: CAPPluginCall) {
        Self.purgeOld(defaults)
        let picked = defaults?.data(forKey: Self.selectionKey) != nil
        // authorizationStatus reads "not determined" for a moment after launch, then loads the real value. Wait up to 3 seconds for it.
        Task { @MainActor in
            var s = AuthorizationCenter.shared.authorizationStatus
            var tries = 0
            while s == .notDetermined && tries < 15 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                s = AuthorizationCenter.shared.authorizationStatus
                tries += 1
            }
            let state = s == .approved ? "approved" : s == .denied ? "denied" : "notDetermined"
            call.resolve(["authorized": s == .approved, "state": state, "picked": picked])
        }
    }

    // Apple's permission prompt has to be asked for on the main thread, or it never appears.
    @objc func authorize(_ call: CAPPluginCall) {
        Task { @MainActor in
            if AuthorizationCenter.shared.authorizationStatus == .approved { call.resolve(["authorized": true]); return }
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                call.resolve(["authorized": true])
            } catch {
                call.resolve(["authorized": false, "error": error.localizedDescription])
            }
        }
    }

    @objc func pickApps(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            // includeEntireCategory: a picked category also covers its websites and apps added later (Safari browsing was being missed).
            var saved = FamilyActivitySelection(includeEntireCategory: true)
            if self.defaults?.bool(forKey: "entireCategory") == true, let data = self.defaults?.data(forKey: Self.selectionKey),
               let old = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { saved = old }
            let picker = PickerView(selection: saved) { picked in
                self.bridge?.viewController?.dismiss(animated: true)
                guard let picked = picked else { call.resolve(["picked": false]); return }
                if let data = try? JSONEncoder().encode(picked) { self.defaults?.set(data, forKey: Self.selectionKey) }
                self.defaults?.set(true, forKey: "entireCategory")
                call.resolve(["picked": true])
            }
            self.bridge?.viewController?.present(UIHostingController(rootView: picker), animated: true)
        }
    }

    // Watches the whole day (midnight to midnight, repeating) with one event per 5 minutes (192 events, up to 16 hours).
    // On iOS 17.4+ each event also counts what was used earlier today (includesPastActivity), so a restart never loses minutes.
    static func startMonitor(_ d: UserDefaults?, reason: String) throws {
        guard let data = d?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            throw NSError(domain: "Blip", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pick apps first"])
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true)
        // The counter watches the picked categories and apps (pick All, then search for Safari and add it: Safari is in no category).
        // Websites are left out on purpose: Safari's own time already covers them, and counting both double counts.
        // History: picked categories + websites missed Safari (Nov 6: 1h vs iPhone 2h21m). An event with no filter
        // ("all activity", build 21) counted idle time (Nov 8: 12h30m vs 1h10m), so it is only watched for the log now.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in stride(from: stepMinutes, through: maxMinutes, by: stepMinutes) {
            let name = DeviceActivityEvent.Name("m\(m)")
            if #available(iOS 17.4, *) {
                events[name] = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens, webDomains: [], threshold: DateComponents(minute: m), includesPastActivity: true)
            } else {
                events[name] = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens, webDomains: [], threshold: DateComponents(minute: m))
            }
        }
        // One time after build 21: today's stored total came from the no-filter counter (idle time included), so start today
        // over. The restart below makes iOS re-send today's real steps (includesPastActivity).
        if d?.bool(forKey: "reset-b22") != true {
            let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            let day = f.string(from: Date())
            d?.removeObject(forKey: "minutes-" + day); d?.removeObject(forKey: "diag-" + day)
            d?.set(true, forKey: "reset-b22")
            log(d, "today's total reset (build 21 counted idle time)")
        }
        let center = DeviceActivityCenter()
        log(d, "restarting counter (" + reason + ")")
        // No stopMonitoring first: starting an activity that is already monitored replaces it, so the counter is never
        // left stopped if iOS suspends Blip between the two calls (Nov 15: daily was off from midnight until Blip opened).
        // Only if iOS refuses the replacement do we stop and start again.
        do { try center.startMonitoring(.daily, during: schedule, events: events) }
        catch {
            log(d, "counter replace refused (" + error.localizedDescription + "), stopping and starting")
            center.stopMonitoring([.daily])
            try center.startMonitoring(.daily, during: schedule, events: events)
        }
        log(d, "counter started, picked categories + apps (" + reason + ")")
        // The old per-category watcher ("cats") is retired: the "picked", "web" and "apps" watchers below replace it.
        center.stopMonitoring([DeviceActivityName("cats"), DeviceActivityName("apps")])
        // TestFlight check: three watchers that are logged only, never counted: websites only, the build 20 counter
        // (categories + apps + websites) and the build 21 counter (no filter).
        func part(_ name: String, apps: Set<ApplicationToken> = [], cats: Set<ActivityCategoryToken> = [], webs: Set<WebDomainToken> = [], all: Bool = false, upTo: Int = 240, step: Int = 15) {
            guard all || !apps.isEmpty || !cats.isEmpty || !webs.isEmpty else { return }
            var ev: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for m in stride(from: step, through: upTo, by: step) {
                let n = DeviceActivityEvent.Name("\(name)\(m)")
                if #available(iOS 17.4, *) {
                    ev[n] = DeviceActivityEvent(applications: apps, categories: cats, webDomains: webs, threshold: DateComponents(minute: m), includesPastActivity: true)
                } else {
                    ev[n] = DeviceActivityEvent(applications: apps, categories: cats, webDomains: webs, threshold: DateComponents(minute: m))
                }
            }
            let a = DeviceActivityName(name)
            center.stopMonitoring([a])
            do { try center.startMonitoring(a, during: schedule, events: ev) }
            catch { Self.log(d, name + " watcher failed: " + error.localizedDescription) }
        }
        part("web", webs: selection.webDomainTokens)
        // The build 20 way (picked apps, categories and websites) and the build 21 way (no filter), side by side.
        part("picked", apps: selection.applicationTokens, cats: selection.categoryTokens, webs: selection.webDomainTokens, upTo: 480)
        part("all", all: true, upTo: 480)
        // The retired "relay" test counter (builds 27-28) re-fired within a minute of each re-arm on iOS 26: stop it if still running.
        center.stopMonitoring([DeviceActivityName("relay")])
        log(d, d?.bool(forKey: "entireCategory") == true ? "whole categories incl. websites: on" : "whole categories incl. websites: OFF (re-pick in Change what counts)")
    }

    // Restarting the watchers is a slow call into iOS. Capacitor runs every plugin call on one shared queue, so a slow restart
    // used to hold up everything behind it (the Screen Time check timed out on Nov 8). Restarts now run on their own queue.
    static let work = DispatchQueue(label: "io.github.gamesbyvidal.lifetime.screentime")

    @objc func start(_ call: CAPPluginCall) {
        let d = defaults
        Self.work.async {
            do {
                try Self.startMonitor(d, reason: "connect or change what counts")
                d?.set(Date().timeIntervalSince1970, forKey: "last-resync")
                call.resolve(["started": true])
            } catch {
                call.reject("Could not start: \(error.localizedDescription)")
            }
        }
    }

    // Called each time the app opens. On iOS 17.4+ restarting with includesPastActivity makes iOS re-check today's
    // full total and re-send any 5-minute steps it missed. Older iOS would lose earlier minutes on a restart, so it skips.
    @objc func resync(_ call: CAPPluginCall) {
        guard #available(iOS 17.4, *) else { call.resolve(["resynced": false]); return }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { call.resolve(["resynced": false]); return }
        // At most every 10 minutes: each restart makes iOS re-send all of today's steps.
        let d = defaults
        if let last = d?.double(forKey: "last-resync"), Date().timeIntervalSince1970 - last < 600 { call.resolve(["resynced": false]); return }
        d?.set(Date().timeIntervalSince1970, forKey: "last-resync")
        Self.work.async {
            do {
                try Self.startMonitor(d, reason: "app opened, re-sync")
                call.resolve(["resynced": true])
            } catch {
                Self.log(d, "re-sync failed: " + error.localizedDescription)
                call.resolve(["resynced": false])
            }
        }
    }

    // day: "YYYY-MM-DD" in the phone's time zone. Returns the highest 5-minute step reached, or null.
    @objc func minutesFor(_ call: CAPPluginCall) {
        let day = call.getString("day") ?? ""
        defaults?.synchronize() // pick up steps the background counter just wrote
        if let m = defaults?.object(forKey: "minutes-" + day) as? Int { call.resolve(["minutes": m]) }
        else { call.resolve(["minutes": NSNull()]) }
    }

    // TestFlight "Screen Time check": the day's log of when each 5-minute step arrived, plus what is being counted.
    static func log(_ d: UserDefaults?, _ what: String) {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let t = DateFormatter(); t.locale = Locale(identifier: "en_US_POSIX"); t.dateFormat = "HH:mm"
        let key = "log-" + f.string(from: Date())
        var list = d?.stringArray(forKey: key) ?? []
        list.append(t.string(from: Date()) + " " + what)
        d?.set(list, forKey: key)
    }
    @objc func checkLog(_ call: CAPPluginCall) {
        let day = call.getString("day") ?? ""
        var apps = 0, cats = 0, webs = 0
        if let data = defaults?.data(forKey: Self.selectionKey), let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            apps = sel.applicationTokens.count; cats = sel.categoryTokens.count; webs = sel.webDomainTokens.count
        }
        let acts = DeviceActivityCenter().activities.map { $0.rawValue }
        call.resolve(["log": Array((defaults?.stringArray(forKey: "log-" + day) ?? []).suffix(300)), "apps": apps, "categories": cats, "webDomains": webs, "watching": acts,
                      "diag": defaults?.dictionary(forKey: "diag-" + day) ?? [:],
                      "hours": defaults?.dictionary(forKey: "hours-" + day) ?? [:],
                      "qt": defaults?.dictionary(forKey: "qt-best") ?? [:], "qtStart": defaults?.double(forKey: "qt-start") ?? 0])
    }

    // TestFlight quick test: four counting methods side by side from this moment for one hour, in 1-minute steps,
    // counting only use AFTER the tap (includesPastActivity false). Lets us compare against iPhone Screen Time many times a day.
    // Logged only, never counted toward the Blip.
    static let qtNames = ["qt-counter", "qt-web", "qt-all", "qt-cats"]
    @objc func quickTest(_ call: CAPPluginCall) {
        guard let d = defaults, let data = d.data(forKey: Self.selectionKey),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { call.reject("Pick apps first"); return }
        Self.work.async { Self.runQuickTest(d, sel, call) }
    }
    static func runQuickTest(_ d: UserDefaults, _ sel: FamilyActivitySelection, _ call: CAPPluginCall) {
        let cal = Calendar.current, now = Date()
        let startDate = now.addingTimeInterval(-120)
        var endDate = now.addingTimeInterval(3600)
        if !cal.isDate(endDate, inSameDayAs: now) { endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? endDate }
        if endDate.timeIntervalSince(startDate) < 16 * 60 { call.reject("Too close to midnight. Try after 12:05 AM."); return }
        let comps: (Date) -> DateComponents = { cal.dateComponents([.hour, .minute, .second], from: $0) }
        let schedule = DeviceActivitySchedule(intervalStart: comps(startDate), intervalEnd: comps(endDate), repeats: false)
        let center = DeviceActivityCenter()
        center.stopMonitoring(Self.qtNames.map { DeviceActivityName($0) })
        d.removeObject(forKey: "qt-best")
        d.set(now.timeIntervalSince1970, forKey: "qt-start")
        let sets: [(String, Set<ApplicationToken>, Set<ActivityCategoryToken>, Set<WebDomainToken>)] = [
            ("qt-counter", sel.applicationTokens, sel.categoryTokens, []),        // the real counter (categories + apps incl. Safari)
            ("qt-web", sel.applicationTokens, sel.categoryTokens, sel.webDomainTokens), // build 20 way (with websites)
            ("qt-all", [], [], []),                                               // build 21 way (no filter)
            ("qt-cats", [], sel.categoryTokens, [])                               // categories only (without Safari and other picked apps)
        ]
        var failed: [String] = []
        for (name, apps, cats, webs) in sets {
            var ev: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for m in 1...60 {
                let n = DeviceActivityEvent.Name("t\(m)")
                if #available(iOS 17.4, *) {
                    ev[n] = DeviceActivityEvent(applications: apps, categories: cats, webDomains: webs, threshold: DateComponents(minute: m), includesPastActivity: false)
                } else {
                    ev[n] = DeviceActivityEvent(applications: apps, categories: cats, webDomains: webs, threshold: DateComponents(minute: m))
                }
            }
            do { try center.startMonitoring(DeviceActivityName(name), during: schedule, events: ev) }
            catch { failed.append(name + ": " + error.localizedDescription) }
        }
        Self.log(d, "quick test started" + (failed.isEmpty ? "" : " (failed: " + failed.joined(separator: "; ") + ")"))
        call.resolve(["started": failed.count < sets.count, "failed": failed])
    }

    // Daily totals are only kept for about a week (privacy policy). Keys look like "minutes-YYYY-MM-DD".
    static let keepDays = 8
    static func purgeOld(_ d: UserDefaults?) {
        guard let d = d else { return }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) else { return }
        let oldest = f.string(from: cutoff)
        for key in d.dictionaryRepresentation().keys {
            if key.hasPrefix("minutes-"), String(key.dropFirst(8)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("log-"), String(key.dropFirst(4)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("diag-"), String(key.dropFirst(5)) < oldest { d.removeObject(forKey: key) }
            if key.hasPrefix("hours-"), String(key.dropFirst(6)) < oldest { d.removeObject(forKey: key) }
        }
    }

    // Optional morning reminder, off until the player turns it on in Settings (the permission prompt shows only then).
    // One a day, and it only says the next year is ready: never results, minutes, streaks or the shop.
    static let reminderID = "blip-morning"
    @objc func remindOn(_ call: CAPPluginCall) {
        let name = call.getString("name") ?? "Your Blip"
        let hour = call.getInt("hour") ?? 8, minute = call.getInt("minute") ?? 0
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { call.resolve(["granted": false]); return }
            let content = UNMutableNotificationContent()
            content.body = call.getString("body") ?? "\(name)'s next year is ready" // Nomad sends its own morning line
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
            center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
            center.add(UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger)) { err in
                call.resolve(["granted": err == nil])
            }
        }
    }
    // TestFlight builds have a sandbox receipt; App Store builds don't. Testing tools only show in TestFlight.
    // What Blip's widget draws besides the count: goal, name, age, streak and the Blip's look. On this phone only.
    @objc func widget(_ call: CAPPluginCall) {
        var info: [String: Any] = [:]
        info["goal"] = call.getInt("goal") ?? 120
        info["name"] = call.getString("name") ?? ""
        info["age"] = call.getInt("age") ?? 0
        info["streak"] = call.getInt("streak") ?? 0
        info["skin"] = call.getString("skin") ?? "#f1c27d"
        info["hair"] = call.getString("hair") ?? "#3b2a4a"
        info["girl"] = call.getBool("girl") ?? false
        info["glum"] = call.getBool("glum") ?? false
        // The player's own Blip, drawn by the app (only sent when the look changes).
        var newArt = false
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group) {
            for name in ["faceHappy", "faceGlum", "faceNeutral", "bodyHappy", "bodyGlum", "lineHappy", "lineGlum", "lineNeutral"] {
                if let b64 = call.getString(name), let data = Data(base64Encoded: b64) {
                    try? data.write(to: dir.appendingPathComponent("widget-" + name + ".png"), options: .atomic)
                    newArt = true
                }
            }
        }
        let old = defaults?.dictionary(forKey: "widget") as NSDictionary?
        if newArt || old == nil || !old!.isEqual(to: info) { defaults?.set(info, forKey: "widget") }
        // Always redraw while Blip is open (free for apps in the foreground), on top of the monitor's redraws.
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    @objc func env(_ call: CAPPluginCall) {
        call.resolve(["testflight": Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"])
    }
    @objc func remindOff(_ call: CAPPluginCall) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        call.resolve()
    }
}

extension DeviceActivityName { static let daily = Self("daily") }

private struct PickerView: View {
    @State var selection: FamilyActivitySelection
    let done: (FamilyActivitySelection?) -> Void
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Tick All, then search Safari")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { done(selection) } }
                }
        }
    }
}

// ---------- Blip Nomad: the lock-screen countdown (Live Activity), started from the app ----------
// Keep BlipTripAttributes identical to the copy in BlipWidget.swift.
struct BlipTripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var emoji: String
        var next: String
        var start: Date
        var end: Date
    }
    var name: String
}

extension ScreenTimePlugin {
    // Starts the countdown, or updates the one already showing. endsAt is in milliseconds (JavaScript time).
    @objc func liveStart(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else { call.resolve(["ok": false, "reason": "ios"]); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { call.resolve(["ok": false, "reason": "off"]); return }
        if let b64 = call.getString("icon"), let data = Data(base64Encoded: b64),
           let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group) {
            try? data.write(to: dir.appendingPathComponent("live-icon.png"), options: .atomic)
        }
        let end = Date(timeIntervalSince1970: (call.getDouble("endsAt") ?? Date().timeIntervalSince1970 * 1000) / 1000)
        let state = BlipTripAttributes.ContentState(title: call.getString("title") ?? "", emoji: call.getString("emoji") ?? "🎒",
                                                    next: call.getString("next") ?? "", start: Date(), end: max(end, Date().addingTimeInterval(60)))
        let content = ActivityContent(state: state, staleDate: state.end)
        let name = call.getString("name") ?? "Blip"
        Task {
            if let a = Activity<BlipTripAttributes>.activities.first, a.attributes.name == name {
                await a.update(content)
                call.resolve(["ok": true])
                return
            }
            for a in Activity<BlipTripAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            do {
                _ = try Activity.request(attributes: BlipTripAttributes(name: name), content: content, pushType: nil)
                call.resolve(["ok": true])
            } catch {
                call.resolve(["ok": false, "reason": error.localizedDescription])
            }
        }
    }
    @objc func liveEnd(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else { call.resolve(); return }
        Task {
            for a in Activity<BlipTripAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            call.resolve()
        }
    }
}

// Blip Nomad widgets (build 33, Lawyer OK 2026-11-20): what Sam is up to, the Coins and the saving goal. Status only, never shop items,
// prices or promotions. Kept in the App Group on this phone only; the widget works out the next Coin from Blip's count.
extension ScreenTimePlugin {
    @objc func nomadWidget(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        var info: [String: Any] = [:]
        for k in ["name", "act", "emoji", "readyTitle", "save", "saveShort", "job"] { info[k] = call.getString(k) ?? "" }
        for k in ["coins", "today", "count", "goal", "prog", "need", "ready", "cost"] { info[k] = call.getInt(k) ?? 0 }
        info["down"] = call.getDouble("down") ?? 0
        info["t"] = call.getDouble("t") ?? Date().timeIntervalSince1970 * 1000
        for k in ["over", "room", "sunrise"] { info[k] = call.getBool(k) ?? false }
        if let b64 = call.getString("scene"), let data = Data(base64Encoded: b64),
           let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group) {
            try? data.write(to: dir.appendingPathComponent("nomad-scene.png"), options: .atomic)
        }
        d?.set(info, forKey: "nomad")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }
    // When Blip's count took its last 5-minute step on a day (for the sunrise gem). Milliseconds, or 0 if there was none.
    @objc func lastStep(_ call: CAPPluginCall) {
        let day = call.getString("day") ?? ""
        let rec = UserDefaults(suiteName: Self.group)?.dictionary(forKey: "at-daily-" + day) as? [String: Double] ?? [:]
        call.resolve(["t": (rec["t"] ?? 0) * 1000, "m": rec["m"] ?? 0])
    }
}

// ---------- Blip friends game (build 1, plan v2 + Lawyer OK 2026-11-25) ----------
// Three tiers, each a fixed set of Apple categories the player ticks in Apple's picker: Red (Social, Entertainment),
// Orange (Games, Shopping & Food, Safari), Yellow (Creativity, Information & Reading, Health & Fitness, Other).
// Anything not picked costs nothing (Free). Each tier is watched in 15-minute steps; only the highest step per tier per day
// is kept, in the App Group on this phone. The only thing that ever leaves the phone is the day's points total
// (BlipMonitor uploads it just after midnight; see MonitorExtension.swift). Never minutes, apps or tiers.
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

private struct TierPickerView: View {
    @State var selection: FamilyActivitySelection
    let title: String
    let done: (FamilyActivitySelection?) -> Void
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { done(selection) } }
                }
        }
    }
}

extension ScreenTimePlugin {
    // tier: red | orange | yellow. Opens Apple's picker with the tier's own title (the screen before it lists what to tick).
    @objc func tierPick(_ call: CAPPluginCall) {
        let tier = call.getString("tier") ?? ""
        guard Friends.tiers.contains(tier) else { call.reject("Unknown tier"); return }
        let d = UserDefaults(suiteName: Self.group)
        let titles = ["red": "Red: Social, Entertainment", "orange": "Orange: Games, Shopping, Safari", "yellow": "Yellow: the rest"]
        DispatchQueue.main.async {
            var saved = FamilyActivitySelection(includeEntireCategory: true)
            let key = d?.data(forKey: "tier-next-" + tier) != nil ? "tier-next-" + tier : "tier-" + tier
            if let data = d?.data(forKey: key), let old = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { saved = old }
            let picker = TierPickerView(selection: saved, title: titles[tier]!) { picked in
                self.bridge?.viewController?.dismiss(animated: true)
                guard let picked = picked, let data = try? JSONEncoder().encode(picked) else { call.resolve(["picked": false]); return }
                // Before the first start, picks apply right away. After that, they apply from tomorrow.
                let later = d?.bool(forKey: "friends-ready") == true
                if later { d?.set(data, forKey: "tier-next-" + tier); d?.set(Friends.dayString(), forKey: "tier-next-day") }
                else { d?.set(data, forKey: "tier-" + tier) }
                call.resolve(["picked": true, "tomorrow": later])
            }
            self.bridge?.viewController?.present(UIHostingController(rootView: picker), animated: true)
        }
    }
    // How many apps and categories each tier has (counts only; Apple never tells us which).
    @objc func tierStatus(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        var out: [String: Any] = ["ready": d?.bool(forKey: "friends-ready") == true, "pending": d?.string(forKey: "tier-next-day") != nil,
                                  "since": d?.string(forKey: "friends-since") ?? ""]
        for t in Friends.tiers {
            let s = Friends.selection(d, t)
            out[t] = ["apps": s?.applicationTokens.count ?? 0, "categories": s?.categoryTokens.count ?? 0]
        }
        call.resolve(out)
    }
    @objc func friendsStart(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        Self.work.async {
            do { try Friends.startWatchers(d); d?.set(Date().timeIntervalSince1970, forKey: "friends-resync"); call.resolve(["started": true]) }
            catch { call.reject("Could not start: \(error.localizedDescription)") }
        }
    }
    // Each app open: apply tomorrow's tier changes once the day has turned, and (iOS 17.4+, at most every 10 minutes)
    // restart the watchers so iOS re-sends any 15-minute steps it missed.
    @objc func friendsResync(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        guard d?.bool(forKey: "friends-ready") == true, AuthorizationCenter.shared.authorizationStatus == .approved else { call.resolve(["resynced": false]); return }
        let applied = Friends.applyPending(d)
        var due = applied
        if #available(iOS 17.4, *) { due = due || Date().timeIntervalSince1970 - (d?.double(forKey: "friends-resync") ?? 0) > 600 }
        guard due else { call.resolve(["resynced": false]); return }
        d?.set(Date().timeIntervalSince1970, forKey: "friends-resync")
        Self.work.async {
            do { try Friends.startWatchers(d); call.resolve(["resynced": true, "applied": applied]) }
            catch { call.resolve(["resynced": false]) }
        }
    }
    // day: "YYYY-MM-DD". Minutes per tier (15-minute steps) and the day's points, on this phone only.
    @objc func friendsMinutes(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        d?.synchronize()
        let day = call.getString("day") ?? Friends.dayString()
        var out: [String: Any] = [:]
        var m: [String: Int] = [:]
        for t in Friends.tiers { let v = d?.integer(forKey: "fmin-" + t + "-" + day) ?? 0; m[t] = v; out[t] = v }
        out["points"] = Friends.points(red: m["red"]!, orange: m["orange"]!, yellow: m["yellow"]!)
        out["sent"] = d?.bool(forKey: "fsent-" + day) == true
        Friends.purge(d)
        call.resolve(out)
    }
    // What BlipMonitor needs to send the points total at midnight: the online service's public key and project,
    // this player's anonymous sign-in token and the match code. Pass nothing to clear it.
    @objc func friendsSync(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        if let sent = call.getString("sentDay") { d?.set(true, forKey: "fsent-" + sent); call.resolve(); return }
        var info: [String: String] = [:]
        for k in ["apiKey", "projectId", "refreshToken", "uid", "match"] { if let v = call.getString(k), !v.isEmpty { info[k] = v } }
        if info.count == 5 { d?.set(info, forKey: "friends-sync") } else { d?.removeObject(forKey: "friends-sync") }
        call.resolve()
    }
    // "Delete my data": stops the watchers and removes everything this game kept on the phone.
    @objc func friendsWipe(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        DeviceActivityCenter().stopMonitoring((Friends.tiers.map { "tier-" + $0 } + ["fclock"]).map { DeviceActivityName($0) })
        for key in (d?.dictionaryRepresentation() ?? [:]).keys where key.hasPrefix("fmin-") || key.hasPrefix("fsent-") || key.hasPrefix("at-tier-")
            || key.hasPrefix("tier-") || key.hasPrefix("friends-") { d?.removeObject(forKey: key) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        call.resolve()
    }
}
