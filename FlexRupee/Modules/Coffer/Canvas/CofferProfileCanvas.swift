import UIKit
import SnapKit
import RxSwift

struct CofferMenuEntry {
    let title: String
    let iconStem: String
    let destination: () -> UIViewController
}

final class CofferProfileCanvas: FlexBaseCanvas {
    private let pilot = CofferProfilePilot()
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerCard = UIView()
    private let menuCard = UIView()
    private let avatarView = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.avatarCoralRing)?.withRenderingMode(.alwaysOriginal))
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let menuStack = UIStackView()

    private lazy var menuEntries: [CofferMenuEntry] = [
        CofferMenuEntry(title: FlexPhraseBook.Coffer.bankAccount, iconStem: FlexSliceCatalog.menuVaultGlyph) { VaultCardCanvas() },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.contactUs, iconStem: FlexSliceCatalog.menuRelayIcon) {
            UIViewController()
        },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.privacyPolicy, iconStem: FlexSliceCatalog.menuPolicyLeaf) {
            UIViewController()
        },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.loanTerms, iconStem: FlexSliceCatalog.menuLoanTerms) {
            UIViewController()
        },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.feedback, iconStem: FlexSliceCatalog.menuFeedbackOrb) { CofferFeedbackCanvas() },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.repaymentInstructions, iconStem: FlexSliceCatalog.menuRepayWave) { CofferRepayGuideCanvas() },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.officialWebsite, iconStem: FlexSliceCatalog.menuWebAnchor) { CofferOfficialCanvas() },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.about, iconStem: FlexSliceCatalog.menuAboutSigil) { CofferAboutCanvas() },
        CofferMenuEntry(title: FlexPhraseBook.Coffer.signOut, iconStem: FlexSliceCatalog.menuExitMark) { UIViewController() }
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(title: FlexPhraseBook.Coffer.profileTitle)
        layoutUI()
        buildMenuRows()
        bindPilot()
        // Refresh on appear only — viewDidLoad + appear double-fired and raced.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pilot.refresh()
    }

    private func layoutUI() {
        styleCard(headerCard)
        styleCard(menuCard)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.flexRoundCorners(28)

        nameLabel.font = FlexTypography.bold(17)
        nameLabel.textColor = FlexPalette.inkPrimary
        nameLabel.text = FlexPhraseBook.Coffer.userNamePlaceholder

        phoneLabel.font = FlexTypography.regular(14)
        phoneLabel.textColor = FlexPalette.inkSecondary

        menuStack.axis = .vertical
        menuStack.spacing = 0

        headerCard.addSubview(avatarView)
        headerCard.addSubview(nameLabel)
        headerCard.addSubview(phoneLabel)
        menuCard.addSubview(menuStack)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.addArrangedSubview(headerCard)
        contentStack.addArrangedSubview(menuCard)

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalTo(view).inset(16)
            make.bottom.equalToSuperview().offset(-100)
        }

        headerCard.snp.makeConstraints { make in
            make.height.equalTo(96)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(56)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(avatarView).offset(8)
        }
        phoneLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
        }
        menuStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func styleCard(_ card: UIView) {
        card.backgroundColor = FlexPalette.cardWhite
        card.flexRoundCorners(28)
        card.layer.shadowOpacity = 0
        card.layer.borderWidth = 0
    }

    private func buildMenuRows() {
        menuEntries.enumerated().forEach { index, entry in
            if index > 0 {
                menuStack.addArrangedSubview(menuSeparator())
            }
            let row = CofferMenuRow()
            row.apply(entry)
            row.onTap = { [weak self] in
                self?.handleMenuTap(entry)
            }
            menuStack.addArrangedSubview(row)
            row.snp.makeConstraints { $0.height.equalTo(52) }
        }
    }

    private func menuSeparator() -> UIView {
        let wrap = UIView()
        let line = UIView()
        line.backgroundColor = FlexPalette.fieldBorder
        wrap.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(54)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        wrap.snp.makeConstraints { $0.height.equalTo(1.0 / UIScreen.main.scale) }
        return wrap
    }

    private func handleMenuTap(_ entry: CofferMenuEntry) {
        if entry.title == FlexPhraseBook.Coffer.signOut {
            showSignOutDialog()
            return
        }
        if entry.title == FlexPhraseBook.Coffer.contactUs {
            FlexLegalDocLaunch.open(.contactUs, from: self)
            return
        }
        if entry.title == FlexPhraseBook.Coffer.privacyPolicy {
            FlexLegalDocLaunch.open(.privacyPolicy, from: self)
            return
        }
        if entry.title == FlexPhraseBook.Coffer.loanTerms {
            FlexLegalDocLaunch.open(.termsOfLoan, from: self)
            return
        }
        (FlexRootOrchestrator.shared.keyWindow?.rootViewController as? FlexDockShell)?
            .setDockHidden(true, animated: false)
        navigationController?.pushViewController(entry.destination(), animated: true)
    }

    private func bindPilot() {
        pilot.profile.stream.subscribe(onNext: { [weak self] shard in
            let name = shard?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self?.nameLabel.text = name.isEmpty ? FlexPhraseBook.Coffer.userNamePlaceholder : name
            self?.phoneLabel.text = shard?.mobileLine
        }).disposed(by: disposeBag)
        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)
        pilot.signOutFailureSignal.stream.subscribe(onNext: { [weak self] message in
            guard let self else { return }
            FlexToast.show(message, on: self.view)
        }).disposed(by: disposeBag)
        pilot.signedOut.stream.subscribe(onNext: {
            FlexRootOrchestrator.shared.presentGate(replaceRoot: true)
        }).disposed(by: disposeBag)
    }

    private func showSignOutDialog() {
        FlexConfirmSheet.present(on: self,
                                 title: FlexPhraseBook.Coffer.signOutTitle,
                                 message: FlexPhraseBook.Coffer.signOutBody,
                                 art: FlexSliceCatalog.dialogSignOut,
                                 presentation: .card) { [weak self] in
            self?.pilot.signOut()
        }
    }
}

// MARK: - Menu row

private final class CofferMenuRow: UIControl {
    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.offerChevronTwine)?.withRenderingMode(.alwaysOriginal))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        titleLabel.font = FlexTypography.regular(15)
        titleLabel.textColor = FlexPalette.inkPrimary
        chevron.contentMode = .scaleAspectFit
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(chevron)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ entry: CofferMenuEntry) {
        titleLabel.text = entry.title
        iconView.image = FlexSlice.slice(entry.iconStem)?.withRenderingMode(.alwaysOriginal)
        iconView.contentMode = .scaleAspectFit
    }

    @objc private func tapped() { onTap?() }
}
