//
//  Filmstack
//

import SwiftUI
import SwiftData

/// The 3D crate of DVD cases.
///
/// Input and rendering are split: an invisible horizontal `ScrollView` of
/// equally sized slots supplies the physics (swipes, trackpad, snapping,
/// programmatic scrolling), and its continuous offset drives a separately
/// rendered layer of projected cases.
struct DVDShelf: View {

    let movies: [Movie]
    let position: (Movie) -> Int?
    @Binding var scroll: ScrollPosition
    /// Continuous scroll position in slots (0 = first movie centered),
    /// written by the scroll view.
    @Binding var scrollOffset: CGFloat
    /// The position the cases are drawn at. Pinned during the intro, because
    /// the scroll view reports 0 before it reaches its initial position.
    let offset: CGFloat
    let flippedID: PersistentIdentifier?
    let intro: CGFloat
    /// The case slid out of the crate, if any.
    let pullIndex: Int?
    let isInteractive: Bool
    let onPhaseChange: (ScrollPhase) -> Void
    let onTapCase: (Int) -> Void
    let onTapFlipped: () -> Void
    let onOpenDetails: (Movie) -> Void

    /// Scroll distance per case.
    static let slotWidth: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            let geometry = ShelfGeometry(size: proxy.size)
            ZStack(alignment: .topLeading) {
                inputLayer(geometry: geometry)
                    .allowsHitTesting(isInteractive && flippedID == nil)

                casesLayer(geometry: geometry)
                    .allowsHitTesting(flippedID != nil)
            }
        }
    }

    // MARK: - Input

    private func inputLayer(geometry: ShelfGeometry) -> some View {
        ScrollView(.horizontal) {
            // Slots run last-to-first, so swiping left (forward through the
            // queue) sends the cases back into the crate, with the finger.
            HStack(spacing: 0) {
                ForEach(movies.reversed(), id: \.persistentModelID) { movie in
                    Rectangle()
                        .fill(.clear)
                        .frame(width: Self.slotWidth, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .id(movie.persistentModelID)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        // .never: a fling carries through several cases (the default limits
        // compact-width scroll views to one item per swipe).
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollPosition($scroll, anchor: .center)
        .contentMargins(.horizontal, max(0, (geometry.size.width - Self.slotWidth) / 2), for: .scrollContent)
        .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
            (scrollGeometry.contentOffset.x + scrollGeometry.contentInsets.leading) / Self.slotWidth
        } action: { _, newValue in
            scrollOffset = CGFloat(movies.count - 1) - newValue
        }
        .onScrollPhaseChange { _, phase in
            onPhaseChange(phase)
        }
        .onTapGesture { location in
            if let index = hitCase(at: location, geometry: geometry) {
                onTapCase(index)
            }
        }
    }

    /// The case under a tap: the focused case if the tap lands on it, otherwise
    /// the case whose center is closest.
    private func hitCase(at location: CGPoint, geometry: ShelfGeometry) -> Int? {
        let focused = Int(offset.rounded())
        if movies.indices.contains(focused) {
            let pose = geometry.pose(u: u(focused), intro: intro, flip: 0, pullOut: focused == pullIndex ? 1 : 0)
            if geometry.screenFrame(pose: pose).contains(location) {
                return focused
            }
        }
        let candidates = visibleRange.filter { $0 != focused }
        return candidates.min { lhs, rhs in
            distance(location, geometry.screenCenter(pose: geometry.pose(u: u(lhs), intro: intro, flip: 0, pullOut: 0)))
                < distance(location, geometry.screenCenter(pose: geometry.pose(u: u(rhs), intro: intro, flip: 0, pullOut: 0)))
        }
    }

    /// Depth of a case along the line from the focus: positive is farther
    /// back. #1 stands at the front and later movies recede into the crate.
    private func u(_ index: Int) -> CGFloat {
        CGFloat(index) - offset
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Rendering

    /// Indices worth rendering around the current position.
    private var visibleRange: [Int] {
        guard !movies.isEmpty else { return [] }
        let center = Int(offset.rounded())
        // Later movies recede into the crate; earlier ones come forward.
        let lower = max(0, center - (intro < 1 ? 30 : 9))
        let upper = min(movies.count - 1, center + 24)
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    private func casesLayer(geometry: ShelfGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            if flippedID != nil {
                // Tapping beside a flipped case flips it back.
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onTapGesture(perform: onTapFlipped)
            }

            ForEach(visibleRange, id: \.self) { index in
                let movie = movies[index]
                let isFlipped = movie.persistentModelID == flippedID
                ProjectedCase(
                    movie: movie,
                    position: position(movie),
                    geometry: geometry,
                    u: u(index),
                    intro: intro,
                    flip: isFlipped ? 1 : 0,
                    pullOut: index == pullIndex ? 1 : 0,
                    onTapBack: onTapFlipped,
                    onOpenDetails: { onOpenDetails(movie) }
                )
                // Interruptible: a spring retargets from wherever the case is,
                // so a case that stops being the candidate slides straight back.
                .animation(.spring(duration: 0.45, bounce: 0.15), value: index == pullIndex)
                .allowsHitTesting(isFlipped)
                .modifier(DepthOrder(u: u(index), flip: isFlipped ? 1 : 0))
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
    }
}

/// One case, drawn as projected front, spine and back faces. `intro` and `flip`
/// are animatable so the opening stream and the flip interpolate smoothly.
private struct ProjectedCase: View, Animatable {

    let movie: Movie
    let position: Int?
    let geometry: ShelfGeometry
    let u: CGFloat
    var intro: CGFloat
    var flip: CGFloat
    var pullOut: CGFloat
    let onTapBack: () -> Void
    let onOpenDetails: () -> Void

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(intro, AnimatablePair(flip, pullOut)) }
        set {
            intro = newValue.first
            flip = newValue.second.first
            pullOut = newValue.second.second
        }
    }

    var body: some View {
        let pose = geometry.pose(u: u, intro: intro, flip: flip, pullOut: pullOut)
        ZStack(alignment: .topLeading) {
            if pose.opacity > 0 {
                // Soft contact shadow on the floor, under everything else.
                // It fades while the case flips up toward the camera.
                RoundedRectangle(cornerRadius: geometry.thickness, style: .continuous)
                    .fill(.black.opacity(0.5 * (1 - flip)))
                    .frame(width: geometry.shadowSize.width, height: geometry.shadowSize.height)
                    .blur(radius: geometry.thickness * 0.45)
                    .projectionEffect(geometry.shadowProjection(pose: pose))
                // Plain plastic sides so each case reads as a closed box.
                ForEach([ShelfGeometry.Face.top, .bottom, .edge], id: \.self) { face in
                    if geometry.isVisible(face, pose: pose) {
                        DVDEdgeFace(size: geometry.faceSize(face), shade: pose.shade, isTop: face == .top)
                            .blur(radius: pose.blur)
                            .projectionEffect(geometry.projection(face, pose: pose))
                    }
                }
                if flip == 0, geometry.isVisible(.back, pose: pose) {
                    DVDEdgeFace(size: geometry.faceSize(.back), shade: pose.shade)
                        .blur(radius: pose.blur)
                        .projectionEffect(geometry.projection(.back, pose: pose))
                }
                if geometry.isVisible(.spine, pose: pose) {
                    DVDSpineFace(movie: movie, position: position, size: geometry.faceSize(.spine))
                        .overlay { Color.black.opacity(0.18 + pose.shade) }
                        .blur(radius: pose.blur)
                        .projectionEffect(geometry.projection(.spine, pose: pose))
                }
                if geometry.isVisible(.front, pose: pose) {
                    DVDFrontFace(movie: movie, size: geometry.faceSize(.front))
                        .overlay { Color.black.opacity(pose.shade) }
                        .blur(radius: pose.blur)
                        .projectionEffect(geometry.projection(.front, pose: pose))
                }
                if flip > 0, geometry.isVisible(.back, pose: pose) {
                    DVDBackFace(
                        movie: movie,
                        position: position,
                        size: geometry.faceSize(.back),
                        onOpenDetails: onOpenDetails
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTapBack)
                    .projectionEffect(geometry.projection(.back, pose: pose))
                }
            }
        }
        .opacity(pose.opacity)
        .shadow(color: .black.opacity(0.3 * pose.pull), radius: 10, y: 8)
    }
}

/// Draw order for a case. The cases are parallel slabs, so nearer cases (lower
/// `u`) always cover farther ones, including a case sliding out along its own
/// plane. Only while a case is actually turning around (a flip) does it go on
/// top. `flip` is animated, so the raise follows the turn frame by frame, in
/// both directions, rather than the tap.
private struct DepthOrder: ViewModifier, Animatable {

    let u: CGFloat
    var flip: CGFloat

    var animatableData: CGFloat {
        get { flip }
        set { flip = newValue }
    }

    func body(content: Content) -> some View {
        // The turn starts at flip 0.25 (ShelfGeometry); before that the case
        // is only sliding out of its slot.
        content.zIndex(Double(-u) + (flip > 0.28 ? 100 : 0))
    }
}
