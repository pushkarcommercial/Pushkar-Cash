import UIKit
import SnapKit

// MARK: - Chip row

private final class RupeeEMIChipButton: UIButton {
    var chipValue = ""

    override var isSelected: Bool {
        didSet { applyStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.font = FlexTypography.medium(13)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.8
        flexRoundCorners(18)
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func applyStyle() {
        backgroundColor = isSelected ? FlexPalette.primaryTeal : FlexPalette.bannerGray
        setTitleColor(isSelected ? .white : FlexPalette.inkSecondary, for: .normal)
    }
}

private final class RupeeEMIChipRow: UIView {
    var onSelect: ((String) -> Void)?

    private let stack = UIStackView()
    private var buttons: [RupeeEMIChipButton] = []
    private var values: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(labels: [String], values: [String]) {
        self.values = values
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }

        zip(labels, values).forEach { label, value in
            let button = RupeeEMIChipButton()
            button.chipValue = value
            button.setTitle(label, for: .normal)
            button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
            button.snp.makeConstraints { $0.height.equalTo(36) }
        }
    }

    func select(matching raw: String?) {
        let normalized = raw ?? ""
        var hit = -1
        for (idx, value) in values.enumerated() where value == normalized {
            hit = idx
            break
        }
        buttons.enumerated().forEach { idx, button in
            button.isSelected = idx == hit
        }
    }

    @objc private func chipTapped(_ sender: RupeeEMIChipButton) {
        buttons.forEach { $0.isSelected = $0 === sender }
        onSelect?(sender.chipValue)
    }
}

// MARK: - Input section

private final class RupeeEMISectionView: UIView {
    let field = FlexBoundedField()
    let chipRow = RupeeEMIChipRow()

    init(title: String, rangeHint: String) {
        super.init(frame: .zero)
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalSpacing

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = FlexTypography.medium(14)
        titleLabel.textColor = FlexPalette.inkPrimary

        let hintLabel = UILabel()
        hintLabel.text = rangeHint
        hintLabel.font = FlexTypography.regular(12)
        hintLabel.textColor = FlexPalette.inkTertiary
        hintLabel.textAlignment = .right
        hintLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(hintLabel)

        field.backgroundColor = FlexPalette.bannerGray
        field.flexRoundCorners(12)
        field.layer.borderWidth = 0
        field.font = FlexTypography.medium(15)
        field.textColor = FlexPalette.inkPrimary
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always

        let stack = UIStackView(arrangedSubviews: [header, field, chipRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(12, after: field)
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        field.snp.makeConstraints { $0.height.equalTo(48) }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Canvas

final class RupeeEMICanvas: FlexBaseCanvas {
    private let scrollView = UIScrollView()
    private let card = UIView()
    private let amountSection = RupeeEMISectionView(
        title: FlexPhraseBook.EMI.loanAmountTitle,
        rangeHint: FlexPhraseBook.EMI.amountRangeHint
    )
    private let durationSection = RupeeEMISectionView(
        title: FlexPhraseBook.EMI.durationTitle,
        rangeHint: FlexPhraseBook.EMI.durationRangeHint
    )
    private let rateSection = RupeeEMISectionView(
        title: FlexPhraseBook.EMI.rateTitle,
        rangeHint: FlexPhraseBook.EMI.rateRangeHint
    )
    private let submitButton = FlexPrimaryButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(title: FlexPhraseBook.EMI.title)
        layoutUI()
        wireFields()
        wireChips()
        applyDefaults()
    }

    private func layoutUI() {
        FlexTheme.styleCard(card, elevated: false)
        card.layer.shadowOpacity = 0

        submitButton.setTitle(FlexPhraseBook.EMI.submit, for: .normal)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        let formStack = UIStackView(arrangedSubviews: [
            amountSection, durationSection, rateSection, submitButton
        ])
        formStack.axis = .vertical
        formStack.spacing = 24
        formStack.setCustomSpacing(28, after: rateSection)
        card.addSubview(formStack)
        formStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        submitButton.snp.makeConstraints { $0.height.equalTo(54) }

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(card)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.bottom.equalToSuperview()
        }
        card.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalTo(view).inset(16)
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    private func wireFields() {
        let amountField = amountSection.field
        amountField.keyboardType = .numberPad
        amountField.inputMode = .digits(max: RupeeEMILimits.maxAmountDigits)
        amountField.validationRule = { RupeeEMIInputGuard.isValidAmount($0) }
        amountField.invalidHint = FlexPhraseBook.EMI.amountRequired
        amountField.addTarget(self, action: #selector(amountEditingChanged), for: .editingChanged)
        amountField.addTarget(self, action: #selector(amountEditingEnded), for: .editingDidEnd)

        let durationField = durationSection.field
        durationField.keyboardType = .numberPad
        durationField.inputMode = .digits(max: 2)
        durationField.validationRule = { RupeeEMIInputGuard.isValidYears($0) }
        durationField.invalidHint = FlexPhraseBook.EMI.durationRequired
        durationField.addTarget(self, action: #selector(yearsEditingChanged), for: .editingChanged)
        durationField.addTarget(self, action: #selector(yearsEditingEnded), for: .editingDidEnd)

        let rateField = rateSection.field
        rateField.placeholder = FlexPhraseBook.EMI.ratePlaceholder
        rateField.keyboardType = .decimalPad
        rateField.inputMode = .plain(max: RupeeEMILimits.maxRateChars)
        rateField.validationRule = { RupeeEMIInputGuard.isValidRate($0) }
        rateField.invalidHint = FlexPhraseBook.EMI.rateRequired
        rateField.addTarget(self, action: #selector(rateEditingChanged), for: .editingChanged)
        rateField.addTarget(self, action: #selector(rateEditingEnded), for: .editingDidEnd)
    }

    private func wireChips() {
        amountSection.chipRow.configure(
            labels: RupeeEMILimits.amountChips.map { RupeeAmountFormat.indian($0) },
            values: RupeeEMILimits.amountChips
        )
        amountSection.chipRow.onSelect = { [weak self] value in
            self?.amountSection.field.text = RupeeAmountFormat.indian(value)
        }

        durationSection.chipRow.configure(
            labels: RupeeEMILimits.yearChips,
            values: RupeeEMILimits.yearChips
        )
        durationSection.chipRow.onSelect = { [weak self] value in
            self?.durationSection.field.text = value
        }

        rateSection.chipRow.configure(
            labels: RupeeEMILimits.rateChips,
            values: RupeeEMILimits.rateChips
        )
        rateSection.chipRow.onSelect = { [weak self] value in
            self?.rateSection.field.text = value
        }
    }

    private func applyDefaults() {
        amountSection.field.text = RupeeAmountFormat.indian(RupeeEMILimits.defaultAmount)
        durationSection.field.text = RupeeEMILimits.defaultYears
        rateSection.field.text = RupeeEMILimits.defaultRate
        syncChipSelection()
    }

    private func syncChipSelection() {
        amountSection.chipRow.select(matching: RupeeAmountFormat.digits(from: amountSection.field.text))
        durationSection.chipRow.select(matching: durationSection.field.text)
        rateSection.chipRow.select(matching: rateSection.field.text)
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        finalizeFields()

        guard RupeeEMIInputGuard.amountReadyForSubmit(amountSection.field.text ?? "") else {
            FlexToast.show(FlexPhraseBook.EMI.amountRequired)
            return
        }
        guard RupeeEMIInputGuard.yearsReadyForSubmit(durationSection.field.text ?? "") else {
            FlexToast.show(FlexPhraseBook.EMI.durationRequired)
            return
        }
        guard RupeeEMIInputGuard.rateReadyForSubmit(rateSection.field.text ?? "") else {
            FlexToast.show(FlexPhraseBook.EMI.rateRequired)
            return
        }

        let principal = Double(RupeeAmountFormat.digits(from: amountSection.field.text)) ?? 0
        let years = Double(durationSection.field.text ?? "") ?? 0
        let rate = Double(rateSection.field.text ?? "") ?? 0
        guard let result = RupeeEMIPilot.compute(principal: principal, years: years, annualRate: rate) else {
            FlexToast.show(FlexPhraseBook.EMI.amountRequired)
            return
        }
        navigationController?.pushViewController(RupeeEMIResultCanvas(result: result), animated: true)
    }

    private func finalizeFields() {
        amountSection.field.text = RupeeEMIInputGuard.finalizeAmount(amountSection.field.text ?? "")
        durationSection.field.text = RupeeEMIInputGuard.finalizeYears(durationSection.field.text ?? "")
        rateSection.field.text = RupeeEMIInputGuard.finalizeRate(rateSection.field.text ?? "")
        syncChipSelection()
    }

    @objc private func amountEditingChanged() {
        let clamped = RupeeEMIInputGuard.clampAmount(amountSection.field.text ?? "")
        if clamped != RupeeAmountFormat.digits(from: amountSection.field.text) {
            amountSection.field.text = clamped
        }
        amountSection.chipRow.select(matching: clamped)
    }

    @objc private func amountEditingEnded() {
        amountSection.field.text = RupeeEMIInputGuard.finalizeAmount(amountSection.field.text ?? "")
        syncChipSelection()
    }

    @objc private func yearsEditingChanged() {
        let clamped = RupeeEMIInputGuard.clampYears(durationSection.field.text ?? "")
        if clamped != durationSection.field.text { durationSection.field.text = clamped }
        if let value = Int(clamped) {
            if value > RupeeEMILimits.maxYears {
                durationSection.field.text = "\(RupeeEMILimits.maxYears)"
            } else if value > 0, value < RupeeEMILimits.minYears {
                durationSection.field.text = "\(RupeeEMILimits.minYears)"
            }
        }
        durationSection.chipRow.select(matching: durationSection.field.text)
    }

    @objc private func yearsEditingEnded() {
        durationSection.field.text = RupeeEMIInputGuard.finalizeYears(durationSection.field.text ?? "")
        syncChipSelection()
    }

    @objc private func rateEditingChanged() {
        let sanitized = RupeeEMIInputGuard.sanitizeRate(rateSection.field.text ?? "")
        if sanitized != rateSection.field.text { rateSection.field.text = sanitized }
        rateSection.chipRow.select(matching: sanitized)
    }

    @objc private func rateEditingEnded() {
        rateSection.field.text = RupeeEMIInputGuard.finalizeRate(rateSection.field.text ?? "")
        syncChipSelection()
    }
}
