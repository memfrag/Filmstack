//
//  Filmstack
//

import SwiftUI
import Charts

/// Statistics for the Watched section: a bar chart of how many movies were
/// watched each month or each year, plus a few headline numbers. Movies
/// without a watched date are left out of the chart.
struct WatchedStatsView: View {

    let movies: [Movie]

    @Environment(\.dismiss) private var dismiss

    /// Whether the chart counts per month or per year.
    enum Period: String, CaseIterable, Identifiable {
        case month, year

        var id: Self { self }

        var component: Calendar.Component {
            switch self {
            case .month: .month
            case .year: .year
            }
        }
    }

    @State private var period: Period = .month

    /// The movie tapped in the list, pushed as a detail page in the sheet.
    @State private var pushedMovie: Movie?

    /// The period whose bar was tapped; its movies are listed below the chart.
    /// Starts on the current month (or year).
    @State private var selectedPeriod: Date? = Calendar.current.dateInterval(of: .month, for: Date())?.start

    private struct PeriodCount: Identifiable {
        let start: Date
        let count: Int
        var id: Date { start }
    }

    private let calendar = Calendar.current

    private func start(of date: Date) -> Date {
        calendar.dateInterval(of: period.component, for: date)?.start ?? date
    }

    /// One entry per month (or year) from the first watched one through the
    /// current one, including periods with nothing watched.
    private var periodCounts: [PeriodCount] {
        let counts = Dictionary(grouping: movies.compactMap(\.dateWatched)) { start(of: $0) }
            .mapValues(\.count)
        guard let first = counts.keys.min() else { return [] }
        let current = start(of: Date())
        let last = max(current, counts.keys.max() ?? current)

        var result: [PeriodCount] = []
        var date = first
        while date <= last {
            result.append(PeriodCount(start: date, count: counts[date] ?? 0))
            guard let next = calendar.date(byAdding: period.component, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    var body: some View {
        let data = periodCounts
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
                        Picker("Period", selection: $period) {
                            Text("By Month").tag(Period.month)
                            Text("By Year").tag(Period.year)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: period) {
                            selectedPeriod = start(of: Date())
                        }
                        summary(data)
                        chartCard(data)
                        // Overlapping layers, so the old and new month cross-fade
                        // in place instead of stacking.
                        ZStack(alignment: .top) {
                            periodMovies
                                .id(selectedPeriod)
                                .transition(.opacity)
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
                    }
                }
                .padding(20)
            }
            .filmWindowBackground()
            .navigationTitle("Statistics")
            .navigationDestination(item: $pushedMovie) { _ in
                MovieDetailColumn(selection: $pushedMovie)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
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

    private func summary(_ data: [PeriodCount]) -> some View {
        let total = data.reduce(0) { $0 + $1.count }
        let year = calendar.component(.year, from: Date())
        let thisYear = movies.compactMap(\.dateWatched)
            .filter { calendar.component(.year, from: $0) == year }
            .count
        let best = data.max { $0.count < $1.count }
        let average = Double(total) / Double(max(data.count, 1))

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            statTile("Total", value: "\(total)")
            statTile("In \(String(year))", value: "\(thisYear)")
            statTile(period == .month ? "Per Month" : "Per Year",
                     value: average.formatted(.number.precision(.fractionLength(1))))
            if let best, best.count > 0 {
                statTile(period == .month ? "Best Month" : "Best Year", value: "\(best.count)",
                         detail: label(for: best.start, short: true))
            }
        }
    }

    /// "May 2026" / "May" style labels for a month, or just the year.
    private func label(for start: Date, short: Bool = false) -> String {
        switch period {
        case .month: start.formatted(.dateTime.month(short ? .abbreviated : .wide).year())
        case .year: start.formatted(.dateTime.year())
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

    private func chartCard(_ data: [PeriodCount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(period == .month ? "Movies Watched per Month" : "Movies Watched per Year")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)

            Chart(data) { item in
                BarMark(
                    x: .value("Period", item.start, unit: period.component),
                    y: .value("Movies", item.count)
                )
                .foregroundStyle(Palette.accent.gradient)
                .opacity(selectedPeriod == nil || selectedPeriod == item.start ? 1 : 0.35)
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
                switch period {
                case .month:
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine().foregroundStyle(Palette.hairline)
                        AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                            .foregroundStyle(Palette.textSecondary)
                        if let date = value.as(Date.self), calendar.component(.month, from: date) == 1 {
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
            .chartScrollableAxes(data.count > 12 ? .horizontal : [])
            .chartXVisibleDomain(length: visibleLength(data))
            .chartScrollPosition(initialX: data.last?.start ?? Date())
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { value in
                    guard let date: Date = proxy.value(atX: value.location.x) else { return }
                    let tapped = start(of: date)
                    selectedPeriod = selectedPeriod == tapped ? nil : tapped
                }
            }
            .animation(.smooth(duration: 0.25), value: selectedPeriod)
            .frame(height: 240)
            // A fresh chart per period, so its scroll position starts at the end.
            .id(period)
        }
        .padding(16)
        .filmCard()
    }

    // MARK: - Selected period

    /// Movies watched in the selected month or year, most recent first.
    @ViewBuilder private var periodMovies: some View {
        if let selectedPeriod {
            let watched = movies
                .filter { movie in
                    movie.dateWatched.map {
                        calendar.isDate($0, equalTo: selectedPeriod, toGranularity: period.component)
                    } ?? false
                }
                .sorted { ($0.dateWatched ?? .distantPast) > ($1.dateWatched ?? .distantPast) }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label(for: selectedPeriod))
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(watched.count == 1 ? "1 movie" : "\(watched.count) movies")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                if watched.isEmpty {
                    Text(period == .month ? "Nothing watched this month." : "Nothing watched this year.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(watched, id: \.persistentModelID) { movie in
                        Divider().overlay(Palette.hairline)
                        Button { pushedMovie = movie } label: { HStack(spacing: 12) {
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
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.textSecondary.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Show up to 12 bars at a time (scrolling for more), starting at the end.
    private func visibleLength(_ data: [PeriodCount]) -> TimeInterval {
        let bars = TimeInterval(min(max(data.count, 1), 12))
        let day: TimeInterval = 24 * 60 * 60
        return bars * (period == .month ? 30.44 : 365.25) * day
    }
}

#if DEBUG
#Preview {
    WatchedStatsView(movies: SampleMovies.makeMovies())
        .modelContainer(MovieStore.previewContainer)
}
#endif
