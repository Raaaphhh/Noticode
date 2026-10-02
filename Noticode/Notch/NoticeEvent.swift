import SwiftUI

/// Les types d'événements affichés dans le notch (`welcome` : salut au lancement de l'app).
enum NoticeKind: CaseIterable {
    case welcome
    case finished
    case question
    case error

    var title: String {
        switch self {
        case .welcome: "Noticode est prêt"
        case .finished: "Terminé"
        case .question: "Question"
        case .error: "Erreur"
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .finished: "checkmark.circle.fill"
        case .question: "questionmark.bubble.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    /// Nom du fichier dans `Resources/sounds`.
    var soundName: String {
        switch self {
        case .welcome: "greet"
        case .finished: "finish"
        case .question: "question"
        case .error: "error"
        }
    }

    /// Animation de Notiboy (voir `Resources/notiboy/notiboy.json`).
    var notiboyAnimation: String {
        switch self {
        case .welcome: "happy"
        case .finished: "celebrate"
        case .question: "curious"
        case .error: "scared"
        }
    }

    var color: Color {
        switch self {
        case .welcome: .cyan
        case .finished: .green
        case .question: .orange
        case .error: .red
        }
    }

    /// Couleur du mode auto, comme le « auto mode » jaune de Claude Code.
    static let autoModeColor = Color.yellow
}

struct NoticeEvent {
    let kind: NoticeKind
    /// Titre affiché (par défaut celui du type, ex. « Autorisation : Bash » pour une permission).
    let title: String
    /// Nom du dossier de la session.
    let project: String
    /// Texte détaillé (commande, question, erreur), vide si rien à ajouter.
    let detail: String
    /// Le détail est une commande ou un chemin : affiché en police à chasse fixe.
    let detailIsCode: Bool
    /// Session Claude Code d'origine (vide si inconnue).
    let sessionID: String
    /// La session est en mode auto (`permission_mode` = "auto") ; nil si l'événement ne donne pas le mode.
    var autoMode: Bool?
    /// Rappel « Claude attend » (`idle_prompt`), pas une vraie question.
    let isIdleReminder: Bool

    init(kind: NoticeKind, title: String? = nil, project: String, detail: String = "", detailIsCode: Bool = false,
         sessionID: String = "", autoMode: Bool? = nil, isIdleReminder: Bool = false) {
        self.kind = kind
        self.title = title ?? kind.title
        self.project = project
        self.detail = detail
        self.detailIsCode = detailIsCode
        self.sessionID = sessionID
        self.autoMode = autoMode
        self.isIdleReminder = isIdleReminder
    }

    /// En mode auto, « Terminé », « Erreur » et le rappel d'attente s'affichent en petit (ailes seules, sans détail) ;
    /// une question ou une autorisation garde le grand notch : elle demande une action.
    var isCompact: Bool {
        autoMode == true && (kind == .finished || kind == .error || isIdleReminder)
    }

    /// Temps d'affichage : court pour le salut et « Terminé », plus long si l'utilisateur doit agir ou lire.
    /// Multiplié par `scale` (réglage « Durée d'affichage »), sauf le salut (durée calée sur son animation).
    func displaySeconds(scale: Double) -> Double {
        let base = switch kind {
        case .welcome: 2.5
        case .finished: 3.0
        case .question, .error: 7.0
        }
        // Le petit notch n'affiche pas le détail : rien à lire en plus.
        let reading = detail.isEmpty || isCompact ? 0 : min(Double(detail.count) / 40, 5)
        return kind == .welcome ? base : (base + reading) * scale
    }
}
