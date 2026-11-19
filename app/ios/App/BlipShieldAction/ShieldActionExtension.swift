import ManagedSettings
import DeviceActivity
import Foundation

// The Blip pause buttons.
// "Head back" closes the app and adds 1 to today's turn-back count (one number a day, on this phone, no app names).
// "Open for 15 min": the first tap starts a short pause; a tap 5+ seconds later lifts the pause for 15 minutes.
// Neither button gains or loses Coins.
class ShieldActionExtension: ShieldActionDelegate {
    let group = "group.io.github.gamesbyvidal.lifetime"
    var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("blippause"))

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }

    private func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func respond(_ action: ShieldAction) -> ShieldActionResponse {
        let now = Date().timeIntervalSince1970
        switch action {
        case .primaryButtonPressed:
            let key = "turnback-" + today()
            defaults?.set((defaults?.integer(forKey: key) ?? 0) + 1, forKey: key)
            defaults?.removeObject(forKey: "pause-wait")
            return .close
        case .secondaryButtonPressed:
            let waitedAt = defaults?.double(forKey: "pause-wait") ?? 0
            if waitedAt > 0 && now - waitedAt >= 5 && now - waitedAt < 60 {
                unlockFor15()
                return .defer
            }
            defaults?.set(now, forKey: "pause-wait")   // the shield redraws with "Taking a short pause..."
            return .defer
        @unknown default:
            return .close
        }
    }

    // Lifts the pause on the picked apps for 15 minutes. A 15-minute DeviceActivity schedule (iOS's shortest) ends the break,
    // and the monitor extension puts the pause back when it ends. Blip also puts it back the next time it opens, as a backup.
    private func unlockFor15() {
        let until = Date().addingTimeInterval(15 * 60)
        defaults?.removeObject(forKey: "pause-wait")
        defaults?.set(until.timeIntervalSince1970, forKey: "pause-until")
        store.clearAllSettings()
        let cal = Calendar.current
        let start = cal.dateComponents([.hour, .minute, .second], from: Date())
        let end = cal.dateComponents([.hour, .minute, .second], from: until.addingTimeInterval(5))
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
        try? DeviceActivityCenter().startMonitoring(DeviceActivityName("pause-unlock"), during: schedule)
    }
}
