import UIKit
import SnapKit
import RxSwift
import AVFoundation

// MARK: - Hub list

final class VerifyGateCanvas: FlexBaseCanvas {
    private var stages: [VerifyStageShard]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let disposeBag = DisposeBag()

    init(stages: [VerifyStageShard]) {
        self.stages = stages
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Verify.hubTitle)
        flexNavBar.onBack = { [weak self] in self?.confirmReturn() }
        tableView.backgroundColor = FlexPalette.canvasGray
        tableView.separatorStyle = .none
        tableView.rowHeight = 64
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(VerifyStageCell.self, forCellReuseIdentifier: VerifyStageCell.reuseId)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStages()
    }

    private func refreshStages() {
        MintHubStore.shared.loadVerifyStages()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] list in
                self?.stages = list
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }

    private func confirmReturn() {
        FlexConfirmSheet.present(on: self,
                                 title: FlexPhraseBook.Verify.returnConfirmTitle,
                                 message: FlexPhraseBook.Verify.returnConfirmBody,
                                 art: FlexSliceCatalog.dialogBackGlyph,
                                 presentation: .card) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func stageMeta(for kind: String) -> VerifyStageShard? {
        stages.first { $0.stageKind == kind }
    }
}

extension VerifyGateCanvas: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        VerifyRoute.ordered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VerifyStageCell.reuseId, for: indexPath) as! VerifyStageCell
        let route = VerifyRoute.ordered[indexPath.row]
        let stage = stageMeta(for: route.kind)
        cell.apply(title: route.title, art: FlexSliceCatalog.kycStageArt(for: route.kind),
                   completed: VerifyRoute.isComplete(stage))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let route = VerifyRoute.ordered[indexPath.row]
        let stage = stageMeta(for: route.kind)
        let canvas = route.factory()
        canvas.configure(stageId: stage?.stageId, stageKind: route.kind, title: route.title, stages: stages)
        navigationController?.pushViewController(canvas, animated: true)
    }
}

// MARK: - Base step

class VerifyFormCanvas: FlexBaseCanvas {
    private(set) var stageKind = ""
    private var stageId: String?
    private var stagesSnapshot: [VerifyStageShard] = []
    fileprivate var stagePilot: VerifyStagePilot?
    private let disposeBag = DisposeBag()

    var fieldMap: [String: FlexBoundedField] = [:]
    fileprivate var selectValues: [String: String] = [:]
    fileprivate var selectLabelViews: [String: UILabel] = [:]
    fileprivate var selectTitleViews: [String: UILabel] = [:]
    private var valueSlots: [VerifyValueSlot] = []
    fileprivate var ifscFieldCode: String?
    fileprivate var ifscField: FlexBoundedField?
    /// Kiva parity: `dictData["bankCode"]` — survives pop/layout and drives display + submit.
    fileprivate var storedBankCode: String?
    private var pendingIFSCCode: String?
    private var lastWhatsAppError: (value: String, time: TimeInterval)?

    private let scrollView = UIScrollView()
    let stack = UIStackView()
    fileprivate let continueButton = FlexPrimaryButton()
    fileprivate let secondaryButton = FlexLedgerWidgets.makeOutlineButton(title: "")
    private let actionBar = UIView()
    private var pageTitle = FlexPhraseBook.Verify.hubTitle
    private(set) var entrySource: VerifyEntrySource = .hub

    func configure(stageId: String?,
                   stageKind: String,
                   title: String,
                   stages: [VerifyStageShard] = [],
                   entrySource: VerifyEntrySource = .hub) {
        self.stageId = stageId
        self.stageKind = stageKind
        self.pageTitle = title
        self.stagesSnapshot = stages
        self.entrySource = entrySource
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FlexPalette.canvasGray
        embedNavStripIfNeeded(showBack: true, title: pageTitle)
        flexNavBar.onBack = { [weak self] in self?.confirmReturn() }

        scrollView.showsVerticalScrollIndicator = false
        stack.axis = .vertical
        stack.spacing = 16

        continueButton.setTitle(FlexPhraseBook.Verify.continueAction, for: .normal)
        continueButton.titleLabel?.font = FlexTypography.bold(18)
        continueButton.flexRoundCorners(12)
        secondaryButton.titleLabel?.font = FlexTypography.bold(18)
        secondaryButton.flexRoundCorners(12)
        secondaryButton.isHidden = true

        view.addSubview(scrollView)
        view.addSubview(actionBar)
        actionBar.addSubview(secondaryButton)
        actionBar.addSubview(continueButton)
        scrollView.addSubview(stack)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionBar.snp.top).offset(-16)
        }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-16 * 2)
        }
        actionBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.height.equalTo(58)
        }
        continueButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        continueButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        buildStaticFieldsIfNeeded()
        bindStagePilot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshIFSCDisplay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshIFSCDisplay()
    }

    func configureSingleAction(title: String) {
        secondaryButton.isHidden = true
        continueButton.setTitle(title, for: .normal)
        guard continueButton.superview != nil else { return }
        continueButton.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configureDualAction(primary: String, secondary: String, secondaryAction: Selector) {
        secondaryButton.isHidden = false
        continueButton.setTitle(primary, for: .normal)
        secondaryButton.setTitle(secondary, for: .normal)
        secondaryButton.removeTarget(nil, action: nil, for: .allEvents)
        secondaryButton.addTarget(self, action: secondaryAction, for: .touchUpInside)
        guard continueButton.superview != nil, secondaryButton.superview != nil else { return }
        secondaryButton.snp.remakeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.48)
        }
        continueButton.snp.remakeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.48)
        }
    }

    func buildStaticFieldsIfNeeded() {}

    private func confirmReturn() {
        FlexConfirmSheet.present(on: self,
                                 title: FlexPhraseBook.Verify.returnConfirmTitle,
                                 message: FlexPhraseBook.Verify.returnConfirmBody,
                                 art: FlexSliceCatalog.dialogBackGlyph,
                                 presentation: .card) { [weak self] in
            guard let self else { return }
            VerifyRoute.abandonFlow(from: self)
        }
    }

    private func bindStagePilot() {
        guard let sid = stageId, !sid.isEmpty else { return }
        let pilot = VerifyStagePilot(stageKind: stageKind)
        stagePilot = pilot
        pilot.bootstrap(stageId: sid)
        pilot.fields.stream
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] fields in
                self?.layoutDynamicFields(fields)
            }).disposed(by: disposeBag)
        pilot.toastSignal.stream.subscribe(onNext: { FlexToast.show($0) }).disposed(by: disposeBag)
        pilot.completed.stream.subscribe(onNext: { [weak self] in
            self?.handleStageCompleted()
        }).disposed(by: disposeBag)
        pilot.documentUnclear.stream.subscribe(onNext: { [weak self] in
            self?.presentDocumentUnclearSheet()
        }).disposed(by: disposeBag)
    }

    /// Override on Aadhaar / PAN to clear photos after Confirm.
    func clearDocumentsAfterUnclearError() {}

    private func presentDocumentUnclearSheet() {
        FlexUploadErrorSheet.present(on: self) { [weak self] in
            self?.clearDocumentsAfterUnclearError()
        }
    }

    func layoutDynamicFields(_ fields: [VerifyFieldShard]) {
        renderDynamicFields(fields)
    }

    func renderDynamicFields(_ fields: [VerifyFieldShard]) {
        fields.forEach { shard in
            let code = shard.fieldCode ?? UUID().uuidString
            guard fieldMap[code] == nil, selectValues[code] == nil else { return }
            if shard.fieldKind == 3, !shard.options.isEmpty {
                addSelectField(shard: shard, code: code)
            } else {
                addTextField(shard: shard, code: code)
            }
        }
        syncIFSCDisplay()
    }

    fileprivate func addTextField(shard: VerifyFieldShard, code: String) {
        let field = FlexBoundedField()
        field.placeholder = FlexPhraseBook.Verify.pleaseEnter
        let isBankCodeField = Self.isBankCodeField(code)
        let requiresInput = shard.requiresInput && code != "credit_card"
        applyRules(field, shard: shard, code: code)
        fieldMap[code] = field
        let row: UIView
        if isBankCodeField {
            row = FlexVerifyWidgets.makeIFSCLabeledField(label: shard.fieldLabel ?? code, field: field) { [weak self] in
                self?.openIFSCSearch(fieldCode: code)
            }
        } else {
            let label = code == "credit_card"
                ? "\(shard.fieldLabel ?? code) (\(FlexPhraseBook.Verify.creditCardOptional))"
                : (shard.fieldLabel ?? code)
            row = FlexVerifyWidgets.makeLabeledField(label: label, field: field)
        }
        stack.addArrangedSubview(row)
        registerSlot(code: code, mandatory: requiresInput, reader: {
            field.text ?? ""
        }) { [weak self] in
            let value = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if code.lowercased() == "whatsapp" {
                return self?.validateWhatsApp(value) ?? false
            }
            if isBankCodeField {
                let hint = value.isEmpty ? FlexPhraseBook.Verify.ifscEmpty : FlexPhraseBook.Verify.ifscInvalid
                guard RupeeInputGuard.matchesIFSC(value) else {
                    FlexToast.show(hint)
                    PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: hint)
                    return false
                }
                return true
            }
            if requiresInput, value.isEmpty {
                let hint = String(format: FlexPhraseBook.Verify.fieldEmptyFormat, shard.fieldLabel ?? code)
                FlexToast.show(hint)
                PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: hint)
                return false
            }
            if value.isEmpty, !requiresInput { return true }
            return field.validateSilently()
        }
    }

    private static func isBankCodeField(_ code: String) -> Bool {
        let lower = code.lowercased()
        return lower == "ifsc" || lower == "bankcode" || lower == "bank_code"
    }

    private func validateWhatsApp(_ value: String) -> Bool {
        let hint: String
        if value.isEmpty {
            hint = FlexPhraseBook.Verify.whatsappEmpty
        } else if !RupeeInputGuard.matchesIndiaMobile(value) {
            hint = FlexPhraseBook.Verify.whatsappInvalid
        } else {
            lastWhatsAppError = nil
            return true
        }
        let now = Date().timeIntervalSince1970
        if let previous = lastWhatsAppError,
           previous.value == value,
           now - previous.time < 0.5 {
            return false
        }
        lastWhatsAppError = (value, now)
        FlexToast.show(hint)
        PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: hint)
        return false
    }

    @objc private func whatsappEditingEnded(_ field: FlexBoundedField) {
        _ = validateWhatsApp(field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    private func addSelectField(shard: VerifyFieldShard, code: String) {
        let (row, valueLabel) = FlexVerifyWidgets.makeSelectRow(label: shard.fieldLabel ?? code, valueText: nil) { [weak self] in
            self?.presentSelectOptions(for: shard, code: code)
        }
        selectLabelViews[code] = valueLabel
        stack.addArrangedSubview(row)
        registerSlot(code: code, mandatory: shard.requiresInput, reader: { [weak self] in
            self?.selectValues[code] ?? ""
        }) { [weak self] in
            guard let self else { return false }
            let value = self.selectValues[code] ?? ""
            if shard.requiresInput, value.trimmingCharacters(in: .whitespaces).isEmpty {
                let hint = String(format: FlexPhraseBook.Verify.selectRequiredFormat, shard.fieldLabel ?? code)
                FlexToast.show(hint)
                PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: hint)
                return false
            }
            return true
        }
    }

    fileprivate func presentSelectOptions(for shard: VerifyFieldShard, code: String) {
        let options = shard.options.sorted { ($0.optionSort ?? 0) < ($1.optionSort ?? 0) }
        let labels = options.compactMap { $0.optionLabel }
        guard !labels.isEmpty else { return }
        if code.hasSuffix("_relation") {
            let contactIndex: String
            if code.hasPrefix("first") { contactIndex = "1" }
            else if code.hasPrefix("second") { contactIndex = "2" }
            else if code.hasPrefix("third") { contactIndex = "3" }
            else { contactIndex = "NULL" }
            PulseBeaconRecorder.shared.stamp(.verifyEmergencyPick, note: contactIndex)
        }
        let currentKey = selectValues[code] ?? ""
        let selectedIndex = options.firstIndex { $0.optionKey == currentKey } ?? 0
        FlexLedgerPickerSheet.present(on: self,
                                      title: shard.fieldLabel ?? FlexPhraseBook.Verify.pleaseChoose,
                                      options: labels,
                                      selectedIndex: selectedIndex) { [weak self] index in
            guard let self, options.indices.contains(index) else { return }
            let option = options[index]
            self.selectValues[code] = option.optionKey ?? ""
            if let titleLabel = self.selectTitleViews[code], let valueLabel = self.selectLabelViews[code] {
                FlexVerifyWidgets.applyContactRelationSelection(
                    titleLabel: titleLabel,
                    valueLabel: valueLabel,
                    titleText: shard.fieldLabel ?? "Relationship",
                    selectedText: option.optionLabel
                )
            } else {
                self.selectLabelViews[code]?.text = option.optionLabel
                self.selectLabelViews[code]?.textColor = FlexPalette.inkPrimary
            }
        }
    }

    private struct VerifyValueSlot {
        let code: String
        let mandatory: Bool
        let reader: () -> String
        let validate: () -> Bool
    }

    fileprivate func registerSlot(code: String, mandatory: Bool, reader: @escaping () -> String, validate: @escaping () -> Bool) {
        valueSlots.append(VerifyValueSlot(code: code, mandatory: mandatory, reader: reader, validate: validate))
    }

    func applyRules(_ field: FlexBoundedField, shard: VerifyFieldShard, code: String) {
        field.invalidHint = String(format: FlexPhraseBook.Verify.fieldInvalidFormat, shard.fieldLabel ?? code)
        switch code {
        case "whatsapp":
            field.inputMode = .digits(max: RupeeFieldLimit.whatsapp)
            field.keyboardType = .numberPad
            field.validationRule = { RupeeInputGuard.matchesIndiaMobile($0) }
            field.invalidHint = FlexPhraseBook.Verify.whatsappInvalid
            field.addTarget(self, action: #selector(whatsappEditingEnded(_:)), for: .editingDidEnd)
        case "account_phone", "first_phone", "second_phone", "third_phone":
            field.inputMode = .digits(max: RupeeFieldLimit.whatsapp)
            field.keyboardType = .numberPad
            field.validationRule = { RupeeInputGuard.matchesIndiaMobile($0) }
            field.invalidHint = FlexPhraseBook.Verify.contactPhoneInvalid
        case "child_count":
            field.inputMode = .digits(max: RupeeFieldLimit.childCount)
            field.keyboardType = .numberPad
        case "ifsc", "bankCode", "bank_code":
            field.inputMode = .uppercased(max: RupeeFieldLimit.ifsc)
            field.validationRule = { RupeeInputGuard.matchesIFSC($0) }
            field.invalidHint = FlexPhraseBook.Verify.ifscInvalid
            attachIFSCSearch(to: field, code: code)
            field.addTarget(self, action: #selector(ifscEdited(_:)), for: .editingChanged)
        case "account_no", "account_no_verify":
            field.inputMode = .digits(max: RupeeFieldLimit.accountNo)
            field.keyboardType = .numberPad
        case "credit_card":
            field.inputMode = .digits(max: RupeeFieldLimit.creditCard)
            field.keyboardType = .numberPad
        case "email":
            field.inputMode = .plain(max: RupeeFieldLimit.email)
            field.keyboardType = .emailAddress
            field.validationRule = { RupeeInputGuard.matchesEmail($0) }
            field.invalidHint = FlexPhraseBook.Verify.emailInvalid
        case "card_no", "tax_card_no":
            if stageKind == "tax" {
                field.inputMode = .uppercased(max: RupeeFieldLimit.pan)
                field.validationRule = { RupeeInputGuard.matchesPAN($0) }
            } else {
                field.inputMode = .digits(max: RupeeFieldLimit.aadhaar)
                field.validationRule = { RupeeInputGuard.matchesAadhaar($0) }
            }
        default:
            field.inputMode = .plain(max: 64)
        }
        if let pattern = shard.patternRule, !pattern.isEmpty {
            field.validationRule = { RupeeInputGuard.matchesServerRule(pattern, text: $0) }
        }
    }

    private func attachIFSCSearch(to field: FlexBoundedField, code: String) {
        ifscFieldCode = code
        ifscField = field
        field.placeholder = FlexPhraseBook.Verify.ifscPlaceholder
    }

    @objc private func ifscEdited(_ field: FlexBoundedField) {
        storedBankCode = field.text ?? ""
        didEditIFSC(storedBankCode ?? "")
    }

    func didEditIFSC(_ code: String) {}

    fileprivate func openIFSCSearch(fieldCode: String) {
        let canvas = VerifyIFSCCanvas()
        canvas.selectionHost = self
        canvas.returnHost = self
        canvas.onSelectIFSC = { [weak self] value in
            self?.applyIFSCSelection(value, fieldCode: fieldCode, clearRelatedFields: true)
        }
        navigationController?.pushViewController(canvas, animated: true)
    }

    /// Echo IFSC from Find IFSC flow back into the bank form.
    func applyIFSCSelection(_ code: String, fieldCode: String? = nil, clearRelatedFields: Bool = false) {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !value.isEmpty else { return }
        let changed = value != storedBankCode
        storedBankCode = value
        pendingIFSCCode = value
        if let key = fieldCode ?? ifscFieldCode, ifscFieldCode == nil {
            ifscFieldCode = key
        }
        print("[IFSC] applyIFSCSelection value=\(value) fieldCode=\(ifscFieldCode ?? "nil") fieldMapKeys=\(fieldMap.keys.sorted())")
        syncIFSCDisplay()
        if clearRelatedFields && changed {
            clearAccountFieldsAfterIFSCChange()
        }
    }

    func refreshIFSCDisplay() {
        syncIFSCDisplay()
    }

    private func syncIFSCDisplay() {
        guard let value = storedBankCode ?? pendingIFSCCode, !value.isEmpty else { return }
        let apply = { [weak self] in
            guard let self else { return }
            if self.writeIFSC(value, preferredKey: self.ifscFieldCode) {
                self.pendingIFSCCode = nil
                print("[IFSC] syncIFSCDisplay displayed=\(self.resolveIFSCField()?.text ?? "") stored=\(value)")
            } else {
                print("[IFSC] syncIFSCDisplay pending=\(value) — field not ready")
            }
            self.scrollView.setNeedsLayout()
            self.scrollView.layoutIfNeeded()
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func flushPendingIFSCSelection() {
        syncIFSCDisplay()
    }

    @discardableResult
    fileprivate func writeIFSC(_ value: String, preferredKey: String?) -> Bool {
        if let field = ifscField {
            field.echoText(value)
            print("[IFSC] wrote to ifscField displayed=\(field.text ?? "")")
            return true
        }
        if let key = preferredKey, let field = fieldMap[key] {
            ifscField = field
            field.echoText(value)
            print("[IFSC] wrote to fieldMap[\(key)] displayed=\(field.text ?? "")")
            return true
        }
        if let field = resolveIFSCField() {
            ifscField = field
            field.echoText(value)
            print("[IFSC] wrote via resolveIFSCField displayed=\(field.text ?? "")")
            return true
        }
        return false
    }

    private func clearAccountFieldsAfterIFSCChange() {
        fieldMap["account_no"]?.text = ""
        fieldMap["account_no_verify"]?.text = ""
    }

    fileprivate func resolveIFSCField() -> FlexBoundedField? {
        if let ifscField { return ifscField }
        if let key = ifscFieldCode, let field = fieldMap[key] { return field }
        for key in ["ifsc", "bankCode", "bank_code"] {
            if let field = fieldMap[key] { return field }
        }
        return fieldMap.first { $0.key.lowercased().contains("ifsc") || $0.key.lowercased().contains("bankcode") }?.value
    }

    @objc func submitTapped() {
        if stageKind == "pay_account" {
            let account = fieldMap["account_no"]?.text ?? ""
            let confirm = fieldMap["account_no_verify"]?.text ?? ""
            if !account.isEmpty, !confirm.isEmpty, account != confirm {
                FlexToast.show(FlexPhraseBook.Verify.accountMismatch)
                PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.accountMismatch)
                return
            }
        }

        for slot in valueSlots where !slot.validate() { return }

        var values: [String: String] = [:]
        valueSlots.forEach { values[$0.code] = $0.reader() }
        fieldMap.forEach { values[$0.key] = $0.value.text ?? "" }

        if let pilot = stagePilot {
            pilot.submit(values: values)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func ensureStagePilot() {
        guard stagePilot == nil, let sid = stageId, !sid.isEmpty else { return }
        bindStagePilot()
    }

    private func handleStageCompleted() {
        MintHubStore.shared.loadVerifyStages()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] stages in
                guard let self else { return }
                self.stagesSnapshot = stages
                VerifyRoute.chainNext(from: self, completedKind: self.stageKind, stages: stages)
            }, onError: { [weak self] _ in
                guard let self else { return }
                VerifyRoute.abandonFlow(from: self)
            })
            .disposed(by: disposeBag)
    }

    func collectValues() -> [String: String] {
        var values: [String: String] = [:]
        valueSlots.forEach { values[$0.code] = $0.reader() }
        fieldMap.forEach { values[$0.key] = $0.value.text ?? "" }
        return values
    }

    func fieldsAreValid() -> Bool {
        for slot in valueSlots where !slot.validate() { return false }
        return true
    }
}

// MARK: - Form steps

final class VerifyPersonalCanvas: VerifyFormCanvas {}
final class VerifyWorkCanvas: VerifyFormCanvas {}
final class VerifyCreditCanvas: VerifyFormCanvas {}

class VerifyBankCanvas: VerifyFormCanvas {
    private let disposeBag = DisposeBag()

    override func buildStaticFieldsIfNeeded() {
        stack.addArrangedSubview(FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Verify.bankAccountHint))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.setTitle(FlexPhraseBook.Verify.submitAction, for: .normal)
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {
        super.layoutDynamicFields(fields)
        CofferProfileStore.shared.loadProfile()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] profile in
                guard let field = self?.fieldMap["account_name"],
                      (field.text ?? "").isEmpty,
                      let name = profile.displayName, !name.isEmpty else { return }
                field.text = name
                field.isUserInteractionEnabled = false
                field.textColor = FlexPalette.inkSecondary
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Bank edit (Me → Bank account)

final class VaultEditCardCanvas: VerifyBankCanvas {
    var onUpdated: (() -> Void)?
    private let editBag = DisposeBag()
    private var didLoadCardDraft = false
    /// Kiva `dictData` — single source of truth for edit-bank defaults + IFSC echo.
    private var cardDraft: [String: String] = [
        "accountType": "debit_card",
        "bankCode": "",
        "accountNo": "",
        "accountNoVerify": "",
        "creditCard": ""
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
        configure(stageId: "pay_account", stageKind: "pay_account", title: FlexPhraseBook.Ledger.changeBank)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        flexNavBar.onBack = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    override func didEditIFSC(_ code: String) {
        cardDraft["bankCode"] = code
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {
        super.layoutDynamicFields(fields)
        applyCardDraftToFields()
        guard !didLoadCardDraft else { return }
        didLoadCardDraft = true
        CofferProfileStore.shared.loadCards()
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] cards in
                guard let self, let card = cards.first else { return }
                self.cardDraft["bankCode"] = card.bankCode ?? ""
                self.cardDraft["accountNo"] = card.accountMask ?? ""
                self.cardDraft["accountNoVerify"] = card.accountMask ?? ""
                self.cardDraft["creditCard"] = card.creditCard ?? ""
                if let type = card.accountType, !type.isEmpty {
                    self.cardDraft["accountType"] = type
                }
                self.applyCardDraftToFields()
            })
            .disposed(by: editBag)
    }

    override func applyIFSCSelection(_ code: String, fieldCode: String? = nil, clearRelatedFields: Bool = false) {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !value.isEmpty else { return }
        let changed = value != cardDraft["bankCode"]?.uppercased()
        cardDraft["bankCode"] = value
        if clearRelatedFields && changed {
            cardDraft["accountNo"] = ""
            cardDraft["accountNoVerify"] = ""
        }
        super.applyIFSCSelection(value, fieldCode: fieldCode, clearRelatedFields: clearRelatedFields)
        applyCardDraftToFields()
    }

    override func refreshIFSCDisplay() {
        applyCardDraftToFields()
    }

    private func applyCardDraftToFields() {
        let bankCode = (cardDraft["bankCode"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !bankCode.isEmpty {
            storedBankCode = bankCode
            _ = writeIFSC(bankCode, preferredKey: ifscFieldCode ?? "ifsc")
        }
        if let account = cardDraft["accountNo"], !account.isEmpty {
            fieldMap["account_no"]?.echoText(account)
            fieldMap["account_no_verify"]?.echoText(cardDraft["accountNoVerify"] ?? account)
        }
        if let pan = cardDraft["creditCard"], !pan.isEmpty {
            fieldMap["credit_card"]?.echoText(pan)
        }
        if let type = cardDraft["accountType"], !type.isEmpty {
            selectValues["account_type"] = type
            selectLabelViews["account_type"]?.text = type
            selectLabelViews["account_type"]?.textColor = FlexPalette.inkPrimary
        }
        print("[IFSC] applyCardDraft bankCode=\(bankCode) fieldText=\(resolveIFSCField()?.text ?? "nil")")
    }

    @objc override func submitTapped() {
        let account = fieldMap["account_no"]?.text ?? ""
        let confirm = fieldMap["account_no_verify"]?.text ?? ""
        if !account.isEmpty, !confirm.isEmpty, account != confirm {
            FlexToast.show(FlexPhraseBook.Verify.accountMismatch)
            return
        }

        guard fieldsAreValid() else { return }

        let values = collectValues()
        let bankCode = resolveIFSCField()?.text ?? values["ifsc"] ?? values["bankCode"] ?? ""
        let payload: [String: Any] = [
            "accountType": cardDraft["accountType"] ?? values["account_type"] ?? "debit_card",
            "bankCode": bankCode,
            "accountNo": values["account_no"] ?? "",
            "accountNoVerify": values["account_no_verify"] ?? "",
            "creditCard": values["credit_card"] ?? ""
        ]
        continueButton.isEnabled = false
        CofferProfileStore.shared.editCard(payload: payload)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                self.continueButton.isEnabled = true
                self.onUpdated?()
                self.navigationController?.popViewController(animated: true)
            }, onError: { [weak self] error in
                self?.continueButton.isEnabled = true
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy)
            })
            .disposed(by: editBag)
    }
}

// MARK: - Face

final class VerifyFaceCanvas: VerifyFormCanvas {
    private enum Phase { case intro, shooting, review }

    private let cameraView = UIView()
    private let introArt = UIImageView()
    private let snapshotView = UIImageView()
    private let instructionWrap = UIStackView()
    private let cameraSession = FlexFaceCameraSession()
    private var faceImage: UIImage?
    private var phase: Phase = .intro
    private var isCapturing = false
    private var awaitingSettingsGrant = false
    private var hasStampedCameraGranted = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraSession.layoutPreview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            cameraSession.tearDown()
        } else {
            cameraSession.stop()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if awaitingSettingsGrant,
           AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            awaitingSettingsGrant = false
            stampCameraGrantedIfNeeded()
        }
        if phase == .shooting {
            cameraSession.start()
        }
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {}

    override func buildStaticFieldsIfNeeded() {
        introArt.image = FlexSlice.slice(FlexSliceCatalog.kycFacePrism)?.withRenderingMode(.alwaysOriginal)
        introArt.contentMode = .scaleAspectFit
        introArt.clipsToBounds = true

        let host = FlexVerifyWidgets.makeFaceCameraHost(cameraView: cameraView, snapshot: snapshotView)
        cameraView.addSubview(introArt)
        introArt.snp.makeConstraints { $0.edges.equalToSuperview() }
        stack.addArrangedSubview(host)

        let (instruction, instructionHi) = FlexVerifyWidgets.makeInstructionBlock()
        instructionWrap.axis = .vertical
        instructionWrap.spacing = 8
        instructionWrap.addArrangedSubview(instruction)
        instructionWrap.addArrangedSubview(instructionHi)
        stack.addArrangedSubview(instructionWrap)

        applyIntroUI()
    }

    @objc override func submitTapped() {
        switch phase {
        case .intro:
            PulseBeaconRecorder.shared.stamp(.verifyFaceStart)
            beginShootingIfAllowed()
        case .shooting:
            takePhoto()
        case .review:
            guard let image = faceImage else { return }
            continueButton.isEnabled = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let base64 = FlexImageCodec.livenessBase64(from: image)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.continueButton.isEnabled = true
                    guard let base64, !base64.isEmpty else {
                        FlexToast.show(FlexPhraseBook.Verify.imageUploadFailed, on: self.view)
                        return
                    }
                    self.ensureStagePilot()
                    self.stagePilot?.submitLiveness(imageBase64: base64)
                }
            }
        }
    }

    @objc private func restartFace() {
        faceImage = nil
        snapshotView.image = nil
        snapshotView.isHidden = true
        introArt.isHidden = true
        phase = .shooting
        configureSingleAction(title: FlexPhraseBook.Verify.takePhoto)
        cameraSession.start()
    }

    private func applyIntroUI() {
        phase = .intro
        faceImage = nil
        introArt.isHidden = false
        snapshotView.isHidden = true
        snapshotView.image = nil
        configureSingleAction(title: FlexPhraseBook.Verify.startAction)
    }

    private func beginShootingIfAllowed() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            stampCameraGrantedIfNeeded()
            enterShooting()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.stampCameraGrantedIfNeeded()
                        self?.enterShooting()
                    } else {
                        PulseBeaconRecorder.shared.stamp(.cameraDenied)
                    }
                }
            }
        default:
            PulseBeaconRecorder.shared.stamp(.cameraDenied)
            presentCameraSettings()
        }
    }

    private func stampCameraGrantedIfNeeded() {
        guard !hasStampedCameraGranted else { return }
        hasStampedCameraGranted = true
        PulseBeaconRecorder.shared.stamp(.cameraGranted)
    }

    private func enterShooting() {
        phase = .shooting
        introArt.isHidden = true
        snapshotView.isHidden = true
        configureSingleAction(title: FlexPhraseBook.Verify.takePhoto)
        cameraSession.attach(to: cameraView)
        view.layoutIfNeeded()
        cameraSession.layoutPreview()
        cameraSession.start { [weak self] ok in
            if !ok {
                FlexToast.show(FlexPhraseBook.Capture.unavailable, on: self?.view)
                self?.applyIntroUI()
            }
        }
    }

    private func takePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        cameraSession.capturePhoto { [weak self] image in
            guard let self else { return }
            self.isCapturing = false
            guard let image else {
                FlexToast.show(FlexPhraseBook.Capture.unavailable, on: self.view)
                return
            }
            PulseBeaconRecorder.shared.stamp(.verifyFaceCapture)
            self.faceImage = image
            self.snapshotView.image = image
            self.snapshotView.isHidden = false
            self.phase = .review
            self.cameraSession.stop()
            self.configureDualAction(primary: FlexPhraseBook.Verify.continueAction,
                                     secondary: FlexPhraseBook.Verify.restart,
                                     secondaryAction: #selector(self.restartFace))
        }
    }

    private func presentCameraSettings() {
        FlexPermissionSheet.present(on: self, kind: .camera,
                                    onConfirm: { [weak self] in
            self?.awaitingSettingsGrant = true
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }, onCancel: nil)
    }
}

// MARK: - Aadhaar

final class VerifyAadhaarCanvas: VerifyFormCanvas {
    private var captureCoordinator: FlexCaptureCoordinator?
    private lazy var frontSlot = FlexDocUploadSlot(caption: FlexPhraseBook.Verify.aadhaarFront)
    private lazy var backSlot = FlexDocUploadSlot(caption: FlexPhraseBook.Verify.aadhaarBack)
    private let numberField = FlexBoundedField()

    override func viewDidLoad() {
        super.viewDidLoad()
        captureCoordinator = FlexCaptureCoordinator(host: self)
        numberField.inputMode = .digits(max: RupeeFieldLimit.aadhaar)
        numberField.keyboardType = .numberPad
        numberField.placeholder = FlexPhraseBook.Verify.pleaseEnter
        numberField.validationRule = { RupeeInputGuard.matchesAadhaar($0) }
        numberField.invalidHint = FlexPhraseBook.Verify.aadhaarInvalid
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {}

    override func buildStaticFieldsIfNeeded() {
        frontSlot.onTap = { [weak self] in self?.capture(side: .front) }
        frontSlot.onRemove = { [weak self] in self?.clear(side: .front) }
        backSlot.onTap = { [weak self] in self?.capture(side: .back) }
        backSlot.onRemove = { [weak self] in self?.clear(side: .back) }

        stack.addArrangedSubview(FlexVerifyWidgets.makeDualUploadCard(
            title: FlexPhraseBook.Verify.uploadAadhaarTitle,
            frontSlot: frontSlot,
            backSlot: backSlot
        ))
        stack.addArrangedSubview(FlexVerifyWidgets.makeInlineCardField(
            label: FlexPhraseBook.Verify.aadhaarNumber,
            field: numberField
        ))
        stack.addArrangedSubview(FlexVerifyWidgets.makeNumberedTips([
            FlexPhraseBook.Verify.aadhaarTip1,
            FlexPhraseBook.Verify.aadhaarTip2
        ]))
    }

    @objc override func submitTapped() {
        guard frontSlot.hasPhoto else {
            FlexToast.show(FlexPhraseBook.Verify.aadhaarFrontMissing)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.aadhaarFrontMissing)
            return
        }
        guard backSlot.hasPhoto else {
            FlexToast.show(FlexPhraseBook.Verify.aadhaarBackMissing)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.aadhaarBackMissing)
            return
        }
        let cardNumber = RupeeInputGuard.digitsOnly(numberField.text ?? "")
        guard RupeeInputGuard.matchesAadhaar(cardNumber) else {
            FlexToast.show(FlexPhraseBook.Verify.aadhaarInvalid)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.aadhaarInvalid)
            return
        }
        ensureStagePilot()
        stagePilot?.submitSingleField(itemCode: "card_no", value: cardNumber)
    }

    private enum Side { case front, back }

    private func capture(side: Side) {
        // LoanEase fires Front identity beacons for both front and back slots.
        captureCoordinator?.capture(slot: .document, allowLibrary: true, trackIdentityEvents: true) { [weak self] image, _ in
            guard let self else { return }
            FlexSpinnerOverlay.beginRequest(on: self.view)
            // Preview == upload JPEG. Scale + quality OK; proportional only (no crop).
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let payload = FlexImageCodec.documentPayload(from: image)
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let payload else {
                        FlexSpinnerOverlay.endRequest()
                        FlexToast.show(FlexPhraseBook.Verify.imageUploadFailed)
                        return
                    }
                    let code = side == .front ? "identity_front_img" : "identity_back_img"
                    switch side {
                    case .front: self.frontSlot.setPhoto(payload.preview)
                    case .back: self.backSlot.setPhoto(payload.preview)
                    }
                    self.ensureStagePilot()
                    self.stagePilot?.uploadImage(itemCode: code, base64: payload.base64, onCardNo: { [weak self] cardNo in
                        guard let self else { return }
                        if side == .front, let cardNo, !cardNo.isEmpty {
                            self.applyCardNumber(cardNo)
                        }
                    }, onFailure: { [weak self] in
                        self?.clear(side: side)
                    })
                }
            }
        }
    }

    private func clear(side: Side) {
        switch side {
        case .front:
            frontSlot.clear()
            numberField.text = ""
        case .back:
            backSlot.clear()
        }
    }

    private func applyCardNumber(_ raw: String) {
        numberField.text = RupeeInputGuard.digitsOnly(raw)
    }

    override func clearDocumentsAfterUnclearError() {
        clear(side: .front)
        clear(side: .back)
    }
}

// MARK: - PAN

final class VerifyPanCanvas: VerifyFormCanvas {
    private var captureCoordinator: FlexCaptureCoordinator?
    private lazy var panSlot = FlexDocUploadSlot(caption: FlexPhraseBook.Verify.panFront)
    private let numberValueLabel = UILabel()
    private var cardNumber = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        captureCoordinator = FlexCaptureCoordinator(host: self)
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {}

    override func buildStaticFieldsIfNeeded() {
        panSlot.onTap = { [weak self] in self?.openCapture() }
        panSlot.onRemove = { [weak self] in self?.clearPan() }

        stack.addArrangedSubview(FlexVerifyWidgets.makeDocumentUploadCard(
            title: FlexPhraseBook.Verify.uploadPanTitle,
            subtitleHi: FlexPhraseBook.Verify.uploadPanSubtitleHi,
            slot: panSlot,
            slotSubtitleHi: FlexPhraseBook.Verify.panFrontHi
        ))
        stack.addArrangedSubview(FlexVerifyWidgets.makeKeyValueCard(label: FlexPhraseBook.Verify.panNumber,
                                                                    valueLabel: numberValueLabel))
        stack.addArrangedSubview(FlexVerifyWidgets.makeBilingualTipCard(
            english: FlexPhraseBook.Verify.panRetakeTip,
            hindi: FlexPhraseBook.Verify.panRetakeTipHi
        ))
    }

    @objc override func submitTapped() {
        // 40 — click PAN submit (required), before local validation.
        PulseBeaconRecorder.shared.stamp(.verifyPanConfirm)
        guard panSlot.hasPhoto else {
            FlexToast.show(FlexPhraseBook.Verify.panUpload)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.panUpload)
            return
        }
        guard RupeeInputGuard.matchesPAN(cardNumber) else {
            FlexToast.show(FlexPhraseBook.Verify.panInvalid)
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.panInvalid)
            return
        }
        ensureStagePilot()
        stagePilot?.submitSingleField(itemCode: "tax_card_no", value: cardNumber.uppercased())
    }

    private func openCapture() {
        // PAN / tax card bury 41–49 (not Aadhaar 50–57).
        captureCoordinator?.capture(slot: .document, allowLibrary: true, trackPanEvents: true) { [weak self] image, _ in
            guard let self else { return }
            FlexSpinnerOverlay.beginRequest(on: self.view)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let payload = FlexImageCodec.documentPayload(from: image)
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let payload else {
                        FlexSpinnerOverlay.endRequest()
                        FlexToast.show(FlexPhraseBook.Verify.imageUploadFailed)
                        return
                    }
                    self.panSlot.setPhoto(payload.preview)
                    self.ensureStagePilot()
                    self.stagePilot?.uploadImage(itemCode: "tax_card_front_img", base64: payload.base64, onCardNo: { [weak self] cardNo in
                        guard let cardNo, !cardNo.isEmpty else { return }
                        self?.cardNumber = cardNo
                        self?.numberValueLabel.text = RupeeInputGuard.formattedPAN(cardNo)
                    }, onFailure: { [weak self] in
                        self?.clearPan()
                    })
                }
            }
        }
    }

    private func clearPan() {
        panSlot.clear()
        cardNumber = ""
        numberValueLabel.text = "-"
    }

    override func clearDocumentsAfterUnclearError() {
        clearPan()
    }
}

// MARK: - Emergency

final class VerifyEmergencyCanvas: VerifyFormCanvas {
    private let contactPicker = RupeeContactPickerCoordinator()
    private var contactGroups: [EmergencyContactGroup] = []
    private var phonePatterns: [String: String] = [:]
    private var namePatterns: [String: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSingleAction(title: FlexPhraseBook.Verify.applyAction)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Keep Apply — base form defaults to Continue in viewDidLoad.
        continueButton.setTitle(FlexPhraseBook.Verify.applyAction, for: .normal)
    }

    private struct EmergencyContactGroup {
        let prefix: String
        let title: String
        let relationCode: String
        let nameCode: String
        let phoneCode: String
        var relationRow: UIView?
        var nameField: FlexBoundedField?
        var phoneField: FlexBoundedField?
    }

    override func layoutDynamicFields(_ fields: [VerifyFieldShard]) {
        let prefixes = [("first", "Contact 01"), ("second", "Contact 02"), ("third", "Contact 03")]
        contactGroups = prefixes.compactMap { prefix, title in
            guard fields.contains(where: { $0.fieldCode?.hasPrefix(prefix) == true }) else { return nil }
            return EmergencyContactGroup(prefix: prefix,
                                         title: title,
                                         relationCode: "\(prefix)_relation",
                                         nameCode: "\(prefix)_name",
                                         phoneCode: "\(prefix)_phone")
        }

        contactGroups.forEach { group in
            guard let relationShard = fields.first(where: { $0.fieldCode == group.relationCode }) else { return }
            let nameField = FlexBoundedField()
            let phoneField = FlexBoundedField()
            nameField.placeholder = FlexPhraseBook.Verify.pleaseChoose
            phoneField.placeholder = FlexPhraseBook.Verify.pleaseChoose
            phoneField.inputMode = .digits(max: RupeeFieldLimit.contactPhone)
            phoneField.keyboardType = .numberPad
            phoneField.validationRule = { RupeeInputGuard.matchesIndiaMobile($0) }
            phoneField.invalidHint = FlexPhraseBook.Verify.contactPhoneInvalid
            fieldMap[group.nameCode] = nameField
            fieldMap[group.phoneCode] = phoneField
            if let nameShard = fields.first(where: { $0.fieldCode == group.nameCode }),
               let pattern = nameShard.patternRule, !pattern.isEmpty {
                namePatterns[group.nameCode] = pattern
            }
            if let phoneShard = fields.first(where: { $0.fieldCode == group.phoneCode }),
               let pattern = phoneShard.patternRule, !pattern.isEmpty {
                phonePatterns[group.phoneCode] = pattern
                phoneField.validationRule = { RupeeInputGuard.matchesServerRule(pattern, text: $0) }
            }

            var mutable = group
            let relationLabel = relationShard.fieldLabel ?? "Relationship"
            let (relationRow, titleLabel, valueLabel) = FlexVerifyWidgets.makeContactRelationRow(
                title: relationLabel
            ) { [weak self] in
                self?.presentSelectOptions(for: relationShard, code: group.relationCode)
            }
            selectTitleViews[group.relationCode] = titleLabel
            selectLabelViews[group.relationCode] = valueLabel
            mutable.relationRow = relationRow
            mutable.nameField = nameField
            mutable.phoneField = phoneField

            let card = FlexVerifyWidgets.makeContactCard(title: group.title,
                                                         relationRow: relationRow,
                                                         nameField: nameField,
                                                         phoneField: phoneField) { [weak self] in
                self?.pickContact(for: group.nameCode, phoneCode: group.phoneCode,
                                  nameField: nameField, phoneField: phoneField)
            }
            stack.addArrangedSubview(card)
            registerSlot(code: group.relationCode, mandatory: true, reader: { [weak self] in
                self?.selectValues[group.relationCode] ?? ""
            }) { [weak self] in
                guard let value = self?.selectValues[group.relationCode], !value.isEmpty else {
                    FlexToast.show(String(format: FlexPhraseBook.Verify.contactRelationMissing, group.title),
                                   on: self?.view)
                    PulseBeaconRecorder.shared.stamp(.verifyFieldFail,
                                                     note: String(format: FlexPhraseBook.Verify.contactRelationMissing, group.title))
                    return false
                }
                return true
            }
            registerSlot(code: group.nameCode, mandatory: true, reader: { nameField.text ?? "" }) { [weak self] in
                let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if name.isEmpty {
                    FlexToast.show(String(format: FlexPhraseBook.Verify.contactMissing, group.title),
                                   on: self?.view)
                    PulseBeaconRecorder.shared.stamp(.verifyFieldFail,
                                                     note: String(format: FlexPhraseBook.Verify.contactMissing, group.title))
                    return false
                }
                return true
            }
            registerSlot(code: group.phoneCode, mandatory: true, reader: { phoneField.text ?? "" }) {
                phoneField.validateSilently()
            }
        }

        fields.filter { $0.fieldCode == "email" }.forEach { shard in
            addTextField(shard: shard, code: "email")
        }
    }

    @objc override func submitTapped() {
        guard fieldsAreValid() else { return }
        var phones: [String] = []
        for group in contactGroups {
            let phoneRaw = fieldMap[group.phoneCode]?.text ?? ""
            let normalized = RupeeInputGuard.normalizedIndiaMobile(phoneRaw)
            if !RupeeInputGuard.matchesIndiaMobile(normalized) {
                FlexToast.show(FlexPhraseBook.Verify.contactPhoneInvalid, on: view)
                PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.contactPhoneInvalid)
                return
            }
            if phones.contains(normalized) {
                FlexToast.show(FlexPhraseBook.Verify.contactDuplicate, on: view)
                PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: FlexPhraseBook.Verify.contactDuplicate)
                return
            }
            phones.append(normalized)
            fieldMap[group.phoneCode]?.text = normalized
        }
        super.submitTapped()
    }

    private func pickContact(for nameCode: String, phoneCode: String,
                             nameField: FlexBoundedField, phoneField: FlexBoundedField) {
        contactPicker.present(from: self) { [weak self] name, phone in
            // Wait until the address-book sheet has dismissed so toast lands on this page.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.applyPickedContact(name: name,
                                         phone: phone,
                                         nameCode: nameCode,
                                         phoneCode: phoneCode,
                                         nameField: nameField,
                                         phoneField: phoneField)
            }
        }
    }

    /// Validate on this page; never write invalid name/phone into the fields.
    private func applyPickedContact(name: String,
                                    phone: String,
                                    nameCode: String,
                                    phoneCode: String,
                                    nameField: FlexBoundedField,
                                    phoneField: FlexBoundedField) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName.lowercased() == "unnamed" {
            showPickError(FlexPhraseBook.Verify.contactNameEmpty)
            return
        }
        if let pattern = namePatterns[nameCode], !pattern.isEmpty,
           !RupeeInputGuard.matchesServerRule(pattern, text: trimmedName) {
            showPickError(FlexPhraseBook.Verify.contactNameInvalid)
            return
        }

        let digits = RupeeInputGuard.digitsOnly(phone)
        let phoneOK: Bool
        if let pattern = phonePatterns[phoneCode], !pattern.isEmpty {
            phoneOK = RupeeInputGuard.matchesServerRule(pattern, text: digits)
                || RupeeInputGuard.matchesServerRule(pattern, text: RupeeInputGuard.normalizedIndiaMobile(digits))
        } else {
            phoneOK = RupeeInputGuard.matchesIndiaMobile(digits)
        }
        guard phoneOK else {
            showPickError(FlexPhraseBook.Verify.contactPhoneInvalid)
            return
        }

        let normalized = RupeeInputGuard.normalizedIndiaMobile(digits)
        guard RupeeInputGuard.matchesIndiaMobile(normalized) else {
            showPickError(FlexPhraseBook.Verify.contactPhoneInvalid)
            return
        }
        if isDuplicatePhone(normalized, excluding: phoneCode) {
            showPickError(FlexPhraseBook.Verify.contactDuplicate)
            return
        }

        nameField.text = trimmedName
        phoneField.text = normalized
        nameField.textColor = FlexPalette.inkPrimary
        phoneField.textColor = FlexPalette.inkPrimary
        nameField.textAlignment = .left
        phoneField.textAlignment = .left
        fieldMap[nameCode] = nameField
        fieldMap[phoneCode] = phoneField
    }

    private func showPickError(_ message: String) {
        FlexToast.show(message, on: view)
        PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: message)
    }

    /// Same number already used by another contact (Kiva checks on pick).
    private func isDuplicatePhone(_ phone: String, excluding phoneCode: String) -> Bool {
        guard !phone.isEmpty else { return false }
        for group in contactGroups {
            if group.phoneCode == phoneCode { continue }
            let other = RupeeInputGuard.normalizedIndiaMobile(fieldMap[group.phoneCode]?.text ?? "")
            if !other.isEmpty && other == phone { return true }
        }
        return false
    }
}

// MARK: - Hub cell

final class VerifyStageCell: UITableViewCell {
    static let reuseId = "VerifyStageCell"
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevron = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.rowChevronTwine))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let card = UIView()
        FlexTheme.styleCard(card)
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = FlexTypography.medium(15)
        titleLabel.textColor = FlexPalette.inkPrimary
        contentView.addSubview(card)
        card.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16))
        }
        [iconView, titleLabel, chevron].forEach { card.addSubview($0) }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(title: String, art: String, completed: Bool) {
        titleLabel.text = title
        titleLabel.textColor = completed ? FlexPalette.inkSecondary : FlexPalette.inkPrimary
        iconView.image = FlexSlice.slice(art)
        iconView.alpha = completed ? 0.5 : 1
    }
}
