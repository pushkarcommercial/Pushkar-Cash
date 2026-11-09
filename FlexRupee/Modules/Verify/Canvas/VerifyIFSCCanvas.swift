import UIKit
import SnapKit
import RxSwift

final class VerifyIFSCCanvas: FlexBaseCanvas {
    var onSelectIFSC: ((String) -> Void)?
    weak var selectionHost: VerifyFormCanvas?
    weak var returnHost: UIViewController?

    private let store = VerifyStageStore.shared
    private let disposeBag = DisposeBag()
    private let continueButton = FlexPrimaryButton()

    private var state = ""
    private var city = ""
    private var bank = ""
    private var branch = ""
    private var valueLabels: [UILabel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Verify.findIFSCTitle)
        layoutUI()
    }

    private func layoutUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        let titles = [
            FlexPhraseBook.Verify.bankState,
            FlexPhraseBook.Verify.bankCity,
            FlexPhraseBook.Verify.bankName,
            FlexPhraseBook.Verify.bankBranch
        ]
        titles.enumerated().forEach { index, title in
            let (row, valueLabel) = FlexVerifyWidgets.makeSelectRow(label: title, valueText: nil) { [weak self] in
                self?.pickLevel(index)
            }
            valueLabels.append(valueLabel)
            stack.addArrangedSubview(row)
        }

        continueButton.setTitle(FlexPhraseBook.Verify.continueAction, for: .normal)
        continueButton.titleLabel?.font = FlexTypography.bold(18)
        continueButton.flexRoundCorners(12)
        continueButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        view.addSubview(stack)
        view.addSubview(continueButton)
        stack.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.height.equalTo(58)
        }
    }

    private func updateLabel(at index: Int, text: String) {
        guard valueLabels.indices.contains(index) else { return }
        valueLabels[index].text = text
        valueLabels[index].textColor = FlexPalette.inkPrimary
    }

    private func resetLabels(from index: Int) {
        guard index < valueLabels.count else { return }
        for idx in index..<valueLabels.count {
            valueLabels[idx].text = FlexPhraseBook.Verify.pleaseChoose
            valueLabels[idx].textColor = FlexPalette.inkTertiary
        }
    }

    private func pickLevel(_ level: Int) {
        var payload: [String: Any] = [:]
        switch level {
        case 0: break
        case 1:
            guard !state.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankState); return }
            payload["state"] = state
        case 2:
            guard !city.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankCity); return }
            payload["state"] = state
            payload["city"] = city
        case 3:
            guard !bank.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankName); return }
            payload["state"] = state
            payload["city"] = city
            payload["bank"] = bank
        default: return
        }

        store.fetchIFSCList(payload: payload)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] options in
                self?.presentOptions(options, level: level)
            }, onError: { error in
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func presentOptions(_ options: [String], level: Int) {
        guard !options.isEmpty else {
            FlexToast.show(FlexPhraseBook.Verify.noIFSCOptions)
            return
        }
        let titles = [
            FlexPhraseBook.Verify.bankState,
            FlexPhraseBook.Verify.bankCity,
            FlexPhraseBook.Verify.bankName,
            FlexPhraseBook.Verify.bankBranch
        ]
        let title = titles.indices.contains(level) ? titles[level] : FlexPhraseBook.Verify.pleaseChoose
        FlexLedgerPickerSheet.present(on: self,
                                      title: title,
                                      options: options,
                                      selectedIndex: 0) { [weak self] index in
            guard let self else { return }
            let value = options[index]
            switch level {
            case 0:
                self.state = value
                self.updateLabel(at: 0, text: value)
                self.city = ""; self.bank = ""; self.branch = ""
                self.resetLabels(from: 1)
            case 1:
                self.city = value
                self.updateLabel(at: 1, text: value)
                self.bank = ""; self.branch = ""
                self.resetLabels(from: 2)
            case 2:
                self.bank = value
                self.updateLabel(at: 2, text: value)
                self.branch = ""
                self.resetLabels(from: 3)
            case 3:
                self.branch = value
                self.updateLabel(at: 3, text: value)
            default: break
            }
        }
    }

    @objc private func confirmTapped() {
        guard !state.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankState); return }
        guard !city.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankCity); return }
        guard !bank.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankName); return }
        guard !branch.isEmpty else { FlexToast.show(FlexPhraseBook.Verify.selectBankBranch); return }
        guard continueButton.isEnabled else { return }

        continueButton.isEnabled = false
        store.fetchIFSCList(payload: ["state": state, "city": city, "bank": bank, "branch": branch])
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] list in
                guard let self else { return }
                print("[IFSC] submit response list: \(list)")
                guard let code = list.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !code.isEmpty else {
                    self.continueButton.isEnabled = true
                    FlexToast.show(FlexPhraseBook.Verify.ifscRequired)
                    return
                }
                self.deliverSelection(code)
            }, onError: { [weak self] error in
                self?.continueButton.isEnabled = true
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: disposeBag)
    }

    private func deliverSelection(_ code: String) {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !value.isEmpty else {
            continueButton.isEnabled = true
            return
        }
        print("[IFSC] deliverSelection raw=\(code) normalized=\(value)")
        selectionHost?.applyIFSCSelection(value, clearRelatedFields: true)
        popBackToHost()
    }

    private func popBackToHost() {
        let host = returnHost ?? selectionHost
        guard let host, let nav = host.navigationController, nav.viewControllers.contains(host) else {
            navigationController?.popViewController(animated: true)
            return
        }
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak host] in
            (host as? VerifyFormCanvas)?.refreshIFSCDisplay()
        }
        nav.popToViewController(host, animated: true)
        CATransaction.commit()
    }
}
