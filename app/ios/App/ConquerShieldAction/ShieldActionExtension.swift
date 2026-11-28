import ManagedSettings
import Foundation

// Buttons on the shield. "Hold the line" / "Close" closes the app. On the Sentry, the second button starts a 5-second
// pause; a tap after the pause lets the player in for 15 minutes. Fortress, Banish, Ceasefire and Treasury can't be skipped here.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action, Weapons.tokenKey(application), Weapons.why(application)))
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action, Weapons.tokenKey(category), Weapons.why(nil, category: category)))
    }
    private func respond(_ action: ShieldAction, _ key: String, _ why: Weapons.Why) -> ShieldActionResponse {
        guard action == .secondaryButtonPressed, case .sentry = why else { return .close }
        let waited = Weapons.sentryWaitStarted(key)
        if waited == 0 { Weapons.sentryStartWait(key); return .defer }
        if Weapons.now() - waited < 5 { return .defer }
        Weapons.sentryPass(key)
        return .defer
    }
}
