import AVFoundation
import Photos
import SwiftUI
import UIKit

struct ImageLook {
    var style: NativeStyle
    var film: FilmPreset?
    var point: CGPoint
    var intensity: Double
    var exposure: Double
}

final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var flashEnabled = false
    @Published var isRecording = false
    @Published var livePhotoEnabled = true
    @Published var livePhotoSupported = false
    @Published var showPermissionAlert = false
    var look = ImageLook(style: .standard, film: nil, point: CGPoint(x: 0.5, y: 0.5), intensity: 0.75, exposure: 0)
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var photoCompletion: ((Bool) -> Void)?
    private var pendingLivePhotoData: Data?
    private var pendingLivePhotoMovieURL: URL?
    private var pendingLivePhotoSettingsID: Int64?

    @MainActor
    func requestAndStart() async {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        let photoGranted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard cameraGranted, micGranted, photoGranted == .authorized || photoGranted == .limited else {
            showPermissionAlert = true
            return
        }
        sessionQueue.async { self.configureSession() }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async { self.showPermissionAlert = true }
            return
        }
        session.addInput(input)
        videoInput = input
        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            videoInput = nil
            DispatchQueue.main.async { self.showPermissionAlert = true }
            return
        }
        session.addOutput(photoOutput)
        if photoOutput.isLivePhotoCaptureSupported {
            photoOutput.isLivePhotoCaptureEnabled = true
            DispatchQueue.main.async { self.livePhotoSupported = true }
        } else {
            DispatchQueue.main.async { self.livePhotoSupported = false }
        }
        // Configuration is committed by defer before the session starts.
        DispatchQueue.main.async {
            if !self.session.isRunning {
                self.sessionQueue.async { self.session.startRunning() }
            }
        }
    }

    func toggleFlash() {
        flashEnabled.toggle()
    }

    func flipCamera() {
        sessionQueue.async {
            guard let current = self.videoInput else { return }
            self.session.beginConfiguration()
            self.session.removeInput(current)
            let position: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let next = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(next) {
                self.session.addInput(next)
                self.videoInput = next
            } else {
                self.session.addInput(current)
            }
            self.session.commitConfiguration()
        }
    }

    func capture(look: ImageLook, completion: @escaping (Bool) -> Void) {
        self.look = look
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        if flashEnabled, let device = videoInput?.device, device.hasFlash {
            settings.flashMode = .on
        }
        pendingLivePhotoData = nil
        pendingLivePhotoMovieURL = nil
        pendingLivePhotoSettingsID = settings.uniqueID
        if livePhotoEnabled, photoOutput.isLivePhotoCaptureSupported,
           photoOutput.isLivePhotoCaptureEnabled {
            let movieURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("YCam-Live-\(UUID().uuidString).mov")
            settings.livePhotoMovieFileURL = movieURL
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stopRecording() {
        // Video recording is not implemented yet. Do not report a successful save.
        DispatchQueue.main.async { self.isRecording = false }
    }

    func openLatestPhoto() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            finishCapture(success: false)
            return
        }
        pendingLivePhotoData = data
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime,
                     photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if error == nil {
            pendingLivePhotoMovieURL = outputFileURL
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        guard error == nil, let photoData = pendingLivePhotoData else {
            if let url = pendingLivePhotoMovieURL { try? FileManager.default.removeItem(at: url) }
            finishCapture(success: false)
            return
        }

        let movieURL = pendingLivePhotoMovieURL
        let shouldSaveLivePair = livePhotoEnabled && movieURL != nil
        // Keep the still/video pair untouched for a valid Live Photo. For ordinary
        // stills, apply the selected look before saving.
        let dataToSave = shouldSaveLivePair ? photoData : filteredPhotoData(photoData)
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            request.addResource(with: .photo, data: dataToSave, options: photoOptions)
            if shouldSaveLivePair, let movieURL {
                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.shouldMoveFile = false
                request.addResource(with: .pairedVideo, fileURL: movieURL, options: videoOptions)
            }
        }) { success, _ in
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
            DispatchQueue.main.async { self.finishCapture(success: success) }
        }
    }

    private func filteredPhotoData(_ data: Data) -> Data {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return data }
        let input = CIImage(cgImage: cgImage)
        let filtered = FilterEngine.apply(input, look: look)
        let context = CIContext()
        guard let output = context.createCGImage(filtered, from: filtered.extent) else { return data }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation).jpegData(compressionQuality: 0.96) ?? data
    }

    private func finishCapture(success: Bool) {
        DispatchQueue.main.async {
            self.photoCompletion?(success)
            self.photoCompletion = nil
            self.pendingLivePhotoData = nil
            self.pendingLivePhotoMovieURL = nil
            self.pendingLivePhotoSettingsID = nil
        }
    }
}
