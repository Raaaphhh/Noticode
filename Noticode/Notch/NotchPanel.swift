import AppKit

/// Panel transparent placé en haut de l'écran, au niveau du notch.
/// Reconnaît le geste « glisser vers le haut » : deux doigts sur le trackpad, ou clic maintenu.
final class NotchPanel: NSPanel {
    var onSwipeUp: (() -> Void)?
    private let swipeThreshold: CGFloat = 25
    private var swipeDistance: CGFloat = 0
    private var swipeHandled = false
    private var dragStart: CGPoint?

    // Sans ça, macOS repousse la fenêtre sous la barre de menus.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .scrollWheel:
            handleScroll(event)
            return
        case .leftMouseDown:
            dragStart = NSEvent.mouseLocation
        case .leftMouseDragged:
            // Coordonnées écran : y augmente vers le haut.
            if let start = dragStart, NSEvent.mouseLocation.y - start.y > swipeThreshold {
                dragStart = nil
                onSwipeUp?()
            }
        case .leftMouseUp:
            dragStart = nil
        default:
            break
        }
        super.sendEvent(event)
    }

    private func handleScroll(_ event: NSEvent) {
        if event.phase == .began {
            swipeDistance = 0
            swipeHandled = false
        }
        // L'inertie qui suit le geste ne compte pas.
        guard event.momentumPhase.isEmpty, !swipeHandled else { return }
        // Doigts vers le haut, quel que soit le réglage « défilement naturel ».
        let up = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        // Une molette compte en lignes, le trackpad en points ; un retour vers le bas annule.
        swipeDistance = max(0, swipeDistance + (event.hasPreciseScrollingDeltas ? up : up * 10))
        if swipeDistance > swipeThreshold {
            swipeDistance = 0
            // Une molette n'a pas de phase : chaque cran est un geste à part.
            swipeHandled = !event.phase.isEmpty
            onSwipeUp?()
        }
    }
}
