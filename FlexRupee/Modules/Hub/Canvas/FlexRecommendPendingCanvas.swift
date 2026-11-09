import UIKit
import SnapKit

/// Recommend empty / non-4102007 fail → pending-repay tip.
/// Flex layout only (hint banner + art + optional primary CTA) — not LoanEase result card.
final class FlexRecommendPendingCanvas: FlexBaseCanvas {
    private let message: String
    private let showsAction: Bool
    private let onAction: (() -> Void)?

    init(message: String,
         showsAction: Bool,
         onAction: (() -> Void)? = nil) {
        // Copy comes from home `promptCopy` only — no local fallback.
        self.message = message
        self.showsAction = showsAction
        self.onAction = onAction
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Hub.noRecommendTitle)

        let banner = FlexCofferWidgets.makeHintBanner(message)

        let artWrap = UIView()
        artWrap.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        artWrap.layer.cornerRadius = 90
        let art = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanWalletPlume))
        art.contentMode = .scaleAspectFit
        artWrap.addSubview(art)
        art.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(120)
        }

        view.addSubview(banner)
        view.addSubview(artWrap)
        banner.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        artWrap.snp.makeConstraints { make in
            make.top.equalTo(banner.snp.bottom).offset(36)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(180)
        }

        if showsAction {
            let button = FlexPrimaryButton()
            button.setTitle(FlexPhraseBook.Hub.viewNow, for: .normal)
            button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            view.addSubview(button)
            button.snp.makeConstraints { make in
                make.top.equalTo(artWrap.snp.bottom).offset(28)
                make.leading.trailing.equalToSuperview().inset(24)
                make.height.equalTo(48)
            }
        }
    }

    @objc private func actionTapped() {
        onAction?()
    }
}
