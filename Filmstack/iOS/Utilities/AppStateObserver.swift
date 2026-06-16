//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import UIKit

/// The AppStateObserver is a convenience object that observes app state
/// notifications and executes the corresponding specified closures.
public final class AppStateObserver {

    public var appWillResignActive: (() -> Void)?

    public var appDidEnterBackground: (() -> Void)?

    public var appWillEnterForeground: (() -> Void)?

    public var appDidBecomeActive: (() -> Void)?

    public var userDidTakeScreenshot: (() -> Void)?

    public init() {
        onNotification(
            UIApplication.willResignActiveNotification,
            invoke: #selector(willResignActive)
        )
        onNotification(
            UIApplication.didEnterBackgroundNotification,
            invoke: #selector(didEnterBackground)
        )
        onNotification(
            UIApplication.willEnterForegroundNotification,
            invoke: #selector(willEnterForeground)
        )
        onNotification(
            UIApplication.didBecomeActiveNotification,
            invoke: #selector(didBecomeActive)
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func onNotification(
        _ name: Notification.Name,
        invoke selector: Selector
    ) {
        NotificationCenter.default
            .addObserver(self, selector: selector, name: name, object: nil)
    }

    @objc private func willResignActive() {
        appWillResignActive?()
    }

    @objc private func didEnterBackground() {
        appDidEnterBackground?()
    }

    @objc private func willEnterForeground() {
        appWillEnterForeground?()
    }

    @objc private func didBecomeActive() {
        appDidBecomeActive?()
    }
}

#endif
