import UIKit
import SnapKit

enum FlexVerifyWidgets {
    static func makeWhiteCard() -> UIView {
        let card = UIView()
        FlexTheme.styleBorderedCard(card)
        card.flexRoundCorners(16)
        return card
    }

    static func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(13)
        label.textColor = FlexPalette.inkSecondary
        return label
    }

    static func makeInputShell(_ field: UIView) -> UIView {
        let wrap = UIView()
        field.backgroundColor = .white
        field.flexRoundCorners(12)
        if let bounded = field as? FlexBoundedField {
            bounded.layer.borderWidth = 1
            bounded.layer.borderColor = FlexPalette.fieldBorder.cgColor
            bounded.font = FlexTypography.regular(15)
            bounded.textColor = FlexPalette.inkPrimary
            bounded.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
            bounded.leftViewMode = .always
        }
        wrap.addSubview(field)
        field.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52)
        }
        return wrap
    }

    static func makeLabeledField(label: String, field: FlexBoundedField) -> UIView {
        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.addArrangedSubview(makeSectionLabel(label))
        wrap.addArrangedSubview(makeInputShell(field))
        return wrap
    }

    /// P23 — IFSC row: text on the left, inset Find IFSC pill on the right.
    static func makeIFSCLabeledField(label: String,
                                     field: FlexBoundedField,
                                     onFindIFSC: @escaping () -> Void) -> UIView {
        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.addArrangedSubview(makeSectionLabel(label))

        let shell = UIView()
        shell.backgroundColor = .white
        shell.layer.cornerRadius = 12
        shell.layer.borderWidth = 1
        shell.layer.borderColor = FlexPalette.fieldBorder.cgColor
        shell.clipsToBounds = true

        styleIFSCTextField(field)
        let findButton = makeIFSCFindButton(onTap: onFindIFSC)

        shell.addSubview(field)
        shell.addSubview(findButton)
        field.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(findButton.snp.leading).offset(-6)
        }
        findButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(38)
            make.width.equalTo(108)
        }
        shell.snp.makeConstraints { $0.height.equalTo(52) }

        wrap.addArrangedSubview(shell)
        return wrap
    }

    private static func styleIFSCTextField(_ field: FlexBoundedField) {
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.layer.borderWidth = 0
        field.font = FlexTypography.regular(15)
        field.textColor = FlexPalette.inkPrimary
        field.tintColor = FlexPalette.primaryTeal
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.rightView = nil
        field.rightViewMode = .never
        field.clearButtonMode = .never
    }

    private static func makeIFSCFindButton(onTap: @escaping () -> Void) -> UIView {
        let button = UIView()
        button.backgroundColor = FlexPalette.primaryTeal
        button.layer.cornerRadius = 19
        button.clipsToBounds = true
        button.isUserInteractionEnabled = true

        let titleLabel = UILabel()
        titleLabel.text = FlexPhraseBook.Verify.findIFSCTitle
        titleLabel.font = FlexTypography.medium(13)
        titleLabel.textColor = .white
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.ifscSearchMark)?.withRenderingMode(.alwaysOriginal))
        chevron.contentMode = .scaleAspectFit

        button.addSubview(titleLabel)
        button.addSubview(chevron)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(4)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        button.addGestureRecognizer(UITapGestureRecognizer(target: FlexVerifyTapProxy.shared,
                                                           action: #selector(FlexVerifyTapProxy.invoke)))
        FlexVerifyTapProxy.shared.store(onTap, for: button)
        return button
    }

    static func makeSelectRow(label: String,
                              valueText: String?,
                              onTap: @escaping () -> Void) -> (UIView, UILabel) {
        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.addArrangedSubview(makeSectionLabel(label))

        let row = UIView()
        row.backgroundColor = .white
        row.flexRoundCorners(12)
        row.layer.borderWidth = 1
        row.layer.borderColor = FlexPalette.fieldBorder.cgColor

        let valueLabel = UILabel()
        valueLabel.font = FlexTypography.regular(15)
        valueLabel.textColor = valueText == nil ? FlexPalette.inkTertiary : FlexPalette.inkPrimary
        valueLabel.text = valueText ?? FlexPhraseBook.Verify.pleaseChoose

        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow))
        chevron.contentMode = .scaleAspectFit

        row.addSubview(valueLabel)
        row.addSubview(chevron)
        valueLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        row.snp.makeConstraints { $0.height.equalTo(52) }

        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: FlexVerifyTapProxy.shared,
                                                          action: #selector(FlexVerifyTapProxy.invoke)))
        FlexVerifyTapProxy.shared.store(onTap, for: row)

        wrap.addArrangedSubview(row)
        return (wrap, valueLabel)
    }

    /// P36 — Relationship: gray bar, title fixed-width left / Please choose + chevron right.
    static func makeContactRelationRow(title: String,
                                       onTap: @escaping () -> Void) -> (UIView, UILabel, UILabel) {
        let row = UIView()
        row.backgroundColor = FlexPalette.bannerGray
        row.flexRoundCorners(12)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = FlexTypography.regular(14)
        titleLabel.textColor = FlexPalette.inkSecondary
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = FlexPhraseBook.Verify.pleaseChoose
        valueLabel.font = FlexTypography.regular(14)
        valueLabel.textColor = FlexPalette.inkTertiary
        valueLabel.textAlignment = .right

        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow))
        chevron.contentMode = .scaleAspectFit

        row.addSubview(titleLabel)
        row.addSubview(valueLabel)
        row.addSubview(chevron)

        let titleWidth = ceil((title as NSString)
            .size(withAttributes: [.font: titleLabel.font as Any]).width)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.equalTo(titleWidth)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalTo(chevron.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { $0.height.equalTo(48) }

        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: FlexVerifyTapProxy.shared,
                                                          action: #selector(FlexVerifyTapProxy.invoke)))
        FlexVerifyTapProxy.shared.store(onTap, for: row)
        return (row, titleLabel, valueLabel)
    }

    /// Apply filled / empty state for P36 relationship row.
    static func applyContactRelationSelection(titleLabel: UILabel,
                                              valueLabel: UILabel,
                                              titleText: String,
                                              selectedText: String?) {
        let titleWidth = ceil((titleText as NSString)
            .size(withAttributes: [.font: titleLabel.font as Any]).width)
        if let selectedText, !selectedText.isEmpty {
            titleLabel.isHidden = true
            titleLabel.snp.updateConstraints { $0.width.equalTo(0) }
            valueLabel.text = selectedText
            valueLabel.textColor = FlexPalette.inkPrimary
            valueLabel.textAlignment = .left
        } else {
            titleLabel.isHidden = false
            titleLabel.snp.updateConstraints { $0.width.equalTo(titleWidth) }
            valueLabel.text = FlexPhraseBook.Verify.pleaseChoose
            valueLabel.textColor = FlexPalette.inkTertiary
            valueLabel.textAlignment = .right
        }
    }

    static func makeContactCard(title: String,
                                relationRow: UIView,
                                nameField: FlexBoundedField,
                                phoneField: FlexBoundedField,
                                onPickContact: @escaping () -> Void) -> UIView {
        let card = makeWhiteCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12

        let header = UILabel()
        header.text = title
        header.font = FlexTypography.bold(15)
        header.textColor = FlexPalette.inkPrimary

        nameField.isUserInteractionEnabled = false
        phoneField.isUserInteractionEnabled = false

        let nameRow = makeContactValueRow(label: "Name", field: nameField)
        let phoneRow = makeContactValueRow(label: "Phone number", field: phoneField)

        let pickButton = UIButton(type: .custom)
        pickButton.setImage(
            FlexSlice.slice(FlexSliceCatalog.kycEmergencyLeaf)?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        pickButton.imageView?.contentMode = .scaleAspectFit
        pickButton.backgroundColor = FlexPalette.bannerGray
        pickButton.flexRoundCorners(12)
        pickButton.addAction(UIAction { _ in onPickContact() }, for: .touchUpInside)

        let fieldColumn = UIStackView(arrangedSubviews: [nameRow, phoneRow])
        fieldColumn.axis = .vertical
        fieldColumn.spacing = 8
        fieldColumn.isUserInteractionEnabled = false

        // Transparent hit target over Name / Phone — opens address book (same as side button).
        let fieldsHit = UIButton(type: .custom)
        fieldsHit.backgroundColor = .clear
        fieldsHit.addAction(UIAction { _ in onPickContact() }, for: .touchUpInside)

        let contactRow = UIView()
        contactRow.addSubview(fieldColumn)
        contactRow.addSubview(fieldsHit)
        contactRow.addSubview(pickButton)
        fieldColumn.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(pickButton.snp.leading).offset(-8)
        }
        fieldsHit.snp.makeConstraints { make in
            make.edges.equalTo(fieldColumn)
        }
        pickButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalTo(52)
        }

        [header, relationRow, contactRow].forEach { cardStack.addArrangedSubview($0) }
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        return card
    }

    private static func makeContactValueRow(label: String, field: FlexBoundedField) -> UIView {
        let row = UIView()
        row.backgroundColor = FlexPalette.bannerGray
        row.flexRoundCorners(12)
        let title = UILabel()
        title.text = label
        title.font = FlexTypography.regular(14)
        title.textColor = FlexPalette.inkSecondary
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        let titleWidth = ceil((label as NSString)
            .size(withAttributes: [.font: title.font as Any]).width)

        field.backgroundColor = .clear
        field.borderStyle = .none
        field.layer.borderWidth = 0
        field.font = FlexTypography.regular(14)
        field.textColor = FlexPalette.inkPrimary
        field.textAlignment = .right
        field.placeholder = FlexPhraseBook.Verify.pleaseChoose
        field.leftView = nil
        field.leftViewMode = .never

        row.addSubview(title)
        row.addSubview(field)
        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.equalTo(titleWidth)
        }
        field.snp.makeConstraints { make in
            make.leading.equalTo(title.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        row.snp.makeConstraints { $0.height.equalTo(48) }
        return row
    }

    static func makeKeyValueCard(label: String, valueLabel: UILabel) -> UIView {
        let card = makeWhiteCard()
        let title = makeInlineTitleLabel(label)
        valueLabel.font = FlexTypography.bold(15)
        valueLabel.textColor = FlexPalette.inkPrimary
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2
        valueLabel.text = "-"
        card.addSubview(title)
        card.addSubview(valueLabel)
        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(inlineTitleWidth(label, font: title.font))
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(title.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        card.snp.makeConstraints { $0.height.greaterThanOrEqualTo(52) }
        return card
    }

    /// P26 — Aadhaar number: title + editable field share one card; title width fits label text.
    static func makeInlineCardField(label: String, field: FlexBoundedField) -> UIView {
        let card = makeWhiteCard()
        let title = makeInlineTitleLabel(label)

        field.backgroundColor = .clear
        field.borderStyle = .none
        field.layer.borderWidth = 0
        field.layer.cornerRadius = 0
        field.font = FlexTypography.bold(15)
        field.textColor = FlexPalette.inkPrimary
        field.textAlignment = .right
        field.leftView = nil
        field.leftViewMode = .never
        field.rightView = nil
        field.rightViewMode = .never

        card.addSubview(title)
        card.addSubview(field)
        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(inlineTitleWidth(label, font: title.font))
        }
        field.snp.makeConstraints { make in
            make.leading.equalTo(title.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
        card.snp.makeConstraints { $0.height.equalTo(52) }
        return card
    }

    private static func makeInlineTitleLabel(_ text: String) -> UILabel {
        let title = UILabel()
        title.text = text
        title.font = FlexTypography.regular(13)
        title.textColor = FlexPalette.inkSecondary
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        return title
    }

    private static func inlineTitleWidth(_ text: String, font: UIFont?) -> CGFloat {
        let resolved = font ?? FlexTypography.regular(13)
        return ceil((text as NSString).size(withAttributes: [.font: resolved]).width)
    }

    static func makeBilingualTipCard(english: String, hindi: String?) -> UIView {
        let card = makeWhiteCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        let en = UILabel()
        en.text = english
        en.font = FlexTypography.regular(12)
        en.textColor = FlexPalette.inkTertiary
        en.numberOfLines = 0
        stack.addArrangedSubview(en)
        if let hindi, !hindi.isEmpty {
            let hi = UILabel()
            hi.text = hindi
            hi.font = FlexTypography.regular(12)
            hi.textColor = FlexPalette.inkTertiary.withAlphaComponent(0.85)
            hi.numberOfLines = 0
            stack.addArrangedSubview(hi)
        }
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        return card
    }

    /// Aadhaar front/back card (Kiva: placeholder camera + in-slot caption; X only after photo).
    static func makeDualUploadCard(title: String,
                                 frontSlot: FlexDocUploadSlot,
                                 backSlot: FlexDocUploadSlot) -> UIView {
        let card = makeWhiteCard()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = FlexTypography.bold(16)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center

        let slots = UIStackView()
        slots.axis = .vertical
        slots.spacing = 16
        slots.alignment = .fill
        slots.addArrangedSubview(frontSlot)
        slots.addArrangedSubview(backSlot)
        // Taller tile so landscape Aadhaar / PAN fit with AspectFit (less letterbox).
        frontSlot.snp.makeConstraints { $0.height.equalTo(168) }
        backSlot.snp.makeConstraints { $0.height.equalTo(168) }

        card.addSubview(titleLabel)
        card.addSubview(slots)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        slots.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        return card
    }

    /// PAN / single-document card.
    static func makeDocumentUploadCard(title: String,
                                       subtitleHi: String?,
                                       slot: FlexDocUploadSlot,
                                       slotSubtitleHi: String?) -> UIView {
        let card = makeWhiteCard()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = FlexTypography.bold(16)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.addArrangedSubview(titleLabel)
        if let subtitleHi, !subtitleHi.isEmpty {
            let hi = UILabel()
            hi.text = subtitleHi
            hi.font = FlexTypography.regular(12)
            hi.textColor = FlexPalette.inkTertiary
            hi.textAlignment = .center
            hi.numberOfLines = 0
            cardStack.addArrangedSubview(hi)
        }
        cardStack.addArrangedSubview(slot)
        slot.snp.makeConstraints { $0.height.equalTo(168) }
        if let slotSubtitleHi, !slotSubtitleHi.isEmpty {
            let hi = UILabel()
            hi.text = slotSubtitleHi
            hi.font = FlexTypography.regular(12)
            hi.textColor = FlexPalette.inkTertiary
            hi.textAlignment = .center
            cardStack.addArrangedSubview(hi)
        }
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        return card
    }

    static func makeFacePreviewHost(_ preview: UIImageView) -> UIView {
        let card = makeWhiteCard()
        // Face-before art already includes its white plate + frame — fit, don't crop.
        if preview.contentMode != .scaleAspectFill {
            preview.contentMode = .scaleAspectFit
        }
        preview.clipsToBounds = true
        preview.flexRoundCorners(16)
        preview.backgroundColor = .white
        card.addSubview(preview)
        preview.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
            make.height.equalTo(preview.snp.width)
        }
        return card
    }

    /// P34 / P35 live camera + snapshot host (rounded square).
    static func makeFaceCameraHost(cameraView: UIView, snapshot: UIImageView) -> UIView {
        let card = makeWhiteCard()
        let frame = UIView()
        frame.backgroundColor = .black
        frame.clipsToBounds = true
        frame.flexRoundCorners(16)
        cameraView.backgroundColor = .black
        cameraView.clipsToBounds = true
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.isHidden = true
        frame.addSubview(cameraView)
        frame.addSubview(snapshot)
        cameraView.snp.makeConstraints { $0.edges.equalToSuperview() }
        snapshot.snp.makeConstraints { $0.edges.equalToSuperview() }
        card.addSubview(frame)
        frame.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
            make.height.equalTo(frame.snp.width)
        }
        return card
    }

    static func makeInstructionBlock() -> (UILabel, UILabel) {
        let instruction = UILabel()
        instruction.text = FlexPhraseBook.Verify.faceInstruction
        instruction.font = FlexTypography.medium(14)
        instruction.textColor = FlexPalette.primaryTeal
        instruction.textAlignment = .center
        instruction.numberOfLines = 0

        let instructionHi = UILabel()
        instructionHi.text = FlexPhraseBook.Verify.faceInstructionHi
        instructionHi.font = FlexTypography.regular(13)
        instructionHi.textColor = FlexPalette.inkSecondary
        instructionHi.textAlignment = .center
        instructionHi.numberOfLines = 0
        return (instruction, instructionHi)
    }


    static func makeNumberedTips(_ lines: [String]) -> UIView {
        let card = makeWhiteCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        lines.enumerated().forEach { index, line in
            let label = UILabel()
            label.font = FlexTypography.regular(12)
            label.textColor = FlexPalette.inkTertiary
            label.numberOfLines = 0
            label.text = "\(index + 1). \(line)"
            stack.addArrangedSubview(label)
        }
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        return card
    }
}

/// ID upload tile (Kiva `KLKycIdentityCardAddView`): camera + caption until filled; delete only after photo.
final class FlexDocUploadSlot: UIControl {
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?
    private(set) var hasPhoto = false

    private let plate = UIView()
    private let photoView = UIImageView()
    private let iconView = UIImageView()
    private let captionLabel = UILabel()
    private let removeBtn = UIButton(type: .custom)

    init(caption: String) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = caption

        plate.backgroundColor = FlexPalette.bannerGray
        plate.flexRoundCorners(12)
        plate.clipsToBounds = true
        plate.isUserInteractionEnabled = false

        // Show the full document — AspectFill was cropping edges (相册/拍照“显示不全”).
        photoView.contentMode = .scaleAspectFit
        photoView.clipsToBounds = true
        photoView.backgroundColor = FlexPalette.bannerGray
        photoView.isHidden = true
        photoView.isUserInteractionEnabled = false

        iconView.contentMode = .scaleAspectFit
        iconView.image = FlexSlice.slice(FlexSliceCatalog.kycCameraOrb)?.withRenderingMode(.alwaysOriginal)
        iconView.isUserInteractionEnabled = false

        captionLabel.text = caption
        captionLabel.font = FlexTypography.medium(14)
        captionLabel.textColor = FlexPalette.inkPrimary
        captionLabel.textAlignment = .center

        removeBtn.setImage(FlexSlice.slice(FlexSliceCatalog.kycRemovePin)?.withRenderingMode(.alwaysOriginal), for: .normal)
        removeBtn.isHidden = true
        removeBtn.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)

        addTarget(self, action: #selector(slotTapped), for: .touchUpInside)
        addSubview(plate)
        plate.addSubview(photoView)
        plate.addSubview(iconView)
        plate.addSubview(captionLabel)
        addSubview(removeBtn)

        plate.snp.makeConstraints { $0.edges.equalToSuperview() }
        photoView.snp.makeConstraints { $0.edges.equalToSuperview() }

        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-12)
            make.width.height.equalTo(48)
        }
        captionLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
        }
        removeBtn.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(8)
            make.width.height.equalTo(22)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 168)
    }

    func setPhoto(_ image: UIImage?) {
        if let image {
            hasPhoto = true
            photoView.image = image
            photoView.isHidden = false
            iconView.isHidden = true
            captionLabel.isHidden = true
            removeBtn.isHidden = false
            accessibilityTraits = .image
        } else {
            clear()
        }
    }

    func clear() {
        hasPhoto = false
        photoView.image = nil
        photoView.isHidden = true
        iconView.isHidden = false
        captionLabel.isHidden = false
        removeBtn.isHidden = true
        accessibilityTraits = .button
    }

    @objc private func slotTapped() {
        guard !hasPhoto else { return }
        onTap?()
    }

    @objc private func removeTapped() {
        onRemove?()
    }
}

final class FlexVerifyTapProxy: NSObject {
    static let shared = FlexVerifyTapProxy()
    private var handlers: [ObjectIdentifier: () -> Void] = [:]

    func store(_ handler: @escaping () -> Void, for view: UIView) {
        handlers[ObjectIdentifier(view)] = handler
    }

    @objc func invoke(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        handlers[ObjectIdentifier(view)]?()
    }
}
