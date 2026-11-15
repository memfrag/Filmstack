//
//  Filmstack
//

import SwiftUI
import Charts

/// Statistics for the Watched section: a bar chart of how many movies were
/// watched each month, plus a few headline numbers. Movies without a watched
/// date are left out of the chart.
struct WatchedStatsView: View {

    let movies: [Movie]

    @Environment(\.dismiss) private var dismiss

    /// The month whose bar was tapped; its movies are listed below the chart.
    /// Starts on the current month.
    @State private var selectedMonth: Date? = Calendar.current.dateInterval(of: .month, for: Date())?.start

    private struct MonthCount: Identifiable {
        let month: Date
        let count: Int
        var id: Date { month }
    }

    private let calendar = Calendar.current

    /// One entry per month from the first watched month through this month,
    /// including months with nothing watched.
    private var monthCounts: [MonthCount] {
        let counts = Dictionary(grouping: movies.compactMap(\.dateWatched)) {
            calendar.dateInterval(of: .month, for: $0)?.start ?? $0
        }.mapValues(\.count)
        guard let first = counts.keys.min(),
              let thisMonth = calendar.dateInterval(of: .month, for: Date())?.start else { return [] }
        let last = max(thisMonth, counts.keys.max() ?? thisMonth)

        var result: [MonthCount] = []
        var month = first
        while month <= last {
            result.append(MonthCount(month: month, count: counts[month] ?? 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    var body: some View {
        let data = monthCounts
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if data.isEmpty {
                        ContentUnavailableView(
                            "No Watch Dates",
                            systemImage: "chart.bar",
                            description: Text("Movies you mark as watched show up here by month.")
                        )
                        .padding(.top, 40)
                    } else {
                        summary(data)
                        chartCard(data)
                        // Overlapping layers, so the old and new month cross-fade
                        // in place instead of stacking.
                        ZStack(alignment: .top) {
                            monthMovies
                                .id(selectedMonth)
                                .transition(.opacity)
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedMonth)
                    }
                }
                .padding(20)
            }
            .filmWindowBackground()
            .navigationTitle("Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary

    private func summary(_ data: [MonthCount]) -> some View {
        let total = data.reduce(0) { $0 + $1.count }
        let year = calendar.component(.year, from: Date())
        let thisYear = data
            .filter { calendar.component(.year, from: $0.month) == year }
            .reduce(0) { $0 + $1.count }
        let best = data.max { $0.count < $1.count }
        let average = Double(total) / Double(max(data.count, 1))

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            statTile("Total", value: "\(total)")
            statTile("In \(String(year))", value: "\(thisYear)")
            statTile("Per Month", value: average.formatted(.number.precision(.fractionLength(1))))
            if let best, best.count > 0 {
                statTile("Best Month", value: "\(best.count)",
                         detail: best.month.formatted(.dateTime.month(.abbreviated).year()))
            }
        }
    }

    private func statTile(_ title: LocalizedStringKey, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .filmCard()
    }

    // MARK: - Chart

    private func chartCard(_ data: [MonthCount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movies Watched per Month")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)

            Chart(data) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Movies", item.count)
                )
                .foregroundStyle(Palette.accent.gradient)
                .opacity(selectedMonth == nil || selectedMonth == item.month ? 1 : 0.35)
                .cornerRadius(3)
                .annotation(position: .top, spacing: 2) {
                    if item.count > 0 {
                        Text("\(item.count)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                        .foregroundStyle(Palette.textSecondary)
                    if let date = value.as(Date.self), calendar.component(.month, from: date) == 1 {
                        AxisValueLabel(format: .dateTime.year(), centered: true, verticalSpacing: 14)
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
            .chartScrollableAxes(data.count > 12 ? .horizontal : [])
            .chartXVisibleDomain(length: visibleLength(data))
            .chartScrollPosition(initialX: data.last?.month ?? Date())
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { value in
                    guard let date: Date = proxy.value(atX: value.location.x),
                          let month = calendar.dateInterval(of: .month, for: date)?.start else { return }
                    selectedMonth = selectedMonth == month ? nil : month
                }
            }
            .animation(.smooth(duration: 0.25), value: selectedMonth)
            .frame(height: 240)
        }
        .padding(16)
        .filmCard()
    }

    // MARK: - Selected month

    /// Movies watched in the selected month, most recent first.
    @ViewBuilder private var monthMovies: some View {
        if let selectedMonth {
            let watched = movies
                .filter { movie in
                    movie.dateWatched.map { calendar.isDate($0, equalTo: selectedMonth, toGranularity: .month) } ?? false
                }
                .sorted { ($0.dateWatched ?? .distantPast) > ($1.dateWatched ?? .distantPast) }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(watched.count == 1 ? "1 movie" : "\(watched.count) movies")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                if watched.isEmpty {
                    Text("Nothing watched this month.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(watched, id: \.persistentModelID) { movie in
                        Divider().overlay(Palette.hairline)
                        HStack(spacing: 12) {
                            PosterView(movie: movie, size: .thumbnail, cornerRadius: 4)
                                .frame(height: 54)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(movie.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                if let date = movie.dateWatched {
                                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if let rating = movie.userRating {
                                StarRatingView(rating: .constant(rating), isEditable: false,
                                               starSize: 12, spacing: 2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Show up to a year at a time (scrolling for more), starting at the end.
    private func visibleLength(_ data: [MonthCount]) -> TimeInterval {
        let months = min(max(data.count, 1), 12)
        return TimeInterval(months) * 30.44 * 24 * 60 * 60
    }
}

#if DEBUG
#Preview {
    WatchedStatsView(movies: SampleMovies.makeMovies())
        .modelContainer(MovieStore.previewContainer)
}
#endif
