import Foundation

// Port Swift du moteur 3D de Notiboy (export JS fourni par l'utilisateur) : maths 3D.
// Seul ce qu'utilise Notiboy est porté : des « cubes arrondis » (superellipsoïdes) pour la tête et les mains.

typealias Vec3 = SIMD3<Double>

/// Quaternion (w, x, y, z).
struct Quaternion {
    var w, x, y, z: Double

    init(w: Double, x: Double, y: Double, z: Double) {
        let length = (w * w + x * x + y * y + z * z).squareRoot()
        let n = length == 0 ? 1 : length
        (self.w, self.x, self.y, self.z) = (w / n, x / n, y / n, z / n)
    }

    init(axis: Vec3, angle: Double) {
        let s = sin(angle / 2)
        self.init(w: cos(angle / 2), x: axis.x * s, y: axis.y * s, z: axis.z * s)
    }

    /// Orientation de la tête : rotations X, Y, Z en degrés, composées comme dans le moteur d'origine.
    init(degreesX: Double, y: Double, z: Double) {
        let rx = Quaternion(axis: [1, 0, 0], angle: degreesX * .pi / 180)
        let ry = Quaternion(axis: [0, 1, 0], angle: y * .pi / 180)
        let rz = Quaternion(axis: [0, 0, 1], angle: z * .pi / 180)
        self = rz * rx * ry
    }

    static func * (a: Quaternion, b: Quaternion) -> Quaternion {
        Quaternion(w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
                   x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                   y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                   z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w)
    }

    func rotate(_ v: Vec3) -> Vec3 {
        let s = 2 * (y * v.z - z * v.y)
        let c = 2 * (z * v.x - x * v.z)
        let l = 2 * (x * v.y - y * v.x)
        return [v.x + w * s + (y * l - z * c),
                v.y + w * c + (z * s - x * l),
                v.z + w * l + (x * c - y * s)]
    }
}

private func signedPow(_ value: Double, _ exponent: Double) -> Double {
    value < 0 ? -pow(-value, exponent) : pow(value, exponent)
}

private func absolute(_ v: Vec3) -> Vec3 {
    [abs(v.x), abs(v.y), abs(v.z)]
}

private func normalized(_ v: Vec3) -> Vec3 {
    let length = (v * v).sum().squareRoot()
    return length == 0 ? v : v / length
}

// MARK: - Cube arrondi (superellipsoïde)

extension NotiboyData.Surface {
    var half: Vec3 { [width / 2, height / 2, depth / 2] }

    /// Exposant de la superellipsoïde (infini = cube à arêtes vives).
    var exponent: Double {
        roundness <= 0 ? .infinity : 2 / (0.04 + min(max(roundness, 0), 2) / 2 * 0.96)
    }

    /// Point de la surface pour les angles `theta` (autour de Y) et `phi` (élévation).
    func point(theta: Double, phi: Double) -> Vec3 {
        let d: Vec3 = [cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta)]
        let r = exponent
        let a = absolute(d)
        var s = r.isFinite ? pow(pow(a.x, r) + pow(a.y, r) + pow(a.z, r), 1 / r) : max(a.x, a.y, a.z)
        if s == 0 { s = 1 }
        return half * d / s
    }

    func normal(at p: Vec3) -> Vec3 {
        let h = half.replacing(with: 1, where: half .== 0)
        let r = exponent
        if r.isFinite {
            let q = p / h
            return normalized([signedPow(q.x, r - 1) / h.x, signedPow(q.y, r - 1) / h.y, signedPow(q.z, r - 1) / h.z])
        }
        let q = absolute(p / h)
        let axis = q.x >= q.y && q.x >= q.z ? 0 : (q.y >= q.z ? 1 : 2)
        var n = Vec3.zero
        n[axis] = p[axis] < 0 ? -1 : 1
        return n
    }

    /// Point de la face avant (z > 0) à la position (x, y), avec sa normale.
    func frontPoint(x: Double, y: Double) -> (point: Vec3, normal: Vec3) {
        let h = half.replacing(with: 1, where: half .== 0)
        let r = exponent
        guard r.isFinite else {
            let p: Vec3 = [min(max(x, -h.x), h.x), min(max(y, -h.y), h.y), h.z]
            return (p, normal(at: p))
        }
        let c = min(max(y / h.y, -1), 1)
        let l = pow(max(0, 1 - pow(abs(c), r)), 1 / r)
        let u = min(max(x, -h.x * l), h.x * l)
        let f = pow(max(0, 1 - pow(abs(u / h.x), r) - pow(abs(c), r)), 1 / r)
        let p: Vec3 = [u, c * h.y, h.z * f]
        return (p, normal(at: p))
    }

    /// Grille de points de la surface (latitude × longitude).
    func grid(rows: Int, columns: Int) -> [Vec3] {
        (0..<rows).flatMap { row in
            let phi = -Double.pi / 2 + Double(row) / Double(rows - 1) * .pi
            return (0..<columns).map { column in
                point(theta: -.pi + Double(column) / Double(columns - 1) * 2 * .pi, phi: phi)
            }
        }
    }
}
