import UIKit
import SnapKit

/// ID capture — portrait UI aligned to P27 / P28 (screenshots rotated to vertical).
/// Art from Assets.xcassets; guide `rupeeArt_kycCardTemplate`.
final class FlexIDCameraCanvas: UIViewController {
    var onConfirmed: ((UIImage) -> Void)?
    var onCancelled: (() -> Void)?
    var onCaptured: (() -> Void)?
    var onRetake: (() -> Void)?

    private let session = FlexDocumentCameraSession()
    private let previewHost = UIView()
    private let snapshotView = UIImageView()
    private let guideView = UIImageView()
    private let backButton = UIButton(type: .custom)
    private let shutterButton = UIButton(type: .custom)
    private let remakeButton = UIButton(type: .custom)
    private let confirmButton = UIButton(type: .custom)

    private var capturedImage: UIImage?
    private var isReviewing = false

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildChrome()
        enterLiveMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session.attach(to: previewHost)
        session.start { [weak self] ok in
            guard let self else { return }
            if !ok {
                FlexToast.show(FlexPhraseBook.Capture.unavailable, on: self.view)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        session.layoutPreview()
    }

    deinit {
        session.tearDown()
    }

    private func buildChrome() {
        previewHost.backgroundColor = .black
        previewHost.clipsToBounds = true

        // Match live preview (resizeAspectFill) so the still does not “shrink” after shutter.
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.clipsToBounds = true
        snapshotView.isHidden = true
        guideView.isHidden = false

        // Guide from Assets (`rupeeArt_kycCardTemplate`) — same frame while live and reviewing.
        guideView.contentMode = .scaleAspectFit
        guideView.clipsToBounds = true
        guideView.image = FlexSlice.slice(FlexSliceCatalog.kycCardTemplate)?.withRenderingMode(.alwaysOriginal)
        guideView.isUserInteractionEnabled = false

        // Portrait top-center back: Assets `wyglsst_kyc_fh_up` (design ↑), not light-nav `kycBackHook`.
        configure(button: backButton,
                  image: UIImage(named: "wyglsst_kyc_fh_up"),
                  action: #selector(backTapped))
        configure(button: shutterButton,
                  image: FlexSlice.slice(FlexSliceCatalog.kycShutterDisc),
                  action: #selector(shutterTapped))
        configure(button: remakeButton,
                  image: FlexSlice.slice(FlexSliceCatalog.kycCaptureFrame),
                  action: #selector(remakeTapped))
        configure(button: confirmButton,
                  image: FlexSlice.slice(FlexSliceCatalog.kycCaptureDone),
                  action: #selector(confirmTapped))

        view.addSubview(previewHost)
        previewHost.addSubview(snapshotView)
        view.addSubview(guideView)
        view.addSubview(backButton)
        view.addSubview(shutterButton)
        view.addSubview(remakeButton)
        view.addSubview(confirmButton)

        previewHost.snp.makeConstraints { $0.edges.equalToSuperview() }
        snapshotView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // P27 vertical: back top-center, shutter bottom-center.
        backButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(44)
        }
        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-28)
            make.width.height.equalTo(64)
        }
        // Guide between chrome — inset so it stays clear of edges and buttons.
        guideView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.top.equalTo(backButton.snp.bottom).offset(16)
            make.bottom.equalTo(shutterButton.snp.top).offset(-24)
        }
        // P28 vertical: ✓ left, X right on bottom.
        confirmButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.trailing.equalTo(shutterButton.snp.leading).offset(-28)
            make.width.height.equalTo(56)
        }
        remakeButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.leading.equalTo(shutterButton.snp.trailing).offset(28)
            make.width.height.equalTo(56)
        }
    }

    private func configure(button: UIButton, image: UIImage?, action: Selector) {
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: action, for: .touchUpInside)
        button.adjustsImageWhenHighlighted = false
    }

    private func enterLiveMode() {
        isReviewing = false
        capturedImage = nil
        snapshotView.image = nil
        snapshotView.isHidden = true
        pinSnapshotFullBleed()
        session.setPreviewHidden(false)
        guideView.isHidden = false
        shutterButton.isHidden = false
        remakeButton.isHidden = true
        confirmButton.isHidden = true
        session.start()
    }

    private func enterReviewMode(with image: UIImage) {
        isReviewing = true
        view.layoutIfNeeded()
        // Crop to the shooting guide so review / upload match the frame, not the full sensor.
        let cropped = cropToGuide(image)
        capturedImage = cropped
        pinSnapshotToGuide()
        snapshotView.image = cropped
        session.setPreviewHidden(true)
        snapshotView.isHidden = false
        guideView.isHidden = false
        shutterButton.isHidden = true
        remakeButton.isHidden = false
        confirmButton.isHidden = false
        session.stop()
    }

    private func pinSnapshotFullBleed() {
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.snp.remakeConstraints { $0.edges.equalToSuperview() }
    }

    private func pinSnapshotToGuide() {
        let rect = guideCropRectInPreviewHost()
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(rect.minX)
            make.top.equalToSuperview().offset(rect.minY)
            make.width.equalTo(rect.width)
            make.height.equalTo(rect.height)
        }
    }

    /// Guide template’s aspect-fit content rect, in `previewHost` coordinates.
    private func guideCropRectInPreviewHost() -> CGRect {
        let bounds = guideView.bounds
        let templateSize = guideView.image?.size ?? bounds.size
        let fitted = FlexImageCodec.aspectFitRect(for: templateSize, in: bounds.size)
        return guideView.convert(fitted, to: previewHost)
    }

    private func cropToGuide(_ image: UIImage) -> UIImage {
        let rect = guideCropRectInPreviewHost()
        guard rect.width > 1, rect.height > 1 else { return image }
        return FlexImageCodec.cropAspectFill(image,
                                             containerSize: previewHost.bounds.size,
                                             rectInContainer: rect)
    }

    @objc private func backTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancelled?()
        }
    }

    @objc private func shutterTapped() {
        guard !isReviewing else { return }
        shutterButton.isEnabled = false
        session.capturePhoto { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.shutterButton.isEnabled = true
                FlexToast.show(FlexPhraseBook.Capture.unavailable, on: self.view)
                return
            }
            self.shutterButton.isEnabled = true
            self.onCaptured?()
            self.enterReviewMode(with: image)
        }
    }

    @objc private func remakeTapped() {
        onRetake?()
        enterLiveMode()
    }

    @objc private func confirmTapped() {
        guard let capturedImage else { return }
        dismiss(animated: true) { [weak self] in
            self?.onConfirmed?(capturedImage)
        }
    }
}
