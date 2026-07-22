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
    /// 출력 이미지 최장변 상한(px). nil = 축소 안 함. 12MP 원본이 파이프라인 전체에 그대로
    /// 상주해 Jetsam(메모리 부족 강제종료)을 유발하므로, 진입 시 1회 축소한다.
    public var maxOutputDimension: CGFloat?
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

    // MARK: - Delivery (정사각 크롭 + 다운스케일)

    /// 크롭·축소를 백그라운드에서 1회 수행하고 메인에서 콜백. 대형 임시 비트맵을
    /// autoreleasepool로 즉시 해제해 진입 순간의 메모리 스파이크를 막는다.
    private func deliver(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let out: UIImage = autoreleasepool {
                let cropped = self.squareMode ? self.cropToSquare(image) : image
                if let maxDim = self.maxOutputDimension {
                    return self.downscaled(cropped, maxDimension: maxDim)
                }
                return cropped
            }
            DispatchQueue.main.async { self.onImageSelected?(out) }
        }
    }

    /// 최장변이 maxDimension을 넘으면 그 크기로 축소(orientation을 세운 .up 이미지 반환 →
    /// 다운스트림 정규화 재렌더도 생략됨). scale=1 이라 픽셀 크기 == 지정 크기.
    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let target = CGSize(width: (image.size.width * ratio).rounded(),
                            height: (image.size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
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
        deliver(image)
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

        // PHPicker는 취소도 이 델리게이트로 온다 — 결과가 비어 있으면 취소다.
        // 여기서 그냥 return하면 호출자가 아무 통보도 못 받아 빈 화면에 갇힌다.
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self)
        else {
            onCancelled?()
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }

            guard let image = object as? UIImage else {
                // 로드 실패도 빈손으로 돌아가는 것과 같다 — 취소로 처리해 갇히지 않게 한다.
                DispatchQueue.main.async { self.onCancelled?() }
                return
            }
            self.deliver(image)
        }
    }
}
