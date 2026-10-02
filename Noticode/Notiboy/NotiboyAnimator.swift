import Foundation

/// Joue une animation de Notiboy (enchaînement d'expressions + clignements) et tourne la tête vers le curseur.
/// Pas d'état observé : la vue le lit à chaque image.
final class NotiboyAnimator {
    /// Décalages ajoutés à l'expression quand le regard est au maximum (curseur loin sur le côté).
    private static let maxYaw = 30.0      // degrés, gauche/droite
    private static let maxPitch = 20.0    // degrés, haut/bas
    private static let eyeShift = CGSize(width: 10, height: 8)

    private let animation: NotiboyData.Animation
    private let expressions: [NotiboyExpression]
    private var nextBlink: TimeInterval
    private var gaze = CGPoint.zero
    private var lastTime: TimeInterval?

    init?(data: NotiboyData, name: String) {
        guard let animation = data.animations[name] else { return nil }
        let expressions = animation.steps.compactMap { data.expressions[$0.expressionId] }
        guard !expressions.isEmpty, expressions.count == animation.steps.count else { return nil }
        self.animation = animation
        self.expressions = expressions
        nextBlink = animation.blink.initialDelayMs / 1000
    }

    /// Expression et ouverture des yeux à `elapsed` secondes, regard tourné vers `target` (-1…1, y vers le haut).
    func frame(at elapsed: TimeInterval, lookingAt target: CGPoint) -> (expression: NotiboyExpression, blink: Double) {
        // Regard lissé, indépendant de la fréquence d'images (même formule que Coucou).
        let dt = min(0.05, max(0, elapsed - (lastTime ?? elapsed)))
        lastTime = elapsed
        let k = 1 - pow(0.0025, dt)
        gaze.x += (target.x - gaze.x) * k
        gaze.y += (target.y - gaze.y) * k

        var expression = expression(at: elapsed * 1000)
        expression.headY += gaze.x * Self.maxYaw
        expression.headX += gaze.y * Self.maxPitch
        expression.positionXLeft += gaze.x * Self.eyeShift.width
        expression.positionXRight += gaze.x * Self.eyeShift.width
        expression.positionYLeft -= gaze.y * Self.eyeShift.height
        expression.positionYRight -= gaze.y * Self.eyeShift.height
        return (expression, blink(at: elapsed))
    }

    /// Étapes en boucle : transition depuis l'expression précédente, puis pause.
    private func expression(at ms: Double) -> NotiboyExpression {
        let steps = animation.steps
        let cycle = steps.reduce(0) { $0 + $1.transitionMs + $1.holdMs }
        var time = cycle > 0 ? ms.truncatingRemainder(dividingBy: cycle) : 0
        // Le tout premier pas part de la pose de départ (= la 1re expression) ; ensuite, de la précédente.
        let firstCycle = ms < cycle
        for (index, step) in steps.enumerated() {
            let duration = step.transitionMs + step.holdMs
            if time < duration {
                let previous = (index == 0 && firstCycle) ? 0 : (index - 1 + steps.count) % steps.count
                let linear = step.transitionMs > 0 ? min(time / step.transitionMs, 1) : 1
                return expressions[previous].blended(with: expressions[index], progress: Self.ease(linear, step.transition))
            }
            time -= duration
        }
        return expressions[0]
    }

    /// 1 = yeux ouverts ; se ferment vite puis se rouvrent, à intervalles aléatoires.
    private func blink(at elapsed: TimeInterval) -> Double {
        let settings = animation.blink
        guard settings.enabled else { return 1 }
        let duration = settings.durationMs / 1000
        let progress = (elapsed - nextBlink) / duration
        if progress < 0 { return 1 }
        if progress >= 1 {
            nextBlink += duration + Double.random(in: settings.minIntervalMs...settings.maxIntervalMs) / 1000
            return 1
        }
        if progress <= 0.42 {
            let close = progress / 0.42
            return 1 - close * close
        }
        let open = (progress - 0.42) / 0.58
        return 1 - (1 - open) * (1 - open)
    }

    private static func ease(_ p: Double, _ transition: String) -> Double {
        switch transition {
        case "smooth": p * p * (3 - 2 * p)
        case "snappy": 1 - pow(1 - p, 3)
        default: 1 - exp(-6 * p) * cos(8 * p)
        }
    }
}
