import UIKit
import SnapKit
import Kingfisher

struct FlexLoanFieldRowModel {
    let label: String
    let value: String
    let hintKind: FlexFieldHintKind?
    let selectable: Bool
}

enum FlexLoanWidgets {
    static func makeWhiteCard() -> UIView {
        let card = UIView()
        FlexTheme.styleBorderedCard(card)
        card.flexRoundCorners(16)
        return card
    }

    static func makeProductRow(name: String, logoURL: String?) -> UIView {
        let row = UIView()
        let logo = UIImageView()
        logo.contentMode = .scaleAspectFill
        logo.backgroundColor = FlexPalette.logoTile
        logo.flexRoundCorners(8)
        logo.clipsToBounds = true
        if let logoURL, let url = URL(string: logoURL) {
            logo.kf.setImage(with: url, placeholder: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        }
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = FlexTypography.medium(15)
        nameLabel.textColor = FlexPalette.inkPrimary
        row.addSubview(logo)
        row.addSubview(nameLabel)
        logo.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(logo.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        row.snp.makeConstraints { $0.height.equalTo(40) }
        return row
    }

    static func makeAmountStepper(amountLabel: UILabel,
                                  minusButton: UIButton,
                                  plusButton: UIButton) -> UIView {
        let wrap = UIView()
        amountLabel.font = FlexTypography.bold(32)
        amountLabel.textColor = FlexPalette.inkPrimary
        amountLabel.textAlignment = .center
        [minusButton, plusButton].forEach { button in
            button.titleLabel?.font = FlexTypography.bold(24)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = FlexPalette.primaryTeal
            button.flexRoundCorners(12)
        }
        minusButton.setTitle("−", for: .normal)
        plusButton.setTitle("+", for: .normal)
        wrap.addSubview(minusButton)
        wrap.addSubview(amountLabel)
        wrap.addSubview(plusButton)
        minusButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        amountLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(minusButton.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(plusButton.snp.leading).offset(-12)
        }
        plusButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        wrap.snp.makeConstraints { $0.height.equalTo(48) }
        return wrap
    }

    static func makeFixedAmountDisplay(amountLabel: UILabel) -> UIView {
        let wrap = UIView()
        amountLabel.font = FlexTypography.bold(32)
        amountLabel.textColor = FlexPalette.primaryTeal
        amountLabel.textAlignment = .center
        wrap.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(48)
        }
        return wrap
    }

    static func makeFieldRow(_ row: FlexLoanFieldRowModel,
                             onSelect: (() -> Void)? = nil,
                             onHint: ((FlexFieldHintKind) -> Void)? = nil) -> UIView {
        let wrap = UIView()
        let label = UILabel()
        label.font = FlexTypography.regular(13)
        label.textColor = FlexPalette.inkSecondary
        label.text = row.label
        if let hintKind = row.hintKind {
            let hint = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanInfoSpark))
            hint.contentMode = .scaleAspectFit
            let labelRow = UIStackView(arrangedSubviews: [label, hint])
            labelRow.axis = .horizontal
            labelRow.spacing = 4
            labelRow.alignment = .center
            wrap.addSubview(labelRow)
            labelRow.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
            }
            hint.snp.makeConstraints { $0.width.height.equalTo(14) }
            if let onHint {
                FlexFieldHintBubble.wireHint(on: labelRow, kind: hintKind) { onHint(hintKind) }
            }
        } else {
            wrap.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
            }
        }
        let value = UILabel()
        value.text = row.value
        value.font = FlexTypography.medium(14)
        value.textColor = FlexPalette.inkPrimary
        value.textAlignment = .right
        value.numberOfLines = 2
        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow)?.withRenderingMode(.alwaysOriginal))
        chevron.contentMode = .scaleAspectFit
        chevron.isHidden = !row.selectable
        wrap.addSubview(value)
        wrap.addSubview(chevron)
        chevron.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        value.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(chevron.snp.leading).offset(row.selectable ? -6 : 0)
            make.leading.greaterThanOrEqualTo(wrap.snp.centerX).offset(-8)
        }
        wrap.snp.makeConstraints { $0.height.greaterThanOrEqualTo(26) }
        if row.selectable, let onSelect {
            wrap.isUserInteractionEnabled = true
            wrap.addGestureRecognizer(UITapGestureRecognizer(target: FlexLedgerTapProxy.shared, action: #selector(FlexLedgerTapProxy.invoke)))
            FlexLedgerTapProxy.shared.store(onSelect, for: wrap)
        }
        return wrap
    }

    static func makeAgreementRow(checkbox: UIButton,
                                 label: UILabel,
                                 linkButton: UIButton) -> UIView {
        let row = UIView()
        checkbox.setImage(FlexSlice.slice(FlexSliceCatalog.agreeMossIdle), for: .normal)
        checkbox.setImage(FlexSlice.slice(FlexSliceCatalog.agreeSageMarked), for: .selected)
        checkbox.isSelected = true
        label.font = FlexTypography.regular(13)
        label.textColor = FlexPalette.inkSecondary
        label.numberOfLines = 0
        linkButton.setTitle(FlexPhraseBook.Loan.termsLink, for: .normal)
        linkButton.setTitleColor(FlexPalette.primaryTeal, for: .normal)
        linkButton.titleLabel?.font = FlexTypography.medium(13)
        let attributed = NSAttributedString(
            string: FlexPhraseBook.Loan.termsLink,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: FlexTypography.medium(13),
                .foregroundColor: FlexPalette.primaryTeal
            ]
        )
        linkButton.setAttributedTitle(attributed, for: .normal)
        let textRow = UIStackView(arrangedSubviews: [label, linkButton])
        textRow.axis = .horizontal
        textRow.spacing = 0
        textRow.alignment = .firstBaseline
        row.addSubview(checkbox)
        row.addSubview(textRow)
        checkbox.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.height.equalTo(22)
        }
        textRow.snp.makeConstraints { make in
            make.leading.equalTo(checkbox.snp.trailing).offset(8)
            make.trailing.top.bottom.equalToSuperview()
        }
        label.text = FlexPhraseBook.Loan.termsPrefix
        return row
    }
}
