import UIKit
import PhotosUI
import AVFoundation

public final class CameraPicker: NSObject {

    // MARK: - Callbacks

    public var onImageSelected: ((UIImage) -> Void)?
    public var onPermissionDenied: ((Source) -> Void)?
    public var onCancelled: (() -> Void)?

    // MARK: - Options

    public var squareMode: Bool = false
    public var customOverlay: UIView?

    // MARK: - Types

    public enum Source {
        case camera
        case photoLibrary
    }

    // MARK: - Private

    private weak var presenter: UIViewController?
    private weak var activePicker: UIImagePickerController?
    private var isGalleryTransition = false

    // MARK: - Init

    public override init() {}

    // MARK: - Present

    public func present(from viewController: UIViewController, source: Source) {
        self.presenter = viewController

        switch source {
        case .camera:
            requestCameraPermission { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.showCamera() : self?.onPermissionDenied?(.camera)
                }
            }
        case .photoLibrary:
            showPhotoLibrary()
        }
    }

    // MARK: - Camera Controls (외부 오버레이용)

    public func takePicture() {
        activePicker?.takePicture()
    }

    public func dismissCamera() {
        activePicker?.dismiss(animated: true)
        onCancelled?()
    }

    @discardableResult
    public func toggleFlash() -> Bool {
        guard let picker = activePicker else { return false }
        switch picker.cameraFlashMode {
        case .off:
            picker.cameraFlashMode = .on
            return true
        default:
            picker.cameraFlashMode = .off
            return false
        }
    }

    public func openGallery() {
        isGalleryTransition = true
        activePicker?.dismiss(animated: true) { [weak self] in
            self?.isGalleryTransition = false
            self?.showPhotoLibrary()
        }
    }

    // MARK: - Camera

    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:
            completion(false)
        }
    }

    private func showCamera() {
        // 카메라 미지원(시뮬레이터 등)이면 갤러리로 폴백 — 개발/데모에서 흐름 테스트 가능.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showPhotoLibrary()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        activePicker = picker

        if squareMode, let overlay = customOverlay {
            picker.showsCameraControls = false
            picker.cameraOverlayView = overlay

            let screen = UIScreen.main.bounds
            let screenRatio = screen.height / screen.width
            let cameraRatio: CGFloat = 4.0 / 3.0
            if screenRatio > cameraRatio {
                let scale = screenRatio / cameraRatio
                picker.cameraViewTransform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }

        presenter?.present(picker, animated: true)
    }

    // MARK: - Photo Library

    private func showPhotoLibrary() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    // MARK: - Square Crop

    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let side = min(CGFloat(cgImage.width), CGFloat(cgImage.height))
        let x = (CGFloat(cgImage.width) - side) / 2
        let y = (CGFloat(cgImage.height) - side) / 2
        let cropRect = CGRect(x: x, y: y, width: side, height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension CameraPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        let result = squareMode ? cropToSquare(image) : image
        onImageSelected?(result)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        if !isGalleryTransition {
            onCancelled?()
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CameraPicker: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            let result = self.squareMode ? self.cropToSquare(image) : image
            DispatchQueue.main.async {
                self.onImageSelected?(result)
            }
        }
    }
}
