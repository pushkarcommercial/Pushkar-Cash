import UIKit
import SnapKit
import RxSwift

final class MintSplashCanvas: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.splashNavy
        let logo = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.splashDawnCrest)?.withRenderingMode(.alwaysOriginal))
        logo.contentMode = .scaleAspectFill
        logo.clipsToBounds = true
        logo.flexRoundCorners(26)
        let title = UILabel()
        title.text = FlexPhraseBook.appName
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .white
        view.addSubview(logo)
        view.addSubview(title)
        logo.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(120)
        }
        title.snp.makeConstraints { make in
            make.top.equalTo(logo.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if CofferVault.shared.isLoggedIn {
                FlexRootOrchestrator.shared.presentDock()
            } else {
                self?.navigationController?.setViewControllers([GateCanvas()], animated: true)
            }
        }
    }
}

final class GateCanvas: FlexBaseCanvas, UITextViewDelegate {
    private let pilot = GatePilot()
    private let disposeBag = DisposeBag()
    private let otpTrigger = PublishSubject<Void>()
    private let signInTrigger = PublishSubject<Void>()
    /// After a finished 60s countdown, button shows Reacquire instead of Get OTP.
    private var otpDidCooldown = false

    private let logoView = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.gateBloomSigil)?.withRenderingMode(.alwaysOriginal))
    private let welcomeLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let mobileTitleLabel = UILabel()
    private let mobileRow = UIView()
    private let mobileIconView = UIImageView()
    private let mobilePrefixLabel = UILabel()
    private let mobileSeparator = UIView()
    private let mobileField = FlexBoundedField()
    private let otpTitleLabel = UILabel()
    private let otpRow = UIView()
    private let otpIconView = UIImageView()
    private let otpField = FlexBoundedField()
    private let otpButton = UIButton(type: .custom)
    private let signInButton = FlexPrimaryButton()
    private let privacyCheck = UIButton(type: .custom)
    private let legalTextView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        flexNavBar.isHidden = true
        layoutUI()
        bindPilot()
        bootstrapRemoteConfig()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        FlexTrackingGate.requestAuthorizationIfNeeded()
    }

    private func bootstrapRemoteConfig() {
        FlexHubBootstrap.runConfigWhenNetworkReady { [weak self] in
            self?.pilot.warmUpRemoteConfig()
        }
    }

    private func layoutUI() {
        view.backgroundColor = FlexPalette.canvasGray

        logoView.contentMode = .scaleAspectFill
        logoView.clipsToBounds = true
        logoView.flexRoundCorners(16)

        welcomeLabel.text = FlexPhraseBook.Gate.welcome
        welcomeLabel.font = FlexTypography.bold(24)
        welcomeLabel.textColor = FlexPalette.inkPrimary
        welcomeLabel.textAlignment = .center

        subtitleLabel.text = FlexPhraseBook.Gate.secureSubtitle
        subtitleLabel.font = FlexTypography.regular(14)
        subtitleLabel.textColor = FlexPalette.inkSecondary
        subtitleLabel.textAlignment = .center

        mobileTitleLabel.text = FlexPhraseBook.Gate.mobileTitle
        otpTitleLabel.text = FlexPhraseBook.Gate.otpTitle
        styleFieldLabel(mobileTitleLabel)
        styleFieldLabel(otpTitleLabel)

        FlexTheme.styleGateInputRow(mobileRow)
        FlexTheme.styleGateInputRow(otpRow)
        otpRow.clipsToBounds = true

        mobileIconView.image = FlexSlice.slice(FlexSliceCatalog.phoneReedGlyph)
        mobileIconView.contentMode = .scaleAspectFit
        mobilePrefixLabel.text = "+91"
        mobilePrefixLabel.font = FlexTypography.medium(16)
        mobilePrefixLabel.textColor = FlexPalette.inkPrimary
        mobileSeparator.backgroundColor = FlexPalette.fieldBorder

        configureGateField(mobileField, placeholder: FlexPhraseBook.Gate.mobilePlaceholder,
                           mode: .digits(max: RupeeFieldLimit.mobileTyping))
        configureGateField(otpField, placeholder: FlexPhraseBook.Gate.otpPlaceholder,
                           mode: .digits(max: RupeeFieldLimit.otpTyping))
        mobileField.keyboardType = .numberPad
        otpField.keyboardType = .numberPad
        mobileField.validationRule = { RupeeInputGuard.matchesIndiaMobile($0) }
        mobileField.invalidHint = FlexPhraseBook.Gate.mobileInvalid
        otpField.validationRule = { RupeeInputGuard.isValidOTP($0) }
        otpField.invalidHint = FlexPhraseBook.Gate.otpInvalid

        otpIconView.image = FlexSlice.slice(FlexSliceCatalog.otpCipherShard)
        otpIconView.contentMode = .scaleAspectFit

        otpButton.setTitle(FlexPhraseBook.Gate.getOTP, for: .normal)
        FlexTheme.styleGateOTPButton(otpButton)

        signInButton.setTitle(FlexPhraseBook.Gate.signIn, for: .normal)

        privacyCheck.setImage(FlexSlice.slice(FlexSliceCatalog.agreeMossIdle), for: .normal)
        privacyCheck.setImage(FlexSlice.slice(FlexSliceCatalog.agreeSageMarked), for: .selected)
        privacyCheck.isSelected = true

        configureLegalTextView()

        mobileRow.addSubview(mobileIconView)
        mobileRow.addSubview(mobilePrefixLabel)
        mobileRow.addSubview(mobileSeparator)
        mobileRow.addSubview(mobileField)
        otpRow.addSubview(otpIconView)
        otpRow.addSubview(otpField)
        otpRow.addSubview(otpButton)

        [
            logoView, welcomeLabel, subtitleLabel,
            mobileTitleLabel, mobileRow, otpTitleLabel, otpRow,
            signInButton, privacyCheck, legalTextView
        ].forEach { view.addSubview($0) }

        let inset = 24
        logoView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(72)
        }
        welcomeLabel.snp.makeConstraints { make in
            make.top.equalTo(logoView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(welcomeLabel.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
        }
        mobileTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        mobileRow.snp.makeConstraints { make in
            make.top.equalTo(mobileTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(52)
        }
        mobileIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        mobilePrefixLabel.snp.makeConstraints { make in
            make.leading.equalTo(mobileIconView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(32)
        }
        mobileSeparator.snp.makeConstraints { make in
            make.leading.equalTo(mobilePrefixLabel.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(1)
            make.height.equalTo(20)
        }
        mobileField.snp.makeConstraints { make in
            make.leading.equalTo(mobileSeparator.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        otpTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(mobileRow.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        otpRow.snp.makeConstraints { make in
            make.top.equalTo(otpTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(52)
        }
        otpIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        otpField.snp.makeConstraints { make in
            make.leading.equalTo(otpIconView.snp.trailing).offset(10)
            make.trailing.equalTo(otpButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        otpButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(36)
        }
        signInButton.snp.makeConstraints { make in
            make.top.equalTo(otpRow.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(52)
        }
        privacyCheck.snp.makeConstraints { make in
            make.top.equalTo(signInButton.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(inset)
            make.width.height.equalTo(20)
        }
        legalTextView.snp.makeConstraints { make in
            make.leading.equalTo(privacyCheck.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-inset)
            make.top.equalTo(privacyCheck).offset(-2)
        }

        mobileField.boundedDelegate = self
        otpField.boundedDelegate = self
        otpButton.addTarget(self, action: #selector(otpTapped), for: .touchUpInside)
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        privacyCheck.addTarget(self, action: #selector(togglePrivacy), for: .touchUpInside)
    }

    private func styleFieldLabel(_ label: UILabel) {
        label.font = FlexTypography.medium(13)
        label.textColor = FlexPalette.inkSecondary
    }

    private func configureGateField(_ field: FlexBoundedField, placeholder: String, mode: FlexBoundedField.InputMode) {
        field.inputMode = mode
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.layer.borderWidth = 0
        field.placeholder = placeholder
        field.font = FlexTypography.regular(15)
        field.textColor = FlexPalette.inkPrimary
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: FlexPalette.inkPlaceholder, .font: FlexTypography.light(15)]
        )
    }

    private func configureLegalTextView() {
        let prefix = FlexPhraseBook.Gate.legalPrefix
        let privacy = FlexPhraseBook.Gate.privacyPolicy
        let connector = FlexPhraseBook.Gate.legalConnector
        let terms = FlexPhraseBook.Gate.serviceAgreement
        let full = prefix + privacy + connector + terms

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: FlexTypography.regular(12),
            .foregroundColor: FlexPalette.inkSecondary
        ]
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .font: FlexTypography.medium(12),
            .foregroundColor: FlexPalette.primaryTeal,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let attr = NSMutableAttributedString(string: full, attributes: bodyAttrs)
        let privacyRange = (full as NSString).range(of: privacy)
        let termsRange = (full as NSString).range(of: terms)
        attr.addAttributes(linkAttrs, range: privacyRange)
        attr.addAttributes(linkAttrs, range: termsRange)
        attr.addAttribute(.link, value: "flexrupee://privacy", range: privacyRange)
        attr.addAttribute(.link, value: "flexrupee://terms", range: termsRange)

        legalTextView.attributedText = attr
        legalTextView.isEditable = false
        legalTextView.isScrollEnabled = false
        legalTextView.backgroundColor = .clear
        legalTextView.textContainerInset = .zero
        legalTextView.textContainer.lineFragmentPadding = 0
        legalTextView.delegate = self
        legalTextView.linkTextAttributes = [
            .foregroundColor: FlexPalette.primaryTeal,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    private func bindPilot() {
        pilot.bindOTPTrigger(otpTrigger.asObservable())
        pilot.bindSignInTrigger(signInTrigger.asObservable())

        pilot.otpCooldown.stream.subscribe(onNext: { [weak self] seconds in
            guard let self else { return }
            if seconds > 0 {
                self.otpDidCooldown = true
                self.otpButton.setTitle(FlexPhraseBook.Gate.otpCountdown(seconds), for: .normal)
                self.otpButton.isEnabled = false
                self.otpButton.backgroundColor = FlexPalette.inkTertiary
            } else {
                let title = self.otpDidCooldown
                    ? FlexPhraseBook.Gate.otpResend
                    : FlexPhraseBook.Gate.getOTP
                self.otpButton.setTitle(title, for: .normal)
                self.otpButton.isEnabled = true
                self.otpButton.backgroundColor = FlexPalette.primaryTeal
            }
        }).disposed(by: disposeBag)

        pilot.toastSignal.stream.subscribe(onNext: { [weak self] message in
            guard let self else { return }
            FlexToast.show(message, on: self.view)
        }).disposed(by: disposeBag)
        pilot.authenticationFailureSignal.stream.subscribe(onNext: { [weak self] message in
            guard let self else { return }
            let duration: TimeInterval = message.count > 80 ? 5 : 3.5
            FlexToast.show(message, on: self.view, duration: duration)
        }).disposed(by: disposeBag)
        pilot.enterDockSignal.stream.subscribe(onNext: { [weak self] in
            guard let self else { return }
            FlexLoginGate.handleLoginSuccess(from: self)
        }).disposed(by: disposeBag)
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.absoluteString.contains("privacy") {
            openPrivacy()
        } else if URL.absoluteString.contains("terms") {
            openTerms()
        }
        return false
    }

    @objc private func otpTapped() { otpTrigger.onNext(()) }
    @objc private func signInTapped() { signInTrigger.onNext(()) }
    @objc private func togglePrivacy() {
        privacyCheck.isSelected.toggle()
        pilot.privacyAccepted.accept(privacyCheck.isSelected)
        pilot.termsAccepted.accept(privacyCheck.isSelected)
    }

    @objc private func openPrivacy() {
        PulseBeaconRecorder.shared.stamp(.privacyLink)
        FlexLegalDocLaunch.open(.privacyPolicy, from: self)
    }

    @objc private func openTerms() {
        PulseBeaconRecorder.shared.stamp(.termsLink)
        FlexLegalDocLaunch.open(.serviceAgreement, from: self)
    }
}

extension GateCanvas: FlexBoundedFieldDelegate {
    func boundedFieldDidChange(_ field: FlexBoundedField) {
        if field === mobileField { pilot.mobileInput.accept(field.text ?? "") }
        if field === otpField { pilot.otpInput.accept(field.text ?? "") }
    }
}
