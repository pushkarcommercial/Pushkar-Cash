import UIKit
import SnapKit

enum FlexUpgradeOverlay {
    private static weak var active: UIView?

    static var isForceBlocking: Bool {
        (active as? FlexUpgradePanel)?.blocksInteraction ?? false
    }

    static func present(on host: UIView, note: ReleaseNoteShard, force: Bool) {
        host.subviews.compactMap { $0 as? FlexUpgradePanel }.forEach { $0.removeFromSuperview() }
        let panel = FlexUpgradePanel(note: note, force: force)
        host.addSubview(panel)
        panel.snp.makeConstraints { $0.edges.equalToSuperview() }
        active = panel
    }
}

/// P37 upgrade dialog — icon, title, version, and dual CTAs inside one card.
private final class FlexUpgradePanel: UIView {
    private let storeURL: URL?
    private let showsDismiss: Bool
    fileprivate let blocksInteraction: Bool
    private let cardView = UIView()
    private let iconView = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.dialogUpgradeBanner))
    private let titleLabel = UILabel()
    private let versionLabel = UILabel()
    private let cancelButton = UIButton(type: .custom)
    private let upgradeButton = UIButton(type: .custom)

    init(note: ReleaseNoteShard, force: Bool) {
        storeURL = URL(string: note.resolvedStoreURL(force: force) ?? "")
        showsDismiss = !force
        blocksInteraction = force
        super.init(frame: .zero)
        backgroundColor = FlexDialogMetrics.scrim
        cardView.backgroundColor = .white
        cardView.flexRoundCorners(FlexDialogMetrics.cardCorner)
        iconView.contentMode = .scaleAspectFit
        titleLabel.text = FlexPhraseBook.Release.upgradeTitle
        titleLabel.font = FlexTypography.bold(20)
        titleLabel.textColor = FlexPalette.inkPrimary
        titleLabel.textAlignment = .center
        let version = note.latestBuild ?? RupeeDeviceProbe.shared.buildStamp
        versionLabel.text = FlexPhraseBook.Release.versionFound(version)
        versionLabel.font = FlexTypography.regular(14)
        versionLabel.textColor = FlexPalette.inkSecondary
        versionLabel.textAlignment = .center
        cancelButton.setTitle(FlexPhraseBook.Dialog.cancel, for: .normal)
        cancelButton.isHidden = !showsDismiss
        cancelButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        upgradeButton.setTitle(FlexPhraseBook.Release.upgradeAction, for: .normal)
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        FlexDialogLayout.styleOutlineAction(cancelButton)
        FlexDialogLayout.stylePrimaryAction(upgradeButton)
        layoutUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layoutUI() {
        addSubview(cardView)
        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(versionLabel)

        let buttonRow = UIStackView(arrangedSubviews: showsDismiss ? [cancelButton, upgradeButton] : [upgradeButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = FlexDialogMetrics.buttonSpacing
        buttonRow.distribution = .fillEqually
        cardView.addSubview(buttonRow)

        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardHorizontalInset)
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
        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(FlexDialogMetrics.titleToBody)
            make.leading.trailing.equalTo(titleLabel)
        }
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(versionLabel.snp.bottom).offset(FlexDialogMetrics.bodyToButtons)
            make.leading.trailing.equalToSuperview().inset(FlexDialogMetrics.cardPadding)
            make.bottom.equalToSuperview().offset(-FlexDialogMetrics.cardPadding)
        }
        cancelButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
        upgradeButton.snp.makeConstraints { $0.height.equalTo(FlexDialogMetrics.buttonHeight) }
    }

    @objc private func upgradeTapped() {
        guard let url = storeURL else { return }
        UIApplication.shared.open(url)
    }

    @objc private func closeTapped() {
        removeFromSuperview()
    }
}
