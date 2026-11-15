//
//  Filmstack
//

import SwiftUI

/// A "poster wall" release calendar for the Upcoming section: one month grid per
/// month that has releases, where each release day is filled by its poster and
/// empty days recede. Tapping a poster selects the movie; a day with several
/// releases opens a menu to pick one.
struct UpcomingCalendarView<MenuContent: View>: View {

    let movies: [Movie]
    @Binding var selection: Movie?
    @ViewBuilder var menu: (Movie) -> MenuContent

    private let calendar = Calendar.current
    private let cellSpacing: CGFloat = 4

    /// Movies grouped by the start of their release day.
    private var moviesByDay: [Date: [Movie]] {
        Dictionary(grouping: movies.filter { $0.releaseDate != nil }) {
            calendar.startOfDay(for: $0.releaseDate!)
        }
    }

    /// The first day of every month that has at least one release, in order.
    private var months: [Date] {
        let starts = Set(moviesByDay.keys.compactMap {
            calendar.dateInterval(of: .month, for: $0)?.start
        })
        return starts.sorted()
    }

    var body: some View {
        let byDay = moviesByDay
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(months, id: \.self) { month in
                    monthView(month, byDay: byDay)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Month

    private func monthView(_ month: Date, byDay: [Date: [Movie]]) -> some View {
        let days = daysInMonth(month)
        let releaseCount = days.filter(\.inMonth).reduce(0) { $0 + (byDay[$1.date]?.count ?? 0) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(releaseCount == 1 ? "1 release" : "\(releaseCount) releases")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7),
                      spacing: cellSpacing) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }
                ForEach(days, id: \.date) { day in
                    if day.inMonth {
                        dayCell(day.date, movies: byDay[day.date] ?? [])
                    } else {
                        outsideDayCell(day.date)
                    }
                }
            }
        }
    }

    /// The month's days as whole weeks: the first and last weeks are filled out
    /// with the neighbouring months' days (`inMonth == false`), so every month is
    /// a full rectangle.
    private func daysInMonth(_ month: Date) -> [(date: Date, inMonth: Bool)] {
        guard let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let total = Int((Double(leading + count) / 7).rounded(.up)) * 7
        return (0..<total).compactMap { index in
            let offset = index - leading
            guard let date = calendar.date(byAdding: .day, value: offset, to: month) else { return nil }
            return (date, offset >= 0 && offset < count)
        }
    }

    /// Very short weekday symbols, starting at the locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: - Day

    @ViewBuilder
    private func dayCell(_ day: Date, movies: [Movie]) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isPast = day < calendar.startOfDay(for: Date())
        let dayNumber = calendar.component(.day, from: day)

        if let first = movies.first {
            let selected = movies.contains { $0.persistentModelID == selection?.persistentModelID }
            Group {
                if movies.count == 1 {
                    Button { selection = first } label: {
                        posterCell(first, day: dayNumber, extra: 0, selected: selected)
                    }
                } else {
                    Menu {
                        ForEach(movies, id: \.persistentModelID) { movie in
                            Button(movie.title) { selection = movie }
                        }
                    } label: {
                        posterCell(first, day: dayNumber, extra: movies.count - 1, selected: selected)
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                }
            }
            .buttonStyle(.plain)
            .contextMenu { if movies.count == 1 { menu(first) } }
            .accessibilityLabel(movies.map(\.title).joined(separator: ", "))
            .accessibilityValue(day.formatted(date: .long, time: .omitted))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.card)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    Text("\(dayNumber)")
                        .font(.caption2.weight(isToday ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(isToday ? Palette.accentBright
                                         : Palette.textSecondary.opacity(isPast ? 0.3 : 0.6))
                        .padding(5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isToday ? Palette.accent.opacity(0.8) : Palette.hairline,
                                      lineWidth: isToday ? 1.5 : 0.5)
                }
                .accessibilityHidden(true)
        }
    }

    /// A day from the previous or next month that pads out a week: a faint tile
    /// with its number, never a poster (that month shows the release itself).
    private func outsideDayCell(_ day: Date) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Palette.card.opacity(0.4))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary.opacity(0.22))
                    .padding(5)
            }
            .accessibilityHidden(true)
    }

    private func posterCell(_ movie: Movie, day: Int, extra: Int, selected: Bool) -> some View {
        PosterView(movie: movie, size: .queue, cornerRadius: 6)
            .overlay(alignment: .topLeading) {
                Text("\(day)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                    .padding(3)
            }
            .overlay(alignment: .bottomTrailing) {
                if extra > 0 {
                    Text("+\(extra)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Palette.accent, in: Capsule())
                        .padding(3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Palette.accentBright, lineWidth: selected ? 2 : 0)
            }
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    UpcomingCalendarView(
        movies: SampleMovies.makeMovies(),
        selection: .constant(nil)
    ) { _ in EmptyView() }
    .filmWindowBackground()
    .modelContainer(MovieStore.previewContainer)
}
#endif
