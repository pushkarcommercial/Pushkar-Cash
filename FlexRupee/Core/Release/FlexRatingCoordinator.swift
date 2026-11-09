import StoreKit
import UIKit
import SnapKit
import RxSwift

/// In-app rating guide — gated by `/app/v3/app/config` `feedbackGuidance`.
enum FlexRatingCoordinator {
    private static let disposeBag = DisposeBag()

    /// Present rating on `host` when possible; otherwise the current top visible screen.
    /// Call after success Confirm (home) or success → Feedback — not from Me → Feedback.
    static func maybePresent(from host: UIViewController? = nil, delay: TimeInterval = 0.3) {
        guard !FlexUpgradeOverlay.isForceBlocking else { return }
        guard !CofferVault.shared.ratingPromptedForCurrentVersion else { return }

        resolveShouldShow { shouldShow in
            guard shouldShow else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let anchor = resolvePresentingHost(preferred: host) else { return }
                presentIfStillAllowed(on: anchor)
            }
        }
    }

    /// LoanEase `isInAppRatingGuideAllowed`:
    /// - missing / 0 → off
    /// - 2 → off when `appUserType == 1`
    /// - otherwise → on
    static func isInAppRatingGuideAllowed(appUserType: Int? = nil) -> Bool {
        guard let guidance = CofferVault.shared.feedbackGuidance else { return false }
        if guidance == 0 { return false }
        if guidance == 2 {
            let userType = appUserType ?? CofferVault.shared.hubAppUserType
            if userType == 1 { return false }
        }
        return true
    }

    private static func resolveShouldShow(completion: @escaping (Bool) -> Void) {
        guard CofferVault.shared.feedbackGuidance == 2 else {
            completion(isInAppRatingGuideAllowed())
            return
        }
        if CofferVault.shared.hubAppUserType != nil {
            completion(isInAppRatingGuideAllowed())
            return
        }
        MintHubStore.shared.loadSnapshot()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { _ in
                completion(isInAppRatingGuideAllowed())
            }, onError: { _ in
                completion(isInAppRatingGuideAllowed())
            })
            .disposed(by: disposeBag)
    }

    private static func presentIfStillAllowed(on host: UIViewController) {
        guard !CofferVault.shared.ratingPromptedForCurrentVersion else { return }
        guard isInAppRatingGuideAllowed() else { return }
        guard host.presentedViewController == nil else { return }
        guard host.view.window != nil else { return }
        CofferVault.shared.markRatingPromptedForCurrentVersion()
        FlexRatingPopup.present(on: host)
    }

    private static func resolvePresentingHost(preferred: UIViewController?) -> UIViewController? {
        if let preferred, preferred.view.window != nil {
            return walkTopPresentable(from: preferred)
        }
        guard let root = FlexRootOrchestrator.shared.keyWindow?.rootViewController else { return nil }
        return walkTopPresentable(from: root)
    }

    private static func walkTopPresentable(from base: UIViewController) -> UIViewController {
        if let presented = base.presentedViewController, !presented.isBeingDismissed {
            return walkTopPresentable(from: presented)
        }
        if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
            return walkTopPresentable(from: visible)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return walkTopPresentable(from: selected)
        }
        return base
    }
}

enum FlexRatingPopup {
    static func present(on host: UIViewController) {
        let overlay = FlexRatingOverlay(frame: host.view.bounds)
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    static func presentThanks(on host: UIViewController, then: (() -> Void)? = nil) {
        FlexIllustratedSheet.present(on: host,
                                     art: FlexSliceCatalog.dialogThanksPlume,
                                     title: FlexPhraseBook.Rating.thanksTitle,
                                     message: FlexPhraseBook.Rating.thanksBody,
                                     showsCancel: false,
                                     onConfirm: { then?() })
    }
}

/// P39 rating dialog — stars, title, body, and dual CTAs inside one card.
private final class FlexRatingOverlay: UIView {
    private enum Layout {
        static let starSize: CGFloat = 36
        static let starsToTitle: CGFloat = 20
    }

    private var selectedStars = 0
    private var starButtons: [UIButton] = []
    private let cardView = UIView()
    private let starsRow = UIStackView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let cancelButton = UIButton(type: .custom)
    private let submitButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        starsRow.axis = .horizontal
        starsRow.spacing = 8
        starsRow.distribution = .fillEqually
        (0..<5).forEach { index in
            let button = UIButton(type: .custom)
            button.tag = index + 1
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            starButtons.append(button)
            starsRow.addArrangedSubview(button)
            button.snp.makeConstraints { $0.width.height.equalTo(Layout.starSize) }
        }
        refreshStars()
        titleLabel.text = FlexPhraseBook.Rating.title
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        bodyLabel.text = FlexPhraseBook.Rating.body
        bodyLabel.font = FlexTypography.regular(14)
        bodyLabel.textColor = FlexPalette.inkSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        cancelButton.setTitle(FlexPhraseBook.Dialog.cancel, for: .normal)
        submitButton.setTitle(FlexPhraseBook.Rating.submit, for: .normal)
        FlexDialogLayout.styleOutlineAction(cancelButton)
        FlexDialogLayout.stylePrimaryAction(submitButton)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        layoutUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layoutUI() {
        addSubview(cardView)
        cardView.addSubview(starsRow)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, submitButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(buttonRow)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardHorizontalInset)
        }
        starsRow.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(starsRow.snp.bottom).offset(Layout.starsToTitle)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
        }
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(FlexDialogMetrics.titleToBody)
            make.leading.trailing.equalTo(titleLabel)
        }
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(FlexDialogMetrics.bodyToButtons)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        submitButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
    }

    private func refreshStars() {
        starButtons.enumerated().forEach { index, button in
            let lit = index < selectedStars
            button.setImage(FlexSlice.slice(lit ? FlexSliceCatalog.dialogStarLit : FlexSliceCatalog.dialogStarRest), for: .normal)
        }
    }

    @objc private func starTapped(_ sender: UIButton) {
        selectedStars = sender.tag
        refreshStars()
    }

    @objc private func submitTapped() {
        guard selectedStars > 0 else {
            FlexToast.show(FlexPhraseBook.Rating.selectStarsHint, on: self)
            return
        }
        guard let host = nearestViewController else {
            removeFromSuperview()
            return
        }
        removeFromSuperview()
        // LoanEase: ≥4 → App Store review; lower → thanks only.
        if selectedStars >= 4 {
            requestStoreReview(from: host)
        } else {
            FlexRatingPopup.presentThanks(on: host)
        }
    }

    @objc private func cancelTapped() {
        removeFromSuperview()
    }

    private func requestStoreReview(from host: UIViewController) {
        if #available(iOS 14.0, *) {
            if let scene = host.view.window?.windowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }
}

private extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
