import AppKit

/// Écran et dimensions du notch.
struct NotchGeometry {
    let screen: NSScreen
    let width: CGFloat
    let height: CGFloat

    /// Écran avec notch si il y en a un, sinon écran principal avec une taille par défaut.
    static func current() -> NotchGeometry? {
        let notchScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notchScreen ?? NSScreen.main else { return nil }

        guard notchScreen != nil else {
            return NotchGeometry(screen: screen, width: 180, height: 32)
        }
        let sides = (screen.auxiliaryTopLeftArea?.width ?? 0) + (screen.auxiliaryTopRightArea?.width ?? 0)
        return NotchGeometry(screen: screen,
                             width: screen.frame.width - sides,
                             height: screen.safeAreaInsets.top)
    }
}
