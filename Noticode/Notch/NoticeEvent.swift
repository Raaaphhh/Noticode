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

    /// Couleurs douces (pas les couleurs système vives).
    var color: Color {
        switch self {
        case .welcome: Color(hex: "#7fbcc4")
        case .finished: Color(hex: "#7cc49a")
        case .question: Color(hex: "#7fa8d6")
        case .error: Color(hex: "#db7a72")
        }
    }

    /// Couleur d'une demande d'autorisation (ambre) et du rappel « En attente » (gris).
    static let permissionColor = Color(hex: "#e0a85e")
    static let idleColor = Color(hex: "#9097a6")
    /// Couleur du mode auto, comme le « auto mode » jaune de Claude Code (adouci).
    static let autoModeColor = Color(hex: "#e3c766")
}

/// Façon d'afficher le détail : texte, commande (chasse fixe) ou chemin (dossier atténué, nom du fichier en avant).
enum DetailStyle {
    case text, code, path
}

struct NoticeEvent {
    let kind: NoticeKind
    /// Titre affiché (par défaut celui du type, ex. « Autoriser ? » pour une permission).
    let title: String
    /// Nom du dossier de la session.
    let project: String
    /// Texte détaillé (commande, question, erreur), vide si rien à ajouter.
    let detail: String
    let detailStyle: DetailStyle
    /// Outil d'une demande d'autorisation (ex. « Bash »), vide sinon.
    let tool: String
    /// Session Claude Code d'origine (vide si inconnue).
    let sessionID: String
    /// La session est en mode auto (`permission_mode` = "auto") ; nil si l'événement ne donne pas le mode.
    var autoMode: Bool?
    /// Rappel « Claude attend » (`idle_prompt`), pas une vraie question.
    let isIdleReminder: Bool

    init(kind: NoticeKind, title: String? = nil, project: String, detail: String = "", detailStyle: DetailStyle = .text,
         tool: String = "", sessionID: String = "", autoMode: Bool? = nil, isIdleReminder: Bool = false) {
        self.kind = kind
        self.title = title ?? kind.title
        self.project = project
        self.detail = detail
        self.detailStyle = detailStyle
        self.tool = tool
        self.sessionID = sessionID
        self.autoMode = autoMode
        self.isIdleReminder = isIdleReminder
    }

    /// En mode auto, « Terminé », « Erreur » et le rappel d'attente s'affichent en petit (ailes seules, sans détail) ;
    /// une question ou une autorisation garde le grand notch : elle demande une action.
    var isCompact: Bool {
        autoMode == true && (kind == .finished || kind == .error || isIdleReminder)
    }

    var color: Color {
        if isIdleReminder { return NoticeKind.idleColor }
        return kind == .question && !tool.isEmpty ? NoticeKind.permissionColor : kind.color
    }

    /// Ligne de détail sous les ailes : seulement quand l'utilisateur doit agir ou lire (pas pour « Terminé »,
    /// le rappel « En attente » ni le petit notch du mode auto). Une autorisation sans détail lisible y montre l'outil.
    var showsDetail: Bool {
        (!detail.isEmpty || !tool.isEmpty) && !isCompact && !isIdleReminder && kind != .finished
    }

    /// Temps d'affichage : court pour le salut et « Terminé », plus long si l'utilisateur doit agir ou lire.
    /// Multiplié par `scale` (réglage « Durée d'affichage »), sauf le salut (durée calée sur son animation).
    func displaySeconds(scale: Double) -> Double {
        let base = switch kind {
        case .welcome: 2.5
        case .finished: 3.0
        case .question, .error: isIdleReminder ? 3.0 : 7.0
        }
        // Sans ligne de détail, rien à lire en plus.
        let reading = showsDetail ? min(Double(detail.count) / 40, 5) : 0
        return kind == .welcome ? base : (base + reading) * scale
    }
}
