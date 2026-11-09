import UIKit
import AVFoundation

/// Front-camera preview + still capture for KYC liveness (P34 / P35).
final class FlexFaceCameraSession: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "flex.rupee.face.camera")
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
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.cornerRadius = view.layer.cornerRadius
        layer.masksToBounds = true
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    /// Must run on `sessionQueue` and **before** `startRunning`.
    /// Setting `isVideoMirrored` while the session is running throws and crashes.
    private func applyPreviewMirroringIfNeeded() {
        guard !session.isRunning,
              let connection = previewLayer?.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }

    func layoutPreview() {
        guard let hostView, let previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = hostView.bounds
        previewLayer.cornerRadius = hostView.layer.cornerRadius
        CATransaction.commit()
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
            self.applyPreviewMirroringIfNeeded()
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
                self.applyPreviewMirroringIfNeeded()
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
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    @discardableResult
    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)

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
}

extension FlexFaceCameraSession: AVCapturePhotoCaptureDelegate {
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

        // Downscale then mirror off the capture queue — full-res flip OOMs / freezes.
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = FlexImageCodec.prepareFrontSelfie(image)
            DispatchQueue.main.async { handler?(prepared) }
        }
    }
}
