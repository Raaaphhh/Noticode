import AVFoundation

/// Joue les sons de l'app. Un seul lecteur par son, préchargé.
@MainActor
final class SoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]

    var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: Preferences.mutedKey) }
    }

    init() {
        isMuted = UserDefaults.standard.bool(forKey: Preferences.mutedKey)
        for name in NoticeKind.allCases.map(\.soundName) {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[name] = player
        }
    }

    /// `volumeScale` : multiplie le volume du réglage (ex. 0,5 pour le petit notch du mode auto).
    func play(_ kind: NoticeKind, volumeScale: Double = 1) {
        play(named: kind.soundName, volumeScale: volumeScale)
    }

    /// Aperçu du volume depuis les réglages (joué même si le son est coupé : c'est une action volontaire).
    func playPreview() {
        guard let player = players[NoticeKind.finished.soundName] else { return }
        player.volume = Float(Preferences.volume)
        player.currentTime = 0
        player.play()
    }

    private func play(named name: String, volumeScale: Double) {
        guard !isMuted, let player = players[name] else { return }
        // Lu à chaque fois : un changement de réglage s'applique tout de suite.
        player.volume = Float(Preferences.volume * volumeScale)
        player.currentTime = 0
        player.play()
    }
}
