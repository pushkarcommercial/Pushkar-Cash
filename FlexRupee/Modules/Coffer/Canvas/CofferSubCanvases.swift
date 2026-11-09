import UIKit
import SnapKit
import RxSwift

// MARK: - Bank Account

final class VaultCardCanvas: FlexBaseCanvas {
    private let store = CofferProfileStore.shared
    private let disposeBag = DisposeBag()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let hintBanner = FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Coffer.bankHint)
    private let cardView = UIView()
    private let cardBg = UIImageView()
    private let bankCodeLabel = UILabel()
    private let accountLabel = UILabel()
    private let holderLabel = UILabel()
    private let editButton = UIButton(type: .custom)
    private let emptyWrap = UIView()
    private let emptyArt = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.vaultEmptyHaze))
    private let emptyLabel = UILabel()
    private var allowsEdit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Coffer.bankAccount)
        layoutUI()
        loadCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    private func layoutUI() {
        contentStack.axis = .vertical
        contentStack.spacing = 12
        cardView.flexRoundCorners(24)
        cardView.clipsToBounds = true
        cardBg.image = FlexSlice.slice(FlexSliceCatalog.vaultHarborPlume)
        cardBg.contentMode = .scaleAspectFill
        bankCodeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        bankCodeLabel.font = FlexTypography.regular(12)
        accountLabel.textColor = .white
        accountLabel.font = FlexTypography.bold(22)
        accountLabel.numberOfLines = 2
        holderLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        holderLabel.font = FlexTypography.medium(14)
        editButton.setImage(FlexSlice.slice(FlexSliceCatalog.vaultEditHook), for: .normal)
        editButton.isHidden = true
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        cardView.isUserInteractionEnabled = true
        cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(editTapped)))
        emptyArt.contentMode = .scaleAspectFit
        emptyLabel.text = FlexPhraseBook.Coffer.bankEmpty
        emptyLabel.font = FlexTypography.regular(15)
        emptyLabel.textColor = FlexPalette.inkSecondary
        emptyLabel.textAlignment = .center
        emptyWrap.addSubview(emptyArt)
        emptyWrap.addSubview(emptyLabel)
        cardView.addSubview(cardBg)
        [bankCodeLabel, accountLabel, holderLabel, editButton].forEach { cardView.addSubview($0) }
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.addArrangedSubview(hintBanner)
        contentStack.addArrangedSubview(cardView)
        contentStack.addArrangedSubview(emptyWrap)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16,
                                                             bottom: 24, right: 16))
            make.width.equalTo(scrollView).offset(-16 * 2)
        }
        cardBg.snp.makeConstraints { $0.edges.equalToSuperview() }
        cardView.snp.makeConstraints { $0.height.equalTo(180) }
        bankCodeLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-8)
        }
        accountLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview().offset(4)
        }
        holderLabel.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview().inset(20)
        }
        editButton.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(16)
            make.width.height.equalTo(28)
        }
        emptyArt.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(120)
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyArt.snp.bottom).offset(12)
            make.centerX.bottom.equalToSuperview()
        }
        emptyWrap.isHidden = true
    }

    private func loadCards() {
        Single.zip(store.loadProfile(), store.loadCards())
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] profile, cards in
                guard let self else { return }
                self.allowsEdit = profile.bankEditSwitch?.lowercased() == "on"
                if let card = cards.first {
                    // Top-left: IFSC (`bankCode`), not bank name / bindId.
                    self.bankCodeLabel.text = Self.displayIFSC(card.bankCode)
                    self.accountLabel.text = FlexCofferWidgets.groupedAccountNumber(card.accountMask ?? "")
                    self.holderLabel.text = card.holderName ?? "User Name"
                    self.emptyWrap.isHidden = true
                    self.cardView.isHidden = false
                    self.editButton.isHidden = !self.allowsEdit
                    self.hintBanner.isHidden = false
                } else {
                    self.cardView.isHidden = true
                    self.hintBanner.isHidden = false
                    self.editButton.isHidden = true
                    self.emptyWrap.isHidden = false
                }
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
    }

    @objc private func editTapped() {
        guard allowsEdit else { return }
        let canvas = VaultEditCardCanvas()
        canvas.onUpdated = { [weak self] in self?.loadCards() }
        navigationController?.pushViewController(canvas, animated: true)
    }

    /// IFSC on card face — compact, no space before the numeric / branch segment.
    private static func displayIFSC(_ raw: String?) -> String {
        (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }
}

// MARK: - About

final class CofferAboutCanvas: FlexBaseCanvas {
    private let disposeBag = DisposeBag()
    private let scrollView = UIScrollView()
    private let brandRow = UIStackView()
    private let logoView = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.brandCedarSeal)?.withRenderingMode(.alwaysOriginal))
    private let appNameLabel = UILabel()
    private let bodyCard = FlexCofferWidgets.makeTextCard(FlexPhraseBook.Coffer.aboutBody)
    private let versionLabel = UILabel()
    private let deleteLink = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Coffer.about)
        layoutUI()
    }

    private func layoutUI() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        brandRow.axis = .horizontal
        brandRow.spacing = 14
        brandRow.alignment = .center

        logoView.contentMode = .scaleAspectFit
        logoView.clipsToBounds = true
        logoView.flexRoundCorners(14)

        appNameLabel.text = FlexPhraseBook.appName
        appNameLabel.font = FlexTypography.bold(22)
        appNameLabel.textColor = FlexPalette.inkPrimary

        versionLabel.text = FlexPhraseBook.Coffer.versionLabel(RupeeDeviceProbe.shared.buildStamp)
        versionLabel.font = FlexTypography.regular(13)
        versionLabel.textColor = FlexPalette.inkTertiary
        versionLabel.textAlignment = .center

        deleteLink.setTitle(FlexPhraseBook.Coffer.deleteTitle, for: .normal)
        deleteLink.setTitleColor(FlexPalette.inkSecondary, for: .normal)
        deleteLink.titleLabel?.font = FlexTypography.bold(16)
        deleteLink.addTarget(self, action: #selector(deleteAccount), for: .touchUpInside)

        brandRow.addArrangedSubview(logoView)
        brandRow.addArrangedSubview(appNameLabel)

        view.addSubview(scrollView)
        view.addSubview(deleteLink)
        scrollView.addSubview(brandRow)
        scrollView.addSubview(bodyCard)
        scrollView.addSubview(versionLabel)

        logoView.snp.makeConstraints { $0.width.height.equalTo(56) }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(deleteLink.snp.top).offset(-16)
        }
        brandRow.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(16)
            make.width.equalTo(scrollView).offset(-32)
        }
        bodyCard.snp.makeConstraints { make in
            make.top.equalTo(brandRow.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-32)
        }
        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(bodyCard.snp.bottom).offset(20)
            make.centerX.equalTo(scrollView)
            make.bottom.equalToSuperview().offset(-24)
        }
        deleteLink.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.centerX.equalToSuperview()
        }
    }

    @objc private func deleteAccount() {
        FlexConfirmSheet.present(on: self,
                                 title: FlexPhraseBook.Coffer.deleteTitle,
                                 message: FlexPhraseBook.Coffer.deleteBody,
                                 art: FlexSliceCatalog.dialogDeleteAccount,
                                 presentation: .card) { [weak self] in
            self?.performDelete()
        }
    }

    private func performDelete() {
        CofferProfileStore.shared.retireAccount()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                FlexIllustratedSheet.present(on: self,
                                             art: FlexSliceCatalog.dialogSuccessCrest,
                                             title: FlexPhraseBook.Coffer.deleteSuccessTitle,
                                             message: FlexPhraseBook.Coffer.deleteSuccessBody,
                                             showsCancel: false) {
                    FlexRootOrchestrator.shared.presentGate(replaceRoot: true)
                }
            }, onError: { [weak self] error in
                guard let self else { return }
                FlexIllustratedSheet.present(on: self,
                                             art: FlexSliceCatalog.dialogFailSeal,
                                             title: FlexPhraseBook.Coffer.deleteFailedTitle,
                                             message: (error as? PulseWireFault)?.message(or: FlexPhraseBook.Coffer.deleteFailedBody)
                                                ?? FlexPhraseBook.Coffer.deleteFailedBody,
                                             showsCancel: false) {}
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Repayment Instructions

final class CofferRepayGuideCanvas: FlexBaseCanvas {
    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Coffer.repaymentInstructions)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.addArrangedSubview(FlexCofferWidgets.makeCopyRow(icon: FlexSliceCatalog.supportMailGem,
                                                               text: CofferConfigBridge.supportEmail))
        stack.addArrangedSubview(FlexCofferWidgets.makeCopyRow(icon: FlexSliceCatalog.supportWebLatch,
                                                               text: CofferConfigBridge.siteURL))
        stack.addArrangedSubview(FlexCofferWidgets.makeTextCard(FlexPhraseBook.Coffer.repayHint1))
        stack.addArrangedSubview(FlexCofferWidgets.makeTextCard(FlexPhraseBook.Coffer.repayHint2))
        stack.addArrangedSubview(FlexCofferWidgets.makeTextCard(FlexPhraseBook.Coffer.repayHint3))
        FlexCofferWidgets.embedScrollStack(on: view, below: contentTopAnchor(), stack: stack)
    }
}

// MARK: - Official Website

final class CofferOfficialCanvas: FlexBaseCanvas {
    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Coffer.officialWebsite)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.addArrangedSubview(FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Coffer.officialHint))
        stack.addArrangedSubview(FlexCofferWidgets.makeCopyRow(icon: FlexSliceCatalog.supportWebLatch,
                                                               text: CofferConfigBridge.siteURL))
        FlexCofferWidgets.embedScrollStack(on: view, below: contentTopAnchor(), stack: stack)
    }
}

// MARK: - Legal (deprecated wrapper — use FlexLegalDocLaunch / FlexLegalDocCanvas)

@available(*, deprecated, message: "Use FlexLegalDocLaunch.open instead")
final class CofferLegalCanvas: FlexBaseCanvas {
    private let pageTitle: String
    private let urlString: String

    init(title: String, urlString: String) {
        self.pageTitle = title
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            FlexToast.show(FlexPhraseBook.Gate.policyUnavailable)
            DispatchQueue.main.async { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            return
        }
        // Replace self with dedicated legal H5 (not repay/defer FlexLedgerLinkCanvas).
        let canvas = FlexLegalDocCanvas(url: url, title: pageTitle)
        var stack = navigationController?.viewControllers ?? [self]
        if let idx = stack.firstIndex(where: { $0 === self }) {
            stack[idx] = canvas
            navigationController?.setViewControllers(stack, animated: false)
        } else {
            navigationController?.pushViewController(canvas, animated: false)
        }
    }
}
