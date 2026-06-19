//
//  Filmstack
//

import SwiftUI

/// A 1–5 star rating control supporting half steps (e.g. 3.5).
///
/// When `isEditable`, tapping or dragging across the stars sets the rating in
/// 0.5 increments; tapping at the far left clears it.
struct StarRatingView: View {

    @Binding var rating: Double?
    var isEditable: Bool = true
    var starSize: CGFloat = 24
    var spacing: CGFloat = 5

    private let count = 5

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...count, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .foregroundStyle(.yellow)
            }
        }
        .font(.system(size: starSize))
        .contentShape(Rectangle())
        .overlay {
            if isEditable {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    setRating(atX: value.location.x, width: geometry.size.width)
                                }
                        )
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue(rating.map { String(format: "%.1f stars", $0) } ?? "Not rated")
    }

    private func symbol(for index: Int) -> String {
        let value = rating ?? 0
        if value >= Double(index) {
            return "star.fill"
        } else if value >= Double(index) - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private func setRating(atX x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let fraction = max(0, min(1, x / width))
        let raw = Double(fraction) * Double(count)
        let stepped = (raw * 2).rounded() / 2
        rating = stepped < 0.5 ? nil : min(stepped, Double(count))
    }
}

#Preview {
    struct Demo: View {
        @State private var rating: Double? = 3.5
        var body: some View {
            VStack(spacing: 20) {
                StarRatingView(rating: $rating)
                StarRatingView(rating: .constant(4.0), isEditable: false, starSize: 16)
                Text(rating.map { String(format: "%.1f", $0) } ?? "—")
            }
            .padding()
        }
    }
    return Demo()
}
