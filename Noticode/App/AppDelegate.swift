import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sounds = SoundPlayer()
    private lazy var notch = NotchController(sounds: sounds)
    private var menuBar: MenuBarController?
    private var hookServer: HookServer?
    private var sessionModes = SessionModes()

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOtherInstances()
        menuBar = MenuBarController(sounds: sounds)
        notch.show(NoticeEvent(kind: .welcome, project: "")) // Notiboy salue au lancement
        startHookServer()
    }

    /// Une seule instance à la fois (sinon la dernière prend le socket et l'autre ne reçoit plus rien) :
    /// la copie qu'on vient de lancer (Debug ou Release) remplace l'ancienne.
    private func quitOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) where app != .current {
            app.terminate()
        }
    }

    private func startHookServer() {
        do {
            try AppPaths.installHookScript()
            AppPaths.updateLaunchFile(enabled: Preferences.launchOnSessionStart)
        } catch {
            NSLog("Noticode : installation du script relais impossible : \(error)")
            return
        }
        // Le serveur tourne sur un thread à part : on revient sur le thread principal pour afficher.
        // La file principale garde l'ordre d'arrivée (une `Task` par événement ne le garantit pas).
        let server = HookServer { [weak self] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.notch.show(self.sessionModes.resolve(event))
                }
            }
        }
        server.start()
        hookServer = server
    }
}
