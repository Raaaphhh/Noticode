import Foundation

/// Réglages de l'utilisateur, enregistrés dans les UserDefaults (la fenêtre Réglages les modifie via `@AppStorage`).
enum Preferences {
    static let mutedKey = "soundMuted"
    static let volumeKey = "soundVolume"
    static let durationKey = "displayDuration"
    static let launchOnSessionStartKey = "launchOnSessionStart"
    static let layoutKey = "notchLayout"

    static let defaultVolume = 0.5

    /// Volume des sons, de 0 à 1.
    static var volume: Double {
        UserDefaults.standard.object(forKey: volumeKey) as? Double ?? defaultVolume
    }

    static var duration: DisplayDuration {
        DisplayDuration(rawValue: UserDefaults.standard.string(forKey: durationKey) ?? "") ?? .normal
    }

    static var layout: NotchLayout {
        NotchLayout(rawValue: UserDefaults.standard.string(forKey: layoutKey) ?? "") ?? .compact
    }

    static var launchOnSessionStart: Bool {
        UserDefaults.standard.bool(forKey: launchOnSessionStartKey)
    }

    /// Identifiant de l'app avant le 2026-10-04 (ses réglages étaient rangés sous ce nom).
    static let legacyBundleID = "com.noticode.app"

    /// Reprend une seule fois les réglages de l'ancien identifiant, puis les efface.
    static func migrateFromLegacyBundleID() {
        let defaults = UserDefaults.standard
        // Un plist vide peut rester après l'effacement : rien à reprendre.
        guard let old = defaults.persistentDomain(forName: legacyBundleID), !old.isEmpty else { return }
        let keys = [mutedKey, volumeKey, durationKey, launchOnSessionStartKey, layoutKey]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = old[key] { defaults.set(value, forKey: key) }
        }
        defaults.removePersistentDomain(forName: legacyBundleID)
    }
}

/// Durée d'affichage des notifications, appliquée à tous les types (sauf le salut au lancement).
enum DisplayDuration: String, CaseIterable, Identifiable {
    case short, normal, long

    var id: Self { self }

    var label: String {
        switch self {
        case .short: "Courte"
        case .normal: "Normale"
        case .long: "Longue"
        }
    }

    var scale: Double {
        switch self {
        case .short: 0.6
        case .normal: 1
        case .long: 1.6
        }
    }
}

/// Taille du notch : compacte (détail sur une ligne, déplié au survol) ou détaillée (détail toujours sur 3 lignes).
enum NotchLayout: String, CaseIterable, Identifiable {
    case compact, detailed

    var id: Self { self }

    var label: String {
        switch self {
        case .compact: "Compacte"
        case .detailed: "Détaillée"
        }
    }
}
