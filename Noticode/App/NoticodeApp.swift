import AppKit

@main
enum NoticodeApp {
    // Le delegate doit rester référencé : NSApplication ne le retient pas.
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        Preferences.migrateFromLegacyBundleID() // avant de créer le delegate, qui lit déjà les réglages
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
