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
            let error = Self.firstText(in: json, keys: ["error_details", "message", "error_type"])
            self.init(kind: .error, project: project, detail: error, sessionID: sessionID, autoMode: autoMode)
        case "PermissionRequest":
            // Arrive tout de suite, contrairement à la notification `permission_prompt`.
            let tool = json["tool_name"] as? String ?? ""
            let input = json["tool_input"] as? [String: Any] ?? [:]
            self.init(kind: .question,
                      title: tool.isEmpty ? "Autorisation requise" : "Autorisation : \(tool)",
                      project: project,
                      detail: Self.firstText(in: input, keys: ["command", "file_path", "path", "url", "pattern", "query", "description"]),
                      detailIsCode: true,
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
