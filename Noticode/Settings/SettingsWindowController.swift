import AppKit
import SwiftUI

/// Fenêtre « Réglages… » : créée à l'ouverture, libérée à la fermeture (rien ne reste en mémoire au repos).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let sounds: SoundPlayer
    private var window: NSWindow?

    init(sounds: SoundPlayer) {
        self.sounds = sounds
    }

    func show() {
        // App sans Dock : il faut l'activer pour que la fenêtre passe au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(sounds: sounds)))
        window.title = "Réglages de Noticode"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
