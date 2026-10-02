import CoreGraphics
import Foundation

// Rendu de Notiboy : projection des surfaces 3D en contours 2D, yeux posés sur la face avant de la tête.

// MARK: - Contours 2D

/// Enveloppe convexe (chaîne monotone d'Andrew).
private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    func chain(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for p in points {
            while result.count >= 2 && cross(result[result.count - 2], result[result.count - 1], p) <= 0 {
                result.removeLast()
            }
            result.append(p)
        }
        return result
    }
    return chain(sorted).dropLast() + chain(sorted.reversed()).dropLast()
}

/// Redécoupe un contour fermé en segments d'au plus `step` points de long.
private func resampled(_ points: [CGPoint], step: Double = 7) -> [CGPoint] {
    points.indices.flatMap { index in
        let a = points[index], b = points[(index + 1) % points.count]
        let count = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
        return (0..<count).map { k in
            let t = Double(k) / Double(count)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}

/// Contour fermé lissé (courbes de Bézier passant par chaque point).
private func smoothPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard points.count >= 3 else {
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }
    let n = points.count
    path.move(to: points[0])
    for i in 0..<n {
        let prev = points[(i - 1 + n) % n], p = points[i], next = points[(i + 1) % n], after = points[(i + 2) % n]
        path.addCurve(to: next,
                      control1: CGPoint(x: p.x + (next.x - prev.x) / 6, y: p.y + (next.y - prev.y) / 6),
                      control2: CGPoint(x: next.x - (after.x - p.x) / 6, y: next.y - (after.y - p.y) / 6))
    }
    path.closeSubpath()
    return path
}

// MARK: - Rendu

/// Formes de Notiboy pour une pose, en coordonnées du moteur (centre = 0, y vers le bas).
struct NotiboyShapes {
    var back: [CGPath] = []   // mains derrière la tête
    var head = CGPath(rect: .zero, transform: nil)
    var eyes: [CGPath] = []   // yeux visibles, à découper par la tête
    var front: [CGPath] = []  // mains devant la tête
}

/// Calcule les formes de Notiboy. Les grilles de points 3D sont calculées une fois, seule la projection change.
final class NotiboyRenderer {
    private static let cameraDistance = 620.0

    private let data: NotiboyData
    private let headGrid: [Vec3]
    private let nodeGrids: [[Vec3]]

    init(data: NotiboyData) {
        self.data = data
        // Grilles plus lâches que l'original (33 × 73 et 17 × 49) : invisible à la taille du notch, 4 fois moins de calcul.
        headGrid = data.surface.grid(rows: 17, columns: 37)
        nodeGrids = data.bodyNodes.map { node in
            let rotation = Quaternion(degreesX: node.rotation[0], y: node.rotation[1], z: node.rotation[2])
            let position = Vec3(node.position[0], node.position[1], node.position[2])
            return node.surface.grid(rows: 9, columns: 25).map { rotation.rotate($0) + position }
        }
    }

    /// `blink` : 1 = yeux ouverts, 0 = fermés.
    func shapes(for expression: NotiboyExpression, blink: Double) -> NotiboyShapes {
        let orientation = Quaternion(degreesX: expression.headX, y: expression.headY, z: expression.headZ)
        func project(_ p: Vec3) -> CGPoint {
            let q = orientation.rotate(p)
            let n = Self.cameraDistance - q.z * expression.perspective
            let scale = abs(n) < 1e-4 ? Self.cameraDistance / 1e-4 : Self.cameraDistance / n
            return CGPoint(x: q.x * scale, y: q.y * scale)
        }
        func outline(_ grid: [Vec3]) -> CGPath {
            smoothPath(resampled(convexHull(grid.map(project))))
        }

        var shapes = NotiboyShapes()
        shapes.head = outline(headGrid)

        // Mains : triées de la plus lointaine à la plus proche, devant si assez en avant.
        let nodes = zip(data.bodyNodes, nodeGrids).map { node, grid in
            let position = Vec3(node.position[0], node.position[1], node.position[2])
            let depth = orientation.rotate(position).z
            let rotation = Quaternion(degreesX: node.rotation[0], y: node.rotation[1], z: node.rotation[2])
            let extent = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)].map { orientation.rotate(rotation.rotate($0)).z }
            let thickness = (pow(extent[0] * node.surface.width / 2, 2) + pow(extent[1] * node.surface.height / 2, 2)
                + pow(extent[2] * node.surface.depth / 2, 2)).squareRoot()
            return (depth: depth, front: depth > thickness * 0.1, path: outline(grid))
        }.sorted { $0.depth < $1.depth }
        shapes.back = nodes.filter { !$0.front }.map(\.path)
        shapes.front = nodes.filter(\.front).map(\.path)

        for side in [-1.0, 1.0] {
            let eye = eyeOutline(expression: expression, side: side, blink: blink)
            let visible = eye.map { orientation.rotate($0.normal).z }.reduce(0, +) > 0
            if visible {
                let path = CGMutablePath()
                path.addLines(between: eye.map { project($0.point) })
                path.closeSubpath()
                shapes.eyes.append(path)
            }
        }
        return shapes
    }

    /// Contour d'un œil (rectangle arrondi tourné), posé sur la face avant de la tête.
    private func eyeOutline(expression e: NotiboyExpression, side: Double, blink: Double) -> [(point: Vec3, normal: Vec3)] {
        let left = side < 0
        let width = left ? e.widthLeft : e.widthRight
        let height = 5 + ((left ? e.heightLeft : e.heightRight) - 5) * blink
        let centerX = side * e.spacing / 2 + (left ? e.positionXLeft : e.positionXRight)
        let centerY = left ? e.positionYLeft : e.positionYRight
        let angle = (left ? e.leftAngle : e.rightAngle) * .pi / 180
        return roundedRect(width: width, height: height).map { p in
            let x = centerX + p.x * cos(angle) - p.y * sin(angle)
            let y = centerY + p.x * sin(angle) + p.y * cos(angle)
            // Courbure légère pour épouser la face avant, comme le moteur d'origine.
            let u = x / 120, v = y / 120
            return data.surface.frontPoint(x: 120 * cos(v) * sin(u), y: 120 * sin(v))
        }
    }

    /// Points d'un rectangle arrondi centré (rayon = moitié du plus petit côté).
    private func roundedRect(width: Double, height: Double) -> [CGPoint] {
        let hw = width / 2, hh = height / 2, r = min(hw, hh)
        var points: [CGPoint] = []
        func line(_ a: CGPoint, _ b: CGPoint) {
            let count = max(2, Int((hypot(b.x - a.x, b.y - a.y) / 1.5).rounded(.up)))
            for k in 0..<count {
                let t = Double(k) / Double(count)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        func arc(_ cx: Double, _ cy: Double, _ start: Double) {
            for k in 0..<14 {
                let a = start + Double(k) / 14 * .pi / 2
                points.append(CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r))
            }
        }
        line(CGPoint(x: -hw + r, y: -hh), CGPoint(x: hw - r, y: -hh)); arc(hw - r, -hh + r, -.pi / 2)
        line(CGPoint(x: hw, y: -hh + r), CGPoint(x: hw, y: hh - r)); arc(hw - r, hh - r, 0)
        line(CGPoint(x: hw - r, y: hh), CGPoint(x: -hw + r, y: hh)); arc(-hw + r, hh - r, .pi / 2)
        line(CGPoint(x: -hw, y: hh - r), CGPoint(x: -hw, y: -hh + r)); arc(-hw + r, -hh + r, .pi)
        return points
    }
}
