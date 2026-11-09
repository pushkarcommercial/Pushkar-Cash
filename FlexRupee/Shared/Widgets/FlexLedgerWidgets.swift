import UIKit
import SnapKit
import Kingfisher

enum FlexLedgerWidgets {
    static func makeHintBanner(_ text: String) -> UIView {
        FlexCofferWidgets.makeHintBanner(text)
    }

    static func makeStatusPillRow(status: Int) -> UIView {
        let wrap = UIView()
        let tint = LedgerStatusLexicon.tint(for: status)
        let ringTint = LedgerStatusLexicon.ringTint(for: status)
        let ringInset = 3 + 2.5

        let leftLine = UIView()
        leftLine.backgroundColor = ringTint.withAlphaComponent(0.42)
        let rightLine = UIView()
        rightLine.backgroundColor = ringTint.withAlphaComponent(0.42)

        let ring = UIView()
        ring.backgroundColor = .white
        ring.layer.borderWidth = 2.5
        ring.layer.borderColor = ringTint.withAlphaComponent(0.55).cgColor
        ring.flexRoundCorners(18.5)

        let pill = UILabel()
        pill.text = LedgerStatusLexicon.label(for: status)
        pill.font = FlexTypography.medium(12)
        pill.textColor = tint
        pill.textAlignment = .center
        pill.backgroundColor = .white
        pill.layer.borderWidth = 1
        pill.layer.borderColor = ringTint.cgColor
        pill.flexRoundCorners(13)

        ring.addSubview(pill)
        wrap.addSubview(leftLine)
        wrap.addSubview(ring)
        wrap.addSubview(rightLine)

        pill.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(ringInset)
        }
        ring.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.62)
            make.height.equalTo(37)
        }
        leftLine.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.equalTo(ring.snp.leading).offset(-8)
            make.height.equalTo(1)
        }
        rightLine.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.equalTo(ring.snp.trailing).offset(8)
            make.height.equalTo(1)
        }
        wrap.snp.makeConstraints { $0.height.equalTo(37) }
        return wrap
    }

    static func makeProductHeader(name: String,
                                  amount: String?,
                                  logoURL: String?,
                                  showsChevron: Bool = false,
                                  onTap: (() -> Void)? = nil) -> UIView {
        let row = UIView()
        let logo = UIImageView()
        logo.contentMode = .scaleAspectFill
        logo.backgroundColor = FlexPalette.logoTile
        logo.flexRoundCorners(8)
        logo.clipsToBounds = true
        let placeholder = FlexSlice.slice(FlexSliceCatalog.loanBankChip)
        logo.image = placeholder
        if let logoURL, let url = URL(string: logoURL), !logoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logo.kf.setImage(with: url, placeholder: placeholder)
        }
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = FlexTypography.medium(15)
        nameLabel.textColor = FlexPalette.inkPrimary
        let amountLabel = UILabel()
        amountLabel.text = RupeeAmountFormat.rupeeSpaced(amount)
        amountLabel.font = FlexTypography.bold(18)
        amountLabel.textColor = FlexPalette.inkPrimary
        amountLabel.textAlignment = .right
        // Use termSelectArrow (grey chevron) — dialogChevronDown asset is a green list badge.
        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow)?.withRenderingMode(.alwaysOriginal))
        chevron.contentMode = .scaleAspectFit
        chevron.isHidden = !showsChevron
        let amountTap = UIView()
        row.addSubview(logo)
        row.addSubview(nameLabel)
        row.addSubview(amountTap)
        amountTap.addSubview(amountLabel)
        amountTap.addSubview(chevron)
        logo.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        amountTap.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        amountLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.equalTo(chevron.snp.leading).offset(showsChevron ? -6 : 0)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(logo.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(amountTap.snp.leading).offset(-8)
        }
        row.snp.makeConstraints { $0.height.equalTo(40) }
        if showsChevron, let onTap {
            amountTap.isUserInteractionEnabled = true
            amountTap.addGestureRecognizer(UITapGestureRecognizer(target: FlexLedgerTapProxy.shared, action: #selector(FlexLedgerTapProxy.invoke)))
            FlexLedgerTapProxy.shared.store(onTap, for: amountTap)
        }
        return row
    }

    static func makeFieldRow(_ row: LedgerDetailRowModel,
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
        value.font = FlexTypography.bold(14)
        value.textColor = FlexPalette.inkPrimary
        value.textAlignment = .right
        value.numberOfLines = 2
        let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.termSelectArrow)?.withRenderingMode(.alwaysOriginal))
        chevron.contentMode = .scaleAspectFit
        chevron.isHidden = row.selectKind == nil
        wrap.addSubview(value)
        wrap.addSubview(chevron)
        chevron.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        value.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(chevron.snp.leading).offset(row.selectKind == nil ? 0 : -6)
            make.leading.greaterThanOrEqualTo(wrap.snp.centerX).offset(-8)
        }
        wrap.snp.makeConstraints { $0.height.greaterThanOrEqualTo(26) }
        if row.selectKind != nil, let onSelect {
            wrap.isUserInteractionEnabled = true
            wrap.addGestureRecognizer(UITapGestureRecognizer(target: FlexLedgerTapProxy.shared, action: #selector(FlexLedgerTapProxy.invoke)))
            FlexLedgerTapProxy.shared.store(onSelect, for: wrap)
        }
        return wrap
    }

    static func makeFieldRowLegacy(_ row: LedgerDetailRowModel) -> UIView {
        makeFieldRow(row)
    }

    static func makeDetailCard() -> UIView {
        let card = UIView()
        FlexTheme.styleBorderedCard(card)
        card.flexRoundCorners(16)
        return card
    }

    static func makeBankBar(mask: String) -> UIView {
        let bar = UIView()
        bar.backgroundColor = FlexPalette.dockBlack
        bar.flexRoundCorners(14)
        let icon = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.loanBankChip))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = FlexPalette.accentGreen
        let label = UILabel()
        label.text = mask
        label.font = FlexTypography.medium(14)
        label.textColor = FlexPalette.accentGreen
        label.textAlignment = .right
        bar.addSubview(icon)
        bar.addSubview(label)
        icon.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview().inset(14)
            make.width.height.equalTo(22)
        }
        label.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview().inset(14)
            make.leading.greaterThanOrEqualTo(icon.snp.trailing).offset(8)
        }
        bar.snp.makeConstraints { $0.height.equalTo(52) }
        return bar
    }

    static func makeUPIWarning() -> UIView {
        let wrap = UIView()
        wrap.backgroundColor = UIColor(hex: 0xFFF8E6)
        wrap.flexRoundCorners(14)
        let label = UILabel()
        label.text = FlexPhraseBook.Ledger.upiWarning
        label.font = FlexTypography.regular(12)
        label.textColor = FlexPalette.warnAmber
        label.numberOfLines = 0
        wrap.addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
        return wrap
    }

    static func makeFooterNote(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = FlexTypography.regular(13)
        label.textColor = FlexPalette.inkSecondary
        label.numberOfLines = 0
        return label
    }

    static func makeOutlineButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(FlexPalette.inkPrimary, for: .normal)
        button.titleLabel?.font = FlexTypography.bold(16)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = FlexPalette.fieldBorder.cgColor
        button.flexRoundCorners(27)
        return button
    }
}

final class FlexLedgerTapProxy: NSObject {
    static let shared = FlexLedgerTapProxy()
    private var handlers: [ObjectIdentifier: () -> Void] = [:]

    func store(_ handler: @escaping () -> Void, for view: UIView) {
        handlers[ObjectIdentifier(view)] = handler
    }

    @objc func invoke(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        handlers[ObjectIdentifier(view)]?()
    }
}
