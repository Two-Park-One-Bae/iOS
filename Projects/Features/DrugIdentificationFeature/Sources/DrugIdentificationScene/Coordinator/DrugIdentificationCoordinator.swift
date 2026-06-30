import UIKit
import BaseFeatureDependency
import Core

public final class DrugIdentificationCoordinator: BaseCoordinator {

    private let cameraPicker: CameraPicker = {
        let picker = CameraPicker()
        picker.squareMode = true
        return picker
    }()

    public override func start() {
        setupOverlay()
        setupCameraPickerCallbacks()
        cameraPicker.present(from: navigationController, source: .camera)
    }

    // MARK: - Overlay (DSKit 토큰 사용)

    private func setupOverlay() {
        let overlay = CameraOverlayView()
        overlay.onClose = { [weak self] in
            self?.cameraPicker.dismissCamera()
        }
        overlay.onShutter = { [weak self] in
            self?.cameraPicker.takePicture()
        }
        overlay.onGallery = { [weak self] in
            self?.cameraPicker.openGallery()
        }
        overlay.onFlash = { [weak self] in
            let isOn = self?.cameraPicker.toggleFlash() ?? false
            overlay.updateFlashIcon(isOn: isOn)
        }
        cameraPicker.customOverlay = overlay
    }

    // MARK: - CameraPicker

    private func setupCameraPickerCallbacks() {
        cameraPicker.onImageSelected = { [weak self] image in
            self?.showResult(image: image)
        }
        cameraPicker.onPermissionDenied = { [weak self] _ in
            self?.showPermissionDenied()
        }
    }

    // MARK: - Navigation

    private func showPermissionDenied() {
        let vc = PermissionDeniedVC()
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onOpenSettings = {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
        vc.onSelectFromGallery = { [weak self] in
            guard let self else { return }
            self.cameraPicker.present(from: self.navigationController, source: .photoLibrary)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showResult(image: UIImage) {
        let viewModel = DrugIdentificationViewModel()
        let vc = DrugIdentificationVC(viewModel: viewModel)
        vc.capturedImage = image
        navigationController.pushViewController(vc, animated: true)
    }
}
