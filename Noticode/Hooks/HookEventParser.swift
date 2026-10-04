import Foundation

extension NoticeEvent {
    /// Convertit le JSON envoyé par un hook Claude Code. Renvoie nil pour un événement ignoré.
    init?(hookJSON data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["hook_event_name"] as? String else { return nil }

        let folder = ((json["cwd"] as? String ?? "") as NSString).lastPathComponent
        let project = folder.isEmpty || folder == "/" ? "Claude Code" : folder
        let sessionID = json["session_id"] as? String ?? ""
        // nil si le champ est absent (ex. Notification) : `SessionModes` le complète avec le mode déjà vu pour la session.
        let autoMode = (json["permission_mode"] as? String).map { $0 == "auto" }

        switch name {
        case "Stop":
            self.init(kind: .finished, project: project, sessionID: sessionID, autoMode: autoMode)
        case "StopFailure":
            // Phrase traduite suivie du détail d'origine (ex. heure de réinitialisation d'une limite).
            let phrase = Self.errorMessage(type: json["error_type"] as? String) ?? ""
            let details = Self.firstText(in: json, keys: ["error_details", "message"])
            let error = [phrase, details].filter { !$0.isEmpty }.joined(separator: " — ")
            self.init(kind: .error, project: project,
                      detail: error.isEmpty ? Self.firstText(in: json, keys: ["error_type"]) : error,
                      sessionID: sessionID, autoMode: autoMode)
        case "PermissionRequest":
            // Arrive tout de suite, contrairement à la notification `permission_prompt`.
            let tool = json["tool_name"] as? String ?? ""
            let input = json["tool_input"] as? [String: Any] ?? [:]
            let path = Self.firstText(in: input, keys: ["file_path", "notebook_path", "path"])
            let detail = path.isEmpty
                ? Self.firstText(in: input, keys: ["command", "url", "pattern", "query", "description"])
                : (path as NSString).abbreviatingWithTildeInPath
            self.init(kind: .question,
                      title: "Autoriser ?",
                      project: project,
                      detail: detail,
                      detailStyle: path.isEmpty ? .code : .path,
                      tool: tool.isEmpty ? "Outil" : Self.shortToolName(tool),
                      sessionID: sessionID, autoMode: autoMode)
        case "Notification":
            // `permission_prompt` est déjà couvert par PermissionRequest (sinon double affichage) ;
            // `auth_success` n'appelle aucune action de l'utilisateur.
            let type = json["notification_type"] as? String
            if type == "permission_prompt" || type == "auth_success" { return nil }
            // `idle_prompt` : simple rappel, ~60 s après la fin d'une réponse sans que l'utilisateur ait tapé.
            let isIdleReminder = type == "idle_prompt"
            self.init(kind: .question,
                      title: isIdleReminder ? "En attente" : nil,
                      project: project,
                      detail: Self.firstText(in: json, keys: ["message"]),
                      sessionID: sessionID, autoMode: autoMode,
                      isIdleReminder: isIdleReminder)
        default:
            return nil
        }
    }

    /// Phrase en français pour les erreurs courantes de `StopFailure` ; nil si le type est inconnu (on garde le message brut).
    private static func errorMessage(type: String?) -> String? {
        switch type {
        case "rate_limit": "Limite d'utilisation atteinte."
        case "overloaded", "overloaded_error": "Serveurs surchargés, réessaie dans un moment."
        case "authentication_failed", "authentication_error": "Connexion à Claude refusée : reconnecte-toi."
        case "billing_error": "Problème de facturation sur le compte."
        case "server_error", "api_error": "Erreur du serveur de Claude."
        case "max_output_tokens": "Réponse coupée : longueur maximale atteinte."
        default: nil
        }
    }

    /// Nom d'outil assez court pour l'étiquette : `mcp__serveur__outil` → `outil`, coupé au-delà de 24 caractères.
    private static func shortToolName(_ name: String) -> String {
        let short = name.components(separatedBy: "__").last { !$0.isEmpty } ?? name
        return short.count > 24 ? String(short.prefix(23)) + "…" : short
    }

    /// Premier texte non vide parmi les clés données, nettoyé et borné (le notch n'affiche que quelques lignes).
    private static func firstText(in dict: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard let text = dict[key] as? String else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return String(trimmed.prefix(300)) }
        }
        return ""
    }
}
