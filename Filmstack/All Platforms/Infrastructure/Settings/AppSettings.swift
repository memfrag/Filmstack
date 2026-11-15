//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import KeyValueStore

// MARK: - AppSettings

/// A container for application-wide user settings.
///
/// `AppSettings` provides observable properties that represent user preferences
/// and persists them using an underlying key–value store.
/// It is designed to be injected into SwiftUI views and other components
/// that depend on reactive settings.
///
@Observable @MainActor public final class AppSettings {

    // MARK: Key

    /// The keys used to store and retrieve settings from the underlying store.
    public enum Key: String {
        /// The ISO 3166-1 region used to resolve release dates.
        case releaseRegion

        /// The user's Letterboxd username (for the diary RSS feed).
        case letterboxdUsername

        /// Whether the Maybe Later section is shown.
        case showsMaybeLater

        /// Whether the movie picker blurs cases away from the focus.
        case pickerDepthOfField

        // <-- (1 / 3) Add key for new property here
    }

    // MARK: Properties

    /// The ISO 3166-1 region code (e.g. "US", "SE") used to pick a local release
    /// date for movies. Defaults to the device's current region.
    public var releaseRegion: String {
        didSet {
            store.save(releaseRegion, for: .releaseRegion)
        }
    }

    /// The device's current region code, used as the default.
    public static var defaultRegion: String {
        Locale.current.region?.identifier ?? "US"
    }

    /// The user's Letterboxd username, used to load their diary RSS feed.
    public var letterboxdUsername: String {
        didSet {
            store.save(letterboxdUsername, for: .letterboxdUsername)
        }
    }

    /// Whether the Maybe Later section (and the actions that move movies there)
    /// is shown. Off by default.
    public var showsMaybeLater: Bool {
        didSet {
            store.save(showsMaybeLater, for: .showsMaybeLater)
        }
    }

    /// Whether the movie picker's shelf uses a depth-of-field blur on cases
    /// away from the focus. Off by default, since the blur costs performance.
    public var pickerDepthOfField: Bool {
        didSet {
            store.save(pickerDepthOfField, for: .pickerDepthOfField)
        }
    }

    // <-- (2 / 3) Add property for new property here

    // MARK: Setup

    /// The key–value store that backs this settings container.
    @ObservationIgnored
    private let store: AnyKeyValueStore<AppSettings.Key>

    /// Creates a new instance of `AppSettings`.
    ///
    /// - Parameter store: The store used to persist values. If `nil`,
    ///   defaults to a `UserDefaults`-backed store.
    ///
    public init(store: AnyKeyValueStore<AppSettings.Key>? = nil) {
        self.store = store ?? .defaultStore
        releaseRegion = self.store.load(.releaseRegion, default: AppSettings.defaultRegion)
        letterboxdUsername = self.store.load(.letterboxdUsername, default: "")
        showsMaybeLater = self.store.load(.showsMaybeLater, default: false)
        pickerDepthOfField = self.store.load(.pickerDepthOfField, default: false)

        // <-- (3 / 3) Add initializer for new property here.
    }
}
