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
            self?.showPreview(image: image)
        }
        cameraPicker.onPermissionDenied = { [weak self] _ in
            self?.showPermissionDenied()
        }
    }

    // MARK: - ② 미리보기

    private func showPreview(image: UIImage) {
        let vc = PhotoPreviewVC(image: image)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onRetake = { [weak self] in
            guard let self else { return }
            self.navigationController.popViewController(animated: false)
            self.cameraPicker.present(from: self.navigationController, source: .camera)
        }
        vc.onUsePhoto = { [weak self] in
            self?.startIdentification(image: image)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ④ 로딩 → ⑤/⑥/⑦

    private func startIdentification(image: UIImage) {
        let viewModel = DrugIdentificationViewModel(image: image)
        let loadingVC = PillLoadingVC(image: image, viewModel: viewModel)

        loadingVC.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        loadingVC.onSuccess = { [weak self] pills, resultImage in
            self?.showResult(pills: pills, image: resultImage, replacing: loadingVC)
        }
        loadingVC.onEmpty = { [weak self] in
            self?.showNotFound(image: image, replacing: loadingVC)
        }
        loadingVC.onFailure = { [weak self] message in
            self?.showFailure(replacing: loadingVC)
        }

        navigationController.pushViewController(loadingVC, animated: true)
    }

    // MARK: - ⑤ 인식 결과

    private func showResult(pills: [IdentifiedPill], image: UIImage, replacing loadingVC: UIViewController) {
        let vc = DrugIdentificationVC(pills: pills, image: image)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onSelectPill = { _ in
            // TODO: 후보 선택 화면 진입
        }
        vc.onConfirm = {
            // TODO: 최종 결과 확인
        }
        replace(loadingVC, with: vc)
    }

    // MARK: - ⑥ 결과 없음

    private func showNotFound(image: UIImage, replacing loadingVC: UIViewController) {
        let vc = PillNotFoundVC(image: image)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onRetake = { [weak self] in
            guard let self else { return }
            self.navigationController.popViewController(animated: false)
            self.cameraPicker.present(from: self.navigationController, source: .camera)
        }
        vc.onSelectFromGallery = { [weak self] in
            guard let self else { return }
            self.cameraPicker.present(from: self.navigationController, source: .photoLibrary)
        }
        replace(loadingVC, with: vc)
    }

    // MARK: - ⑦ 분석 실패

    private func showFailure(replacing loadingVC: UIViewController) {
        let vc = AnalysisFailedVC()
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onRetry = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        replace(loadingVC, with: vc)
    }

    // MARK: - ③ 권한 거부

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

    // MARK: - Helper

    // 로딩 VC를 결과/실패 VC로 교체 (뒤로가기 시 로딩으로 돌아가지 않도록)
    private func replace(_ loadingVC: UIViewController, with vc: UIViewController) {
        var stack = navigationController.viewControllers
        if let index = stack.firstIndex(of: loadingVC) {
            stack[index] = vc
            navigationController.setViewControllers(stack, animated: true)
        } else {
            navigationController.pushViewController(vc, animated: true)
        }
    }
}
