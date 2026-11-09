import UIKit
import WebKit
import SnapKit

/// In-app H5 host for repayment / deferment links (LoanEase business parity, FlexRupee chrome).
final class FlexLedgerLinkCanvas: FlexBaseCanvas {
    private let pageTitle: String
    private let requestURL: URL
    private var progressObservation: NSKeyValueObservation?

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = FlexPalette.canvasGray
        view.scrollView.backgroundColor = FlexPalette.canvasGray
        return view
    }()

    private let progressBar = UIProgressView(progressViewStyle: .bar)

    init(url: URL, title: String) {
        self.requestURL = url
        self.pageTitle = title
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: pageTitle)
        flexNavBar.onBack = { [weak self] in self?.leave() }

        progressBar.progressTintColor = FlexPalette.accentGreen
        progressBar.trackTintColor = FlexPalette.fieldBorder
        progressBar.isHidden = true

        view.addSubview(webView)
        view.addSubview(progressBar)
        progressBar.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(2)
        }
        webView.snp.makeConstraints { make in
            make.top.equalTo(progressBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        webView.navigationDelegate = self
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            guard let self else { return }
            let progress = Float(web.estimatedProgress)
            self.progressBar.isHidden = progress >= 1
            self.progressBar.setProgress(progress, animated: true)
            if progress >= 1 {
                FlexSpinnerOverlay.endRequest()
            }
        }

        FlexSpinnerOverlay.beginRequest()
        webView.load(URLRequest(url: requestURL))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            tearDown()
        }
    }

    private func leave() {
        tearDown()
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func tearDown() {
        progressObservation?.invalidate()
        progressObservation = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        FlexSpinnerOverlay.endRequest()
    }
}

extension FlexLedgerLinkCanvas: WKNavigationDelegate {
    /// LoanEase `LEOrderRepayWebViewController`: http(s) stay in WKWebView; UPI / app schemes → system open.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url.absoluteString.hasPrefix("http") {
            decisionHandler(.allow)
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                FlexToast.show(FlexPhraseBook.Ledger.externalAppUnavailable)
            }
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        FlexSpinnerOverlay.endRequest()
        progressBar.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        FlexSpinnerOverlay.endRequest()
        progressBar.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        FlexSpinnerOverlay.endRequest()
        progressBar.isHidden = true
    }
}
