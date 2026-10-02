import Foundation

/// Réglages de l'utilisateur, enregistrés dans les UserDefaults (la fenêtre Réglages les modifie via `@AppStorage`).
enum Preferences {
    static let mutedKey = "soundMuted"
    static let volumeKey = "soundVolume"
    static let durationKey = "displayDuration"
    static let launchOnSessionStartKey = "launchOnSessionStart"

    static let defaultVolume = 0.5

    /// Volume des sons, de 0 à 1.
    static var volume: Double {
        UserDefaults.standard.object(forKey: volumeKey) as? Double ?? defaultVolume
    }

    static var duration: DisplayDuration {
        DisplayDuration(rawValue: UserDefaults.standard.string(forKey: durationKey) ?? "") ?? .normal
    }

    static var launchOnSessionStart: Bool {
        UserDefaults.standard.bool(forKey: launchOnSessionStartKey)
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
