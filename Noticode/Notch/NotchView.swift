import SwiftUI

/// Forme noire qui part de la taille du notch et s'agrandit en « ailes » de part et d'autre, à la hauteur du notch :
/// Notiboy et un mot coloré à gauche du notch physique, le projet à droite (« AUTO » en mode auto).
/// Quand l'utilisateur doit agir (autorisation, question, erreur), une ligne de détail s'ajoute dessous ;
/// elle se déplie sur 3 lignes au survol (ou toujours, réglage « Taille : détaillée »).
/// Le bord du bas se vide vers le centre pendant le temps d'affichage.
struct NotchView: View {
    let model: NotchModel
    @State private var openHeight: CGFloat = 32
    @State private var titleWidth: CGFloat = 0
    @State private var rightWidth: CGFloat = 0

    private let avatarSize: CGFloat = 24
    private let leftInset: CGFloat = 10
    private let rightInset: CGFloat = 12
    private let notchGap: CGFloat = 8
    private let maxWingText: CGFloat = 150
    /// Largeur minimale quand une ligne de détail s'affiche.
    private let detailWidth: CGFloat = 400
    /// Rayons de la forme (haut : raccord avec le bord de l'écran), ouverte et fermée.
    private let openRadii = (top: CGFloat(10), bottom: CGFloat(14))
    private let closedRadii = (top: CGFloat(6), bottom: CGFloat(10))

    private var notch: CGSize { model.notchSize }
    private var rowHeight: CGFloat { max(notch.height, 32) }
    private var wingWidth: CGFloat {
        let left = leftInset + avatarSize + 6 + min(titleWidth, maxWingText)
        let right = rightInset + min(rightWidth, maxWingText)
        return max(left, right) + notchGap
    }
    private var openWidth: CGFloat {
        guard let event = model.event else { return notch.width }
        if event.kind == .welcome { return notch.width + 60 }
        let wings = notch.width + 2 * wingWidth
        return event.showsDetail ? max(wings, detailWidth) : wings
    }

    var body: some View {
        let isOpen = model.isOpen
        let radii = isOpen ? openRadii : closedRadii
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
        .overlay(alignment: .bottom) {
            if let event = model.event, event.kind != .welcome {
                Countdown(state: model.countdown, color: event.color)
                    .id(model.countdown)
                    .padding(.horizontal, openRadii.bottom)
                    .opacity(isOpen ? 1 : 0)
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: {
            model.shapeSize = CGSize(width: $0.width + 2 * openRadii.top, height: $0.height)
        }
        .background(
            // Les coins du haut débordent de `top` de chaque côté pour se raccorder au bord de l'écran.
            NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)
                .fill(.black)
                .padding(.horizontal, -radii.top)
        )
        .overlay {
            if model.event?.isCompact == true {
                NotchShape(topRadius: radii.top, bottomRadius: radii.bottom, closesTop: false)
                    .stroke(NoticeKind.autoModeColor.opacity(isOpen ? 0.75 : 0), lineWidth: 1.5)
                    .padding(.horizontal, -radii.top)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isOpen)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: openHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func content(for event: NoticeEvent) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    avatar(for: event)
                    Text(event.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(event.color)
                        .lineLimit(1)
                        .idealWidth { titleWidth = $0 }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, leftInset)
                Color.clear.frame(width: notch.width + 2 * notchGap) // notch physique
                rightWing(for: event)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, rightInset)
            }
            .frame(height: rowHeight)
            if event.showsDetail {
                detail(for: event)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 9)
            }
        }
        .id(model.animationStart) // nouvel événement = textes remesurés
    }

    @ViewBuilder
    private func avatar(for event: NoticeEvent) -> some View {
        if let animator = model.animator {
            NotiboyAvatar(animator: animator, start: model.animationStart, panelTopLeft: model.panelTopLeft,
                          size: avatarSize, color: event.isCompact ? NoticeKind.autoModeColor : event.color,
                          haloOpacity: 0.45, haloRadius: avatarSize / 2 + 3)
        }
    }

    private func rightWing(for event: NoticeEvent) -> some View {
        HStack(spacing: 6) {
            if event.isCompact {
                AutoBadge()
            } else if !event.project.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .opacity(0.75)
                    Text(event.project)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            }
            if model.pendingCount > 0 {
                Text("+\(model.pendingCount)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .idealWidth { rightWidth = $0 }
    }

    /// Ligne de détail : étiquette de l'outil (autorisation) puis le texte, sur 1 ligne ou 3 dépliée.
    private func detail(for event: NoticeEvent) -> some View {
        let expanded = model.isHovered || model.isDetailed
        return HStack(alignment: .firstTextBaseline, spacing: 7) {
            if !event.tool.isEmpty {
                Text(event.tool)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(event.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(event.color.opacity(0.18)))
                    .fixedSize()
            }
            detailText(for: event)
                .lineLimit(expanded ? 3 : 1)
                // Chemin coupé au début : le nom du fichier reste visible.
                .truncationMode(event.detailStyle == .path && !expanded ? .head : .tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailText(for event: NoticeEvent) -> Text {
        switch event.detailStyle {
        case .text:
            return Text(event.detail)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.88))
        case .code:
            return Text(event.detail)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
        case .path:
            let path = event.detail as NSString
            let folder = path.deletingLastPathComponent
            let dir = Text(verbatim: folder.isEmpty ? "" : folder.hasSuffix("/") ? folder : folder + "/")
                .foregroundStyle(.white.opacity(0.45))
            let file = Text(verbatim: path.lastPathComponent)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            return Text("\(dir)\(file)")
                .font(.system(size: 11.5, design: .monospaced))
        }
    }
}

/// Rappel du mode auto, comme le « auto mode » jaune de Claude Code (aussi dans l'aide des Réglages).
struct AutoBadge: View {
    var fontSize: CGFloat = 10

    var body: some View {
        Text("AUTO")
            .font(.system(size: fontSize, weight: .bold))
            .tracking(0.2)
            .foregroundStyle(NoticeKind.autoModeColor)
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
