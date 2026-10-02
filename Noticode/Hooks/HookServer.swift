import Foundation
import Darwin

/// Écoute le socket Unix sur lequel le script relais envoie les événements des hooks.
/// Local uniquement, aucun réseau. Le thread reste bloqué sur `accept` : 0 % CPU au repos.
final class HookServer: Sendable {
    /// Large : une demande d'autorisation `Write`/`Edit` contient tout le fichier (mémoire libérée juste après).
    private static let maxMessageSize = 4 * 1024 * 1024

    private let onEvent: @Sendable (NoticeEvent) -> Void

    init(onEvent: @escaping @Sendable (NoticeEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        Thread.detachNewThread { self.listen() }
    }

    private func listen() {
        let path = AppPaths.socketPath
        unlink(path) // reste d'un lancement précédent

        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        guard server >= 0 else { return fail("socket") }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { close(server); return fail("chemin trop long") }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            for (index, byte) in pathBytes.enumerated() { buffer[index] = UInt8(bitPattern: byte) }
        }

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { close(server); return fail("bind") }
        chmod(path, 0o600) // seul l'utilisateur peut écrire dans le socket
        guard Darwin.listen(server, 8) == 0 else { close(server); return fail("listen") }

        while true {
            let client = accept(server, nil, nil)
            if client >= 0 { handle(client); continue }
            if errno == EINTR || errno == ECONNABORTED { continue } // passager : on continue d'écouter
            break
        }
        close(server)
        fail("accept")
    }

    private func fail(_ step: String) {
        NSLog("Noticode : serveur des hooks arrêté (\(step), errno \(errno))")
    }

    /// Lit un message (jusqu'au saut de ligne), le convertit et le transmet.
    private func handle(_ client: Int32) {
        defer { close(client) }

        // Un client qui ne dit rien ne doit pas bloquer le serveur.
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var message = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while message.count < Self.maxMessageSize {
            let count = recv(client, &buffer, buffer.count, 0)
            if count <= 0 { break }
            message.append(contentsOf: buffer[0..<count])
            if buffer[0..<count].contains(UInt8(ascii: "\n")) { break }
        }

        if message.count >= Self.maxMessageSize { NSLog("Noticode : message de hook trop gros, ignoré") }
        guard let event = NoticeEvent(hookJSON: message) else { return }
        onEvent(event)
    }
}
