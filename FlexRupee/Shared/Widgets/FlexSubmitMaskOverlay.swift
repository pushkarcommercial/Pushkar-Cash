import UIKit
import SnapKit

/// Review card shown while device and contact data sync for an order.
final class FlexSubmitMaskOverlay: UIView {
    private static weak var active: FlexSubmitMaskOverlay?
    private let card = UIView()
    private let scrollView = UIScrollView()
    private let content = UIView()
    private let progressTrack = UIView()
    private let progressFill = CAGradientLayer()
    private let percentLabel = UILabel()
    private var progress: CGFloat = 0.2

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.42)
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.clipsToBounds = true
        scrollView.showsVerticalScrollIndicator = false
        addSubview(card)
        card.addSubview(scrollView)
        scrollView.addSubview(content)

        card.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(454).priority(.high)
            make.height.lessThanOrEqualToSuperview().inset(24)
        }
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        content.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        let reviewArt = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.dialogUpgradeBanner))
        reviewArt.contentMode = .scaleAspectFit
        content.addSubview(reviewArt)
        reviewArt.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(64)
        }

        let heading = makeLabel("Under review", size: 21, weight: .bold, color: .black, alignment: .center)
        content.addSubview(heading)
        heading.snp.makeConstraints { make in
            make.top.equalTo(reviewArt.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        progressTrack.backgroundColor = UIColor(hex: 0xF0F2F2)
        progressTrack.layer.cornerRadius = 4
        progressTrack.clipsToBounds = true
        progressFill.colors = [UIColor(hex: 0x4A768C).cgColor, UIColor(hex: 0x8CCF91).cgColor]
        progressFill.startPoint = CGPoint(x: 0, y: 0.5)
        progressFill.endPoint = CGPoint(x: 1, y: 0.5)
        progressTrack.layer.addSublayer(progressFill)
        content.addSubview(progressTrack)
        progressTrack.snp.makeConstraints { make in
            make.top.equalTo(heading.snp.bottom).offset(26)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-62)
            make.height.equalTo(8)
        }
        percentLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        percentLabel.textColor = FlexPalette.primaryTeal
        percentLabel.textAlignment = .right
        content.addSubview(percentLabel)
        percentLabel.snp.makeConstraints { make in
            make.centerY.equalTo(progressTrack)
            make.leading.equalTo(progressTrack.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        let description = makeLabel("Updating your credit score, please do not leave this page. This process takes about 15 seconds...",
                                    size: 15, weight: .regular, color: UIColor(hex: 0x666A6C), alignment: .left)
        content.addSubview(description)
        description.snp.makeConstraints { make in
            make.top.equalTo(progressTrack.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        let steps = makeSteps()
        content.addSubview(steps)
        steps.snp.makeConstraints { make in
            make.top.equalTo(description.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(92)
        }

        let footnote = makeLabel("Just one more step before your loan is credited, please don’t leave this page.",
                                 size: 13, weight: .regular, color: FlexPalette.primaryTeal, alignment: .center)
        content.addSubview(footnote)
        footnote.snp.makeConstraints { make in
            make.top.equalTo(steps.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
        updateProgress(0.2)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        progressFill.frame = CGRect(x: 0, y: 0,
                                    width: progressTrack.bounds.width * progress,
                                    height: progressTrack.bounds.height)
        progressFill.cornerRadius = progressTrack.bounds.height / 2
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight,
                           color: UIColor, alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        return label
    }

    private func makeSteps() -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor(hex: 0xF3F5F5)
        panel.layer.cornerRadius = 16
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fill
        panel.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(10) }
        let items: [(String, String?, String?)] = [
            ("Apply now", "doc.text", nil),
            ("Reviewed", "magnifyingglass", nil),
            ("Received", nil, FlexSliceCatalog.dialogWithdrawArt)
        ]
        var firstColumn: UIStackView?
        for (index, item) in items.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.alignment = .center
            column.spacing = 6
            let circle = UIView()
            circle.backgroundColor = FlexPalette.accentGreen
            circle.layer.cornerRadius = 20
            circle.snp.makeConstraints { $0.width.height.equalTo(40) }
            if let asset = item.2 {
                let image = UIImageView(image: FlexSlice.slice(asset))
                image.contentMode = .scaleAspectFit
                circle.addSubview(image)
                image.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let image = UIImageView(image: UIImage(systemName: item.1 ?? ""))
                image.tintColor = .white
                image.contentMode = .scaleAspectFit
                circle.addSubview(image)
                image.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(21) }
            }
            let caption = makeLabel(item.0, size: 12, weight: .semibold, color: .black, alignment: .center)
            column.addArrangedSubview(circle)
            column.addArrangedSubview(caption)
            row.addArrangedSubview(column)
            if let firstColumn {
                column.snp.makeConstraints { $0.width.equalTo(firstColumn) }
            } else {
                firstColumn = column
            }
            if index < 2 {
                let arrow = UIImageView(image: UIImage(systemName: "arrow.right"))
                arrow.tintColor = FlexPalette.accentGreen
                arrow.contentMode = .scaleAspectFit
                arrow.snp.makeConstraints { $0.width.equalTo(16) }
                row.addArrangedSubview(arrow)
            }
        }
        return panel
    }

    private func updateProgress(_ value: CGFloat) {
        progress = min(max(value, 0), 1)
        percentLabel.text = "\(Int(progress * 100))%"
        setNeedsLayout()
    }

    static func setProgress(_ value: CGFloat) {
        DispatchQueue.main.async { active?.updateProgress(value) }
    }

    static func show(on host: UIView? = nil) {
        hide()
        guard let container = host ?? FlexRootOrchestrator.shared.keyWindow else { return }
        let overlay = FlexSubmitMaskOverlay(frame: container.bounds)
        container.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        active = overlay
    }

    static func hide() {
        active?.removeFromSuperview()
        active = nil
    }
}

enum FlexPendingDealSheet {
    /// Tip after termV3/business 6230002 (review) / 6230003 (withdraw).
    /// Know More → order detail: prefer `dealId`, else `orderId=1` + `productId` (Kiva/FinTrust).
    static func present(on host: UIViewController,
                        message: String,
                        productId: String,
                        dealId: String?,
                        code: Int? = nil) {
        let body = message.isEmpty ? FlexPhraseBook.Loan.pendingOrderBody : message
        FlexIllustratedSheet.present(
            on: host,
            art: FlexSliceCatalog.dialogThanksPlume,
            title: FlexPhraseBook.Loan.orderTipTitle,
            message: body,
            confirmTitle: FlexPhraseBook.Loan.knowMore,
            cancelTitle: FlexPhraseBook.Loan.orderTipBack,
            showsCancel: true,
            buttonOrder: .cancelThenConfirm,
            bodyAlignment: .left,
            onConfirm: {
                let resolvedDealId = dealId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolvedProductId = productId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !resolvedDealId.isEmpty || !resolvedProductId.isEmpty else { return }
                let canvas = LedgerDetailCanvas(
                    dealId: resolvedDealId,
                    productId: resolvedProductId,
                    preferWithdraw: code == 6230003
                )
                host.navigationController?.pushViewController(canvas, animated: true)
            },
            onCancel: {
                if host.navigationController?.topViewController === host {
                    host.navigationController?.popViewController(animated: true)
                }
            }
        )
    }
}
