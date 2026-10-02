import SwiftUI

/// Temps restant montré par la barre : part de départ (1 = pleine), secondes pour la vider, figée si `running` est faux.
/// Le contrôleur en donne un nouveau à chaque départ, pause ou reprise ; la vue est alors recréée (`.id`).
struct CountdownState: Hashable {
    var fraction = 1.0
    var seconds = 0.0
    var running = false
    /// Rend chaque état unique : deux événements identiques à la suite ont chacun leur barre.
    var id = UUID()
}

/// Bord du bas de la forme, qui se vide vers le centre pendant le temps d'affichage.
struct Countdown: View {
    let color: Color
    let state: CountdownState
    @State private var fraction: Double

    init(state: CountdownState, color: Color) {
        self.state = state
        self.color = color
        _fraction = State(initialValue: state.fraction)
    }

    var body: some View {
        Capsule()
            .fill(color.opacity(0.85))
            .scaleEffect(x: fraction, y: 1, anchor: .center)
            .frame(height: 1.5)
            .onAppear {
                guard state.running else { return }
                withAnimation(.linear(duration: state.seconds)) { fraction = 0 }
            }
    }
}
