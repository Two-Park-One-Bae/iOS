import UIKit
import Combine
import BaseFeatureDependency
import Core
import Domain
import DSKit

public final class DrugIdentificationCoordinator: BaseCoordinator {

    private let cameraPicker: CameraPicker = {
        let picker = CameraPicker()
        picker.squareMode = true
        // Jetsam 방지: 12MP 원본이 프리뷰·추론·결과 화면에 그대로 상주하지 않도록 진입 시 축소.
        // 추론 입력은 내부적으로 576px, 썸네일은 작게 표시 → 2048이면 화질 여유 충분.
        picker.maxOutputDimension = 2048
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

    @Injected private var pillUseCase: PillUseCase

    // MARK: - ② 미리보기

    private func showPreview(image: UIImage) {
        let vc = PhotoPreviewVC(image: image)
        vc.onRetake = { [weak self] in
            guard let self else { return }
            self.navigationController.popViewController(animated: false)
            self.cameraPicker.present(from: self.navigationController, source: .camera)
        }
        vc.onUsePhoto = { [weak self] in
            guard let self else { return }

            // fail-closed: 안정적 기기 식별자를 못 만들면(Keychain 불가) 식별을 막는다.
            // 매 실행 새 id면 카운트가 리셋돼 한도가 무력화되므로 — 차라리 '잠시 후 다시'.
            guard DeviceIdentifier.current != nil else {
                DSAlertCardView.presentOverWindow(
                    title: "일시적 오류",
                    message: "기기 확인에 실패했어요.\n잠시 후 다시 시도해 주세요."
                )
                return
            }

            // 세션 중 소진 방어: 진입 후 마지막 횟수를 쓰고 돌아온 경우, 요청을 보내지 않는다.
            // 값을 모르면 통과 — 최종 판정은 서버 429다 (NM-323).
            if let usage = self.pillUseCase.pillUsage.value, usage.isExhausted {
                self.exitToHomeWithLimitAlert(usage: usage, source: "gate")
                return
            }

            self.startIdentification(image: image)
        }
        vc.onExitToHome = { [weak self] in self?.exitToHome() }
        // 미리보기에도 남은 횟수를 표시한다 (촬영 화면에는 표시하지 않는다).
        vc.bindUsage(pillUseCase.pillUsage.eraseToAnyPublisher())
        navigationController.pushViewController(vc, animated: true)
    }

    /// 한도에 걸리면 홈으로 되돌리고 안내 팝업을 띄운다.
    ///
    /// 미리보기에 남겨두면 재촬영·이 사진 사용 둘 다 다시 막혀 막다른 길이 된다.
    /// 요청 전에 막힌 경우(게이트)와 서버가 거절한 경우(429)를 사용자는 구분할 수 없으므로
    /// 두 경로의 동작을 통일한다.
    private func exitToHomeWithLimitAlert(usage: PillUsageModel?, source: String) {
        // source: gate(요청 전 세션 게이트) / server(요청 후 429) — 어디서 막혔는지 구분.
        AppAnalytics.track(.pillLimitReached(source: source))
        navigationController.popToRootViewController(animated: false)
        NotificationCenter.default.post(name: .selectHomeTab, object: nil)

        // 탭 전환 뒤에도 보이도록 윈도우 위에 띄운다.
        DSAlertCardView.presentOverWindow(
            title: PillLimitAlertText.title,
            message: PillLimitAlertText.message(resetAt: usage?.resetAt)
        )
    }

    // MARK: - ④ 로딩 → ⑤/⑥/⑦

    private func startIdentification(image: UIImage) {
        let viewModel = DrugIdentificationViewModel(image: image)
        let loadingVC = PillLoadingVC(image: image, viewModel: viewModel)

        // loadingVC 를 강하게 캡처하면 loadingVC → 클로저 → loadingVC 사이클로 안 죽는다.
        // (죽지 않으면 분석 VM 이 공유 errorMessage 를 계속 구독해 다른 화면 오류까지 받는다.)
        loadingVC.onSuccess = { [weak self, weak loadingVC] pills, resultImage in
            guard let loadingVC else { return }
            self?.showResult(pills: pills, image: resultImage, replacing: loadingVC)
        }
        loadingVC.onEmpty = { [weak self, weak loadingVC] in
            guard let loadingVC else { return }
            self?.showNotFound(image: image, replacing: loadingVC)
        }
        loadingVC.onFailure = { [weak self, weak loadingVC] message in
            guard let loadingVC else { return }
            self?.showFailure(replacing: loadingVC)
        }
        // 한도 도달은 실패가 아니다 — 미리보기로 되돌리고 안내 팝업만 띄운다.
        loadingVC.onLimitExceeded = { [weak self] usage in
            self?.exitToHomeWithLimitAlert(usage: usage, source: "server")
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
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑩ 세부정보

    private func showPillDetail(pillCode: String, licenseStatus: LicenseStatus) {
        let viewModel = PillDetailViewModel(pillCode: pillCode, licenseStatus: licenseStatus)
        let vc = PillDetailVC(viewModel: viewModel)
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
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        // ⑧ 후보 썸네일 탭 → 이미지 비교 뷰어 (NM-354)
        vc.onSelectCompare = { [weak self] candidate, crop, sourceFrame, sourceImage in
            self?.showImageComparison(candidate: candidate, croppedImage: crop, sourceFrame: sourceFrame, sourceImage: sourceImage)
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
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        vc.onSelectCompare = { [weak self] candidate, crop, sourceFrame, sourceImage in
            self?.showImageComparison(candidate: candidate, croppedImage: crop, sourceFrame: sourceFrame, sourceImage: sourceImage)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - ⑧ 후보 이미지 비교 (NM-354)

    private func showImageComparison(
        candidate: PillCandidateModel,
        croppedImage: UIImage?,
        sourceFrame: CGRect,
        sourceImage: UIImage?
    ) {
        let url = candidate.pillImageUrl.flatMap { URL(string: $0) }
        let vc = PillImageComparisonVC(
            candidateImageURL: url,
            croppedImage: croppedImage,
            sourceFrame: sourceFrame,
            sourceImage: sourceImage
        )
        navigationController.present(vc, animated: true)
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
        // 뒤로가기 → 홈으로. 단순 pop이면 알약탭 스택에 빈 화면만 남으므로 popToRoot + 홈탭 전환.
        vc.onBackTapped = { [weak self] in self?.exitToHome() }
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
