import ManagedSettings
import ManagedSettingsUI
import UIKit

// The screen iOS shows over a locked app (design handoff boards D1 and section 20). Words only, no prices and no upsell.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let ink = UIColor(red: 0.925, green: 0.894, blue: 0.816, alpha: 1)       // ivory
    private let dim = UIColor(white: 1, alpha: 0.62)
    private let bg = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
    private let gold = UIColor(red: 0.79, green: 0.65, blue: 0.29, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(application.token, category: nil, name: application.localizedDisplayName)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(application.token, category: category.token, name: application.localizedDisplayName)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { locked("Locked for now", "This site is one of your Red apps.") }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { locked("Locked for now", "This site is one of your Red apps.") }

    private func crown() -> UIImage? { UIImage(systemName: "crown.fill")?.withTintColor(gold, renderingMode: .alwaysOriginal) }
    private func locked(_ title: String, _ sub: String) -> ShieldConfiguration {
        ShieldConfiguration(backgroundBlurStyle: .dark, backgroundColor: bg, icon: crown(),
                            title: .init(text: title, color: ink), subtitle: .init(text: sub + " Texts, calls and Maps still work.", color: dim),
                            primaryButtonLabel: .init(text: "Close", color: bg), primaryButtonBackgroundColor: ink)
    }
    private func points() -> Int {
        let d = Weapons.d, day = Weapons.dayString()
        let red = d?.integer(forKey: "fmin-red-" + day) ?? 0, orange = d?.integer(forKey: "fmin-orange-" + day) ?? 0
        return max(0, 1000 - (red / 15) * 40 - (orange / 15) * 20)
    }

    private func make(_ token: ApplicationToken?, category: ActivityCategoryToken?, name: String?) -> ShieldConfiguration {
        switch Weapons.why(token, category: category) {
        case .fortress(let u): return locked("Fortress mode", "Your Red apps are locked until \(Weapons.clock(u)).")
        case .banish(let u): return locked("Banished", "Your Red apps are gone until \(Weapons.clock(u)).")
        case .ceasefire(let u): return locked("Ceasefire", u.map { "Your Red apps are locked until \(Weapons.clock($0))." } ?? "Your Red apps are locked for now.")
        case .treasury: return locked("Treasury is empty", "Your Red apps are locked until midnight.")
        case .sentry:
            let app = name ?? "This app"
            // A whole-category lock reports the category to the button handler, so the pause is kept per category then.
            let byApp = token.map { Weapons.sentryTarget()?.applicationTokens.contains($0) ?? false } ?? false
            let key = byApp ? Weapons.tokenKey(token!) : category.map { Weapons.tokenKey($0) } ?? token.map { Weapons.tokenKey($0) } ?? ""
            let waited = Weapons.sentryWaitStarted(key)
            let ready = waited > 0 && Weapons.now() - waited >= 5
            let sub = waited == 0 ? "\(app) is a Red app. 15 minutes costs 40 points. Enter anyway?"
                : ready ? "Still want it? You can go in for 15 minutes." : "Take a breath. Wait 5 seconds, then tap Enter."
            return ShieldConfiguration(backgroundBlurStyle: .dark, backgroundColor: bg, icon: crown(),
                                       title: .init(text: "You have \(points()) points left today", color: ink),
                                       subtitle: .init(text: sub, color: dim),
                                       primaryButtonLabel: .init(text: "Hold the line", color: bg), primaryButtonBackgroundColor: ink,
                                       secondaryButtonLabel: .init(text: waited == 0 ? "Wait 5 seconds" : "Enter for 15 minutes", color: dim))
        }
    }
}
