import UIKit
import SnapKit
import RxSwift

final class RupeeEMIResultCanvas: FlexBaseCanvas {
    private let result: RupeeEMIResult
    private let applyPilot = RupeeEMIApplyPilot()
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let resultCard = UIView()
    private let summaryCard = UIView()
    private let applyButton = FlexPrimaryButton()

    init(result: RupeeEMIResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.EMI.title)
        layoutUI()
        fillResult()
        bindApplyPilot()
        applyPilot.refreshApplyVisibility()
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyPilot.refreshApplyVisibility()
    }

    private func layoutUI() {
        resultCard.backgroundColor = FlexPalette.primaryTeal
        resultCard.flexRoundCorners(24)

        FlexTheme.styleCard(summaryCard, elevated: false)
        summaryCard.layer.shadowOpacity = 0

        applyButton.setTitle(FlexPhraseBook.Hub.applyNow, for: .normal)
        applyButton.isHidden = true

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.addArrangedSubview(resultCard)
        contentStack.addArrangedSubview(summaryCard)

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        view.addSubview(applyButton)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(applyButton.snp.top).offset(-16)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalTo(view).inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        applyButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.height.equalTo(54)
        }
    }

    private func fillResult() {
        populateMetricCard(
            resultCard,
            rows: [
                (FlexPhraseBook.EMI.totalPayment, RupeeAmountFormat.rupeeDecimal(result.totalPayment)),
                (FlexPhraseBook.EMI.monthlyEMI, RupeeAmountFormat.rupeeDecimal(result.monthlyEMI)),
                (FlexPhraseBook.EMI.totalInterest, RupeeAmountFormat.rupeeDecimal(result.totalInterest))
            ],
            style: .result
        )

        let rateText = result.annualRate.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(result.annualRate))"
            : String(format: "%.2f", result.annualRate)
        populateMetricCard(
            summaryCard,
            rows: [
                (FlexPhraseBook.EMI.summaryAmount, RupeeAmountFormat.indian("\(Int(result.principal))")),
                (FlexPhraseBook.EMI.summaryDuration, "\(Int(result.years))"),
                (FlexPhraseBook.EMI.summaryRate, rateText)
            ],
            style: .summary
        )
    }

    private enum MetricCardStyle {
        case result
        case summary

        var titleColor: UIColor {
            switch self {
            case .result: return UIColor.white.withAlphaComponent(0.88)
            case .summary: return FlexPalette.inkSecondary
            }
        }

        var valueColor: UIColor {
            switch self {
            case .result: return .white
            case .summary: return FlexPalette.inkPrimary
            }
        }

        var titleFont: UIFont {
            switch self {
            case .result: return FlexTypography.regular(14)
            case .summary: return FlexTypography.regular(13)
            }
        }

        var valueFont: UIFont {
            switch self {
            case .result: return FlexTypography.bold(15)
            case .summary: return FlexTypography.medium(14)
            }
        }

        var separatorColor: UIColor {
            switch self {
            case .result: return UIColor.white.withAlphaComponent(0.22)
            case .summary: return FlexPalette.fieldBorder
            }
        }

        var rowHeight: CGFloat {
            switch self {
            case .result: return 52
            case .summary: return 48
            }
        }

        var inset: CGFloat {
            switch self {
            case .result: return 20
            case .summary: return 16
            }
        }
    }

    private func populateMetricCard(_ card: UIView, rows: [(String, String)], style: MetricCardStyle) {
        card.subviews.forEach { $0.removeFromSuperview() }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(style.inset)
        }

        rows.enumerated().forEach { index, row in
            if index > 0 {
                let line = UIView()
                line.backgroundColor = style.separatorColor
                stack.addArrangedSubview(line)
                line.snp.makeConstraints { $0.height.equalTo(1.0 / UIScreen.main.scale) }
            }
            stack.addArrangedSubview(metricRow(title: row.0, value: row.1, style: style))
        }
    }

    private func metricRow(title: String, value: String, style: MetricCardStyle) -> UIView {
        let row = UIView()
        let left = UILabel()
        left.text = title
        left.font = style.titleFont
        left.textColor = style.titleColor
        let right = UILabel()
        right.text = value
        right.font = style.valueFont
        right.textColor = style.valueColor
        right.textAlignment = .right
        right.adjustsFontSizeToFitWidth = true
        right.minimumScaleFactor = 0.8
        row.addSubview(left)
        row.addSubview(right)
        left.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        right.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(left.snp.trailing).offset(12)
        }
        row.snp.makeConstraints { $0.height.equalTo(style.rowHeight) }
        return row
    }

    private func bindApplyPilot() {
        applyPilot.showApply.stream.subscribe(onNext: { [weak self] show in
            self?.applyButton.isHidden = !show
        }).disposed(by: disposeBag)
    }

    @objc private func applyTapped() {
        applyPilot.performApply(from: self, onVerify: { [weak self] stages in
            guard let self else { return }
            VerifyRoute.pushFirstIncomplete(from: self, stages: stages, entrySource: .emiDetail)
        }, onGoHome: { [weak self] in
            FlexRootOrchestrator.shared.popToHub()
            self?.navigationController?.popToRootViewController(animated: false)
        })
    }
}
