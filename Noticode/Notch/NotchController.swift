import AppKit
import SwiftUI

/// Affiche les événements dans le notch, puis le referme.
/// Un nouvel événement remplace tout de suite celui affiché ; en rafale, chacun reste visible au moins `minimumDisplay`.
/// Tant que la souris est sur la forme, le temps s'arrête et rien ne remplace l'événement affiché.
@MainActor
final class NotchController {
    private let closeAnimationDuration: Duration = .milliseconds(600)
    private let minimumDisplay = 1.5
    /// Au-delà, les plus anciens en attente sont abandonnés (ils seraient périmés).
    private let maxPending = 5

    private let sounds: SoundPlayer
    private let model = NotchModel()
    private var panel: NotchPanel?
    private var pending: [NoticeEvent] = []
    private var runTask: Task<Void, Never>?
    /// Attente de l'événement affiché, réveillée par un nouvel événement ou un geste de fermeture.
    private var sleepTask: Task<Void, Never>?
    private var dismissed = false
    /// Pendant l'affichage, active les clics sur la forme seulement (ailleurs ils traversent).
    private var mouseTask: Task<Void, Never>?

    init(sounds: SoundPlayer) {
        self.sounds = sounds
    }

    /// Geste « glisser vers le haut » : ferme l'événement affiché (les suivants en attente s'affichent ensuite).
    private func dismissCurrent() {
        guard model.isOpen else { return }
        dismissed = true
        sleepTask?.cancel()
    }

    func show(_ event: NoticeEvent) {
        pending.append(event)
        if pending.count > maxPending { pending.removeFirst() }
        model.pendingCount = pending.count
        sleepTask?.cancel() // l'événement affiché passe au temps minimal
        guard runTask == nil else { return } // la boucle en cours prendra l'événement
        runTask = Task {
            // Un événement arrivé pendant l'animation de fermeture relance l'affichage.
            repeat { await runQueue() } while !pending.isEmpty
            runTask = nil
        }
    }

    /// Affiche chaque événement en attente, puis referme le notch quand la file est vide.
    private func runQueue() async {
        while !pending.isEmpty {
            let event = pending.removeFirst()
            model.pendingCount = pending.count
            guard let geometry = NotchGeometry.current() else { continue }
            sounds.play(event.kind, volumeScale: event.isCompact || event.isIdleReminder ? 0.5 : 1)

            let panel = self.panel ?? makePanel()
            self.panel = panel
            position(panel, on: geometry)
            model.notchSize = CGSize(width: geometry.width, height: geometry.height)
            model.event = event
            model.displaySeconds = event.displaySeconds(scale: Preferences.duration.scale)
            model.isDetailed = Preferences.layout == .detailed
            model.animator = NotiboyData.shared.flatMap { NotiboyAnimator(data: $0, name: event.kind.notiboyAnimation) }
            model.animationStart = Date()
            panel.orderFrontRegardless()
            model.isOpen = true
            startMouseTracking()

            await waitWhileShown()
        }
        model.isOpen = false
        stopMouseTracking()
        // On cache la fenêtre une fois l'animation finie : rien ne tourne au repos.
        try? await Task.sleep(for: closeAnimationDuration)
        if pending.isEmpty {
            panel?.orderOut(nil)
            model.event = nil
            model.animator = nil
        }
    }

    /// Seul, l'événement reste son temps complet ; si un autre attend, seulement `minimumDisplay` (pour avoir le temps de le voir).
    /// Pendant le survol, le temps ne compte pas et rien ne remplace l'événement. Un geste de fermeture coupe court.
    /// L'échéance est recalculée à chaque réveil (`show`, geste, début ou fin du survol).
    private func waitWhileShown() async {
        dismissed = false
        var elapsed = 0.0 // temps affiché hors survol
        while !dismissed {
            let left = (pending.isEmpty ? model.displaySeconds : minimumDisplay) - elapsed
            let running = !model.isHovered
            guard left > 0 || !running else { return }
            model.countdown = CountdownState(fraction: max(0, min(left / model.displaySeconds, 1)),
                                             seconds: max(0, left), running: running)
            let start = Date()
            // Pendant le survol, pas d'échéance : la fin du survol réveille.
            let sleep = Task { _ = try? await Task.sleep(for: .seconds(running ? left : 3600)) }
            sleepTask = sleep
            await sleep.value
            sleepTask = nil
            if running { elapsed += Date().timeIntervalSince(start) }
        }
    }

    private func startMouseTracking() {
        guard mouseTask == nil else { return }
        mouseTask = Task {
            while !Task.isCancelled {
                updateMouseCapture()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopMouseTracking() {
        mouseTask?.cancel()
        mouseTask = nil
        model.isHovered = false
        panel?.ignoresMouseEvents = true
    }

    /// Le panel est bien plus grand que la forme : il ne capte la souris que lorsqu'elle est sur la forme.
    private func updateMouseCapture() {
        guard let panel else { return }
        let size = model.shapeSize
        let shape = NSRect(x: panel.frame.midX - size.width / 2,
                           y: panel.frame.maxY - size.height,
                           width: size.width,
                           height: size.height)
        let onShape = shape.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == onShape {
            panel.ignoresMouseEvents = !onShape
        }
        if model.isHovered != onShape {
            model.isHovered = onShape
            sleepTask?.cancel() // met en pause ou relance le temps
        }
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(contentRect: .zero,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered,
                               defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // clics traversants
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: NotchView(model: model))
        panel.onSwipeUp = { [weak self] in self?.dismissCurrent() }
        return panel
    }

    /// Panel centré en haut de l'écran, assez grand pour la forme déployée.
    private func position(_ panel: NSPanel, on geometry: NotchGeometry) {
        let size = NSSize(width: 760, height: geometry.height + 180)
        let frame = geometry.screen.frame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2,
                              y: frame.maxY - size.height,
                              width: size.width,
                              height: size.height),
                       display: false)
        model.panelTopLeft = CGPoint(x: panel.frame.minX, y: panel.frame.maxY)
    }
}
