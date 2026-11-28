import ManagedSettings
import ManagedSettingsUI
import UIKit

// The screen iOS shows over a locked app (design handoff boards D1 and section 20). Words only, no prices and no upsell.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let ink = UIColor(red: 236 / 255, green: 228 / 255, blue: 208 / 255, alpha: 1)        // ivory #ECE4D0
    private let dim = UIColor(white: 1, alpha: 0.62)
    private let bg = UIColor(red: 13 / 255, green: 13 / 255, blue: 15 / 255, alpha: 1)            // #0D0D0F
    private let btnInk = UIColor(red: 20 / 255, green: 18 / 255, blue: 16 / 255, alpha: 1)         // #141210
    private let gold = UIColor(red: 0.79, green: 0.65, blue: 0.29, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(application.token, category: nil, name: application.localizedDisplayName)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(application.token, category: category.token, name: application.localizedDisplayName)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { locked("Locked for now", "This site is on your weapons list.") }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { locked("Locked for now", "This site is on your weapons list.") }

    // The app icon crown with its gold glow (handoff section 21). Every shield uses it.
    private func crown() -> UIImage? { UIImage(named: "SentryCrown") ?? UIImage(systemName: "crown.fill")?.withTintColor(gold, renderingMode: .alwaysOriginal) }
    private func locked(_ title: String, _ sub: String) -> ShieldConfiguration {
        ShieldConfiguration(backgroundBlurStyle: nil, backgroundColor: bg, icon: crown(),
                            title: .init(text: title, color: ink), subtitle: .init(text: sub + " Anything you didn't pick stays open. Emergency calls always work.", color: dim),
                            primaryButtonLabel: .init(text: "Close", color: btnInk), primaryButtonBackgroundColor: ink)
    }
    private func points() -> Int {
        let d = Weapons.d, day = Weapons.dayString()
        let red = d?.integer(forKey: "fmin-red-" + day) ?? 0, orange = d?.integer(forKey: "fmin-orange-" + day) ?? 0
        return max(0, 1000 - (red / 15) * 40 - (orange / 15) * 20)
    }

    // The app's real color, from the player's picks: "red", "orange", or "" for an app with no color.
    private func tier(_ token: ApplicationToken?, category: ActivityCategoryToken?) -> String {
        for t in ["red", "orange"] {
            guard let s = Weapons.selection("tier-" + t) else { continue }
            if let a = token, s.applicationTokens.contains(a) { return t }
            if let c = category, s.categoryTokens.contains(c) { return t }
        }
        return ""
    }

    private func make(_ token: ApplicationToken?, category: ActivityCategoryToken?, name: String?) -> ShieldConfiguration {
        switch Weapons.why(token, category: category) {
        case .fortress(let u): return locked("Fortress mode", "The apps on your list are locked until \(Weapons.clock(u)).")
        case .banish(let u): return locked("Banished", "The apps on your list are gone until \(Weapons.clock(u)).")
        case .ceasefire(let u): return locked("Ceasefire", u.map { "The apps on your list are locked until \(Weapons.clock($0))." } ?? "The apps on your list are locked for now.")
        case .treasury: return locked("Treasury is empty", "The apps on your list are locked until midnight.")
        case .sentry:
            let app = name ?? "This app"
            // A whole-category lock reports the category to the button handler, so the pause is kept per category then.
            let byApp = token.map { Weapons.sentryTarget()?.applicationTokens.contains($0) ?? false } ?? false
            let key = byApp ? Weapons.tokenKey(token!) : category.map { Weapons.tokenKey($0) } ?? token.map { Weapons.tokenKey($0) } ?? ""
            let waited = Weapons.sentryWaitStarted(key)
            let ready = waited > 0 && Weapons.now() - waited >= 5
            let first: String
            switch tier(token, category: category) {
            case "red": first = "\(app) is a Red app. 15 minutes costs 40 points. Enter anyway?"
            case "orange": first = "\(app) is an Orange app. 15 minutes costs 20 points. Enter anyway?"
            default: first = "The Sentry stands guard over \(app). Enter anyway?"
            }
            let sub = waited == 0 ? first
                : ready ? "Still want it? You can go in for 15 minutes." : "Take a breath. Wait 5 seconds, then tap Enter."
            return ShieldConfiguration(backgroundBlurStyle: nil, backgroundColor: bg, icon: crown(),
                                       title: .init(text: "You have \(points()) points left today", color: ink),
                                       subtitle: .init(text: sub, color: dim),
                                       primaryButtonLabel: .init(text: "Hold the line", color: btnInk), primaryButtonBackgroundColor: ink,
                                       secondaryButtonLabel: .init(text: waited == 0 ? "Wait 5 seconds" : "Enter for 15 minutes", color: dim))
        }
    }
}
