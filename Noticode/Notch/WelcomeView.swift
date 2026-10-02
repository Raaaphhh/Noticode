import SwiftUI

/// Salut au lancement, différent des notifications : pas d'ailes ni de barre de temps,
/// Notiboy « tombe » du notch et rebondit, puis le texte apparaît dessous.
struct WelcomeView: View {
    let model: NotchModel
    let notchHeight: CGFloat
    @State private var dropped = false

    var body: some View {
        VStack(spacing: 6) {
            Color.clear.frame(height: notchHeight) // notch physique
            if let animator = model.animator {
                NotiboyAvatar(animator: animator, start: model.animationStart, panelTopLeft: model.panelTopLeft,
                              size: 56, color: NoticeKind.welcome.color, haloOpacity: 0.75, haloRadius: 40, haloSize: 80)
                    .scaleEffect(dropped ? 1 : 0.3)
                    .offset(y: dropped ? 0 : -50)
            }
            Text(NoticeKind.welcome.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(dropped ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.35), value: dropped)
        }
        .padding(.bottom, 14)
        .id(model.animationStart)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.1)) { dropped = true }
        }
    }
}
