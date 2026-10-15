import SwiftUI
import WebKit

struct WebDocumentSurfaceView: View {
    let url: URL
    var onFailure: () -> Void

    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(canGoBack ? .white : .gray)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                    }
                    .disabled(!canGoBack)

                    Spacer()

                    Button {
                        webView?.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(minHeight: 52)
                .background(Color.black)

                WebDocumentHostRepresentable(
                    url: url,
                    webView: $webView,
                    canGoBack: $canGoBack,
                    isLoading: $isLoading,
                    onFailure: onFailure
                )
            }

            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isLoading)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - UIViewRepresentable

struct WebDocumentHostRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var isLoading: Bool
    var onFailure: () -> Void

    private static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static let compatibilityScript = """
    (function () {
      if (typeof Notification === 'undefined') {
        window.Notification = function () {};
        window.Notification.permission = 'default';
        window.Notification.requestPermission = function () {
          return Promise.resolve('default');
        };
      } else if (typeof Notification.permission === 'undefined') {
        Notification.permission = 'default';
      }
      if (!navigator.permissions || typeof navigator.permissions.query !== 'function') {
        navigator.permissions = {
          query: function () {
            return Promise.resolve({ state: 'prompt', onchange: null });
          }
        };
      }

      // Some tracker scripts stop when window.open() returns null.
      window.open = function (url, target, features) {
        if (typeof url === 'string' && url.length > 0) {
          window.location.assign(url);
        }
        return window;
      };
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.compatibilityScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.backgroundColor = .black
        view.isOpaque = false
        view.allowsBackForwardNavigationGestures = true
        view.customUserAgent = Self.safariUserAgent
        context.coordinator.attach(webView: view)
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // Writing @Binding synchronously here triggers "Modifying state during view update".
        if webView !== uiView {
            DispatchQueue.main.async {
                webView = uiView
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebDocumentHostRepresentable
        private weak var attachedWebView: WKWebView?
        private var failureCalled = false
        /// Once content is shown, redirect chains must not bring the spinner back.
        private var hasRevealedContent = false
        private var revealTimeoutWork: DispatchWorkItem?
        private let revealTimeout: TimeInterval = 8

        init(parent: WebDocumentHostRepresentable) {
            self.parent = parent
        }

        deinit {
            revealTimeoutWork?.cancel()
        }

        func attach(webView: WKWebView) {
            attachedWebView = webView
            scheduleRevealTimeout()
        }

        // MARK: Loading overlay

        private func scheduleRevealTimeout() {
            revealTimeoutWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                StartAppLogger.debug("WebView reveal timeout fired")
                self?.revealContent()
            }
            revealTimeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + revealTimeout, execute: work)
        }

        private func revealContent() {
            revealTimeoutWork?.cancel()
            revealTimeoutWork = nil
            hasRevealedContent = true
            publishLoading(false)
        }

        private func publishLoading(_ loading: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.isLoading != loading else { return }
                self.parent.isLoading = loading
            }
        }

        private func publishCanGoBack(_ value: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.canGoBack != value else { return }
                self.parent.canGoBack = value
            }
        }

        private static func isCancellation(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
        }

        // MARK: WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse,
               navigationResponse.isForMainFrame,
               LaunchSessionStore.shared.savedLastURL == nil,
               !failureCalled,
               (400...599).contains(httpResponse.statusCode) {
                StartAppLogger.debug("WebView main frame HTTP \(httpResponse.statusCode)")
                decisionHandler(.cancel)
                revealContent()
                triggerFailureIfNeeded()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               ["mailto", "tel", "sms"].contains(url.scheme?.lowercased()) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if !hasRevealedContent {
                publishLoading(true)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            revealContent()
            publishCanGoBack(webView.canGoBack)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            revealContent()
            publishCanGoBack(webView.canGoBack)
            // Persist the entry URL, not the redirected offer URL, so relaunch replays the funnel.
            if LaunchSessionStore.shared.savedLastURL == nil {
                LaunchSessionStore.shared.savedLastURL = parent.url
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !Self.isCancellation(error) else { return }
            StartAppLogger.debug("WebView provisional failure: \(error.localizedDescription)")
            revealContent()
            triggerFailureIfNeeded()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !Self.isCancellation(error) else { return }
            StartAppLogger.debug("WebView navigation failure: \(error.localizedDescription)")
            revealContent()
            triggerFailureIfNeeded()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            StartAppLogger.debug("WebView content process terminated, reloading")
            webView.reload()
        }

        private func triggerFailureIfNeeded() {
            guard LaunchSessionStore.shared.savedLastURL == nil, !failureCalled else { return }
            failureCalled = true
            LaunchSessionStore.shared.hasShownNativeShell = true
            DispatchQueue.main.async { self.parent.onFailure() }
        }
    }
}
