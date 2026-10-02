/// Retient si chaque session Claude Code est en mode auto, d'après les événements qui donnent le mode
/// (`Stop`, `PermissionRequest`…), pour compléter ceux qui ne le donnent pas (`Notification`, ex. le rappel d'attente).
struct SessionModes {
    /// Au-delà, on repart de zéro : les vieilles sessions sont sans doute terminées.
    private let maxSessions = 50
    private var autoMode: [String: Bool] = [:]

    mutating func resolve(_ event: NoticeEvent) -> NoticeEvent {
        guard !event.sessionID.isEmpty else { return event }
        var event = event
        if let mode = event.autoMode {
            if autoMode[event.sessionID] == nil && autoMode.count >= maxSessions { autoMode.removeAll() }
            autoMode[event.sessionID] = mode
        } else {
            event.autoMode = autoMode[event.sessionID]
        }
        return event
    }
}
