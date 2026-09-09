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

    /// 알약별 체류시간 누적기 — `PillEditVC` 가 매번 새로 만들어져도 값이 이어지도록 여기서 소유한다.
    /// 이 Coordinator 는 탭당 하나로 앱 수명 내내 살아 있어서, 새 인식 세션마다 `reset()` 해야
    /// 이전 사진의 알약 순번과 누적값이 섞이지 않는다.
    private let dwellTracker = PillDwellTracker()

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
            guard let self else { return }
            // 진입 시 잔여 조회 (spec: §식별 횟수 제한 "첫 실행·재설치·화면 진입 시 표시값의 기준").
            // 조회 전용이라 카운트는 늘지 않는다(NM-331). 홈이 viewWillAppear 마다 하는 것과 같은
            // 이유로, 홈을 거치지 않고 탭으로 바로 들어온 경우에도 값을 최신으로 만든다.
            self.pillUseCase.fetchPillUsage()
            self.presentCameraIfAppropriate()
        }
    }

    deinit {
        if let pillTabObserver { NotificationCenter.default.removeObserver(pillTabObserver) }
    }

    /// 알약 탭 루트에서(식별 결과 등이 push되지 않았고 모달도 없을 때) 카메라를 present.
    private func presentCameraIfAppropriate() {
        guard navigationController.presentedViewController == nil,
              navigationController.viewControllers.count <= 1 else { return }

        /*
         진입 게이트 (spec: feature/pill-recognition/README.md §식별 횟수 제한 §흐름 규칙
         "식별 진입 시점(홈 '알약 식별' 카드/탭)에 … 0이면 안내 팝업을 띄우고 진입하지 않는다").

         홈 카드는 HomeViewModel 이 같은 규칙으로 막는데 **탭 경로에만 게이트가 없어서**,
         탭으로 들어오면 0회여도 촬영까지 그대로 진행됐다.

         값을 모르면 통과한다 — 최종 판정은 서버 429 다(spec: "잔여 미확인 시 통과").

         막을 때는 홈으로 되돌린다. 알약 탭 루트는 **카메라가 덮는 걸 전제로 한 빈 화면**이라
         그대로 두면 흰 화면만 남는다. spec 흐름도도 팝업 확인 뒤를 홈으로 둔다(P -->|확인| H).
         (미리보기에서 막힌 경우는 반대로 화면을 유지한다 — 거긴 찍은 사진이 있고, 잔여 0회를
          경고색으로 보여 주는 자리다.)
         */
        if let usage = pillUseCase.pillUsage.value, usage.isExhausted {
            NotificationCenter.default.post(name: .selectHomeTab, object: nil)
            presentLimitAlert(usage: usage)
            return
        }

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
            self?.trackButton("gallery", screen: "camera")
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
            self.trackButton("retake", screen: "photo_preview")
            self.navigationController.popViewController(animated: false)
            self.cameraPicker.present(from: self.navigationController, source: .camera)
        }
        vc.onUsePhoto = { [weak self] in
            guard let self else { return }

            // 기기 식별자 fail-closed 게이트는 제거했다 (NM-410 클린 컷오버).
            // 서버가 식별 한도를 기기 UUID 가 아니라 소셜 계정 해시로 세고 `X-Device-Id` 도
            // 받지 않으므로, Keychain 실패로 식별을 막을 이유가 사라졌다 — 남겨 두면
            // 아무 효과 없이 식별만 거부하는 게이트가 된다.

            // 세션 중 소진 방어: 진입 후 마지막 횟수를 쓰고 돌아온 경우, 요청을 보내지 않는다.
            // 값을 모르면 통과 — 최종 판정은 서버 429다 (NM-323).
            if let usage = self.pillUseCase.pillUsage.value, usage.isExhausted {
                // 이미 미리보기에 서 있다 — 화면을 그대로 두고 팝업만 띄운다.
                self.presentLimitAlert(usage: usage)
                return
            }

            self.startIdentification(image: image)
        }
        vc.onExitToHome = { [weak self] in self?.exitToHome() }
        // 미리보기에도 남은 횟수를 표시한다 (촬영 화면에는 표시하지 않는다).
        vc.bindUsage(pillUseCase.pillUsage.eraseToAnyPublisher())
        navigationController.pushViewController(vc, animated: true)
    }

    /// 한도 안내 팝업 — **확인 뒤 미리보기에 머무른다**. 찍은 사진을 잃지 않는다
    /// (spec: feature/pill-recognition/README.md §식별 횟수 제한 "확인 시 현재 화면에 머무른다").
    ///
    /// 예전엔 홈으로 내보내 사진이 날아갔다. "미리보기에 남겨두면 재촬영·이 사진 사용 둘 다
    /// 다시 막혀 막다른 길" 이라는 게 이유였지만, 미리보기는 남은 횟수를 0회·경고색으로
    /// 표시하므로 막다른 길이 아니라 **왜 막혔는지 보이는 자리**다. 사진을 버리는 대가로
    /// 얻는 게 없다 — 다시 찍으려면 촬영부터 다시 해야 한다.
    ///
    /// **여기서는 계측하지 않는다.** `pill_limit_reached` 는 한도를 실제로 소진하는 순간
    /// (마지막 1회를 쓴 요청의 성공 응답)에 `DrugIdentificationViewModel` 이 발사한다 —
    /// 막힌 시도를 세면 재시도하지 않은 사용자가 빠지고 재시도한 사용자는 중복으로 잡힌다.
    private func presentLimitAlert(usage: PillUsageModel?) {
        // 루트(네비게이션 컨트롤러) 뷰에 붙으므로 push·pop 과 무관하게 남는다.
        DSAlertCardView.presentOverWindow(
            title: PillLimitAlertText.title,
            message: PillLimitAlertText.message(resetAt: usage?.resetAt)
        )
    }

    // MARK: - ④ 로딩 → ⑤/⑥/⑦

    private func startIdentification(image: UIImage) {
        navigationController.pushViewController(makeLoadingVC(image: image), animated: true)
    }

    /// 로딩 화면 + 분석 VM 한 벌.
    ///
    /// 최초 진입은 push 로, **실패 후 재시도는 실패 화면과 replace** 해서 쓴다 —
    /// 재시도가 같은 사진으로 분석을 처음부터(온디바이스 탐지 + 서버 왕복) 다시 돌려야 하는데,
    /// VM 은 이미 종료 상태를 방출한 뒤라 재사용할 수 없다.
    private func makeLoadingVC(image: UIImage) -> PillLoadingVC {
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
            self?.showFailure(message: message, image: image, replacing: loadingVC)
        }
        // 한도 도달은 실패가 아니다 — 미리보기로 되돌리고 안내 팝업만 띄운다.
        loadingVC.onLimitExceeded = { [weak self] usage in
            guard let self else { return }
            // 로딩 화면은 머무를 수 있는 자리가 아니다 — 나갈 버튼이 없다(PillLoadingVC 가 숨긴다).
            // 사진을 고른 미리보기로 되돌려, 게이트로 막힌 경우와 같은 자리에서 같은 팝업을 띄운다
            // (spec: "요청이 429 로 거부된 경우도 같은 팝업으로 처리한다").
            self.navigationController.popViewController(animated: true)
            self.presentLimitAlert(usage: usage)
        }

        return loadingVC
    }

    // MARK: - ⑤ 인식 결과

    private weak var resultVC: DrugIdentificationVC?

    private func showResult(pills: [IdentifiedPill], image: UIImage, replacing loadingVC: UIViewController) {
        // 새 인식 세션 — 이전 사진의 알약별 누적 체류시간을 비운다.
        dwellTracker.reset()
        let vc = DrugIdentificationVC(pills: pills, image: image)
        resultVC = vc
        vc.onExitToHome = { [weak self, weak vc] in
            // 확정 없이 ⑤ 이탈 — 미확정 개수·경과시간 등 세션 요약 집계.
            if let s = vc?.identificationSummary() {
                AppAnalytics.track(.pillIdentifySessionExit(
                    detectedCount: s.detectedCount, confirmedCount: s.confirmedCount,
                    unconfirmedCount: s.unconfirmedCount, deletedCount: s.deletedCount,
                    manualAddedCount: s.manualAddedCount, elapsedSec: s.elapsedSec))
            }
            self?.exitToHome()
        }
        vc.onSelectPill = { [weak self] pill in
            self?.showEdit(pill: pill)
        }
        vc.onAddPill = { [weak self] in
            self?.trackButton("add_pill", screen: "identify_result")
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
            // 완주(완료 버튼) — ⑤ 전원 확정 상태라 미확정=0.
            if let s = self?.resultVC?.identificationSummary() {
                AppAnalytics.track(.pillIdentifyComplete(
                    detectedCount: s.detectedCount, confirmedCount: s.confirmedCount,
                    deletedCount: s.deletedCount, manualAddedCount: s.manualAddedCount))
            }
            self?.navigationController.popToRootViewController(animated: false)
            NotificationCenter.default.post(name: .selectHomeTab, object: nil)
        }
        // ⑨ 카드 탭 → ⑩ 세부정보 진입 (NM-317)
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.trackButton("pill_detail", screen: "final_result")
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
        vc.dwellTracker = dwellTracker
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
            self?.trackButton("pill_detail", screen: "pill_edit")
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        // ⑧ 후보 썸네일 탭 → 이미지 비교 뷰어 (NM-354)
        vc.onSelectCompare = { [weak self] candidate, crop, sourceFrame, sourceImage in
            self?.trackButton("compare", screen: "pill_edit")
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
        let viewModel = PillEditViewModel(pillIndex: index, attribute: empty, thumbnail: nil, isManual: true)
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
            self.trackButton("retake", screen: "not_found")
            self.navigationController.popViewController(animated: false)
            self.cameraPicker.present(from: self.navigationController, source: .camera)
        }
        vc.onSelectFromGallery = { [weak self] in
            guard let self else { return }
            self.trackButton("gallery", screen: "not_found")
            self.cameraPicker.present(from: self.navigationController, source: .photoLibrary)
        }
        replace(loadingVC, with: vc)
    }

    // MARK: - ⑦ 분석 실패

    /// - Parameter message: 서버가 준 실패 사유. 화면이 그대로 띄운다 — 예전엔 여기서 버려져
    ///   네트워크와 무관한 오류(App Check 실패 등)도 "네트워크 연결을 확인하라"고 안내됐다.
    private func showFailure(message: String?, image: UIImage, replacing loadingVC: UIViewController) {
        let vc = AnalysisFailedVC(message: message)

        /*
         두 버튼 모두 spec 의 분기를 따른다 (spec: feature/pill-recognition/README.md §식별 → 인식 결과).

           E -->|재시도| B   재시도는 **인식으로 되돌아간다** — 같은 사진으로 다시 분석
           E -->|뒤로| X     뒤로는 **촬영/미리보기로 복귀**

         예전엔 둘 다 어긋나 있었다. 재시도가 pop 이라 사실상 spec 의 '뒤로' 였고, 뒤로는
         홈으로 나가 버려 사진을 다시 고를 기회 없이 흐름이 끊겼다("돌아갈 이전 단계가 없다"고
         적혀 있었지만, showPreview 가 push 한 PhotoPreviewVC 가 스택에 그대로 남아 있다).
         */
        vc.onBackTapped = { [weak self] in self?.navigationController.popViewController(animated: true) }
        vc.onBack = { [weak self] in self?.navigationController.popViewController(animated: true) }
        vc.onRetry = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.replace(vc, with: self.makeLoadingVC(image: image))
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
            self.trackButton("gallery", screen: "permission_denied")
            self.cameraPicker.present(from: self.navigationController, source: .photoLibrary)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Helper

    private func trackButton(_ target: String, screen: String) {
        AppAnalytics.track(.buttonTap(target: target, screen: screen))
    }

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
