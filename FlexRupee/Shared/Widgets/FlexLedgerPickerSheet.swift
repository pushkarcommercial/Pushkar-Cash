import UIKit
import SnapKit

enum FlexLedgerPickerSheet {
    static func present(on host: UIViewController,
                        title: String,
                        options: [String],
                        selectedIndex: Int = 0,
                        onPick: @escaping (Int) -> Void) {
        host.view.endEditing(true)
        let overlay = FlexLedgerPickerOverlay(frame: host.view.bounds)
        overlay.configure(title: title, options: options, selectedIndex: selectedIndex, onPick: onPick)
        host.view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

/// P38 Relationship dialog — centered card, icon, list + checkmark, Cancel / Confirm.
private final class FlexLedgerPickerOverlay: UIView {
    private static let cardHeight: CGFloat = 430

    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let cancelButton = UIButton(type: .custom)
    private let confirmButton = UIButton(type: .custom)
    private var options: [String] = []
    private var selectedIndex = 0
    private var onPick: ((Int) -> Void)?
    private var needsInitialScroll = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        tableView.separatorColor = FlexPalette.fieldBorder
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.showsVerticalScrollIndicator = true
        tableView.tableFooterView = UIView()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FlexPickerOptionCell.self, forCellReuseIdentifier: FlexPickerOptionCell.reuseId)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        FlexDialogLayout.styleOutlineAction(cancelButton)
        FlexDialogLayout.stylePrimaryAction(confirmButton)
        cancelButton.setTitle(FlexPhraseBook.Dialog.cancel, for: .normal)
        confirmButton.setTitle(FlexPhraseBook.Dialog.confirm, for: .normal)

        addSubview(cardView)
        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(tableView)
        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(buttonRow)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardHorizontalInset)
            make.height.equalTo(Self.cardHeight).priority(.high)
            make.height.lessThanOrEqualToSuperview().inset(32)
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(FlexDialogMetrics.cardPadding)
            make.centerX.equalToSuperview()
            make.size.equalTo(FlexDialogMetrics.iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(FlexDialogMetrics.iconToTitle)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(FlexDialogMetrics.titleToBody)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(buttonRow.snp.top).offset(-FlexDialogMetrics.bodyToButtons)
        }
        buttonRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        confirmButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, options: [String], selectedIndex: Int, onPick: @escaping (Int) -> Void) {
        // P38 list-picker badge (shared by amount/term, relationship, IFSC).
        // dialogWithdrawArt belongs to the pending-withdraw hub prompt — not this sheet.
        iconView.image = FlexSlice.slice(FlexSliceCatalog.dialogChevronDown)?.withRenderingMode(.alwaysOriginal)
        titleLabel.text = title
        self.options = options
        self.selectedIndex = min(max(0, selectedIndex), max(0, options.count - 1))
        self.onPick = onPick
        tableView.reloadData()
        needsInitialScroll = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard needsInitialScroll, options.indices.contains(selectedIndex), tableView.bounds.height > 0 else { return }
        needsInitialScroll = false
        tableView.layoutIfNeeded()
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    @objc private func cancelTapped() {
        removeFromSuperview()
    }

    @objc private func confirmTapped() {
        onPick?(selectedIndex)
        removeFromSuperview()
    }
}

extension FlexLedgerPickerOverlay: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FlexPickerOptionCell.reuseId, for: indexPath) as! FlexPickerOptionCell
        cell.apply(text: options[indexPath.row], selected: indexPath.row == selectedIndex)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        tableView.reloadData()
    }
}

private final class FlexPickerOptionCell: UITableViewCell {
    static let reuseId = "FlexPickerOptionCell"
    private let titleLabel = UILabel()
    private let checkView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        titleLabel.font = FlexTypography.regular(15)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        checkView.contentMode = .scaleAspectFit
        checkView.image = FlexSlice.slice(FlexSliceCatalog.dialogCheckboxRest)
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkView)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.bottom.equalToSuperview().inset(14)
            make.trailing.equalTo(checkView.snp.leading).offset(-12)
            make.height.greaterThanOrEqualTo(24)
        }
        checkView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(text: String, selected: Bool) {
        titleLabel.text = text
        titleLabel.font = selected ? FlexTypography.bold(15) : FlexTypography.regular(15)
        checkView.isHidden = !selected
    }
}
