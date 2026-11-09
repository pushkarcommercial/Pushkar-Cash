import UIKit
import SnapKit
import RxSwift

private struct FeedbackAttachment {
    let id = UUID()
    let preview: UIImage
    var remoteURL: String?
    var isUploading = false
}

final class CofferFeedbackCanvas: FlexBaseCanvas {
    private enum Layout {
        static let maxAttachments = 3
        static let slotSpacing: CGFloat = 12
        /// scroll (16×2) + card (16×2)
        static let horizontalInset: CGFloat = 64
        static let minSlotSide: CGFloat = 88
    }

    /// Opened from loan-success — back / submit skip success and land on hub home.
    private let exitToHubHome: Bool

    private var slotRowHeightConstraint: Constraint?
    private var lastResolvedSlotSide: CGFloat = 0

    private let store = MintHubStore.shared
    private let disposeBag = DisposeBag()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let textView = UITextView()
    private let counterLabel = UILabel()
    private let slotRow = UIStackView()
    private let submit = FlexPrimaryButton()
    private var attachments: [FeedbackAttachment] = []
    private var captureCoordinator: FlexCaptureCoordinator?

    init(exitToHubHome: Bool = false) {
        self.exitToHubHome = exitToHubHome
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        embedNavStripIfNeeded(showBack: true, title: FlexPhraseBook.Coffer.feedback)
        if exitToHubHome {
            flexNavBar.onBack = { [weak self] in self?.leave() }
        }
        layoutUI()
        rebuildUploadRow()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if exitToHubHome {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func leave() {
        if exitToHubHome {
            NotificationCenter.default.post(name: .flexHubNeedsRefresh, object: nil)
            FlexRootOrchestrator.shared.returnToHubHome()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func layoutUI() {
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.addArrangedSubview(FlexCofferWidgets.makeHintBanner(FlexPhraseBook.Coffer.feedbackHint))

        let questionCard = FlexCofferWidgets.makeWhiteCard()
        let questionTitle = FlexCofferWidgets.makeFieldCaption(FlexPhraseBook.Coffer.feedbackQuestion)
        let inputWrap = UIView()
        inputWrap.backgroundColor = FlexPalette.bannerGray
        inputWrap.flexRoundCorners(12)
        textView.backgroundColor = .clear
        textView.font = FlexTypography.regular(15)
        textView.textColor = FlexPalette.inkPrimary
        textView.delegate = self
        counterLabel.font = FlexTypography.regular(12)
        counterLabel.textColor = FlexPalette.inkTertiary
        counterLabel.text = "0/\(RupeeFieldLimit.feedback)"
        counterLabel.textAlignment = .right
        inputWrap.addSubview(textView)
        inputWrap.addSubview(counterLabel)
        questionCard.addSubview(questionTitle)
        questionCard.addSubview(inputWrap)
        questionTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        inputWrap.snp.makeConstraints { make in
            make.top.equalTo(questionTitle.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(148)
        }
        textView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(counterLabel.snp.top).offset(-6)
        }
        counterLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(12)
        }
        contentStack.addArrangedSubview(questionCard)

        let uploadCard = FlexCofferWidgets.makeWhiteCard()
        let uploadTitle = FlexCofferWidgets.makeFieldCaption(FlexPhraseBook.Coffer.feedbackUpload)
        slotRow.axis = .horizontal
        slotRow.spacing = Layout.slotSpacing
        slotRow.alignment = .top
        slotRow.distribution = .fill
        uploadCard.addSubview(uploadTitle)
        uploadCard.addSubview(slotRow)
        uploadTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        slotRow.snp.makeConstraints { make in
            make.top.equalTo(uploadTitle.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            slotRowHeightConstraint = make.height.equalTo(resolvedSlotSide()).constraint
        }
        contentStack.addArrangedSubview(uploadCard)

        submit.setTitle(FlexPhraseBook.EMI.submit, for: .normal)
        submit.addTarget(self, action: #selector(submitFeedback), for: .touchUpInside)

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(submit)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(contentTopAnchor()).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(submit.snp.top).offset(-16)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
            make.width.equalTo(scrollView).offset(-32)
        }
        submit.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(54)
        }

        let placeholder = FlexPhraseBook.Coffer.feedbackPlaceholder
        textView.text = placeholder
        textView.textColor = FlexPalette.inkPlaceholder
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = resolvedSlotSide()
        guard abs(side - lastResolvedSlotSide) > 0.5 else { return }
        lastResolvedSlotSide = side
        rebuildUploadRow()
    }

    /// Square side length for each horizontal slot — always based on a 3-column row.
    private func resolvedSlotSide() -> CGFloat {
        let width = max(view.bounds.width, UIScreen.main.bounds.width) - Layout.horizontalInset
        let gaps = Layout.slotSpacing * CGFloat(Layout.maxAttachments - 1)
        return max(Layout.minSlotSide, floor((width - gaps) / CGFloat(Layout.maxAttachments)))
    }

    private func rebuildUploadRow() {
        slotRow.arrangedSubviews.forEach { view in
            slotRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let side = resolvedSlotSide()
        lastResolvedSlotSide = side
        slotRowHeightConstraint?.update(offset: side)

        if attachments.count < Layout.maxAttachments {
            slotRow.addArrangedSubview(makeUploadSlot(side: side) { [weak self] in self?.pickImage() })
        }

        attachments.forEach { attachment in
            let slot = makeUploadSlot(side: side)
            slot.showPreview(attachment.preview, uploading: attachment.isUploading)
            slot.onRemove = { [weak self] in self?.removeAttachment(id: attachment.id) }
            slotRow.addArrangedSubview(slot)
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        slotRow.addArrangedSubview(spacer)
    }

    private func makeUploadSlot(side: CGFloat, onTap: (() -> Void)? = nil) -> FeedbackUploadSlot {
        let slot = FeedbackUploadSlot()
        slot.onTap = onTap
        slot.snp.makeConstraints { make in
            make.width.height.equalTo(side)
        }
        return slot
    }

    private func pickImage() {
        guard attachments.count < Layout.maxAttachments else { return }
        captureCoordinator = FlexCaptureCoordinator(host: self)
        captureCoordinator?.capture(slot: .document, libraryOnly: true) { [weak self] image, _ in
            self?.handlePickedImage(image)
        } onDenied: {}
    }

    private func handlePickedImage(_ image: UIImage) {
        guard attachments.count < Layout.maxAttachments else { return }
        guard let jpeg = FlexImageCodec.jpegData(from: image) else {
            FlexToast.show(FlexPhraseBook.Coffer.feedbackUploadFailed)
            return
        }
        let preview = UIImage(data: jpeg) ?? image
        attachments.append(FeedbackAttachment(preview: preview, remoteURL: nil, isUploading: true))
        rebuildUploadRow()
        uploadAttachment(id: attachments.last!.id, jpeg: jpeg)
    }

    private func uploadAttachment(id: UUID, jpeg: Data) {
        store.uploadFeedbackImage(jpeg)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] url in
                guard let self,
                      let index = self.attachments.firstIndex(where: { $0.id == id }) else { return }
                self.attachments[index].remoteURL = url
                self.attachments[index].isUploading = false
                self.rebuildUploadRow()
            }, onError: { [weak self] _ in
                guard let self,
                      let index = self.attachments.firstIndex(where: { $0.id == id }) else { return }
                self.attachments.remove(at: index)
                self.rebuildUploadRow()
                FlexToast.show(FlexPhraseBook.Coffer.feedbackUploadFailed)
            })
            .disposed(by: disposeBag)
    }

    private func removeAttachment(id: UUID) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments.remove(at: index)
        rebuildUploadRow()
    }

    @objc private func submitFeedback() {
        var content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if content == FlexPhraseBook.Coffer.feedbackPlaceholder { content = "" }
        if content.isEmpty {
            FlexToast.show(FlexPhraseBook.Coffer.feedbackEmpty)
            return
        }
        if content.count > RupeeFieldLimit.feedback {
            FlexToast.show(FlexPhraseBook.Coffer.feedbackLimit)
            return
        }
        if attachments.contains(where: \.isUploading) {
            FlexToast.show(FlexPhraseBook.Coffer.feedbackUploadFailed)
            return
        }
        let imageURLs = attachments.compactMap(\.remoteURL)
        if attachments.count != imageURLs.count {
            FlexToast.show(FlexPhraseBook.Coffer.feedbackUploadFailed)
            return
        }
        store.submitFeedback(content: content, images: imageURLs)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                FlexToast.show(FlexPhraseBook.Coffer.feedbackSubmitted)
                self?.leave()
            }, onError: { [weak self] error in
                guard let self else { return }
                FlexToast.show((error as? PulseWireFault)?.description ?? FlexPhraseBook.Network.busy,
                               on: self.view)
            })
            .disposed(by: disposeBag)
    }
}

extension CofferFeedbackCanvas: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == FlexPhraseBook.Coffer.feedbackPlaceholder {
            textView.text = ""
            textView.textColor = FlexPalette.inkPrimary
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = FlexPhraseBook.Coffer.feedbackPlaceholder
            textView.textColor = FlexPalette.inkPlaceholder
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text == FlexPhraseBook.Coffer.feedbackPlaceholder ? "" : (textView.text ?? "")
        guard let swiftRange = Range(range, in: current) else { return false }
        let merged = current.replacingCharacters(in: swiftRange, with: text)
        if merged.count <= RupeeFieldLimit.feedback {
            counterLabel.text = "\(merged.count)/\(RupeeFieldLimit.feedback)"
            return true
        }
        FlexToast.show(FlexPhraseBook.Coffer.feedbackLimit)
        return false
    }
}

private final class FeedbackUploadSlot: UIControl {
    enum SlotState { case empty, filled }

    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?
    private(set) var slotState: SlotState = .empty

    private let preview = UIImageView()
    private let placeholderArt = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.feedbackAttachLoop)?.withRenderingMode(.alwaysOriginal))
    private let uploadArt = UIImageView(image: FlexSlice.slice(FlexSliceCatalog.feedbackUploadPod)?.withRenderingMode(.alwaysOriginal))
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let removeBtn = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        uploadArt.contentMode = .scaleAspectFill
        uploadArt.clipsToBounds = true
        uploadArt.flexRoundCorners(12)
        uploadArt.isUserInteractionEnabled = false

        placeholderArt.contentMode = .scaleAspectFill
        placeholderArt.clipsToBounds = true
        placeholderArt.flexRoundCorners(12)
        placeholderArt.isHidden = true

        preview.contentMode = .scaleAspectFill
        preview.clipsToBounds = true
        preview.flexRoundCorners(12)
        preview.isHidden = true

        spinner.hidesWhenStopped = true
        spinner.isHidden = true

        removeBtn.setImage(FlexSlice.slice(FlexSliceCatalog.feedbackRemoveCoil)?.withRenderingMode(.alwaysOriginal), for: .normal)
        removeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        removeBtn.flexRoundCorners(11)
        removeBtn.imageView?.contentMode = .scaleAspectFit
        removeBtn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        removeBtn.isHidden = true
        removeBtn.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(uploadArt)
        addSubview(placeholderArt)
        addSubview(preview)
        addSubview(spinner)
        addSubview(removeBtn)

        uploadArt.snp.makeConstraints { $0.edges.equalToSuperview() }
        placeholderArt.snp.makeConstraints { $0.edges.equalToSuperview() }
        preview.snp.makeConstraints { $0.edges.equalToSuperview() }
        spinner.snp.makeConstraints { $0.center.equalToSuperview() }
        removeBtn.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(6)
            make.width.height.equalTo(22)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func showPreview(_ image: UIImage?, uploading: Bool = false) {
        slotState = .filled
        preview.image = image
        preview.isHidden = image == nil
        placeholderArt.isHidden = image != nil
        uploadArt.isHidden = true
        removeBtn.isHidden = false
        if uploading {
            spinner.isHidden = false
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            spinner.isHidden = true
        }
    }

    func reset() {
        slotState = .empty
        preview.image = nil
        preview.isHidden = true
        placeholderArt.isHidden = true
        uploadArt.isHidden = false
        removeBtn.isHidden = true
        spinner.stopAnimating()
        spinner.isHidden = true
    }

    @objc private func tapped() {
        guard slotState == .empty else { return }
        onTap?()
    }

    @objc private func removeTapped() { onRemove?() }
}
