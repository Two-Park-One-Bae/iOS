import UIKit
import PhotosUI
import AVFoundation

public final class CameraPicker: NSObject {

    // MARK: - Callbacks

    /// 이미지 선택 완료 시 호출
    public var onImageSelected: ((UIImage) -> Void)?
    /// 카메라 권한 거부 시 호출
    public var onPermissionDenied: ((Source) -> Void)?

    // MARK: - Types

    public enum Source {
        case camera
        case photoLibrary
    }

    // MARK: - Private

    /// 순환 참조 방지를 위해 weak 참조
    private weak var presenter: UIViewController?

    // MARK: - Init

    public override init() {}

    // MARK: - Public

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

    // MARK: - Camera

    /// 카메라 권한 상태 확인 후 요청
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            // 최초 진입 시 권한 팝업 표시
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:
            completion(false)
        }
    }

    private func showCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    // MARK: - Photo Library

    /// PHPickerViewController 사용 — iOS 14+, 별도 권한 요청 불필요
    private func showPhotoLibrary() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter?.present(picker, animated: true)
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
        onImageSelected?(image)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CameraPicker: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        /// loadObject는 백그라운드 스레드에서 실행되므로 메인 스레드로 전환
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.onImageSelected?(image)
            }
        }
    }
}
