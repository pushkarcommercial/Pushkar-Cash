import UIKit
import WebKit
import SnapKit

/// 据量 / Accurate Recommendation H5 — aligned with LoanEase `LERejectH5WebViewController`.
final class FlexRejectVolumeCanvas: FlexBaseCanvas {
    private let pageURL: URL
    private let bridgeName = "iosHandler"
    private var scriptRelay: FlexRejectVolumeScriptRelay?

    private let webView: WKWebView

    init(url: URL) {
        self.pageURL = url
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let relay = FlexRejectVolumeScriptRelay()
        self.scriptRelay = relay
        config.userContentController.add(relay, name: bridgeName)
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = FlexPalette.canvasGray
        view.scrollView.backgroundColor = FlexPalette.canvasGray
        view.allowsBackForwardNavigationGestures = false
        self.webView = view
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        relay.target = self
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Hub.rejectVolumeTitle)
        flexNavBar.onBack = { [weak self] in self?.leave() }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.bottom.equalToSuperview()
        }

        webView.navigationDelegate = self
        FlexSpinnerOverlay.beginRequest()
        webView.load(URLRequest(url: pageURL))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed { tearDown() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func leave() {
        tearDown()
        navigationController?.popViewController(animated: true)
    }

    private func tearDown() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: bridgeName)
        webView.stopLoading()
        webView.navigationDelegate = nil
        scriptRelay?.target = nil
        FlexSpinnerOverlay.endRequest()
    }

    /// LoanEase: inject once on `didFinish`.
    private func injectRejectData() {
        let bag = MintStampBuilder.shared.rejectH5SessionBag(mobile: CofferVault.shared.cachedMobileLine)
        guard JSONSerialization.isValidJSONObject(bag),
              let data = try? JSONSerialization.data(withJSONObject: bag),
              let json = String(data: data, encoding: .utf8) else { return }
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        webView.evaluateJavaScript("rejectData('\(escaped)')") { _, _ in }
    }

    fileprivate func handleBridgeBody(_ body: Any) {
        if Self.shouldTriggerDetailGoProduct(body) {
            openAccurateRecommend()
            return
        }
        let raw = (body as? String) ?? String(describing: body)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("thirdUrl") else { return }
        let dict = Self.parseQueryMessage(trimmed)
        let third = (dict["thirdUrl"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let type = (dict["type"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        PulseBeaconRecorder.shared.stamp(.rejectH5Open, remark2: type.isEmpty ? "NULL" : type)
        guard !third.isEmpty, let url = URL(string: third) else { return }
        // LoanEase: leave App via system open.
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// H5 `detailGoProduct` → leave 据量页, run manual dcRecommend matching from home.
    private func openAccurateRecommend() {
        tearDown()
        FlexRootOrchestrator.shared.returnToHubHome()
        DispatchQueue.main.async {
            guard let dock = FlexRootOrchestrator.shared.keyWindow?.rootViewController as? FlexDockShell,
                  let nav = dock.viewControllers?.first as? UINavigationController,
                  let host = nav.viewControllers.first else { return }
            FlexRecommendLaunch.open(from: host, autoOrder: false)
        }
    }

    private static func shouldTriggerDetailGoProduct(_ body: Any) -> Bool {
        if let dict = body as? [String: Any], dict["detailGoProduct"] != nil {
            return true
        }
        if let raw = body as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "detailGoProduct" || trimmed.hasPrefix("detailGoProduct") {
                return true
            }
            let dict = parseQueryMessage(trimmed)
            if dict["detailGoProduct"] != nil { return true }
            if let json = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any],
               json["detailGoProduct"] != nil {
                return true
            }
        }
        return false
    }

    private static func parseQueryMessage(_ message: String) -> [String: String] {
        guard !message.isEmpty,
              let components = URLComponents(string: "http://127.0.0.1/flex-reject?\(message)") else {
            return [:]
        }
        var out: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard !item.name.isEmpty else { continue }
            out[item.name] = item.value?.removingPercentEncoding ?? item.value ?? ""
        }
        return out
    }
}

private final class FlexRejectVolumeScriptRelay: NSObject, WKScriptMessageHandler {
    weak var target: FlexRejectVolumeCanvas?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "iosHandler" else { return }
        target?.handleBridgeBody(message.body)
    }
}

extension FlexRejectVolumeCanvas: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        FlexSpinnerOverlay.endRequest()
        injectRejectData()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(error: error)
    }

    private func finishLoad(error: Error) {
        FlexSpinnerOverlay.endRequest()
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return }
        FlexToast.show(error.localizedDescription)
    }
}

/// Entry for 据量 H5 — LoanEase `LERejectH5Navigator` (config-cached URL).
enum FlexRejectVolumeLaunch {
    static var hasURL: Bool { resolvedURL() != nil }

    /// Order list status 31 / 41 → open H5 instead of detail when URL exists.
    static func isRejectedOrderState(_ state: Int?) -> Bool {
        guard let state else { return false }
        return state == 31 || state == 41
    }

    static func makeCanvasIfAvailable() -> FlexRejectVolumeCanvas? {
        guard let url = resolvedURL() else { return nil }
        let canvas = FlexRejectVolumeCanvas(url: url)
        canvas.hidesBottomBarWhenPushed = true
        return canvas
    }

    static func open(from host: UIViewController, message: String? = nil) {
        guard let url = resolvedURL() else {
            let fallback = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            FlexToast.show(fallback.isEmpty ? FlexPhraseBook.Network.busy : fallback)
            return
        }
        guard let nav = host.navigationController else {
            FlexToast.show(FlexPhraseBook.Network.busy)
            return
        }
        nav.pushViewController(FlexRejectVolumeCanvas(url: url), animated: true)
    }

    private static func resolvedURL() -> URL? {
        let raw = CofferVault.shared.cachedRejectH5URL
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}
