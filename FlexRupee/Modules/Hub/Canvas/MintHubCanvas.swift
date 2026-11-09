import UIKit
import SnapKit
import RxSwift

final class MintHubCanvas: FlexBaseCanvas {
    private let pilot = MintHubPilot()
    private let disposeBag = DisposeBag()
    private let overlayHost = HubOverlayHost()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let loanCard = UIView()
    private let maxAmountCaption = UILabel()
    private let amountLabel = UILabel()
    private let rateLabel = UILabel()
    private let termLabel = UILabel()
    private let bannerButton = FlexPrimaryButton()

    private let kycBanner = UIView()
    private let kycLabel = UILabel()
    private let kycChevron = UIImageView()

    private let checkInCard = UIView()
    private let checkInHintLabel = UILabel()
    private let checkInButton = UIButton(type: .system)

    private var hubBootstrapDone = false
    private var skipNextAppearRefresh = false

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(title: FlexPhraseBook.Hub.homeTitle)
        layoutUI()
        overlayHost.install(on: view)
        bindPilot()
        applyLoggedOutVisuals()
        FlexHubBootstrap.runOnHome { [weak self] in
            guard let self else { return }
            self.hubBootstrapDone = true
            self.skipNextAppearRefresh = true
            self.refreshForAutoOrderEval()
        }
        NotificationCenter.default.addObserver(forName: .flexSessionDidLogin, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.pilot.resetAutoOrderSession()
            self.hubBootstrapDone = true
            self.skipNextAppearRefresh = true
            self.refreshForAutoOrderEval()
        }
        NotificationCenter.default.addObserver(forName: .flexHubNeedsRefresh, object: nil, queue: .main) { [weak self] _ in
            // KYC finished / order abort → re-check auto-order eligibility (status may become 20).
            self?.refreshForAutoOrderEval()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard hubBootstrapDone else { return }
        if skipNextAppearRefresh {
            skipNextAppearRefresh = false
            // Re-login can skip appear refresh after the login ping — still pull if empty.
            if FlexLoginGate.isLoggedIn && pilot.snapshot.value == nil {
                refreshForAutoOrderEval()
            }
            return
        }
        refreshIfLoggedIn()
    }

    @objc private func refreshIfLoggedIn() {
        guard FlexLoginGate.isLoggedIn else {
            applyLoggedOutVisuals()
            return
        }
        // Tab reappear: still refresh snapshot & re-check conditions, but auto-order
        // only starts once per session (`hasAttemptedSession` in auto pilot).
        pilot.refreshHub(evaluateAutoOrder: true)
    }

    private func refreshForAutoOrderEval() {
        guard FlexLoginGate.isLoggedIn else {
            applyLoggedOutVisuals()
            return
        }
        pilot.refreshHub(evaluateAutoOrder: true)
    }

    private func applyLoggedOutVisuals() {
        kycBanner.isHidden = false
        kycBanner.isUserInteractionEnabled = true
        kycChevron.isHidden = false
        kycLabel.text = FlexPhraseBook.Hub.kycBanner
        bannerButton.setTitle(FlexPhraseBook.Hub.apply, for: .normal)
        amountLabel.text = HubBannerVisual.amountText(nil)
        rateLabel.text = HubBannerVisual.rateText(nil)
        termLabel.text = HubBannerVisual.termText(nil)
    }

    private func layoutUI() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        contentStack.axis = .vertical
        contentStack.spacing = 12

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-96)
            make.width.equalTo(scrollView).offset(-32)
        }

        buildLoanCard()
        buildKYCBanner()
        buildCheckInCard()
        contentStack.addArrangedSubview(loanCard)
        contentStack.addArrangedSubview(kycBanner)
        contentStack.addArrangedSubview(checkInCard)
    }

    private func buildLoanCard() {
        loanCard.backgroundColor = FlexPalette.dockBlack
        loanCard.flexRoundCorners(24)

        maxAmountCaption.text = FlexPhraseBook.Hub.maxLoanAmount
        maxAmountCaption.font = FlexTypography.regular(13)
        maxAmountCaption.textColor = UIColor.white.withAlphaComponent(0.88)
        maxAmountCaption.textAlignment = .center

        amountLabel.font = FlexTypography.bold(36)
        amountLabel.textColor = FlexPalette.loanGold
        amountLabel.textAlignment = .center
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.6

        [rateLabel, termLabel].forEach { label in
            label.font = FlexTypography.medium(14)
            label.textColor = .white
            label.textAlignment = .center
        }

        bannerButton.setTitle(FlexPhraseBook.Hub.apply, for: .normal)
        bannerButton.backgroundColor = FlexPalette.accentGreen
        bannerButton.setTitleColor(.white, for: .normal)
        bannerButton.titleLabel?.font = FlexTypography.bold(17)
        bannerButton.flexRoundCorners(27)
        bannerButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        let metricRow = UIStackView(arrangedSubviews: [rateLabel, termLabel])
        metricRow.axis = .horizontal
        metricRow.distribution = .fillEqually
        metricRow.alignment = .center

        [maxAmountCaption, amountLabel, metricRow, bannerButton].forEach { loanCard.addSubview($0) }
        plantBannerCoins(on: loanCard)
        loanCard.subviews.filter { $0 !== maxAmountCaption && $0 !== amountLabel && $0 !== metricRow && $0 !== bannerButton }
            .forEach { loanCard.sendSubviewToBack($0) }

        maxAmountCaption.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(maxAmountCaption.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(28)
        }
        metricRow.snp.makeConstraints { make in
            make.top.equalTo(amountLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        bannerButton.snp.makeConstraints { make in
            make.top.equalTo(metricRow.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    private func plantBannerCoins(on card: UIView) {
        let left = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.hubBannerCoinLeft))
        left.contentMode = .scaleAspectFit
        left.isUserInteractionEnabled = false
        let right = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.hubBannerCoinRight))
        right.contentMode = .scaleAspectFit
        right.isUserInteractionEnabled = false
        card.addSubview(left)
        card.addSubview(right)
        left.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalTo(amountLabel)
            make.width.height.equalTo(72)
        }
        right.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalTo(amountLabel)
            make.width.height.equalTo(72)
        }
    }

    private func buildKYCBanner() {
        FlexTheme.styleBanner(kycBanner)
        kycLabel.text = FlexPhraseBook.Hub.kycBanner
        kycLabel.font = FlexTypography.regular(12)
        kycLabel.textColor = FlexPalette.inkSecondary
        kycLabel.numberOfLines = 0
        kycChevron.image = FlexSlice.slice(FlexSliceCatalog.offerChevronTwine)
        kycChevron.contentMode = .scaleAspectFit
        kycBanner.addSubview(kycLabel)
        kycBanner.addSubview(kycChevron)
        kycLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(16)
            make.trailing.equalTo(kycChevron.snp.leading).offset(-10)
        }
        kycChevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }
        kycBanner.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(kycTapped)))
        kycBanner.snp.makeConstraints { $0.height.greaterThanOrEqualTo(48) }
    }

    private func buildCheckInCard() {
        checkInCard.backgroundColor = .white
        checkInCard.flexRoundCorners(20)
        checkInCard.clipsToBounds = true

        let ring = UIView()
        ring.backgroundColor = UIColor(hex: 0xEEF3F6)
        ring.layer.cornerRadius = 90
        checkInCard.addSubview(ring)
        ring.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(40)
            make.centerY.equalToSuperview().offset(8)
            make.width.height.equalTo(180)
        }

        checkInHintLabel.text = FlexPhraseBook.Hub.checkInHint
        checkInHintLabel.font = FlexTypography.regular(13)
        checkInHintLabel.textColor = FlexPalette.inkSecondary
        checkInHintLabel.numberOfLines = 0

        checkInButton.setTitle(FlexPhraseBook.Hub.checkInAction, for: .normal)
        checkInButton.backgroundColor = FlexPalette.accentGreen
        checkInButton.setTitleColor(.white, for: .normal)
        checkInButton.titleLabel?.font = FlexTypography.bold(15)
        checkInButton.flexRoundCorners(24)
        checkInButton.addTarget(self, action: #selector(checkInTapped), for: .touchUpInside)

        checkInCard.addSubview(checkInHintLabel)
        checkInCard.addSubview(checkInButton)
        checkInHintLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        checkInButton.snp.makeConstraints { make in
            make.top.equalTo(checkInHintLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    private func bindPilot() {
        pilot.showKycBanner.stream.subscribe(onNext: { [weak self] show in
            self?.kycBanner.isHidden = !show
        }).disposed(by: disposeBag)

        pilot.statusBannerText.stream.subscribe(onNext: { [weak self] text in
            self?.kycLabel.text = text
        }).disposed(by: disposeBag)

        pilot.statusBannerTappable.stream.subscribe(onNext: { [weak self] tappable in
            self?.kycBanner.isUserInteractionEnabled = tappable
            self?.kycChevron.isHidden = !tappable
        }).disposed(by: disposeBag)

        pilot.bannerButtonTitle.stream.subscribe(onNext: { [weak self] title in
            self?.bannerButton.setTitle(title, for: .normal)
        }).disposed(by: disposeBag)

        pilot.bannerButtonOverdue.stream.subscribe(onNext: { [weak self] overdue in
            self?.bannerButton.setTitleColor(overdue ? FlexPalette.dangerRose : .white, for: .normal)
        }).disposed(by: disposeBag)

        pilot.quotaAmountText.stream.subscribe(onNext: { [weak self] text in
            self?.amountLabel.text = text
        }).disposed(by: disposeBag)

        pilot.rateText.stream.subscribe(onNext: { [weak self] text in
            self?.rateLabel.text = text
        }).disposed(by: disposeBag)

        pilot.termText.stream.subscribe(onNext: { [weak self] text in
            self?.termLabel.text = text
        }).disposed(by: disposeBag)

        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)

        pilot.snapshot.stream.subscribe(onNext: { [weak self] snap in
            guard let self, snap != nil else { return }
            self.pilot.runAutoOrderIfNeeded(from: self)
        }).disposed(by: disposeBag)

        pilot.openRecommend.stream.subscribe(onNext: { [weak self] autoOrder in
            guard let self else { return }
            FlexRecommendLaunch.open(from: self, autoOrder: autoOrder)
        }).disposed(by: disposeBag)

        pilot.needsVerify.stream.subscribe(onNext: { [weak self] stages in
            guard let self else { return }
            VerifyRoute.pushFirstIncomplete(from: self, stages: stages)
        }).disposed(by: disposeBag)

        pilot.openLoanSuccess.stream.subscribe(onNext: { [weak self] orderIds in
            guard let self else { return }
            self.navigationController?.pushViewController(
                FlexLoanSuccessCanvas(orderIds: orderIds, leaveStyle: .hubHome),
                animated: true
            )
        }).disposed(by: disposeBag)

        NotificationCenter.default.addObserver(forName: .flexHubOpenDealDetail, object: nil, queue: .main) { [weak self] note in
            guard let self, let dealId = note.object as? String else { return }
            self.navigationController?.pushViewController(
                LedgerDetailCanvas(dealId: dealId, productId: ""),
                animated: true
            )
        }

        pilot.openOrderDetail.stream.subscribe(onNext: { [weak self] payload in
            guard let self else { return }
            self.navigationController?.pushViewController(
                LedgerDetailCanvas(dealId: payload.dealId, productId: payload.productId),
                animated: true
            )
        }).disposed(by: disposeBag)

        pilot.openOrdersTab.stream.subscribe(onNext: { tab in
            FlexRootOrchestrator.shared.openLedger(tab: tab)
        }).disposed(by: disposeBag)

    }



    func performRecommendStatusJump() {
        pilot.performStatusJump(from: self, allowRecommend: false)
    }

    @objc private func applyTapped() {
        guard FlexLoginGate.requireLogin(from: self) else { return }
        pilot.routePrimaryApply(from: self)
    }

    @objc private func kycTapped() {
        guard FlexLoginGate.requireLogin(from: self) else { return }
        pilot.routeStatusMessage(from: self)
    }

    @objc private func checkInTapped() {
        FlexToast.show(FlexPhraseBook.Hub.checkInDone)
        checkInButton.setTitle(FlexPhraseBook.Hub.checkInDone, for: .normal)
        checkInButton.isEnabled = false
        checkInButton.alpha = 0.45
    }
}
