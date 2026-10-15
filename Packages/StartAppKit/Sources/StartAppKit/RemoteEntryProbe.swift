import Foundation

/// GET reachability preflight. WebView must still load the entry URL: URLSession cookies are not shared with WKWebView.
final class RemoteEntryProbe {

    private let session: URLSession
    private var task: URLSessionDataTask?
    private let timeout: TimeInterval
    private let maxAttempts: Int

    private static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static let customHeaders: [String: String] = [
        "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
        "Accept-Language": Locale.preferredLanguages.first ?? "en",
        "X-Entry-Channel": "start-app",
        "Cache-Control": "no-cache",
    ]

    init(
        timeout: TimeInterval = 12,
        maxAttempts: Int = 2,
        session: URLSession? = nil
    ) {
        self.timeout = timeout
        self.maxAttempts = max(1, maxAttempts)
        self.session = session ?? RemoteEntryProbe.makeSession(timeout: timeout)
    }

    private static func makeSession(timeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = customHeaders
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func probe(
        entryURL: URL,
        onProgress: ((Double) -> Void)? = nil,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        cancel()
        onProgress?(0.2)
        attempt(entryURL: entryURL, remainingAttempts: maxAttempts, onProgress: onProgress, completion: completion)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func attempt(
        entryURL: URL,
        remainingAttempts: Int,
        onProgress: ((Double) -> Void)?,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        var request = URLRequest(url: entryURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (field, value) in RemoteEntryProbe.customHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue(RemoteEntryProbe.safariUserAgent, forHTTPHeaderField: "User-Agent")

        let attemptIndex = maxAttempts - remainingAttempts + 1

        task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            self.task = nil

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                StartAppLogger.debug("Preflight cancelled — attempt \(attemptIndex)")
                return
            }

            if let error {
                StartAppLogger.debug("Preflight error — attempt \(attemptIndex): \(error.localizedDescription)")
                self.retryOrFail(
                    entryURL: entryURL,
                    remainingAttempts: remainingAttempts,
                    onProgress: onProgress,
                    completion: completion
                )
                return
            }

            guard let http = response as? HTTPURLResponse else {
                StartAppLogger.debug("Preflight: no HTTP response — attempt \(attemptIndex)")
                onProgress?(1.0)
                completion(false, nil)
                return
            }

            StartAppLogger.debug("Preflight status \(http.statusCode) — attempt \(attemptIndex)")
            onProgress?(0.85)

            if (200...299).contains(http.statusCode) {
                onProgress?(1.0)
                completion(true, http.url ?? entryURL)
            } else {
                self.retryOrFail(
                    entryURL: entryURL,
                    remainingAttempts: remainingAttempts,
                    onProgress: onProgress,
                    completion: completion
                )
            }
        }
        StartAppLogger.debug("Preflight start — attempt \(attemptIndex)/\(maxAttempts)")
        task?.resume()
    }

    private func retryOrFail(
        entryURL: URL,
        remainingAttempts: Int,
        onProgress: ((Double) -> Void)?,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        if remainingAttempts > 1 {
            attempt(
                entryURL: entryURL,
                remainingAttempts: remainingAttempts - 1,
                onProgress: onProgress,
                completion: completion
            )
        } else {
            onProgress?(1.0)
            completion(false, nil)
        }
    }
}
