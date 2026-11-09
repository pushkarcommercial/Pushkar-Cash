import UIKit
import AVFoundation

/// Rear-camera preview + still capture for Aadhaar / PAN (portrait).
final class FlexDocumentCameraSession: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "flex.rupee.doc.camera")
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var hostView: UIView?
    private var captureHandler: ((UIImage?) -> Void)?
    private var isConfigured = false
    private var isCapturingPhoto = false

    var isRunning: Bool { session.isRunning }

    func attach(to view: UIView) {
        hostView = view
        if let layer = previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = view.bounds
            CATransaction.commit()
            return
        }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        // Match LoanEase ID camera — fill the guide frame (no letterbox mismatch vs still).
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func layoutPreview() {
        guard let hostView, let previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = hostView.bounds
        CATransaction.commit()
        applyPortraitOrientation()
    }

    func setPreviewHidden(_ hidden: Bool) {
        previewLayer?.isHidden = hidden
    }

    func start(completion: ((Bool) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                let ok = self.configureSession()
                if !ok {
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.layoutPreview()
                completion?(true)
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isCapturingPhoto { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func tearDown() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isCapturingPhoto = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            self.session.commitConfiguration()
            self.photoOutput = nil
            self.isConfigured = false
            DispatchQueue.main.async {
                self.previewLayer?.removeFromSuperlayer()
                self.previewLayer = nil
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let output = self.photoOutput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.isCapturingPhoto = true
            self.captureHandler = completion
            let settings: AVCapturePhotoSettings
            if output.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            // Do not force portrait on the still — LoanEase leaves sensor orientation,
            // then the coordinator rotates -90° for upload / OCR.
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    @discardableResult
    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Prefer widest FOV (triple/dual @ 0.5x → ultra-wide → wide), LoanEase parity.
        guard let device = preferredBackCaptureDevice(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        applyWidestDefaultZoom(on: device)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)
        photoOutput = output
        session.commitConfiguration()
        isConfigured = true
        return true
    }

    private func preferredBackCaptureDevice() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInWideAngleCamera
        ]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return AVCaptureDevice.default(for: .video)
    }

    /// Dual/triple virtual cameras expose ultra-wide at `minAvailableVideoZoomFactor` (usually 0.5).
    private func applyWidestDefaultZoom(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = device.minAvailableVideoZoomFactor
        } catch {
            // Keep default zoom if configuration fails.
        }
    }

    private func applyPortraitOrientation() {
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
}

extension FlexDocumentCameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let handler = captureHandler
        captureHandler = nil
        sessionQueue.async { [weak self] in
            self?.isCapturingPhoto = false
        }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { handler?(nil) }
            return
        }
        DispatchQueue.main.async { handler?(image) }
    }
}
