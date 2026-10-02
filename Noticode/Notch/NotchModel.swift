import SwiftUI

/// État observé par la vue : l'événement affiché et si le notch est déployé.
@MainActor
@Observable
final class NotchModel {
    var event: NoticeEvent?
    var isOpen = false
    /// Temps d'affichage de l'événement (réglage compris), calculé une fois par le contrôleur.
    var displaySeconds = 0.0
    /// Barre de temps restant, figée pendant le survol.
    var countdown = CountdownState()
    /// La souris est sur la forme : le détail se déplie et le temps s'arrête.
    var isHovered = false
    /// Réglage « Taille : détaillée » : détail sur 3 lignes sans survol.
    var isDetailed = false
    /// Nombre de notifications en attente derrière celle affichée (« +N »).
    var pendingCount = 0
    /// Notiboy de l'événement affiché et l'instant où l'animation démarre ; coin haut-gauche du panel à l'écran (pour suivre le curseur).
    var animator: NotiboyAnimator?
    var animationStart = Date()
    var panelTopLeft = CGPoint.zero
    /// Taille du notch, recalculée à chaque affichage (l'écran a pu changer).
    var notchSize = CGSize(width: 180, height: 32)
    /// Taille de la forme noire déployée (coins du haut compris), pour ne capter la souris que dessus.
    var shapeSize = CGSize.zero
}
