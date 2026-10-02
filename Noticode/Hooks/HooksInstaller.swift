import Foundation

/// Modification prévue de `~/.claude/settings.json`, calculée sans rien écrire.
struct HooksChange {
    /// Lignes ajoutées (+) et retirées (-). Vide s'il n'y a rien à changer.
    let diff: String
    let newData: Data
    /// Contenu lu au moment de l'aperçu (nil si le fichier n'existait pas).
    let oldData: Data?
    /// Fichier concerné (`~/.claude/settings.json`, ou une copie dans les tests).
    let settingsURL: URL
    var isEmpty: Bool { diff.isEmpty }
}

enum HooksInstallerError: LocalizedError {
    case invalidSettings
    case settingsChanged

    var errorDescription: String? {
        switch self {
        case .invalidSettings: "settings.json n'est pas un JSON valide ou sa section « hooks » a une forme inattendue : rien n'a été modifié."
        case .settingsChanged: "settings.json a changé pendant l'aperçu : rien n'a été modifié. Recommence l'opération."
        }
    }
}

/// Ajoute ou retire les hooks Noticode dans `~/.claude/settings.json`.
/// Les hooks des autres outils sont conservés tels quels.
enum HooksInstaller {
    /// `SessionStart` sert seulement à ouvrir l'app si elle est fermée (réglage), il n'affiche rien.
    private static let events = ["Stop", "StopFailure", "Notification", "PermissionRequest", "SessionStart"]
    private static let scriptName = "noticode-hook.sh"
    private static let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    static let defaultSettingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
        .resolvingSymlinksInPath()

    // MARK: - Calcul de la modification

    static func plan(install: Bool, settingsURL: URL = defaultSettingsURL) throws -> HooksChange {
        let oldData = try readData(settingsURL)
        let old = try parse(oldData)
        try checkHooksShape(old)
        var new = old
        if install { addHooks(to: &new) } else { removeHooks(from: &new) }

        let data = try JSONSerialization.data(withJSONObject: new, options: options)
        return HooksChange(diff: diff(from: old, to: new), newData: data + Data("\n".utf8),
                           oldData: oldData, settingsURL: settingsURL)
    }

    /// Vrai si tous les hooks Noticode sont déjà dans settings.json (faux aussi si le fichier est illisible).
    static var isInstalled: Bool {
        (try? plan(install: true).isEmpty) ?? false
    }

    private static func addHooks(to settings: inout [String: Any]) {
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        // Le chemin contient un espace ("Application Support") : guillemets simples, rien n'y est interprété par le shell.
        let command = "'" + AppPaths.hookScriptURL.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let entry: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 10]]]

        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            if !groups.contains(where: isOurs) { groups.append(entry) }
            hooks[event] = groups
        }
        settings["hooks"] = hooks
    }

    private static func removeHooks(from settings: inout [String: Any]) {
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]], groups.contains(where: isOurs) else { continue }
            let kept = groups.compactMap(withoutOurs)
            if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
    }

    private static func isOurs(_ group: [String: Any]) -> Bool {
        let inner = group["hooks"] as? [[String: Any]] ?? []
        return inner.contains { ($0["command"] as? String)?.contains(scriptName) == true }
    }

    /// Le groupe sans nos commandes, ou nil s'il ne reste rien dedans.
    private static func withoutOurs(_ group: [String: Any]) -> [String: Any]? {
        guard isOurs(group) else { return group }
        let inner = group["hooks"] as? [[String: Any]] ?? []
        let rest = inner.filter { ($0["command"] as? String)?.contains(scriptName) != true }
        if rest.isEmpty { return nil }
        var copy = group
        copy["hooks"] = rest
        return copy
    }

    // MARK: - Écriture

    /// Sauvegarde datée puis écriture. À appeler seulement après confirmation de l'utilisateur.
    /// Renvoie l'emplacement de la sauvegarde (nil si le fichier n'existait pas).
    @discardableResult
    static func apply(_ change: HooksChange) throws -> URL? {
        let fileManager = FileManager.default
        let settingsURL = change.settingsURL
        guard try readData(settingsURL) == change.oldData else { throw HooksInstallerError.settingsChanged }
        var backup: URL?
        var permissions = NSNumber(value: 0o644)

        if fileManager.fileExists(atPath: settingsURL.path) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let stamp = formatter.string(from: Date())
            // Deux écritures dans la même milliseconde : numéro en plus, jamais d'écrasement d'une sauvegarde.
            var url = settingsURL.appendingPathExtension("bak-\(stamp)")
            var index = 1
            while fileManager.fileExists(atPath: url.path) {
                index += 1
                url = settingsURL.appendingPathExtension("bak-\(stamp)-\(index)")
            }
            try fileManager.copyItem(at: settingsURL, to: url)
            backup = url
            if let current = try fileManager.attributesOfItem(atPath: settingsURL.path)[.posixPermissions] as? NSNumber {
                permissions = current
            }
        } else {
            try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        // Fichier temporaire aux droits d'origine, puis renommage : settings.json n'est jamais
        // incomplet, ni lisible par d'autres un instant s'il était réservé à l'utilisateur.
        let temporary = settingsURL.appendingPathExtension("noticode-tmp")
        try? fileManager.removeItem(at: temporary)
        guard fileManager.createFile(atPath: temporary.path, contents: change.newData,
                                     attributes: [.posixPermissions: permissions]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        guard rename(temporary.path, settingsURL.path) == 0 else {
            try? fileManager.removeItem(at: temporary)
            throw CocoaError(.fileWriteUnknown)
        }
        return backup
    }

    // MARK: - Outils

    /// Contenu brut de settings.json, nil s'il n'existe pas.
    private static func readData(_ settingsURL: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        return try Data(contentsOf: settingsURL)
    }

    /// `hooks` doit être un objet et chacun de nos événements un tableau : sinon on écraserait
    /// sans le dire un contenu qu'on ne comprend pas.
    private static func checkHooksShape(_ settings: [String: Any]) throws {
        guard let value = settings["hooks"] else { return }
        guard let hooks = value as? [String: Any] else { throw HooksInstallerError.invalidSettings }
        for event in events {
            if let groups = hooks[event], !(groups is [[String: Any]]) { throw HooksInstallerError.invalidSettings }
        }
    }

    private static func parse(_ data: Data?) throws -> [String: Any] {
        guard let data else { return [:] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HooksInstallerError.invalidSettings
        }
        return json
    }

    /// Différences lisibles : une ligne par commande ajoutée (+) ou retirée (-), avec son événement.
    private static func diff(from old: [String: Any], to new: [String: Any]) -> String {
        let before = commands(in: old)
        let after = commands(in: new)
        var lines: [String] = []
        for event in Set(before.keys).union(after.keys).sorted() {
            for change in (after[event] ?? []).difference(from: before[event] ?? []) {
                switch change {
                case .remove(_, let command, _): lines.append("- [\(event)] \(command)")
                case .insert(_, let command, _): lines.append("+ [\(event)] \(command)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Toutes les commandes de hooks, par événement.
    private static func commands(in settings: [String: Any]) -> [String: [String]] {
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return hooks.mapValues { value in
            let groups = value as? [[String: Any]] ?? []
            return groups.flatMap { group in
                (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
            }
        }
    }
}
