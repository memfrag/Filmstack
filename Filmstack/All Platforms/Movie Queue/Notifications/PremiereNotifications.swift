//
//  Filmstack
//

import SwiftUI
import SwiftData
import UserNotifications

/// Keeps a local notification scheduled at 8:00 on the release day of every
/// movie in the library that isn't watched yet and comes out in the future.
///
/// Attach once near the root with `.premiereNotifications()`. It reschedules
/// whenever the library changes (new movies, changed dates, movies watched),
/// and removes them all when Release Day Reminders is turned off in Profile.
struct PremiereNotificationsModifier: ViewModifier {

    @Query(filter: #Predicate<Movie> { $0.statusRawValue != "watched" })
    private var unwatchedMovies: [Movie]

    @Environment(AppSettings.self) private var appSettings

    func body(content: Content) -> some View {
        content
            .task(id: signature) {
                await PremiereNotifications.reschedule(for: upcoming)
            }
    }

    /// Movies whose notification time hasn't passed yet; none when the
    /// setting is off, which clears any scheduled ones.
    private var upcoming: [PremiereNotifications.Premiere] {
        guard appSettings.releaseNotifications else { return [] }
        return unwatchedMovies.compactMap { movie in
            guard let fireDate = PremiereNotifications.fireDate(forRelease: movie.releaseDate),
                  fireDate > Date() else { return nil }
            return .init(id: movie.id, title: movie.title, fireDate: fireDate,
                         notes: movie.userNotes, overview: movie.overview)
        }
    }

    /// Changes whenever the set of notifications to schedule changes.
    private var signature: String {
        upcoming
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id)|\($0.title)|\($0.fireDate.timeIntervalSince1970)|\($0.notes)" }
            .joined(separator: ",")
    }
}

extension View {
    /// Schedules 8:00 release-day notifications for upcoming library movies.
    func premiereNotifications() -> some View {
        modifier(PremiereNotificationsModifier())
    }
}

enum PremiereNotifications {

    struct Premiere: Sendable {
        let id: UUID
        let title: String
        let fireDate: Date
        /// The user's own notes on the movie, worked into the reminder.
        var notes: String = ""
        var overview: String?
    }

    /// Premieres this close get a written reminder line from their notes;
    /// later ones are rewritten when they come within range.
    private static let personalizedWindow: TimeInterval = 14 * 24 * 60 * 60

    /// The notification body: a line written from the user's notes when
    /// there are any and a model is available, otherwise fixed text.
    private static func body(for premiere: Premiere) async -> String {
        let notes = premiere.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else {
            return String(localized: "\(premiere.title) is out today.")
        }
        if premiere.fireDate.timeIntervalSinceNow < personalizedWindow,
           let line = await ReminderWriter.line(title: premiere.title, notes: notes,
                                                overview: premiere.overview) {
            return line
        }
        return String(localized: "\(premiere.title) is out today. Your note: \(notes)")
    }

    private static let identifierPrefix = "premiere-"
    /// iOS keeps at most 64 pending notifications per app; leave room.
    private static let maximumScheduled = 48
    private static let hour = 8

    /// 8:00 local time on the release day. TMDB release dates are stored as
    /// midnight UTC, so the day is read in UTC and the hour in local time.
    static func fireDate(forRelease releaseDate: Date?) -> Date? {
        guard let releaseDate else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? utc.timeZone
        var components = utc.dateComponents([.year, .month, .day], from: releaseDate)
        components.hour = hour
        return Calendar.current.date(from: components)
    }

    /// Replaces all scheduled premiere notifications with `premieres`. Asks
    /// for permission the first time there is something to schedule.
    static func reschedule(for premieres: [Premiere]) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let existing = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard !premieres.isEmpty, await isAuthorized(center) else { return }

        let soonest = premieres.sorted { $0.fireDate < $1.fireDate }.prefix(maximumScheduled)
        for premiere in soonest {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Premieres Today")
            content.body = await body(for: premiere)
            guard !Task.isCancelled else { return }
            content.sound = .default
            content.userInfo = ["movieID": premiere.id.uuidString]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: premiere.fireDate
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + premiere.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    private static func isAuthorized(_ center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}
