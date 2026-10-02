// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 Raphaël Descamps
// Port Swift du moteur AvatarProceduralEngine (@bible-strong/avatar-core),
// (c) Stéphane Montlouis-Calixte, AGPL-3.0-only, commit 79fe9ba06e48.
// Modifié en septembre-octobre 2026 pour Noticode. Voir NOTICE.md.

import AppKit
import SwiftUI

/// Notiboy dessiné en direct (vraie 3D), animé et qui suit le curseur. Ne se redessine que tant que la vue existe.
struct NotiboyView: View {
    /// Distance (en points) à laquelle le regard atteint son maximum.
    private static let reach = CGSize(width: 400, height: 250)
    /// Zone du moteur affichée (coordonnées centrées), assez large pour les mains et les rotations.
    private static let viewBox = 470.0

    /// Formes calculées une fois pour toute l'app (grilles 3D), couleurs de l'avatar.
    @MainActor private static let renderer = NotiboyData.shared.map(NotiboyRenderer.init)
    @MainActor private static let colors = NotiboyData.shared.map { (body: Color(hex: $0.colors.body), eyes: Color(hex: $0.colors.eyes)) }

    let animator: NotiboyAnimator
    let start: Date
    /// Coin haut-gauche du panel, en coordonnées écran (origine en bas à gauche).
    let panelTopLeft: CGPoint

    @State private var center = CGPoint.zero // centre de Notiboy dans le panel (origine en haut à gauche)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { canvas, size in
                guard let renderer = Self.renderer, let colors = Self.colors else { return }
                let frame = animator.frame(at: context.date.timeIntervalSince(start), lookingAt: target)
                let shapes = renderer.shapes(for: frame.expression, blink: frame.blink)
                let scale = min(size.width, size.height) / Self.viewBox
                canvas.translateBy(x: size.width / 2, y: size.height / 2)
                canvas.scaleBy(x: scale, y: scale)
                for path in shapes.back { canvas.fill(Path(path), with: .color(colors.body)) }
                canvas.fill(Path(shapes.head), with: .color(colors.body))
                canvas.drawLayer { eyes in
                    eyes.clip(to: Path(shapes.head))
                    for path in shapes.eyes { eyes.fill(Path(path), with: .color(colors.eyes)) }
                }
                for path in shapes.front { canvas.fill(Path(path), with: .color(colors.body)) }
            }
        }
        .onGeometryChange(for: CGPoint.self) {
            let frame = $0.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: {
            center = $0
        }
    }

    /// Direction du curseur par rapport à Notiboy, entre -1 et 1 (y positif = vers le haut).
    private var target: CGPoint {
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - (panelTopLeft.x + center.x)
        let dy = mouse.y - (panelTopLeft.y - center.y)
        return CGPoint(x: min(max(dx / Self.reach.width, -1), 1),
                       y: min(max(dy / Self.reach.height, -1), 1))
    }
}

/// Notiboy sur un halo coloré (sinon son bleu sombre se perd dans le noir du notch).
struct NotiboyAvatar: View {
    let animator: NotiboyAnimator
    let start: Date
    let panelTopLeft: CGPoint
    let size: CGFloat
    let color: Color
    var haloOpacity = 0.6
    /// Rayon du dégradé, et taille du cercle qui le contient (par défaut celle de Notiboy).
    let haloRadius: CGFloat
    var haloSize: CGFloat?

    var body: some View {
        let halo = haloSize ?? size
        NotiboyView(animator: animator, start: start, panelTopLeft: panelTopLeft)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(haloOpacity), .clear],
                                         center: .center, startRadius: 0, endRadius: haloRadius))
                    .frame(width: halo, height: halo)
            )
    }
}

extension Color {
    /// Couleur « #rrggbb » ; noir si le texte est invalide.
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
