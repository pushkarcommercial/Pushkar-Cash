import UIKit
import AVFoundation

final class FlexCaptureCoordinator: NSObject {
    enum Slot {
        case document
        case face
    }

    /// Document photo bury set — Aadhaar uses 50–57; PAN / tax uses 41–49.
    enum DocumentTrackKind {
        case none
        case identity
        case pan
    }

    private weak var host: UIViewController?
    private var slot: Slot = .document
    /// `(image, fromCamera)` — camera stills are rotated; encode may scale + quality (no crop).
    private var onCapture: ((UIImage, Bool) -> Void)?
    private var onDenied: (() -> Void)?
    private var documentTrack: DocumentTrackKind = .none

    init(host: UIViewController) {
        self.host = host
    }

    func capture(slot: Slot,
                 allowLibrary: Bool = false,
                 libraryOnly: Bool = false,
                 trackIdentityEvents: Bool = false,
                 trackPanEvents: Bool = false,
                 onCapture: @escaping (_ image: UIImage, _ fromCamera: Bool) -> Void,
                 onDenied: (() -> Void)? = nil) {
        self.slot = slot
        self.onCapture = onCapture
        self.onDenied = onDenied
        if trackPanEvents {
            documentTrack = .pan
        } else if trackIdentityEvents {
            documentTrack = .identity
        } else {
            documentTrack = .none
        }
        stampSelectPhoto()
        if libraryOnly {
            FlexSpinnerOverlay.beginRequest(on: host?.view)
            presentPhotoLibrary()
        } else if allowLibrary {
            presentSourceSheet()
        } else if slot == .document {
            requestCameraAccess { [weak self] in self?.presentDocumentCamera() }
        } else {
            requestCameraAccess { [weak self] in self?.presentSystemCamera() }
        }
    }

    private func presentSourceSheet() {
        guard let host else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: FlexPhraseBook.Verify.captureSheetCamera, style: .default) { [weak self] _ in
            self?.stampSelectCamera()
            self?.requestCameraAccess {
                if self?.slot == .document {
                    self?.presentDocumentCamera()
                } else {
                    self?.presentSystemCamera()
                }
            }
        })
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            sheet.addAction(UIAlertAction(title: FlexPhraseBook.Verify.captureSheetLibrary, style: .default) { [weak self] _ in
                self?.stampSelectAlbum()
                // Show loading immediately — action sheet dismiss leaves a blank gap otherwise.
                FlexSpinnerOverlay.beginRequest(on: self?.host?.view)
                self?.presentPhotoLibrary()
            })
        }
        sheet.addAction(UIAlertAction(title: FlexPhraseBook.Dialog.cancel, style: .cancel) { [weak self] _ in
            self?.onDenied?()
        })
        host.present(sheet, animated: true)
    }

    private func requestCameraAccess(then: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            PulseBeaconRecorder.shared.stamp(.cameraGranted)
            then()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        PulseBeaconRecorder.shared.stamp(.cameraGranted)
                        then()
                    } else {
                        PulseBeaconRecorder.shared.stamp(.cameraDenied)
                        self.onDenied?()
                    }
                }
            }
        default:
            PulseBeaconRecorder.shared.stamp(.cameraDenied)
            presentCameraDenied()
        }
    }

    private func presentCameraDenied() {
        guard let host else { return }
        FlexPermissionSheet.present(on: host, kind: .camera,
                                    onConfirm: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }, onCancel: { [weak self] in
            self?.onDenied?()
        })
    }

    /// Custom ID camera (P27 / P28).
    private func presentDocumentCamera() {
        guard let host else { return }
        stampOpenCamera()
        let canvas = FlexIDCameraCanvas()
        canvas.modalPresentationStyle = .fullScreen
        canvas.onCaptured = { [weak self] in
            self?.stampCapturePhoto()
        }
        canvas.onRetake = { [weak self] in
            self?.stampRetakePhoto()
        }
        canvas.onConfirmed = { [weak self] image in
            self?.stampConfirmPhoto()
            self?.deliver(image, fromCamera: true)
        }
        canvas.onCancelled = { [weak self] in
            self?.stampCancelCamera()
            self?.onDenied?()
        }
        host.present(canvas, animated: true)
    }

    private func presentSystemCamera() {
        guard let host else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            FlexToast.show(FlexPhraseBook.Capture.unavailable, on: host.view)
            onDenied?()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        if slot == .face, UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        host.present(picker, animated: true)
    }

    /// System photo picker only — no Photos permission prompt (`UIImagePickerController`).
    private func presentPhotoLibrary() {
        guard let host else {
            FlexSpinnerOverlay.endRequest()
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            FlexSpinnerOverlay.endRequest()
            PulseBeaconRecorder.shared.stamp(.albumDenied)
            FlexToast.show(FlexPhraseBook.Capture.unavailable, on: host.view)
            onDenied?()
            return
        }
        // Wait for action-sheet dismiss so present isn't ignored; keep spinner visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak host] in
            guard let self, let host, host.view.window != nil else {
                FlexSpinnerOverlay.endRequest()
                return
            }
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = false
            host.present(picker, animated: true) {
                FlexSpinnerOverlay.endRequest()
                PulseBeaconRecorder.shared.stamp(.albumGranted)
            }
        }
    }

    private func deliver(_ image: UIImage, fromCamera: Bool = false) {
        switch slot {
        case .document:
            FlexSpinnerOverlay.beginRequest(on: host?.view)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                // Camera: LoanEase rotates -90° after normalize (sensor still → landscape ID).
                // Album: keep EXIF-normalized orientation only — never force-rotate.
                // Soft max-side is proportional (no crop); final JPEG ≤600KB (over → scale + quality).
                let upright = FlexImageCodec.prepareIdentityDocument(image)
                let prepared = fromCamera ? FlexImageCodec.rotate(upright, byDegrees: -90) : upright
                DispatchQueue.main.async {
                    self?.onCapture?(prepared, fromCamera)
                    FlexSpinnerOverlay.endRequest()
                }
            }
        case .face:
            onCapture?(image, fromCamera)
        }
    }

    // MARK: - Document track stamps (identity 50–57 / pan 41–49)

    private func stampSelectPhoto() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identitySelectPhoto)
        case .pan: PulseBeaconRecorder.shared.stamp(.panSelectPhoto)
        case .none: break
        }
    }

    private func stampSelectCamera() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identitySelectCamera)
        case .pan: PulseBeaconRecorder.shared.stamp(.panSelectCamera)
        case .none: break
        }
    }

    private func stampSelectAlbum() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identitySelectAlbum)
        case .pan: PulseBeaconRecorder.shared.stamp(.panSelectAlbum)
        case .none: break
        }
    }

    private func stampOpenCamera() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityOpenCamera)
        case .pan: PulseBeaconRecorder.shared.stamp(.panOpenCamera)
        case .none: break
        }
    }

    private func stampCapturePhoto() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityCapturePhoto)
        case .pan: PulseBeaconRecorder.shared.stamp(.panCapturePhoto)
        case .none: break
        }
    }

    private func stampConfirmPhoto() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityConfirmPhoto)
        case .pan: PulseBeaconRecorder.shared.stamp(.panConfirmPhoto)
        case .none: break
        }
    }

    private func stampRetakePhoto() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityCancelCamera)
        case .pan: PulseBeaconRecorder.shared.stamp(.panRetakePhoto)
        case .none: break
        }
    }

    private func stampCancelCamera() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityCancelCamera)
        case .pan: PulseBeaconRecorder.shared.stamp(.panCancelCamera)
        case .none: break
        }
    }

    private func stampAlbumSelectPhoto() {
        switch documentTrack {
        case .identity: PulseBeaconRecorder.shared.stamp(.identityAlbumSelectPhoto)
        case .pan: PulseBeaconRecorder.shared.stamp(.panAlbumSelectPhoto)
        case .none: break
        }
    }
}

extension FlexCaptureCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        FlexSpinnerOverlay.endRequest()
        onDenied?()
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            FlexSpinnerOverlay.endRequest()
            onDenied?()
            return
        }
        if picker.sourceType == .photoLibrary {
            stampAlbumSelectPhoto()
        }
        deliver(image)
    }
}
