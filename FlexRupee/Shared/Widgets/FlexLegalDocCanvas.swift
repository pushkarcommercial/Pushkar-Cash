import UIKit
import WebKit
import SnapKit

/// Protocol / legal document H5 — separate from repayment/deferment `FlexLedgerLinkCanvas`.
final class FlexLegalDocCanvas: FlexBaseCanvas {
    private let pageTitle: String
    private let requestURL: URL
    private var progressObservation: NSKeyValueObservation?

    private let card = FlexCofferWidgets.makeWhiteCard()
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        return view
    }()

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

        view.addSubview(card)
        card.addSubview(progressBar)
        card.addSubview(webView)
        card.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
        }
        progressBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(2)
        }
        webView.snp.makeConstraints { make in
            make.top.equalTo(progressBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview().inset(8)
        }

        webView.navigationDelegate = self
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            guard let self else { return }
            let progress = Float(web.estimatedProgress)
            self.progressBar.isHidden = progress >= 1
            self.progressBar.setProgress(progress, animated: true)
            if progress >= 1 { FlexSpinnerOverlay.endRequest() }
        }

        FlexSpinnerOverlay.beginRequest()
        webView.load(URLRequest(url: requestURL))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed { tearDown() }
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

extension FlexLegalDocCanvas: WKNavigationDelegate {
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

enum FlexLegalDocKind {
    case privacyPolicy
    case serviceAgreement
    case termsOfLoan
    case contactUs

    var title: String {
        switch self {
        case .privacyPolicy: return FlexPhraseBook.Gate.privacyPolicy
        case .serviceAgreement: return FlexPhraseBook.Gate.serviceAgreement
        case .termsOfLoan: return FlexPhraseBook.Coffer.loanTerms
        case .contactUs: return FlexPhraseBook.Coffer.contactUs
        }
    }

    var urlString: String {
        switch self {
        case .privacyPolicy:
            return "https://www.pushkarcommercial.com/PrivacyPolicy.html"
        case .serviceAgreement:
            return "https://www.pushkarcommercial.com/ServiceAgreement.html"
        case .termsOfLoan:
            return "https://www.pushkarcommercial.com/loanContract.html"
        case .contactUs:
            return "https://www.pushkarcommercial.com/contactUs.html"
        }
    }
}

/// Opens hardcoded legal H5 pages (never uses repay/defer `FlexLedgerLinkCanvas`).
enum FlexLegalDocLaunch {
    static func open(_ kind: FlexLegalDocKind, from host: UIViewController) {
        guard let url = resolvedURL(from: kind.urlString) else {
            FlexToast.show(FlexPhraseBook.Gate.policyUnavailable)
            return
        }
        push(from: host, url: url, title: kind.title)
    }

    private static func resolvedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    private static func push(from host: UIViewController, url: URL, title: String) {
        let canvas = FlexLegalDocCanvas(url: url, title: title)
        if let nav = host.navigationController {
            nav.pushViewController(canvas, animated: true)
        } else {
            let wrap = UINavigationController(rootViewController: canvas)
            wrap.setNavigationBarHidden(true, animated: false)
            wrap.modalPresentationStyle = .fullScreen
            host.present(wrap, animated: true)
        }
    }
}
