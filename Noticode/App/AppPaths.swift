import Foundation

/// Emplacements des fichiers de l'app (~/Library/Application Support/Noticode).
enum AppPaths {
    static let supportDir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Noticode")

    static let socketPath = supportDir.appendingPathComponent("noticode.sock").path
    static let hookScriptURL = supportDir.appendingPathComponent("noticode-hook.sh")
    /// Présent seulement si le réglage « ouvrir au démarrage d'une session » est actif :
    /// contient le chemin de l'app, que le script relais ouvre si l'app ne répond pas.
    static let launchFileURL = supportDir.appendingPathComponent("launch-app")

    /// Crée ou retire le fichier lu par le script relais. Réécrit à chaque lancement : le chemin suit la copie utilisée.
    static func updateLaunchFile(enabled: Bool) {
        if enabled {
            try? Data(Bundle.main.bundlePath.utf8).write(to: launchFileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: launchFileURL)
        }
    }

    /// Crée le dossier (réservé à l'utilisateur) et y copie le script relais du bundle s'il a changé.
    static func installHookScript() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
        // Aussi pour un dossier déjà existant aux droits plus larges.
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: supportDir.path)

        guard let source = Bundle.main.url(forResource: "noticode-hook", withExtension: "sh") else {
            NSLog("Noticode : script relais absent de l'app, hooks inactifs")
            return
        }
        let script = try Data(contentsOf: source)
        guard (try? Data(contentsOf: hookScriptURL)) != script else { return }
        // Fichier temporaire déjà exécutable, puis renommage : un hook lancé pendant ce temps
        // trouve toujours un script complet (l'ancien ou le nouveau).
        let temporary = supportDir.appendingPathComponent("noticode-hook.sh.tmp")
        try script.write(to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        guard rename(temporary.path, hookScriptURL.path) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
