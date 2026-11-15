//
//  Filmstack
//

import SwiftUI
import QuartzCore

/// The 3D layout of the DVD shelf ("crate").
///
/// Cases stand on edge in a line that recedes diagonally into the scene, each
/// turned the same way so its cover faces front-left and its spine faces
/// front-right. The focused case is pulled out of the line, turned to face the
/// viewer. Everything is computed as real 3D transforms with a single
/// perspective camera, so the front, spine and back faces of a case line up.
///
/// Conventions: x right, y down (screen), z toward the viewer. Matrices are
/// `CATransform3D` (row vectors, `concat(a, b)` applies `a` first).
struct ShelfGeometry {

    let size: CGSize

    // MARK: Case dimensions

    var caseSize: CGSize {
        let height = min(size.height * 0.5, size.width * 0.58 * 190 / 135)
        return CGSize(width: height * 135 / 190, height: height)
    }

    var thickness: CGFloat { caseSize.width * 0.1 }

    // MARK: Camera

    /// Distance from the eye to the z = 0 plane.
    /// Far back (a long lens), so cases toward the sides keep their shape
    /// instead of skewing away from the viewer.
    var eyeDistance: CGFloat { max(size.width, size.height) * 3.4 }

    /// How far the eye sits above the scene. The camera is raised rather than
    /// tilted (a shift lens), so vertical edges stay perfectly vertical while
    /// the tops of the cases stay visible and distant cases still rise.
    var eyeHeight: CGFloat { eyeDistance * tan(14 * .pi / 180) }

    // MARK: Line (resting crate)

    /// How far the cases in the line are turned (cover toward front-left).
    let lineAngle: CGFloat = 54 * .pi / 180

    /// Unit-ish direction the line recedes in (opposite the covers' normal,
    /// plus a little rise).
    var lineDirection: SIMD3<Double> {
        SIMD3(-Double(sin(lineAngle)), -0.2, -Double(cos(lineAngle)))
    }

    /// Distance between neighbouring cases along the line.
    var gap: CGFloat { thickness * 1.6 }

    /// Where the focused slot sits on the line.
    var lineAnchor: SIMD3<Double> {
        SIMD3(Double(caseSize.width * 0.3), Double(caseSize.height * 0.01), Double(-caseSize.width * 0.45))
    }

    // MARK: Focused case

    /// The focused case slides out of the crate along its own width (keeping
    /// the line's angle) — toward the viewer and to the right.
    var slideDirection: SIMD3<Double> {
        SIMD3(-Double(cos(lineAngle)), 0, Double(sin(lineAngle)))
    }

    var slideDistance: CGFloat { caseSize.width * 0.72 }

    /// Angle the case turns to when flipped, so the back cover is readable.
    let flippedAngle: CGFloat = -7 * .pi / 180

    /// Extra distance a tapped case slides out before it starts to turn.
    var flipClearance: CGFloat { caseSize.width * 0.5 }

    /// How much larger the flipped case appears than at rest.
    let flippedZoom: CGFloat = 1.35

    /// Where a flipped case ends up: horizontally centered, brought toward the
    /// camera by `flippedZoom` (capped to fit the view), at the same height on
    /// screen as it was.
    private func presentedPosition(from p: SIMD3<Double>) -> SIMD3<Double> {
        let d = Double(eyeDistance), h = Double(eyeHeight)
        let w0 = 1 - p.z / d
        let fit = Double(caseSize.height / (size.height * 0.94))
        let w = min(max(w0 / Double(flippedZoom), fit), w0)
        let screenY = (p.y + h) / w0 - h
        return SIMD3(0, (screenY + h) * w - h, d * (1 - w))
    }

    // MARK: Poses

    struct Pose {
        /// Case → world (before the scene tilt and camera).
        var world: CATransform3D
        /// Like `world`, but without a flip's lift: where the case's floor
        /// shadow sits.
        var floor: CATransform3D
        /// How far this case is pulled out into focus (0…1).
        var pull: CGFloat
        /// Depth-of-field blur for cases close to the camera.
        var blur: CGFloat
        var opacity: CGFloat
        /// Darkening for cases in the line.
        var shade: CGFloat
    }

    /// The pose of a case `u` slots from the scroll position.
    ///
    /// - Parameters:
    ///   - u: Continuous offset from the focus (0 = focused).
    ///   - intro: Opening animation progress (0 = streaming in, 1 = settled).
    ///   - flip: Back-cover flip progress (0…1), applied only when pulled.
    ///   - pullOut: How far this case is slid out of the line (0…1).
    func pose(u: CGFloat, intro: CGFloat, flip: CGFloat, pullOut: CGFloat = 1) -> Pose {
        let settle = smoothstep(0.8, 1.0, intro) * pullOut
        // Staggered intro: the far end of the line lands first and the nearer
        // cases follow, so they slide into place one after another.
        let delay = 0.4 * min(max((16 - u) / 28, 0), 1)
        let local = min(max((intro - delay) / (1 - delay), 0), 1)
        // `pullOut` is per case (animated), so the case the shelf is heading
        // for can start sliding out before it reaches the focus.
        let pull = settle

        // Resting line position. Evenly spaced: the focused case slides out
        // of its slot without the neighbours making room.
        let along = Double(u * gap)
        var line = lineAnchor + lineDirection * along

        // Intro: the whole line is shifted toward (and past) the camera and
        // bent into a curve that sweeps up from the bottom left.
        let streaming = 1 - smoothstep(0, 1, local)
        if streaming > 0 {
            let shift = Double(streaming) * 11 * Double(gap)
            let v = along - shift
            line = lineAnchor + lineDirection * v
            if v < 0 {
                let bend = v * v / Double(gap) * Double(streaming)
                line += SIMD3(0.0, 0.055, 0.11) * bend
            }
        }

        // Flip, in two phases: the case first slides further out of the crate
        // to clear its neighbours, then turns around while it is brought
        // toward the camera so the back cover reads larger.
        let clear = smoothstep(0, 0.4, flip)
        let turn = smoothstep(0.25, 1, flip)

        var position = line + slideDirection * Double(slideDistance * pull + flipClearance * clear)
        if turn > 0 {
            position = mix(position, presentedPosition(from: position), Double(turn))
        }
        // No rotation on the way out; only a flip turns the case to face front.
        let angle = lineAngle - (lineAngle + flippedAngle) * turn
        let lift = sin(turn * .pi) * caseSize.width * 0.25

        var world = rotationY(angle - turn * .pi)
        let floor = CATransform3DConcat(world, CATransform3DMakeTranslation(
            CGFloat(position.x), CGFloat(position.y), CGFloat(position.z)
        ))
        world = CATransform3DConcat(world, CATransform3DMakeTranslation(
            CGFloat(position.x), CGFloat(position.y), CGFloat(position.z) + lift
        ))

        // Blur and hide cases that come too close to the camera.
        let center = applyTilt(position)
        let depth = CGFloat(center.z)
        let magnification = 1 / max(0.05, 1 - depth / eyeDistance)
        let nearBlur = min(14, max(0, (magnification - 1.45) * 10))
        // Depth of field: cases soften gradually the further they stand from
        // the focus, behind it or in front of it; the focus stays sharp.
        let focusBlur = smoothstep(1.5, 12, abs(u)) * 3.5
        let blur = max(nearBlur, focusBlur)
        // Fade cases out well before any part of them reaches the eye plane,
        // where the projection would flip them over to the other side.
        var opacity: CGFloat = 1 - smoothstep(eyeDistance * 0.4, eyeDistance * 0.55, depth)
        // Fade the far end of the line.
        opacity *= 1 - smoothstep(16, 24, u)
        opacity = max(opacity, turn)

        return Pose(
            world: world,
            floor: floor,
            pull: pull,
            blur: blur,
            opacity: opacity,
            shade: 0.32 * (1 - pull)
        )
    }

    // MARK: Faces

    /// The six sides of a case. `edge` is the opening side opposite the spine.
    enum Face: CaseIterable { case front, back, spine, edge, top, bottom }

    /// Size of a face's view.
    func faceSize(_ face: Face) -> CGSize {
        switch face {
        case .front, .back: caseSize
        case .spine, .edge: CGSize(width: thickness, height: caseSize.height)
        case .top, .bottom: CGSize(width: caseSize.width, height: thickness)
        }
    }

    /// Face (centered) → case transform.
    private func faceTransform(_ face: Face) -> CATransform3D {
        switch face {
        case .front:
            CATransform3DMakeTranslation(0, 0, thickness / 2)
        case .back:
            CATransform3DConcat(rotationY(.pi), CATransform3DMakeTranslation(0, 0, -thickness / 2))
        case .spine:
            // The spine is on the left of the front cover, like a real case.
            CATransform3DConcat(rotationY(-.pi / 2), CATransform3DMakeTranslation(-caseSize.width / 2, 0, 0))
        case .edge:
            CATransform3DConcat(rotationY(.pi / 2), CATransform3DMakeTranslation(caseSize.width / 2, 0, 0))
        case .top:
            CATransform3DConcat(rotationX(.pi / 2), CATransform3DMakeTranslation(0, -caseSize.height / 2, 0))
        case .bottom:
            CATransform3DConcat(rotationX(-.pi / 2), CATransform3DMakeTranslation(0, caseSize.height / 2, 0))
        }
    }

    /// Face view (origin top-left, at the container's top-left) → world, tilted.
    private func faceToWorld(_ face: Face, pose: Pose) -> CATransform3D {
        let fs = faceSize(face)
        var m = CATransform3DMakeTranslation(-fs.width / 2, -fs.height / 2, 0)
        m = CATransform3DConcat(m, faceTransform(face))
        m = CATransform3DConcat(m, pose.world)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, eyeHeight, 0))
        return m
    }

    /// The full projection for a face view placed at the container's top-left.
    func projection(_ face: Face, pose: Pose) -> ProjectionTransform {
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / eyeDistance
        var m = faceToWorld(face, pose: pose)
        m = CATransform3DConcat(m, perspective)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(size.width / 2, size.height / 2 - eyeHeight, 0))
        return ProjectionTransform(m)
    }

    // MARK: Floor shadow

    /// Footprint of a case's contact shadow on the floor: a little wider than
    /// the case and spread out front and back.
    var shadowSize: CGSize { CGSize(width: caseSize.width * 0.96, height: thickness * 1.7) }

    /// How far the floor is below the cases, so they seem to float.
    var floatHeight: CGFloat { caseSize.height * 0.035 }

    /// Projection for a shadow view lying flat on the floor under a case.
    /// It follows the case's position and turn, but not a flip's lift.
    func shadowProjection(pose: Pose) -> ProjectionTransform {
        var m = CATransform3DMakeTranslation(-shadowSize.width / 2, -shadowSize.height / 2, 0)
        m = CATransform3DConcat(m, rotationX(-.pi / 2))
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, caseSize.height / 2 + floatHeight, 0))
        m = CATransform3DConcat(m, pose.floor)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, eyeHeight, 0))
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / eyeDistance
        m = CATransform3DConcat(m, perspective)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(size.width / 2, size.height / 2 - eyeHeight, 0))
        return ProjectionTransform(m)
    }

    /// Whether a face points toward the eye (back-face culling).
    func isVisible(_ face: Face, pose: Pose) -> Bool {
        let m = faceToWorld(face, pose: pose)
        let fs = faceSize(face)
        let center = transform(SIMD3(Double(fs.width / 2), Double(fs.height / 2), 0), m)
        let tip = transform(SIMD3(Double(fs.width / 2), Double(fs.height / 2), 1), m)
        let normal = tip - center
        let toEye = SIMD3(0, 0, Double(eyeDistance)) - center
        return (normal * toEye).sum() > 0
    }

    /// Screen-space center of a case.
    func screenCenter(pose: Pose) -> CGPoint {
        let m = faceToWorld(.front, pose: pose)
        let fs = faceSize(.front)
        return project(transform(SIMD3(Double(fs.width / 2), Double(fs.height / 2), 0), m))
    }

    /// Screen-space bounding box of a case's front face.
    func screenFrame(pose: Pose) -> CGRect {
        let m = faceToWorld(.front, pose: pose)
        let fs = faceSize(.front)
        let corners = [(0.0, 0.0), (Double(fs.width), 0.0), (0.0, Double(fs.height)), (Double(fs.width), Double(fs.height))]
            .map { project(transform(SIMD3($0.0, $0.1, 0), m)) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    // MARK: Math

    private func project(_ p: SIMD3<Double>) -> CGPoint {
        let w = 1 - p.z / Double(eyeDistance)
        return CGPoint(x: p.x / w + Double(size.width / 2), y: p.y / w + Double(size.height / 2 - eyeHeight))
    }

    private func applyTilt(_ p: SIMD3<Double>) -> SIMD3<Double> {
        p + SIMD3(0, Double(eyeHeight), 0)
    }

    private func transform(_ p: SIMD3<Double>, _ m: CATransform3D) -> SIMD3<Double> {
        let x = p.x * Double(m.m11) + p.y * Double(m.m21) + p.z * Double(m.m31) + Double(m.m41)
        let y = p.x * Double(m.m12) + p.y * Double(m.m22) + p.z * Double(m.m32) + Double(m.m42)
        let z = p.x * Double(m.m13) + p.y * Double(m.m23) + p.z * Double(m.m33) + Double(m.m43)
        return SIMD3(x, y, z)
    }

    /// x' = x cos + z sin, z' = -x sin + z cos.
    private func rotationY(_ angle: CGFloat) -> CATransform3D {
        var m = CATransform3DIdentity
        m.m11 = cos(angle); m.m13 = -sin(angle)
        m.m31 = sin(angle); m.m33 = cos(angle)
        return m
    }

    /// y' = y cos - z sin, z' = y sin + z cos.
    private func rotationX(_ angle: CGFloat) -> CATransform3D {
        var m = CATransform3DIdentity
        m.m22 = cos(angle); m.m23 = sin(angle)
        m.m32 = -sin(angle); m.m33 = cos(angle)
        return m
    }
}

private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}


private func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double) -> SIMD3<Double> {
    a + (b - a) * t
}
