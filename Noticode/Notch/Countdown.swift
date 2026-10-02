import SwiftUI

/// Barre fine qui se vide pendant le temps d'affichage de l'événement.
struct Countdown: View {
    let seconds: Double
    let color: Color
    @State private var remaining = 1.0

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.1))
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(color.opacity(0.7)).frame(width: geometry.size.width * remaining)
                }
            }
            .frame(height: 2)
            .onAppear {
                withAnimation(.linear(duration: seconds)) { remaining = 0 }
            }
    }
}
