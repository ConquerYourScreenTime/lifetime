import ManagedSettings
import ManagedSettingsUI
import UIKit

// The Blip pause screen. iOS shows it when the player opens an app they picked for the pause.
// Wording from the Lawyer review (2026-11-19): no minute numbers, no guilt, no health words.
// It only reads what Blip is doing from the shared App Group on this phone. It never uses the internet.
class ShieldConfigExtension: ShieldConfigurationDataSource {
    let group = "group.io.github.gamesbyvidal.lifetime"
    var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    override func configuration(shielding application: Application) -> ShieldConfiguration { blip() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { blip() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { blip() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { blip() }

    private func blip() -> ShieldConfiguration {
        let ink = UIColor(red: 0.231, green: 0.165, blue: 0.290, alpha: 1)     // #3b2a4a
        let coral = UIColor(red: 0.886, green: 0.376, blue: 0.247, alpha: 1)   // #e2603f
        let cream = UIColor(red: 1.0, green: 0.957, blue: 0.878, alpha: 1)     // #fff4e0
        // After the first "Open for 15 min" tap the screen can't count down, so it says so and the second tap works after 5 seconds.
        let waitedAt = defaults?.double(forKey: "pause-wait") ?? 0
        let waiting = waitedAt > 0 && Date().timeIntervalSince1970 - waitedAt < 60
        let line = waiting
            ? "Taking a short pause... In a few seconds, tap \"Open for 15 min\" again."
            : (defaults?.string(forKey: "pause-line") ?? "Blip is out exploring. Want to head back?")
        var icon: UIImage? = nil
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            icon = UIImage(contentsOfFile: dir.appendingPathComponent("pause-icon.png").path)
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialLight,
            backgroundColor: cream,
            icon: icon,
            title: ShieldConfiguration.Label(text: "Blip's on an adventure", color: ink),
            subtitle: ShieldConfiguration.Label(text: line, color: ink),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Head back", color: .white),
            primaryButtonBackgroundColor: coral,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Open for 15 min", color: ink)
        )
    }
}
