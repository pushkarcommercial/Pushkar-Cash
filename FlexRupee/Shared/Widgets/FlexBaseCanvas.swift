import UIKit
import SnapKit

class FlexBaseCanvas: UIViewController {
    let flexNavBar = FlexNavStrip()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        navigationController?.setNavigationBarHidden(true, animated: false)
        embedNavStripIfNeeded()
    }

    func embedNavStripIfNeeded(showBack: Bool = false, title: String = "") {
        guard flexNavBar.superview == nil else {
            flexNavBar.apply(title: title, showBack: showBack)
            return
        }
        flexNavBar.apply(title: title, showBack: showBack)
        flexNavBar.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        view.addSubview(flexNavBar)
        flexNavBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
    }

    func contentTopAnchor() -> ConstraintItem {
        flexNavBar.snp.bottom
    }
}

final class FlexNavStrip: UIView {
    var onBack: (() -> Void)?

    private let backGlyph = UIButton(type: .custom)
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexPalette.canvasGray
        // Light-nav back: `rupeeArt_navBackPlate` (ex-`wyglsst_fj`).
        // Use .custom + alwaysOriginal so the plate is not templated away.
        backGlyph.setImage(
            FlexSlice.slice(FlexSliceCatalog.navBackPlate)?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        backGlyph.tintColor = .clear
        backGlyph.adjustsImageWhenHighlighted = false
        backGlyph.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        titleLabel.font = FlexTypography.bold(18)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        addSubview(backGlyph)
        addSubview(titleLabel)
        backGlyph.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-8)
            make.width.height.equalTo(32)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(4)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(backGlyph)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backGlyph.snp.trailing).offset(8)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(title: String, showBack: Bool) {
        titleLabel.text = title
        backGlyph.isHidden = !showBack
    }

    func setTitleHidden(_ hidden: Bool, animated: Bool = true) {
        let apply = { self.titleLabel.alpha = hidden ? 0 : 1 }
        guard animated else {
            apply()
            return
        }
        UIView.animate(withDuration: 0.2, animations: apply)
    }

    @objc private func backTapped() { onBack?() }
}

final class FlexPrimaryButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        FlexTheme.stylePrimaryButton(self)
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class FlexToast {
    private static weak var activeToast: UIView?

    static func show(_ text: String, on view: UIView? = nil, duration: TimeInterval = 3.5) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { show(text, on: view, duration: duration) }
            return
        }
        guard let host = view ?? foregroundView() else { return }
        activeToast?.removeFromSuperview()
        let wrap = UIView()
        activeToast = wrap
        wrap.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        wrap.flexRoundCorners(10)
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        wrap.addSubview(label)
        host.addSubview(wrap)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
        wrap.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(host.safeAreaLayoutGuide).priority(.medium)
            make.bottom.lessThanOrEqualTo(host.keyboardLayoutGuide.snp.top).offset(-16)
            make.width.lessThanOrEqualTo(host).multipliedBy(0.85)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            wrap.removeFromSuperview()
            if activeToast === wrap { activeToast = nil }
        }
    }

    private static func foregroundView() -> UIView? {
        guard let window = FlexRootOrchestrator.shared.keyWindow else { return nil }
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller?.view ?? window
    }
}

final class FlexSpinnerOverlay {
    private static var overlay: UIView?
    private static var activeCount = 0
    private static let lock = NSLock()

    static func beginRequest(on view: UIView? = nil) {
        show(on: view)
    }

    static func endRequest() {
        hide()
    }

    static func show(on view: UIView? = nil) {
        lock.lock()
        activeCount += 1
        let shouldPresent = activeCount == 1
        lock.unlock()
        guard shouldPresent else { return }
        runOnMain { presentIfNeeded(on: view) }
    }

    static func hide() {
        lock.lock()
        activeCount = max(0, activeCount - 1)
        let shouldDismiss = activeCount == 0
        lock.unlock()
        guard shouldDismiss else { return }
        runOnMain { dismissIfNeeded() }
    }

    static func reset() {
        lock.lock()
        activeCount = 0
        lock.unlock()
        runOnMain {
            overlay?.removeFromSuperview()
            overlay = nil
        }
    }

    private static func presentIfNeeded(on view: UIView?) {
        lock.lock()
        let shouldShow = activeCount > 0
        lock.unlock()
        guard shouldShow else { return }
        overlay?.removeFromSuperview()
        guard let host = view ?? FlexRootOrchestrator.shared.keyWindow else { return }
        let veil = UIView(frame: host.bounds)
        veil.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        veil.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        veil.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: veil.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: veil.centerYAnchor)
        ])
        host.addSubview(veil)
        overlay = veil
    }

    private static func dismissIfNeeded() {
        lock.lock()
        let shouldHide = activeCount == 0
        lock.unlock()
        guard shouldHide else { return }
        overlay?.removeFromSuperview()
        overlay = nil
    }

    private static func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
