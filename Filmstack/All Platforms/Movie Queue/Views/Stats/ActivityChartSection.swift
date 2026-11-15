//
//  Filmstack
//

import SwiftUI
import Charts

/// Movies watched per month (or year) as bars. Tap or drag across the bars
/// to pick a period; its movies show in the poster history below.
struct ActivityChartSection: View {

    let stats: WatchedStats
    let granularity: WatchedStats.Granularity
    @Binding var selection: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(granularity == .month ? "Movies Watched per Month" : "Movies Watched per Year")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            selectionSummary
            // A fresh chart per granularity, so its bars grow in again and its
            // scroll position starts at the end.
            ActivityChart(stats: stats, granularity: granularity, selection: $selection)
                .id(granularity)
        }
        .padding(16)
        .filmCard(cornerRadius: 20)
    }

    /// "July 2026 · 8 movies" for the picked bar, so the selection isn't
    /// shown by colour alone.
    @ViewBuilder private var selectionSummary: some View {
        if let selection {
            let count = stats.counts(granularity).first { $0.start == selection }?.count ?? 0
            HStack(spacing: 6) {
                Text(granularity == .month
                     ? selection.formatted(.dateTime.month(.wide).year())
                     : selection.formatted(.dateTime.year()))
                    .foregroundStyle(Palette.textPrimary)
                Text("·").foregroundStyle(Palette.textSecondary)
                Text(count == 1 ? "1 movie" : "\(count) movies")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(Palette.accentBright)
            }
            .font(.subheadline.weight(.semibold))
            .animation(.smooth(duration: 0.25), value: selection)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Selected: \(selection.formatted(.dateTime.month(.wide).year())), \(count) movies")
        }
    }
}

private struct ActivityChart: View {

    let stats: WatchedStats
    let granularity: WatchedStats.Granularity
    @Binding var selection: Date?

    /// Bars start flat and grow to their counts when the chart appears.
    @State private var grown = false
    /// Raw value from the chart's own selection gesture.
    @State private var rawSelection: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var data: [WatchedStats.PeriodCount] { stats.counts(granularity) }
    private var scrollable: Bool { data.count > 12 }

    var body: some View {
        let maxCount = max(data.map(\.count).max() ?? 0, 1)
        Chart(data) { item in
            let isSelected = selection == item.start
            BarMark(
                x: .value("Period", item.start, unit: granularity.component),
                y: .value("Movies", grown ? item.count : 0)
            )
            .foregroundStyle(isSelected ? Palette.accentBright.gradient : Palette.accent.gradient)
            .opacity(selection == nil || isSelected ? 1 : 0.35)
            .cornerRadius(4)
            .annotation(position: .top, spacing: 2) {
                if item.count > 0 {
                    Text("\(item.count)")
                        .font(.caption2.weight(isSelected ? .bold : .semibold).monospacedDigit())
                        .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                        .opacity(grown ? 1 : 0)
                }
            }
            .accessibilityLabel(label(for: item.start))
            .accessibilityValue(item.count == 1 ? "1 movie" : "\(item.count) movies")
        }
        // Fixed so the axis doesn't rescale while the bars grow.
        .chartYScale(domain: 0...(Double(maxCount) * 1.15))
        .chartXAxis {
            switch granularity {
            case .month:
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                        .foregroundStyle(Palette.textSecondary)
                    if let date = value.as(Date.self), stats.calendar.component(.month, from: date) == 1 {
                        AxisValueLabel(format: .dateTime.year(), centered: true, verticalSpacing: 14)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            case .year:
                AxisMarks(values: .stride(by: .year)) { _ in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel(format: .dateTime.year(), centered: true)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel().foregroundStyle(Palette.textSecondary)
            }
        }
        .chartScrollableAxes(scrollable ? .horizontal : [])
        .chartXVisibleDomain(length: visibleLength)
        .chartScrollPosition(initialX: data.last?.start ?? Date())
        // Tap a bar to pick it, or press and drag across the bars. Plain
        // swipes still scroll the page (and the chart, when it scrolls).
        // The chart clears its own selection when the touch ends; the
        // picked period stays.
        .chartXSelection(value: $rawSelection)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { proxy.selectXValue(at: $0.location.x) }
                .exclusively(before: LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        if case .second(true, let drag?) = value {
                            proxy.selectXValue(at: drag.location.x)
                        }
                    })
        }
        .onChange(of: rawSelection) { _, date in
            guard let date else { return }
            let start = stats.start(of: date, granularity)
            if data.contains(where: { $0.start == start }), start != selection {
                withAnimation(.smooth(duration: 0.25)) { selection = start }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .frame(height: 150)
        .accessibilityLabel(granularity == .month ? "Movies watched per month" : "Movies watched per year")
        .onAppear {
            if reduceMotion {
                grown = true
            } else {
                withAnimation(.smooth(duration: 0.8).delay(0.15)) { grown = true }
            }
        }
    }

    private func label(for start: Date) -> String {
        granularity == .month
            ? start.formatted(.dateTime.month(.wide).year())
            : start.formatted(.dateTime.year())
    }

    /// Up to 12 bars at a time (scrolling for more), starting at the end.
    private var visibleLength: TimeInterval {
        let bars = TimeInterval(min(max(data.count, 1), 12))
        let day: TimeInterval = 24 * 60 * 60
        return bars * (granularity == .month ? 30.44 : 365.25) * day
    }
}
