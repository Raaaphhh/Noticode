import SwiftUI

/// Forme noire qui part de la taille du notch et s'agrandit en « ailes » de part et d'autre :
/// Notiboy et le titre à gauche du notch physique, le projet à droite, le détail éventuel dessous.
/// Les ailes sont symétriques (le notch reste centré) et prennent la largeur de leur texte ; la hauteur est mesurée.
/// En mode auto (`isCompact`) : ailes seules, plus basses, badge « AUTO » à droite, halo et contour jaunes.
struct NotchView: View {
    let model: NotchModel
    @State private var openHeight: CGFloat = 60
    @State private var titleWidth: CGFloat = 0
    @State private var rightWidth: CGFloat = 0

    private var isCompact: Bool { model.event?.isCompact == true }
    private var avatarSize: CGFloat { isCompact ? 30 : 40 }
    private let outerInset: CGFloat = 14
    private let notchGap: CGFloat = 10
    private let maxWingText: CGFloat = 190

    private var notch: CGSize { model.notchSize }
    private var wingWidth: CGFloat {
        let left = avatarSize + 8 + min(titleWidth, maxWingText)
        let right = min(rightWidth, maxWingText)
        return outerInset + max(left, right) + notchGap
    }
    /// Un détail a besoin d'un peu de largeur pour rester lisible.
    private var openWidth: CGFloat {
        if model.event?.kind == .welcome { return notch.width + 60 }
        let wings = notch.width + 2 * wingWidth
        return model.event?.detail.isEmpty == false && !isCompact ? max(wings, 440) : wings
    }

    var body: some View {
        let isOpen = model.isOpen
        VStack(spacing: 0) {
            if let event = model.event {
                Group {
                    if event.kind == .welcome {
                        WelcomeView(model: model, notchHeight: notch.height)
                    } else {
                        content(for: event)
                    }
                }
                    .opacity(isOpen ? 1 : 0)
                    .animation(.easeOut(duration: 0.2).delay(isOpen ? 0.12 : 0), value: isOpen)
            }
        }
        .frame(width: openWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { openHeight = $0 }
        .frame(width: isOpen ? openWidth : notch.width,
               height: isOpen ? openHeight : notch.height,
               alignment: .top)
        .clipped()
        .onGeometryChange(for: CGSize.self) { $0.size } action: {
            model.shapeSize = CGSize(width: $0.width + 28, height: $0.height)
        }
        .background(
            // Les coins du haut débordent de `topRadius` de chaque côté pour se raccorder au bord de l'écran.
            NotchShape(topRadius: isOpen ? 14 : 6, bottomRadius: isOpen ? 20 : 10)
                .fill(.black)
                .padding(.horizontal, isOpen ? -14 : -6)
        )
        .overlay {
            if isCompact {
                NotchShape(topRadius: isOpen ? 14 : 6, bottomRadius: isOpen ? 20 : 10, closesTop: false)
                    .stroke(NoticeKind.autoModeColor.opacity(isOpen ? 0.7 : 0), lineWidth: 1.5)
                    .padding(.horizontal, isOpen ? -14 : -6)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isOpen)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: openHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func content(for event: NoticeEvent) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    avatar(for: event)
                    title(for: event)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, outerInset)
                Color.clear.frame(width: notch.width + 2 * notchGap) // notch physique
                Group {
                    if event.isCompact {
                        autoBadge
                    } else if !event.project.isEmpty {
                        project(for: event)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, outerInset)
            }
            .frame(height: max(notch.height, avatarSize + 4))
            if !event.isCompact {
                Group {
                    if !event.detail.isEmpty {
                        detail(for: event)
                    }
                    Countdown(seconds: model.displaySeconds, color: event.kind.color)
                }
                .padding(.horizontal, outerInset)
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, event.isCompact ? 4 : 10)
        .id(model.animationStart) // nouvel événement = nouveau compte à rebours
    }

    @ViewBuilder
    private func avatar(for event: NoticeEvent) -> some View {
        if let animator = model.animator {
            NotiboyAvatar(animator: animator, start: model.animationStart, panelTopLeft: model.panelTopLeft,
                          size: avatarSize, color: event.isCompact ? NoticeKind.autoModeColor : event.kind.color,
                          haloRadius: avatarSize / 2 + 4)
        }
    }

    private func title(for event: NoticeEvent) -> some View {
        HStack(spacing: 5) {
            Image(systemName: event.kind.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(event.kind.color)
            Text(event.title)
                .font(.system(size: 14, weight: .semibold))
        }
        .lineLimit(1)
        .idealWidth { titleWidth = $0 }
    }

    private func project(for event: NoticeEvent) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
            Text(event.project)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .lineLimit(1)
        .idealWidth { rightWidth = $0 }
    }

    private var autoBadge: some View {
        AutoBadge().idealWidth { rightWidth = $0 }
    }

    private func detail(for event: NoticeEvent) -> some View {
        Text(event.detail)
            .font(.system(size: 12, design: event.detailIsCode ? .monospaced : .default))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(3)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.07))
                    .strokeBorder(.white.opacity(0.08))
            )
            .overlay(alignment: .leading) {
                // Liseré de la couleur de l'événement.
                Capsule().fill(event.kind.color).frame(width: 3).padding(.vertical, 8)
            }
    }
}

/// Rappel du mode auto, comme le « auto mode » jaune de Claude Code (aussi dans l'aide des Réglages).
struct AutoBadge: View {
    var fontSize: CGFloat = 11

    var body: some View {
        Text("AUTO")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(NoticeKind.autoModeColor)
            .padding(.horizontal, fontSize * 0.64)
            .padding(.vertical, fontSize * 0.18)
            .background(Capsule().fill(NoticeKind.autoModeColor.opacity(0.15)))
            .lineLimit(1)
    }
}

private extension View {
    /// Largeur du contenu sans troncature (copie invisible), pour dimensionner les ailes.
    func idealWidth(_ action: @escaping (CGFloat) -> Void) -> some View {
        background(alignment: .leading) {
            fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: action)
        }
    }
}
