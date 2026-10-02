import AppKit

/// Icône de la barre de menus et son menu.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let sounds: SoundPlayer
    private let settings: SettingsWindowController

    init(sounds: SoundPlayer) {
        self.sounds = sounds
        settings = SettingsWindowController(sounds: sounds)
        super.init()
        if let button = statusItem.button {
            let image = NSImage(resource: .menuBarIcon)
            image.isTemplate = true
            image.accessibilityDescription = "Noticode"
            button.image = image
        }
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let mute = NSMenuItem(title: "Couper le son", action: #selector(toggleMute(_:)), keyEquivalent: "")
        mute.target = self
        mute.state = sounds.isMuted ? .on : .off
        menu.addItem(mute)
        let preferences = NSMenuItem(title: "Réglages…", action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)
        menu.addItem(.separator())

        let install = NSMenuItem(title: "Installer les hooks Claude Code…", action: #selector(installHooks), keyEquivalent: "")
        install.target = self
        menu.addItem(install)
        let uninstall = NSMenuItem(title: "Retirer les hooks Claude Code…", action: #selector(uninstallHooks), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter Noticode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleMute(_ sender: NSMenuItem) {
        sounds.isMuted.toggle()
        sender.state = sounds.isMuted ? .on : .off
    }

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func installHooks() {
        HooksInstallFlow.run(install: true)
    }

    @objc private func uninstallHooks() {
        HooksInstallFlow.run(install: false)
    }
}
