import Foundation
import Capacitor
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings
import UserNotifications
import WidgetKit
import ActivityKit
import AVFoundation
import UIKit

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
        CAPPluginMethod(name: "friendsWipe", returnType: CAPPluginReturnPromise),
        // Conquer Your Screen Time (build 4)
        CAPPluginMethod(name: "notifySchedule", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "conquerWidget", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "haptic", returnType: CAPPluginReturnPromise),
        // Dynasty tools (build 5)
        CAPPluginMethod(name: "wallStart", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "wallStop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "wallStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "weaponStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "weaponsResume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sentryPick", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sentrySet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "banishStart", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "banishMorning", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "ceaseSet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "treasurySet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "heraldSet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "redHours", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "guardLabels", returnType: CAPPluginReturnPromise)
    ]

    static let group = "group.io.github.gamesbyvidal.lifetime"
    static let selectionKey = "selection"
    static let stepMinutes = 5
    static let maxMinutes = 16 * 60

    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.group) }

    // Capacitor's notification router owns the notification delegate once the bridge is up; Conquer's 8 AM
    // notification actions are handled through it.
    override public func load() {
        bridge?.notificationRouter.localNotificationHandler = Conquer.notes
        Conquer.registerCategory()
    }

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
            throw NSError(domain: "Conquer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pick apps first"])
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
        let name = call.getString("name") ?? "Conquer"
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
        Conquer.clearMornings { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID]); call.resolve() }
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
        let name = call.getString("name") ?? "Conquer"
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
// Two tiers, each a fixed set of Apple categories the player ticks in Apple's picker: Red (Social, Entertainment),
// Orange (Games, Shopping & Food, Safari). Two tiers only (Matthew 2026-11-25: Yellow dropped to make setup easier).
// Anything not picked costs nothing (Free). Each tier is watched in 15-minute steps; only the highest step per tier per day
// is kept, in the App Group on this phone. The only thing that ever leaves the phone is the day's points total
// (BlipMonitor uploads it just after midnight; see MonitorExtension.swift). Never minutes, apps or tiers.
enum Friends {
    static let tiers = ["red", "orange"]
    static let cost = ["red": 40, "orange": 20]   // points per 15 minutes, the same for every player
    static let bank = 1000
    static let step = 15
    static let maxMinutes = 16 * 60
    static let keepDays = 41   // daily totals are kept 40 days (Lawyer ruling 2026-11-25)

    static func dayString(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func points(red: Int, orange: Int) -> Int {
        let spent = (red / step) * cost["red"]! + (orange / step) * cost["orange"]!
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
        let mine = Set((tiers.map { "tier-" + $0 } + ["fclock", "wall"]).map { DeviceActivityName($0) })  // "wall" = Fortress mode
        center.stopMonitoring(center.activities.filter { !mine.contains($0) && !Weapons.keeps($0) })
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
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("fmin-") || key.hasPrefix("fhour-") || key.hasPrefix("fsent-") || key.hasPrefix("at-tier-") {
            let day = key.split(separator: "-").suffix(3).joined(separator: "-")
            if day < oldest { d.removeObject(forKey: key) }
        }
    }
}

// Apple's list with a card pinned above it that keeps showing what to tick, so the player never has to remember it
// or go back. The card counts ticks as they happen (Apple gives counts, never names) and turns green when they match.
// Styled in Blip Friends' Black and Gold look; the sheet is forced dark so Apple's list matches the card.
private enum ConquerStyle {
    static let bg = Color(red: 0x0d/255, green: 0x0d/255, blue: 0x0f/255)
    static let card = Color(red: 0x1c/255, green: 0x1c/255, blue: 0x21/255)
    static let ink = Color(red: 0xf5/255, green: 0xf1/255, blue: 0xe6/255)
    static let dim = Color(red: 0xb5/255, green: 0xad/255, blue: 0x99/255)
    static let ivory = Color(red: 0xec/255, green: 0xe4/255, blue: 0xd0/255)
    static let free = Color(red: 0x6f/255, green: 0xc2/255, blue: 0x9b/255)
    static let red = Color(red: 0xe8/255, green: 0x6a/255, blue: 0x74/255)
    static let orange = Color(red: 0xdc/255, green: 0x9c/255, blue: 0x55/255)
}
private struct TierPickerView: View {
    @State var selection: FamilyActivitySelection
    let title: String
    let tier: String
    let ticks: [String]
    let wantCategories: Int
    let wantApps: Int
    let done: (FamilyActivitySelection?) -> Void
    private var cats: Int { selection.categoryTokens.count }
    private var apps: Int { selection.applicationTokens.count }
    private var matches: Bool { cats == wantCategories && apps == wantApps }
    private var tierColor: Color { tier == "red" ? ConquerStyle.red : ConquerStyle.orange }
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tick these, then tap Done").font(.subheadline).foregroundColor(ConquerStyle.dim)
                    ForEach(ticks, id: \.self) { t in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle").foregroundColor(tierColor)
                            Text(t).fontWeight(.semibold).foregroundColor(ConquerStyle.ink)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: matches ? "checkmark.circle.fill" : "circle.dashed")
                        Text(matches ? "All set. Tap Done." : "Ticked: \(cats) of \(wantCategories) categories" + (wantApps > 0 ? ", \(apps) of \(wantApps) app" : ""))
                    }
                    .font(matches ? Font.footnote.weight(.semibold) : Font.footnote)
                    .foregroundColor(matches ? ConquerStyle.free : ConquerStyle.dim)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(ConquerStyle.card))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(matches ? ConquerStyle.free.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
                .background(ConquerStyle.bg)
                FamilyActivityPicker(selection: $selection)
            }
            .background(ConquerStyle.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Circle().fill(tierColor).frame(width: 10, height: 10)
                        Text(title).font(.system(.headline, design: .serif)).foregroundColor(ConquerStyle.ink)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }.foregroundColor(ConquerStyle.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { done(selection) }) { Text("Done").fontWeight(.semibold) }.foregroundColor(ConquerStyle.ivory)
                }
            }
        }
        .navigationViewStyle(.stack)
        .accentColor(ConquerStyle.ivory)
        .preferredColorScheme(.dark)
    }
}

extension ScreenTimePlugin {
    // tier: red | orange. ticks: the names to show above Apple's list. categories/apps: how many to expect.
    // Resolves with the counts picked, so the web side can say "that doesn't look right" if they don't match.
    @objc func tierPick(_ call: CAPPluginCall) {
        let tier = call.getString("tier") ?? ""
        guard Friends.tiers.contains(tier) else { call.reject("Unknown tier"); return }
        let d = UserDefaults(suiteName: Self.group)
        let titles = ["red": "Red: 40 points per 15 min", "orange": "Orange: 20 points per 15 min"]
        let ticks = (call.getArray("ticks", String.self) ?? []).filter { !$0.isEmpty }
        let wantCategories = call.getInt("categories") ?? 0, wantApps = call.getInt("apps") ?? 0
        DispatchQueue.main.async {
            var saved = FamilyActivitySelection(includeEntireCategory: true)
            let key = d?.data(forKey: "tier-next-" + tier) != nil ? "tier-next-" + tier : "tier-" + tier
            if let data = d?.data(forKey: key), let old = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { saved = old }
            let picker = TierPickerView(selection: saved, title: titles[tier]!, tier: tier, ticks: ticks, wantCategories: wantCategories, wantApps: wantApps) { picked in
                self.bridge?.viewController?.dismiss(animated: true)
                guard let picked = picked, let data = try? JSONEncoder().encode(picked) else { call.resolve(["picked": false]); return }
                // Before the first start, picks apply right away. After that, they apply from tomorrow.
                let later = d?.bool(forKey: "friends-ready") == true
                if later { d?.set(data, forKey: "tier-next-" + tier); d?.set(Friends.dayString(), forKey: "tier-next-day") }
                else { d?.set(data, forKey: "tier-" + tier) }
                call.resolve(["picked": true, "tomorrow": later, "categories": picked.categoryTokens.count, "apps": picked.applicationTokens.count])
            }
            let host = UIHostingController(rootView: picker)
            host.overrideUserInterfaceStyle = .dark  // Apple's list follows this, so it matches the Black and Gold card
            self.bridge?.viewController?.present(host, animated: true)
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
        out["points"] = Friends.points(red: m["red"]!, orange: m["orange"]!)
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
        d?.removeObject(forKey: Conquer.widgetKey)
        Conquer.lowerWall(d)
        WidgetCenter.shared.reloadAllTimelines()
        Conquer.clearMornings { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID]); call.resolve() }
    }

    // ---------- Conquer Your Screen Time (build 4) ----------

    // The 8 AM notifications for the next 7 mornings, each with its own words (one rival, several, Monday).
    // items: [{day: "YYYY-MM-DD", body}]. Never a winner or a score. The wax seal is the picture; actions
    // "Break the seal" (opens the app, which shows the reveal) and "Remind me in an hour" (handled in AppDelegate).
    @objc func notifySchedule(_ call: CAPPluginCall) {
        let hour = call.getInt("hour") ?? 8
        let items = (call.getArray("items", JSObject.self) ?? []).compactMap { o -> (String, String)? in
            guard let day = o["day"] as? String, let body = o["body"] as? String else { return nil }
            return (day, body)
        }
        let center = UNUserNotificationCenter.current()
        Conquer.registerCategory()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { call.resolve(["granted": false]); return }
            Conquer.clearMornings {
                center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])  // the older single daily reminder
                let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
                let group = DispatchGroup()
                for (day, body) in items {
                    guard let date = f.date(from: day) else { continue }
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    comps.hour = hour; comps.minute = 0
                    let req = UNNotificationRequest(identifier: Conquer.morningPrefix + day, content: Conquer.content(body),
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                    group.enter(); center.add(req) { _ in group.leave() }
                }
                group.notify(queue: .main) { call.resolve(["granted": true]) }
            }
        }
    }

    // What the widgets show besides today's points: how many rivals, crowns held, week leads, and whether the
    // seal is broken (a result is never shown before that). On this phone only.
    @objc func conquerWidget(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        var info: [String: Any] = [:]
        for k in ["rivals", "held", "of", "weekLead", "weekOf", "revealedAt", "me"] { if let v = call.getInt(k) { info[k] = v } }
        info["rows"] = (call.getArray("rows", JSObject.self) ?? []).prefix(6).compactMap { o -> [String: Any]? in
            guard let n = o["n"] as? String, let dv = o["d"] as? Int else { return nil }
            return ["n": n, "d": dv]
        }
        info["revealed"] = call.getBool("revealed") ?? false
        info["resultDay"] = call.getString("resultDay") ?? ""
        if call.getInt("rivals") == nil { d?.removeObject(forKey: Conquer.widgetKey) } else { d?.set(info, forKey: Conquer.widgetKey) }
        Conquer.shareFont()
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    // ---------- Fortress mode (Dynasty; was Shield Wall): one tap locks the Red apps for 1, 2 or 4 hours ----------
    // Uses the Red apps and categories the player ticked at setup. Apple's standard shield covers them until the time
    // is up; BlipMonitor lowers it when the "wall" interval ends, even if the app is closed. Scoring is unchanged.
    @objc func wallStart(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        let hours = max(1, min(4, call.getInt("hours") ?? 1))
        guard let sel = Friends.selection(d, "red"), !(sel.applicationTokens.isEmpty && sel.categoryTokens.isEmpty) else { call.reject("No Red apps picked"); return }
        let now = Date(), end = now.addingTimeInterval(Double(hours) * 3600)
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("wall"))
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        d?.set(end.timeIntervalSince1970, forKey: "wall-until")
        let cal = Calendar.current, parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: cal.dateComponents(parts, from: now.addingTimeInterval(-60)),
                                              intervalEnd: cal.dateComponents(parts, from: end), repeats: false)
        let center = DeviceActivityCenter(), name = DeviceActivityName("wall")
        center.stopMonitoring([name])
        do { try center.startMonitoring(name, during: schedule) } catch { /* the app also lowers it when opened after the end */ }
        call.resolve(["until": end.timeIntervalSince1970])
    }
    // Leaving early (after the 30-second wait in the app) or when time is up.
    @objc func wallStop(_ call: CAPPluginCall) {
        Conquer.lowerWall(UserDefaults(suiteName: Self.group))
        call.resolve()
    }
    @objc func wallStatus(_ call: CAPPluginCall) {
        let d = UserDefaults(suiteName: Self.group)
        let until = d?.double(forKey: "wall-until") ?? 0
        if until > 0 && until <= Date().timeIntervalSince1970 { Conquer.lowerWall(d); call.resolve(["until": 0]); return }
        call.resolve(["until": until])
    }

    // Handoff section 13: seal = one firm tap; win = success haptic + one short chime; loss = one soft tap. Nothing else.
    @objc func haptic(_ call: CAPPluginCall) {
        let kind = call.getString("kind") ?? ""
        DispatchQueue.main.async {
            switch kind {
            case "seal": UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            case "win": UINotificationFeedbackGenerator().notificationOccurred(.success); Conquer.chime()
            case "loss": UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            default: break
            }
            call.resolve()
        }
    }
}

enum Conquer {
    static let group = "group.io.github.gamesbyvidal.lifetime"
    static let widgetKey = "conquer-widget"
    static let morningPrefix = "conquer-morning-"
    static let category = "conquer-seal"
    static let actionBreak = "break-seal"
    static let actionLater = "remind-hour"
    private static var player: AVAudioPlayer?
    static let notes = ConquerNotes()

    // "Remind me in an hour": the same words again, an hour later.
    static func handle(_ response: UNNotificationResponse, done: @escaping () -> Void) {
        guard response.actionIdentifier == actionLater else { done(); return }
        let req = UNNotificationRequest(identifier: "conquer-later-\(UUID().uuidString)", content: content(response.notification.request.content.body),
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false))
        UNUserNotificationCenter.current().add(req) { _ in done() }
    }

    static func lowerWall(_ d: UserDefaults?) {
        ManagedSettingsStore(named: ManagedSettingsStore.Name("wall")).clearAllSettings()
        DeviceActivityCenter().stopMonitoring([DeviceActivityName("wall")])
        d?.removeObject(forKey: "wall-until")
    }
    static func registerCategory() {
        let open = UNNotificationAction(identifier: actionBreak, title: "Break the seal", options: [.foreground])
        let later = UNNotificationAction(identifier: actionLater, title: "Remind me in an hour", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier: category, actions: [open, later], intentIdentifiers: [], options: [])])
    }
    static func clearMornings(_ done: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map { $0.identifier }.filter { $0.hasPrefix(morningPrefix) || $0.hasPrefix("conquer-later") })
            done()
        }
    }
    // The wax seal picture (www/seal.png in the app bundle). iOS moves an attachment's file, so each one gets its own copy.
    static func content(_ body: String) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.body = body
        c.sound = .default
        c.categoryIdentifier = category
        if let src = Bundle.main.url(forResource: "seal", withExtension: "png", subdirectory: "public") {
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent("seal-\(UUID().uuidString).png")
            if (try? FileManager.default.copyItem(at: src, to: dst)) != nil,
               let a = try? UNNotificationAttachment(identifier: "seal", url: dst, options: nil) { c.attachments = [a] }
        }
        return c
    }
    // The widgets use Playfair Display too: a copy of the app's bundled font goes into the shared App Group once.
    static func shareFont() {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let src = Bundle.main.url(forResource: "PlayfairDisplay-Bold", withExtension: "ttf", subdirectory: "public/fonts") else { return }
        let dst = dir.appendingPathComponent("PlayfairDisplay-Bold.ttf")
        if !FileManager.default.fileExists(atPath: dst.path) { try? FileManager.default.copyItem(at: src, to: dst) }
    }
    // One short, warm chime that follows the silent switch (.ambient).
    static func chime() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav", subdirectory: "public") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.8
        player?.play()
    }
}

class ConquerNotes: NSObject, NotificationHandlerProtocol {
    func willPresent(notification: UNNotification) -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
    func didReceive(response: UNNotificationResponse) { Conquer.handle(response) {} }
}


// ---------- Weapons against screen time (design handoff sections 18 to 20; the rules are in Shared/Weapons.swift) ----------
extension ScreenTimePlugin {
    // Everything My Armory shows. Counts and times only: Apple never tells the app which apps were picked.
    @objc func weaponStatus(_ call: CAPPluginCall) {
        let d = Weapons.d
        let s = Weapons.selection("sentry-sel")
        let pend = d?.array(forKey: "cease-next")
        let out: [String: Any] = [
            "sentry": ["mode": d?.string(forKey: "sentry-mode") ?? "off", "apps": s?.applicationTokens.count ?? 0, "since": d?.string(forKey: "sentry-since") ?? ""] as [String: Any],
            "red": ["apps": Weapons.red?.applicationTokens.count ?? 0, "cats": Weapons.red?.categoryTokens.count ?? 0, "webs": Weapons.red?.webDomainTokens.count ?? 0] as [String: Any],
            "fortress": Weapons.fortressUntil,
            "banish": Weapons.banishUntil, "morning": Weapons.morningMinutes,
            "cease": pend ?? (Weapons.ceaseList() as [Any]), "ceasePending": pend != nil, "ceaseOn": Weapons.ceaseActive,
            "treasury": (d?.object(forKey: "treasury-next") as? Int) ?? Weapons.treasuryMinutes, "treasuryNow": Weapons.treasuryMinutes, "treasuryOut": Weapons.treasuryOut,
            "herald": d?.bool(forKey: "herald-on") == true, "heraldAt": d?.object(forKey: "herald-at") as? Int ?? 720,
        ]
        call.resolve(out)
    }
    // Each app open: apply changes that were waiting for a new day, and tidy up locks whose time has passed.
    @objc func weaponsResume(_ call: CAPPluginCall) {
        Self.work.async {
            if Weapons.applyCeasePending() { Weapons.startCeasefires() }
            if Weapons.applyTreasuryPending() { Weapons.startTreasury() }
            if (Weapons.d?.double(forKey: "banish-until") ?? 0) > 0 && Weapons.banishUntil == 0 { Weapons.endBanish() }
            if (Weapons.d?.double(forKey: "wall-until") ?? 0) > 0 && Weapons.fortressUntil == 0 { Conquer.lowerWall(Weapons.d) }
            if Weapons.d?.string(forKey: "treasury-out").map({ $0 != Weapons.dayString() }) == true { Weapons.treasuryNewDay() }
            if Weapons.ceaseActive && Weapons.ceaseEndsAt() == nil { Weapons.d?.removeObject(forKey: "cease-on"); Weapons.unlock("cease") }
            Weapons.applySentry()
            let day = Weapons.dayString(), d = Weapons.d
            Weapons.scheduleHerald(points: Friends.points(red: d?.integer(forKey: "fmin-red-" + day) ?? 0, orange: d?.integer(forKey: "fmin-orange-" + day) ?? 0))
            call.resolve()
        }
    }
    // The Sentry's one guarded app (free play). Picked only in Apple's list.
    @objc func sentryPick(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var saved = FamilyActivitySelection()
            if let old = Weapons.selection("sentry-sel") { saved = old }
            let picker = WeaponPickerView(selection: saved, title: "Pick one app to guard") { picked in
                self.bridge?.viewController?.dismiss(animated: true)
                guard let picked = picked else { call.resolve(["picked": false]); return }
                if picked.applicationTokens.count != 1 || !picked.categoryTokens.isEmpty { call.resolve(["picked": false, "count": picked.applicationTokens.count + picked.categoryTokens.count]); return }
                if let data = try? JSONEncoder().encode(picked) { Weapons.d?.set(data, forKey: "sentry-sel") }
                Weapons.d?.set(Weapons.dayString(), forKey: "sentry-since")
                if Weapons.d?.string(forKey: "sentry-mode") == nil || Weapons.d?.string(forKey: "sentry-mode") == "off" { Weapons.d?.set("one", forKey: "sentry-mode") }
                Weapons.applySentry()
                call.resolve(["picked": true])
            }
            let host = UIHostingController(rootView: picker)
            host.overrideUserInterfaceStyle = .dark
            self.bridge?.viewController?.present(host, animated: true)
        }
    }
    // mode: "off", "one" (the picked app) or "all" (every Red app; Dynasty).
    @objc func sentrySet(_ call: CAPPluginCall) {
        let mode = call.getString("mode") ?? "off"
        Weapons.d?.set(["one", "all"].contains(mode) ? mode : "off", forKey: "sentry-mode")
        Weapons.applySentry()
        call.resolve()
    }
    @objc func banishStart(_ call: CAPPluginCall) {
        let until = Weapons.banish()
        if until == 0 { call.reject("No Red apps picked"); return }
        call.resolve(["until": until])
    }
    @objc func banishMorning(_ call: CAPPluginCall) {
        Weapons.d?.set(max(240, min(720, call.getInt("minutes") ?? 420)), forKey: "banish-morning")
        call.resolve()
    }
    // A new ceasefire list. Before any ceasefire has been set it applies now; after that, from tomorrow.
    @objc func ceaseSet(_ call: CAPPluginCall) {
        let list = (call.getArray("list", JSObject.self) ?? []).prefix(6).map { w -> [String: Any] in
            ["name": (w["name"] as? String) ?? "", "start": (w["start"] as? Int) ?? 0, "end": (w["end"] as? Int) ?? 0,
             "days": (w["days"] as? String) == "weekdays" ? "weekdays" : "all", "on": (w["on"] as? Bool) == true]
        }
        let d = Weapons.d
        let first = d?.object(forKey: "cease-list") == nil
        Self.work.async {
            if first { d?.set(Array(list), forKey: "cease-list"); Weapons.startCeasefires() }
            else { d?.set(Array(list), forKey: "cease-next"); d?.set(Weapons.dayString(), forKey: "cease-next-day") }
            call.resolve(["tomorrow": !first])
        }
    }
    // Allowance in minutes (30, 60 or 120; 0 = off). Same rule: first setting now, changes from tomorrow.
    @objc func treasurySet(_ call: CAPPluginCall) {
        let m = [0, 30, 60, 120].contains(call.getInt("minutes") ?? 0) ? (call.getInt("minutes") ?? 0) : 60
        let d = Weapons.d
        let first = d?.object(forKey: "treasury-min") == nil
        Self.work.async {
            if first { d?.set(m, forKey: "treasury-min"); Weapons.startTreasury() }
            else { d?.set(m, forKey: "treasury-next"); d?.set(Weapons.dayString(), forKey: "treasury-next-day") }
            call.resolve(["tomorrow": !first])
        }
    }
    @objc func heraldSet(_ call: CAPPluginCall) {
        let d = Weapons.d
        d?.set(call.getBool("on") ?? false, forKey: "herald-on")
        if let at = call.getInt("at") { d?.set(max(600, min(960, at)), forKey: "herald-at") }
        let go = {
            let day = Weapons.dayString()
            Weapons.scheduleHerald(points: Friends.points(red: d?.integer(forKey: "fmin-red-" + day) ?? 0, orange: d?.integer(forKey: "fmin-orange-" + day) ?? 0))
            call.resolve(["on": d?.bool(forKey: "herald-on") == true])
        }
        if d?.bool(forKey: "herald-on") == true {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in if !ok { d?.set(false, forKey: "herald-on") }; go() }
        } else { go() }
    }
    // Shows which apps a weapon guards. The page leaves empty boxes marked data-guard="sentry:0" or "red:3", and sends their
    // positions here. Apple's Label(token) draws each app's icon and name on top of the box. The app itself never learns the names.
    @objc func guardLabels(_ call: CAPPluginCall) {
        let items = call.getArray("items", JSObject.self) ?? []
        let color = UIColor(hex: call.getString("color") ?? "") ?? .white
        DispatchQueue.main.async {
            guard let web = self.bridge?.webView, let parent = web.superview else { call.resolve(); return }
            let layer = GuardLayer.shared
            if layer.superview !== parent { layer.removeFromSuperview(); parent.insertSubview(layer, aboveSubview: web) }
            layer.frame = web.frame
            layer.show(items.compactMap { o -> GuardSpot? in
                guard let key = o["key"] as? String, let i = (o["i"] as? Int) ?? (o["i"] as? Double).map({ Int($0) }) else { return nil }
                let n = { (k: String) -> CGFloat in CGFloat((o[k] as? Double) ?? Double((o[k] as? Int) ?? 0)) }
                return GuardSpot(key: key, i: i, part: (o["part"] as? String) ?? "both", size: n("size") > 0 ? n("size") : 15,
                                 rect: CGRect(x: n("x"), y: n("y"), width: n("w"), height: n("h")))
            }, color: Color(color))
            call.resolve()
        }
    }
    // Red and Orange minutes by hour for the last `days` days, and when Red minutes last grew. Read by Royal Advisor and Missions.
    @objc func redHours(_ call: CAPPluginCall) {
        let d = Weapons.d, n = max(1, min(40, call.getInt("days") ?? 14))
        var out: [String: Any] = [:]
        for i in 0..<n {
            guard let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let day = Weapons.dayString(date)
            out[day] = ["red": d?.integer(forKey: "fmin-red-" + day) ?? 0, "orange": d?.integer(forKey: "fmin-orange-" + day) ?? 0,
                        "hours": d?.dictionary(forKey: "fhour-red-" + day) ?? [:]] as [String: Any]
        }
        call.resolve(["days": out, "redLast": d?.double(forKey: "fred-last") ?? 0])
    }
}

// One guarded item, drawn by Apple.
private enum GuardItem: Equatable {
    case app(ApplicationToken), cat(ActivityCategoryToken), web(WebDomainToken)
}
private struct GuardSpot { let key: String; let i: Int; let part: String; let size: CGFloat; let rect: CGRect }
// part: "icon" (the app's icon, filling the box), "title" (its name) or "both".
private struct GuardLabelView: View {
    let item: GuardItem
    let part: String
    let color: Color
    let size: CGFloat
    var body: some View {
        let label = Group {
            switch item {
            case .app(let t): Label(t)
            case .cat(let t): Label(t)
            case .web(let t): Label(t)
            }
        }
        switch part {
        case "icon":
            label.labelStyle(.iconOnly).font(.system(size: size)).imageScale(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case "title":
            label.labelStyle(.titleOnly).font(.system(size: size, weight: .semibold)).foregroundColor(color).lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            label.labelStyle(.titleAndIcon).font(.system(size: size, weight: .semibold)).foregroundColor(color).lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
// A see-through layer over the web page that holds the labels. Touches pass through to the page.
private final class GuardLayer: UIView {
    static let shared: GuardLayer = { let v = GuardLayer(); v.isUserInteractionEnabled = false; v.clipsToBounds = true; v.backgroundColor = .clear; return v }()
    private var hosts: [String: UIHostingController<GuardLabelView>] = [:]
    private var cacheData: [String: Data] = [:]
    private var cacheItems: [String: [GuardItem]] = [:]

    // The items behind a key, in a fixed order so "red:3" always means the same app.
    private func list(_ key: String) -> [GuardItem] {
        let dkey = key == "sentry" ? "sentry-sel" : "tier-red"
        guard let data = Weapons.d?.data(forKey: dkey) else { return [] }
        if cacheData[key] == data, let l = cacheItems[key] { return l }
        guard let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return [] }
        let enc = { (e: Encodable) -> String in (try? JSONEncoder().encode(AnyEnc(e)))?.base64EncodedString() ?? "" }
        let l = s.applicationTokens.map { (enc($0), GuardItem.app($0)) }.sorted { $0.0 < $1.0 }.map { $0.1 }
            + s.categoryTokens.map { (enc($0), GuardItem.cat($0)) }.sorted { $0.0 < $1.0 }.map { $0.1 }
            + s.webDomainTokens.map { (enc($0), GuardItem.web($0)) }.sorted { $0.0 < $1.0 }.map { $0.1 }
        cacheData[key] = data; cacheItems[key] = l
        return l
    }
    func show(_ items: [GuardSpot], color: Color) {
        var keep = Set<String>()
        for g in items {
            let l = list(g.key), i = g.i, rect = g.rect, size = g.size
            guard i >= 0, i < l.count, rect.width > 0, rect.height > 0 else { continue }
            let id = g.key + ":" + String(i) + ":" + g.part
            keep.insert(id)
            let view = GuardLabelView(item: l[i], part: g.part, color: color, size: size)
            if let h = hosts[id] {
                if h.rootView.item != l[i] || h.rootView.size != size || h.rootView.color != color { h.rootView = view }
                h.view.frame = rect
            } else {
                let h = UIHostingController(rootView: view)
                h.view.backgroundColor = .clear
                h.view.isUserInteractionEnabled = false
                h.view.frame = rect
                addSubview(h.view)
                hosts[id] = h
            }
        }
        for (id, h) in hosts where !keep.contains(id) { h.view.removeFromSuperview(); hosts[id] = nil }
    }
}
private struct AnyEnc: Encodable {
    let e: Encodable
    init(_ e: Encodable) { self.e = e }
    func encode(to encoder: Encoder) throws { try e.encode(to: encoder) }
}
private extension UIColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("rgb") {
            let n = h.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap { Double($0) }
            guard n.count >= 3 else { return nil }
            self.init(red: n[0] / 255, green: n[1] / 255, blue: n[2] / 255, alpha: n.count > 3 ? n[3] : 1); return
        }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

private struct WeaponPickerView: View {
    @State var selection: FamilyActivitySelection
    let title: String
    let done: (FamilyActivitySelection?) -> Void
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Keep Phone, Maps and Messages off this list.").font(.footnote).foregroundColor(.secondary).padding(.vertical, 8)
                FamilyActivityPicker(selection: $selection)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { done(selection) } }
            }
        }
    }
}
