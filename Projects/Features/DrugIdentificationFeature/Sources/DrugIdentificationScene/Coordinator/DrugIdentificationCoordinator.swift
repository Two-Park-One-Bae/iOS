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

    private var pillTabObserver: NSObjectProtocol?

    public override func start() {
        setupOverlay()
        setupCameraPickerCallbacks()

        // 알약 탭의 루트 — 카메라는 이 위에 모달로 뜬다. 탭바가 런치 시 모든 탭을 미리 빌드해도
        // 여기선 카메라를 띄우지 않아, 앱 시작하자마자 촬영 화면이 뜨는 문제를 막는다.
        let root = UIViewController()
        root.view.backgroundColor = .systemBackground
        navigationController.setViewControllers([root], animated: false)

        // 알약 탭이 실제로 선택될 때만 카메라를 present (사용자 탭 + 프로그래밍 전환 모두).
        pillTabObserver = NotificationCenter.default.addObserver(
            forName: .pillTabSelected, object: nil, queue: .main
        ) { [weak self] _ in
            self?.presentCameraIfAppropriate()
        }
    }

    deinit {
        if let pillTabObserver { NotificationCenter.default.removeObserver(pillTabObserver) }
    }

    /// 알약 탭 루트에서(식별 결과 등이 push되지 않았고 모달도 없을 때) 카메라를 present.
    private func presentCameraIfAppropriate() {
        guard navigationController.presentedViewController == nil,
              navigationController.viewControllers.count <= 1 else { return }
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
        cameraPicker.onCancelled = { [weak self] in
            // 촬영 취소 → 알약 탭 루트는 빈 화면이므로 홈 탭으로 복귀.
            self?.navigationController.popToRootViewController(animated: false)
            NotificationCenter.default.post(name: .selectHomeTab, object: nil)
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
        vc.onExitToHome = { [weak self] in self?.exitToHome() }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ④ 로딩 → ⑤/⑥/⑦

    private func startIdentification(image: UIImage) {
        let viewModel = DrugIdentificationViewModel(image: image)
        let loadingVC = PillLoadingVC(image: image, viewModel: viewModel)

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
        vc.onExitToHome = { [weak self] in self?.exitToHome() }
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
        // 공유는 FinalResultVC 가 시스템 공유 시트(텍스트+PDF)를 직접 띄운다(PillShareComposer).
        // 완료 → 알약 탭 스택을 루트(빈 화면)로 정리하고 홈 탭으로 복귀.
        // 촬영 취소 흐름과 동일. 다음에 알약 탭을 다시 선택하면 카메라가 새로 뜬다.
        vc.onComplete = { [weak self] in
            self?.navigationController.popToRootViewController(animated: false)
            NotificationCenter.default.post(name: .selectHomeTab, object: nil)
        }
        // ⑨ 카드 탭 → ⑩ 세부정보 진입 (NM-317)
        vc.onSelectDetail = { [weak self] pillCode, imageUrl in
            self?.showPillDetail(pillCode: pillCode, imageUrl: imageUrl)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑩ 세부정보

    private func showPillDetail(pillCode: String, imageUrl: String?) {
        let viewModel = PillDetailViewModel(pillCode: pillCode)
        let vc = PillDetailVC(viewModel: viewModel, imageUrl: imageUrl)
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
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
        // ⑧ 후보 ⓘ → ⑩ 세부정보 진입 (NM-317)
        vc.onSelectDetail = { [weak self] pillCode, imageUrl in
            self?.showPillDetail(pillCode: pillCode, imageUrl: imageUrl)
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
        vc.onSelectDetail = { [weak self] pillCode, imageUrl in
            self?.showPillDetail(pillCode: pillCode, imageUrl: imageUrl)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑥ 결과 없음

    private func showNotFound(image: UIImage, replacing loadingVC: UIViewController) {
        let vc = PillNotFoundVC(image: image)
        vc.onBackTapped = { [weak self] in self?.exitToHome() }
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
        // 네비바 뒤로·푸터 '뒤로' 모두 홈으로 — 이 화면엔 돌아갈 이전 단계가 없다.
        vc.onBackTapped = { [weak self] in self?.exitToHome() }
        vc.onBack = { [weak self] in self?.exitToHome() }
        vc.onRetry = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        replace(loadingVC, with: vc)
    }

    /// 식별을 중단하고 홈 탭으로 되돌린다.
    /// 알약 탭 루트는 빈 화면이라 그대로 두면 갈 곳이 없어, 촬영 취소와 같은 경로를 쓴다.
    private func exitToHome() {
        navigationController.popToRootViewController(animated: false)
        NotificationCenter.default.post(name: .selectHomeTab, object: nil)
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
