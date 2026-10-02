import Foundation

// Données de Notiboy (Resources/notiboy/notiboy.json, extrait de l'export JS de l'avatar).

struct NotiboyData: Decodable {
    struct Surface: Decodable {
        let width: Double
        let height: Double
        let depth: Double
        let roundness: Double
    }

    struct BodyNode: Decodable {
        let surface: Surface
        let position: [Double]
        let rotation: [Double]
    }

    struct Colors: Decodable {
        let body: String
        let eyes: String
    }

    struct Animation: Decodable {
        struct Blink: Decodable {
            let enabled: Bool
            let initialDelayMs: Double
            let minIntervalMs: Double
            let maxIntervalMs: Double
            let durationMs: Double
        }

        struct Step: Decodable {
            let expressionId: String
            let holdMs: Double
            let transitionMs: Double
            let transition: String
        }

        let blink: Blink
        let steps: [Step]
    }

    let surface: Surface
    let bodyNodes: [BodyNode]
    let colors: Colors
    let expressions: [String: NotiboyExpression]
    let animations: [String: Animation]

    static let shared: NotiboyData? = {
        guard let url = Bundle.main.url(forResource: "notiboy", withExtension: "json"),
              let json = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NotiboyData.self, from: json)
    }()
}

/// Une expression : angles de la tête (degrés) et forme/position des yeux.
struct NotiboyExpression: Decodable {
    var headX, headY, headZ: Double
    var widthLeft, widthRight, heightLeft, heightRight: Double
    var spacing: Double
    var positionXLeft, positionXRight, positionYLeft, positionYRight: Double
    var leftAngle, rightAngle: Double
    var perspective: Double

    private static var fields: [WritableKeyPath<NotiboyExpression, Double>] { [
        \.headX, \.headY, \.headZ, \.widthLeft, \.widthRight, \.heightLeft, \.heightRight, \.spacing,
        \.positionXLeft, \.positionXRight, \.positionYLeft, \.positionYRight, \.leftAngle, \.rightAngle, \.perspective,
    ] }

    /// Mélange champ par champ (`progress` 0 → self, 1 → other).
    func blended(with other: NotiboyExpression, progress: Double) -> NotiboyExpression {
        var result = self
        for field in Self.fields {
            result[keyPath: field] += (other[keyPath: field] - self[keyPath: field]) * progress
        }
        return result
    }
}
