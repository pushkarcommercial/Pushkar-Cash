import UIKit
import SnapKit
import RxSwift

final class LedgerOrdersCanvas: FlexBaseCanvas {
    private let pilot = LedgerOrdersPilot()
    private let disposeBag = DisposeBag()

    private let tabBarWrap = UIView()
    private let tabStack = UIStackView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyWrap = UIView()
    private let emptyArtView = UIImageView()
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(title: FlexPhraseBook.Ledger.title)
        layoutUI()
        bindPilot()
        // Load in viewWillAppear only — doing it here too cancelled the first request and toasted.
        NotificationCenter.default.addObserver(forName: .flexOpenLedgerTab, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if let tab = note.object as? LedgerTabKind {
                self.applyTab(tab)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        consumePendingTabIfNeeded()
        pilot.loadRows()
    }

    private func consumePendingTabIfNeeded() {
        guard let tab = LedgerOrdersLaunch.pendingTab else { return }
        LedgerOrdersLaunch.pendingTab = nil
        applyTab(tab)
    }

    private func applyTab(_ tab: LedgerTabKind) {
        highlightTab(index: tab.rawValue)
        pilot.selectTab(tab)
    }

    private func layoutUI() {
        tabBarWrap.backgroundColor = FlexPalette.bannerGray
        tabBarWrap.flexRoundCorners(16)
        tabBarWrap.clipsToBounds = true

        tabStack.axis = .horizontal
        tabStack.spacing = 4
        tabStack.distribution = .fillEqually
        tabBarWrap.addSubview(tabStack)
        tabStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        LedgerTabKind.allCases.enumerated().forEach { index, kind in
            let btn = UIButton(type: .custom)
            btn.setTitle(kind.title, for: .normal)
            btn.titleLabel?.font = FlexTypography.medium(12)
            btn.titleLabel?.numberOfLines = 2
            btn.titleLabel?.textAlignment = .center
            btn.titleLabel?.lineBreakMode = .byWordWrapping
            btn.tag = index
            btn.flexRoundCorners(12)
            btn.clipsToBounds = true
            btn.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(btn)
        }

        tableView.register(LedgerRowCell.self, forCellReuseIdentifier: LedgerRowCell.reuseId)
        tableView.separatorStyle = .none
        tableView.backgroundColor = FlexPalette.canvasGray
        tableView.rowHeight = 156
        tableView.delegate = self
        tableView.dataSource = self

        emptyArtView.image = FlexSlice.slice(FlexSliceCatalog.ordersEmptyDrift)
        emptyArtView.contentMode = .scaleAspectFit
        emptyLabel.text = FlexPhraseBook.Ledger.empty
        emptyLabel.font = FlexTypography.regular(14)
        emptyLabel.textColor = FlexPalette.inkTertiary
        emptyLabel.textAlignment = .center
        emptyWrap.isHidden = true
        emptyWrap.addSubview(emptyArtView)
        emptyWrap.addSubview(emptyLabel)

        view.backgroundColor = FlexPalette.canvasGray
        view.addSubview(tabBarWrap)
        view.addSubview(tableView)
        view.addSubview(emptyWrap)

        tabBarWrap.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(tabBarWrap.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-88)
        }
        emptyWrap.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        emptyArtView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(96)
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyArtView.snp.bottom).offset(12)
            make.centerX.bottom.equalToSuperview()
        }
        highlightTab(index: 0)
    }

    private func bindPilot() {
        pilot.rows.stream.subscribe(onNext: { [weak self] rows in
            self?.tableView.reloadData()
            self?.emptyWrap.isHidden = !rows.isEmpty
        }).disposed(by: disposeBag)
        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)
    }

    @objc private func tabChanged(_ sender: UIButton) {
        highlightTab(index: sender.tag)
        pilot.activeTab.accept(LedgerTabKind.allCases[sender.tag])
    }

    private func highlightTab(index: Int) {
        tabStack.arrangedSubviews.enumerated().forEach { idx, view in
            guard let btn = view as? UIButton else { return }
            let active = idx == index
            btn.backgroundColor = active ? FlexPalette.primaryTeal : .clear
            btn.setTitleColor(active ? .white : FlexPalette.inkSecondary, for: .normal)
        }
    }
}

extension LedgerOrdersCanvas: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pilot.rows.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LedgerRowCell.reuseId, for: indexPath) as! LedgerRowCell
        cell.apply(pilot.rows.value[indexPath.row], tab: pilot.activeTab.value)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = pilot.rows.value[indexPath.row]
        if FlexRejectVolumeLaunch.isRejectedOrderState(row.dealState),
           FlexRejectVolumeLaunch.hasURL {
            FlexRejectVolumeLaunch.open(from: self)
            return
        }
        let canvas = LedgerDetailCanvas(dealId: row.dealId ?? "", productId: row.productId ?? "")
        navigationController?.pushViewController(canvas, animated: true)
    }
}

final class LedgerRowCell: UITableViewCell {
    static let reuseId = "LedgerRowCell"

    private let card = UIView()
    private let statusHost = UIView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let leftDateTitle = UILabel()
    private let leftDateValue = UILabel()
    private let rightDateTitle = UILabel()
    private let rightDateValue = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.backgroundColor = .white
        card.flexRoundCorners(16)

        titleLabel.font = FlexTypography.bold(16)
        titleLabel.textColor = FlexPalette.inkPrimary
        amountLabel.font = FlexTypography.bold(16)
        amountLabel.textColor = FlexPalette.inkPrimary
        amountLabel.textAlignment = .right

        [leftDateTitle, rightDateTitle].forEach {
            $0.font = FlexTypography.regular(12)
            $0.textColor = FlexPalette.inkTertiary
            $0.numberOfLines = 2
        }
        [leftDateValue, rightDateValue].forEach {
            $0.font = FlexTypography.medium(14)
            $0.textColor = FlexPalette.inkPrimary
            $0.numberOfLines = 2
            $0.lineBreakMode = .byWordWrapping
        }
        rightDateTitle.textAlignment = .right
        rightDateValue.textAlignment = .right

        contentView.addSubview(card)
        card.addSubview(statusHost)
        [titleLabel, amountLabel, leftDateTitle, leftDateValue, rightDateTitle, rightDateValue]
            .forEach { card.addSubview($0) }

        card.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16))
        }
        statusHost.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(statusHost.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-8)
        }
        amountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        leftDateTitle.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(card.snp.centerX).offset(-12)
        }
        leftDateValue.snp.makeConstraints { make in
            make.top.equalTo(leftDateTitle.snp.bottom).offset(4)
            make.leading.trailing.equalTo(leftDateTitle)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
        rightDateTitle.snp.makeConstraints { make in
            make.top.equalTo(leftDateTitle)
            make.leading.equalTo(card.snp.centerX).offset(12)
            make.trailing.equalToSuperview().offset(-16)
        }
        rightDateValue.snp.makeConstraints { make in
            make.top.equalTo(rightDateTitle.snp.bottom).offset(4)
            make.leading.trailing.equalTo(rightDateTitle)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ row: LedgerRowShard, tab: LedgerTabKind) {
        titleLabel.text = row.productTitle ?? "Appname"
        amountLabel.text = RupeeAmountFormat.rupee(row.principal)

        let columns = Self.dateColumns(for: tab, row: row)
        leftDateTitle.text = columns.leftTitle
        leftDateValue.text = columns.leftValue
        rightDateTitle.text = columns.rightTitle
        rightDateValue.text = columns.rightValue

        statusHost.subviews.forEach { $0.removeFromSuperview() }
        let statusRow = FlexLedgerWidgets.makeStatusPillRow(status: row.dealState ?? 0)
        statusHost.addSubview(statusRow)
        statusRow.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private static func dateColumns(for tab: LedgerTabKind, row: LedgerRowShard) -> (leftTitle: String, leftValue: String, rightTitle: String, rightValue: String) {
        switch tab {
        case .pendingRepay:
            return (
                FlexPhraseBook.Ledger.paymentDate,
                displayDate(row.grantStamp ?? row.applyStamp),
                FlexPhraseBook.Ledger.dueDate,
                displayDate(row.dueStamp)
            )
        case .submit, .processing:
            return (
                FlexPhraseBook.Ledger.applyDate,
                displayDate(row.applyStamp),
                FlexPhraseBook.Ledger.dueDate,
                displayDate(row.dueStamp)
            )
        case .completed:
            // 结清列表：放款日期 (loanDate) + 结清日期 (repayDate).
            return (
                FlexPhraseBook.Ledger.paymentDate,
                displayDate(row.grantStamp ?? row.applyStamp),
                FlexPhraseBook.Ledger.repaymentDate,
                displayDate(row.repayStamp)
            )
        }
    }

    private static func displayDate(_ raw: String?) -> String {
        RupeeDateFormat.ledgerDisplay(raw)
    }
}
