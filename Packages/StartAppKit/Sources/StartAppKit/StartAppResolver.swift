import SwiftUI
import UIKit

/// Orchestrates launch destination: native shell, web document, or staging + probe.
@MainActor
public final class StartAppResolver {

    private let configuration: StartAppConfiguration
    private let sessionStore: LaunchSessionStore
    private let gateEvaluator: CalendarGateEvaluator
    private let urlComposer: RemoteEntryURLComposer
    private let windowPresenter: RootWindowPresenter
    private var activeProbe: RemoteEntryProbe?
    private var stagingProbeCancelled = false

    public init(window: UIWindow?, configuration: StartAppConfiguration) {
        self.configuration = configuration
        self.sessionStore = LaunchSessionStore.shared
        self.gateEvaluator = CalendarGateEvaluator(
            anchorDateString: configuration.calendarGateAnchor,
            timeZone: configuration.gateTimeZone
        )
        self.urlComposer = RemoteEntryURLComposer(
            template: configuration.remoteEntryTemplate,
            trackingParameterName: configuration.trackingParameterName
        )
        self.windowPresenter = RootWindowPresenter(window: window)
        if sessionStore.savedLastURL == nil {
            sessionStore.hasShownNativeShell = false
        }
    }

    public func resolveEntryViewController() -> UIViewController {
        let destination = resolveDestination()
        StartAppLogger.notice("Resolved destination: \(String(describing: destination))")
        return viewController(for: destination)
    }

    public func cancelPendingOperations() {
        stagingProbeCancelled = true
        activeProbe?.cancel()
        activeProbe = nil
        StartAppLogger.debug("Cancelled pending launch probe")
    }

    // MARK: - Destination resolution

    func resolveDestination() -> LaunchDestination {
        #if DEBUG
        switch StartAppDebugOptions.current {
        case .forceNative:
            StartAppLogger.debug("DEBUG override: force native")
            return .native
        case .forceWeb:
            StartAppLogger.debug("DEBUG override: force web")
            if let url = urlComposer.composedURL() ?? sessionStore.savedLastURL {
                return .web(url)
            }
            return .native
        case .forceStaging:
            StartAppLogger.debug("DEBUG override: force staging")
            return .staging
        case .automatic:
            break
        }
        #endif

        guard isRemoteFlowAllowed else {
            return .native
        }

        if sessionStore.hasShownNativeShell {
            return .native
        }

        if let saved = sessionStore.savedLastURL {
            // Saved value only marks that web succeeded once; WKWebView must replay the funnel from the entry URL.
            return .web(urlComposer.composedURL() ?? saved)
        }

        return .staging
    }

    func viewController(for destination: LaunchDestination) -> UIViewController {
        switch destination {
        case .native:
            return makeNativeHost()
        case .web(let url):
            return makeWebHost(url: url)
        case .staging:
            return makeStagingHost()
        }
    }

    private var isRemoteFlowAllowed: Bool {
        gateEvaluator.isGateOpen()
    }

    // MARK: - Hosts

    private func makeNativeHost() -> UIViewController {
        let host = configuration.makeNativeRoot()
        host.modalPresentationStyle = .fullScreen
        return host
    }

    private func makeWebHost(url: URL) -> UIViewController {
        let surface = WebDocumentSurfaceView(url: url) { [weak self] in
            self?.pivotToNative()
        }
        let host = UIHostingController(rootView: surface)
        host.modalPresentationStyle = .fullScreen
        return host
    }

    private func makeStagingHost() -> UIViewController {
        let state = LaunchStagingState(statusMessage: configuration.stagingMessage)
        let canvas = DeferredLaunchCanvas(
            state: state,
            background: configuration.stagingBackground,
            style: configuration.stagingStyle
        )
        let host = UIHostingController(rootView: canvas)
        host.modalPresentationStyle = .fullScreen

        stagingProbeCancelled = false
        DispatchQueue.main.async { [weak self] in
            self?.runStagingProbe(state: state)
        }
        return host
    }

    private func runStagingProbe(state: LaunchStagingState) {
        guard !stagingProbeCancelled else { return }
        guard let entryURL = urlComposer.composedURL() else {
            StartAppLogger.debug("Invalid composed entry URL")
            finishStaging(success: false, webURL: nil)
            return
        }

        let probe = RemoteEntryProbe()
        activeProbe = probe
        probe.probe(entryURL: entryURL, onProgress: { value in
            Task { @MainActor in
                state.progress = value
            }
        }, completion: { [weak self] success, _ in
            Task { @MainActor in
                self?.activeProbe = nil
                guard let self, !self.stagingProbeCancelled else { return }
                self.finishStaging(success: success, webURL: entryURL)
            }
        })
    }

    private func finishStaging(success: Bool, webURL: URL?) {
        if success, let webURL {
            pivotToWeb(url: webURL)
        } else {
            pivotToNative()
        }
    }

    // MARK: - Pivot (after staging)

    func pivotToNative() {
        windowPresenter.crossfade(to: makeNativeHost())
    }

    func pivotToWeb(url: URL) {
        windowPresenter.crossfade(to: makeWebHost(url: url))
    }
}
