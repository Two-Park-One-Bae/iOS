import UIKit
import BaseFeatureDependency
import Core
import Domain

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

    private weak var resultVC: DrugIdentificationVC?

    private func showResult(pills: [IdentifiedPill], image: UIImage, replacing loadingVC: UIViewController) {
        let vc = DrugIdentificationVC(pills: pills, image: image)
        resultVC = vc
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onSelectPill = { [weak self] pill in
            self?.showEdit(pill: pill)
        }
        vc.onAddPill = { [weak self] in
            self?.showManualAdd()
        }
        vc.onConfirm = { [weak self] in
            self?.showFinalResult()
        }
        replace(loadingVC, with: vc)
    }

    // MARK: - ⑨ 최종 결과

    private func showFinalResult() {
        guard let resultVC else { return }
        let results = resultVC.finalizedResults()
        guard !results.isEmpty else { return }

        let pills = results.map(\.pill)
        let candidates = Dictionary(uniqueKeysWithValues: results.map { ($0.pill.index, $0.candidate) })

        let vc = FinalResultVC(pills: pills, candidates: candidates)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        // 스펙 NM-136: 공유는 텍스트 복사(MVP·화면 유지)
        vc.onShare = {
            let text = results.map { "\($0.pill.index). \($0.candidate.pillName ?? "이름 미상")" }
                .joined(separator: "\n")
            UIPasteboard.general.string = text
        }
        // 완료 → 홈 이동. 메인 앱 연동 시 Coordinator 종료/디스미스 처리
        vc.onComplete = { /* TODO: 홈 화면으로 이동 */ }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑧ 알약 수정

    private func showEdit(pill: IdentifiedPill) {
        let viewModel = PillEditViewModel(
            pillIndex: pill.index,
            attribute: pill.attribute,
            thumbnail: pill.thumbnail
        )
        let vc = PillEditVC(viewModel: viewModel)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onCancel = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onConfirm = { [weak self] candidate in
            self?.resultVC?.applySelection(
                pillIndex: pill.index,
                candidate: candidate
            )
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑧ 알약 수동 추가 (NM-187)

    private func showManualAdd() {
        guard let resultVC else { return }
        let index = resultVC.nextManualIndex()
        let empty = PillAttributeModel(
            pillId: "manual-\(index)", colors: [], isTransparent: false,
            shape: nil, formulation: nil, front: nil, back: nil, error: nil
        )
        let viewModel = PillEditViewModel(pillIndex: index, attribute: empty, thumbnail: nil)
        let vc = PillEditVC(viewModel: viewModel)
        vc.onBackTapped = { [weak self] in self?.navigationController.popViewController(animated: true) }
        vc.onCancel = { [weak self] in self?.navigationController.popViewController(animated: true) }
        // 빈 입력으로 후보 선택·확정 시에만 결과 목록에 새 카드로 추가 (취소 시 미추가)
        vc.onConfirm = { [weak self] candidate in
            self?.resultVC?.addManualPill(index: index, candidate: candidate)
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(vc, animated: true)
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
