import UIKit
import Combine
import BaseFeatureDependency
import Core
import Domain
import DSKit
import DrugIdentificationFeatureInterface

public final class DrugIdentificationCoordinator: BaseCoordinator {

    /// 식별을 어디서 시작했나 — 끝내거나 그만두면 그 화면으로 돌아간다 (spec: "들어온 화면 (홈 / 알약 탭)").
    private enum Entry {
        case home
        case pillTab
    }

    private let cameraPicker: CameraPicker = {
        let picker = CameraPicker()
        picker.squareMode = true
        // Jetsam 방지: 12MP 원본이 프리뷰·추론·결과 화면에 그대로 상주하지 않도록 진입 시 축소.
        // 추론 입력은 내부적으로 576px, 썸네일은 작게 표시 → 2048이면 화질 여유 충분.
        picker.maxOutputDimension = 2048
        return picker
    }()

    private var pillTabObserver: NSObjectProtocol?
    private var captureObserver: NSObjectProtocol?
    private var entry: Entry = .pillTab
    private weak var listVC: PillHistoryListVC?
    /// 지금 식별의 기록 id — 결과 화면이 열릴 때 만들어 저장 · 다시 시도까지 같은 값을 쓴다
    /// (같은 id 로 다시 보내면 통째로 바뀌어 중복 기록이 생기지 않는다 — spec: domains/history.md).
    private var historyId: String?
    /// 지금 사진의 학습용 라벨 키(UUID v7, NM-568) — 사진을 고를 때 만들고 다시 분석해도 같은 값을 쓴다.
    /// 학습 데이터를 보내지 않는 빌드(내부 빌드)면 nil 이고, 원본 업로드 · 라벨을 모두 건너뛴다.
    private var imageId: String?
    /// 수동 추가 알약의 라벨 번호(100부터) — 결과 화면의 알약 index → pillIndex. 다시 고쳐 `선택` 해도 같은 번호로 보낸다.
    private var manualLabelIndexes: [Int: Int] = [:]

    /// 알약별 체류시간 누적기 — `PillEditVC` 가 매번 새로 만들어져도 값이 이어지도록 여기서 소유한다.
    /// 이 Coordinator 는 탭당 하나로 앱 수명 내내 살아 있어서, 새 인식 세션마다 `reset()` 해야
    /// 이전 사진의 알약 순번과 누적값이 섞이지 않는다.
    private let dwellTracker = PillDwellTracker()

    public override func start() {
        setupOverlay()
        setupCameraPickerCallbacks()

        // 알약 탭의 루트 — 촬영 버튼 + 식별 기록 목록 (NM-552). 촬영은 이 위에 모달로 뜬다.
        let list = PillHistoryListVC(viewModel: PillHistoryListViewModel())
        listVC = list
        list.onCaptureTapped = { [weak self] in
            self?.trackButton("capture", screen: "pill_history")
            self?.startCapture(from: .pillTab)
        }
        list.onSelectHistory = { [weak self] summary in
            self?.showHistoryDetail(summary)
        }
        navigationController.setViewControllers([list], animated: false)

        // 알약 탭 진입 — 목록 화면이 잔여 횟수를 보이므로 갱신하고, 촬영에 대비해 모델을 미리 연다.
        // 카메라는 띄우지 않는다: 알약 탭은 기록 목록이고, 촬영은 촬영 버튼으로 시작한다.
        pillTabObserver = NotificationCenter.default.addObserver(
            forName: .pillTabSelected, object: nil, queue: .main
        ) { [weak self] _ in
            // 조회 전용이라 카운트는 늘지 않는다(NM-331).
            self?.pillUseCase.fetchPillUsage()
            // 각인·마크 모델을 촬영하는 동안 미리 연다 — 마크 ANE 첫 컴파일이 수 초 걸린다.
            PillFaceAnalyzer.shared.prewarm()
        }

        // 홈 '알약 식별' 카드 → 곧장 촬영. 끝나면 홈으로 돌아간다.
        captureObserver = NotificationCenter.default.addObserver(
            forName: .startPillCapture, object: nil, queue: .main
        ) { [weak self] _ in
            self?.startCapture(from: .home)
        }
    }

    deinit {
        if let pillTabObserver { NotificationCenter.default.removeObserver(pillTabObserver) }
        if let captureObserver { NotificationCenter.default.removeObserver(captureObserver) }
    }

    /// 알약 탭 루트에서(식별 결과 등이 push되지 않았고 모달도 없을 때) 카메라를 present.
    private func startCapture(from entry: Entry) {
        guard navigationController.presentedViewController == nil,
              navigationController.viewControllers.count <= 1 else { return }
        self.entry = entry
        PillFaceAnalyzer.shared.prewarm()

        /*
         진입 게이트 (spec: feature/pill-recognition/README.md §식별 횟수 제한 §흐름 규칙
         "식별 진입 시점(홈 '알약 식별' 카드 / 알약 탭 촬영 버튼)에 … 0이면 안내 팝업을 띄우고 진입하지 않는다").

         값을 모르면 통과한다 — 최종 판정은 서버 429 다(spec: "잔여 미확인 시 통과").

         막을 때는 들어온 화면에 머문다 — 홈에서 왔으면 홈으로 되돌리고, 알약 탭이면 기록 목록이 그대로 보인다.
         (미리보기에서 막힌 경우도 화면을 유지한다 — 거긴 찍은 사진이 있고, 잔여 0회를
          경고색으로 보여 주는 자리다.)
         */
        if let usage = pillUseCase.pillUsage.value, usage.isExhausted {
            if entry == .home { NotificationCenter.default.post(name: .selectHomeTab, object: nil) }
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
        cameraPicker.squareGuideCenterY = overlay.squareFrame.midY
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
            // 촬영 취소 → 들어온 화면으로 (홈 / 알약 탭 기록 목록).
            self?.exitToEntry()
        }
    }

    @Injected private var pillUseCase: PillUseCase
    @Injected private var historyUseCase: PillHistoryUseCase
    @Injected private var labelUseCase: PillLabelUseCase
    private var cancelBag = Set<AnyCancellable>()

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
        // 사진 한 장에 id 하나 — 같은 값을 원본 업로드와 속성 추출에 보낸다(spec label.md 단위와 키).
        imageId = AppEnvironment.collectsTrainingData ? PillImageId.make() : nil
        navigationController.pushViewController(makeLoadingVC(image: image), animated: true)
    }

    /// 로딩 화면 + 분석 VM 한 벌.
    ///
    /// 최초 진입은 push 로, **실패 후 재시도는 실패 화면과 replace** 해서 쓴다 —
    /// 재시도가 같은 사진으로 분석을 처음부터(온디바이스 탐지 + 서버 왕복) 다시 돌려야 하는데,
    /// VM 은 이미 종료 상태를 방출한 뒤라 재사용할 수 없다.
    private func makeLoadingVC(image: UIImage) -> PillLoadingVC {
        // 재시도도 같은 imageId — 서버는 아직 UNCONFIRMED 인 행과 위치만 덮어쓴다.
        let viewModel = DrugIdentificationViewModel(image: image, imageId: imageId)
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
        manualLabelIndexes = [:]
        // 기록 id 는 앱이 만든다 — 응답은 소문자라 처음부터 소문자로 둔다 (spec: domains/history.md).
        historyId = UUID().uuidString.lowercased()
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
            self?.exitToEntry()
        }
        vc.onSelectPill = { [weak self] pill in
            self?.showEdit(pill: pill)
        }
        vc.onAddPill = { [weak self] in
            self?.trackButton("add_pill", screen: "identify_result")
            self?.showManualAdd()
        }
        // 완료 → 기록 저장 → 들어온 화면으로 (NM-552 · NM-587). 결과 화면이 최종 결과를 겸한다.
        vc.onComplete = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.saveHistory(from: vc)
        }
        // 식별 완료 카드 ⓘ → 세부정보 (NM-317)
        vc.onSelectDetail = { [weak self] pillCode, licenseStatus in
            self?.trackButton("pill_detail", screen: "identify_result")
            self?.showPillDetail(pillCode: pillCode, licenseStatus: licenseStatus)
        }
        replace(loadingVC, with: vc)
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
        guard let resultVC else { return }
        let isManual = resultVC.isManual(pill.index)
        let viewModel = PillEditViewModel(
            pillIndex: pill.index,
            displayNumber: resultVC.displayNumber(of: pill.index),
            // 전에 고친 조건이 있으면 이어서 연다 — 없으면 모델 출력으로 시작.
            conditions: resultVC.conditions(of: pill),
            editRecord: resultVC.editRecord(of: pill.index),
            thumbnail: pill.thumbnail,
            isManual: isManual
        )
        var latest = viewModel.conditions
        let vc = PillEditVC(viewModel: viewModel)
        vc.dwellTracker = dwellTracker
        vc.onConditionsChanged = { [weak resultVC] conditions in
            latest = conditions
            resultVC?.store(conditions, for: pill.index)
        }
        vc.onEditRecordChanged = { [weak resultVC] record in
            resultVC?.store(record, for: pill.index)
        }
        vc.onBackTapped = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        vc.onConfirm = { [weak self] candidate in
            self?.resultVC?.applySelection(
                pillIndex: pill.index,
                candidate: candidate
            )
            self?.sendLabel(index: pill.index, modelPill: isManual ? nil : pill, candidate: candidate, conditions: latest)
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
        // 사진이 없는 알약 — 모델 출력 없이 모든 칸 `전체`, 펼친 상태로 시작.
        let viewModel = PillEditViewModel(
            pillIndex: index,
            displayNumber: resultVC.nextDisplayNumber(),
            conditions: PillConditions(model: .empty),
            thumbnail: nil,
            isManual: true
        )
        var latest = viewModel.conditions
        let vc = PillEditVC(viewModel: viewModel)
        vc.onConditionsChanged = { latest = $0 }
        vc.onBackTapped = { [weak self] in self?.navigationController.popViewController(animated: true) }
        // 빈 입력으로 후보 선택·확정 시에만 결과 목록에 새 카드로 추가 (취소 시 미추가)
        vc.onConfirm = { [weak self] candidate in
            self?.resultVC?.addManualPill(index: index, candidate: candidate)
            self?.resultVC?.store(latest, for: index)   // 다시 열면 고친 조건 그대로
            self?.sendLabel(index: index, modelPill: nil, candidate: candidate, conditions: latest)
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
        vc.onBackTapped = { [weak self] in self?.exitToEntry() }
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

    /// 식별을 끝내거나 그만두고 들어온 화면으로 돌아간다 — 홈이면 홈 탭, 알약 탭이면 기록 목록.
    private func exitToEntry() {
        navigationController.popToRootViewController(animated: false)
        if entry == .home {
            NotificationCenter.default.post(name: .selectHomeTab, object: nil)
        }
        entry = .pillTab
        historyId = nil
        imageId = nil
    }

    // MARK: - 학습용 라벨 (NM-568)

    /// 후보를 `선택` 하고 돌아올 때 그 알약 하나를 보낸다. 베스트 에포트 — 실패해도 화면에 아무것도 띄우지 않는다.
    ///
    /// - Parameters:
    ///   - index: 결과 화면의 알약 index.
    ///   - modelPill: 모델이 찾은 알약이면 그 알약. 수동 추가 알약이면 nil.
    ///   - conditions: 마지막으로 찾은 조건 — 그 후보 조회 요청이 `userInput` 이다.
    private func sendLabel(index: Int, modelPill: IdentifiedPill?, candidate: PillCandidateModel, conditions: PillConditions) {
        guard let imageId else { return }

        let pillIndex: Int
        let model: PillCandidateQuery?
        if let modelPill {
            // 속성 추출에 보낸 pillId 그대로 — 카드를 지워 화면 번호가 당겨져도 바뀌지 않는다.
            guard let id = Int(modelPill.pillId), PillLabelIndex.model.contains(id) else { return }
            pillIndex = id
            // 첫 후보 조회 요청 = 모델 출력으로 연 조건의 요청(사용자가 아무것도 고치기 전).
            model = PillConditions(model: modelPill.modelOutput).query
        } else {
            let next = PillLabelIndex.manual.lowerBound + manualLabelIndexes.count
            let assigned = manualLabelIndexes[index] ?? next
            guard PillLabelIndex.manual.contains(assigned) else { return }
            manualLabelIndexes[index] = assigned
            pillIndex = assigned
            model = nil
        }

        labelUseCase.sendLabel(
            imageId: imageId,
            pillIndex: pillIndex,
            label: PillLabelModel(
                pillCode: candidate.pillCode,
                manual: modelPill == nil,
                model: model,
                userInput: conditions.query
            )
        )
    }

    // MARK: - ⑤ 완료 → 기록 저장 (NM-552)

    /// 확정한 품목을 화면 순서대로 저장한다. 성공하면 들어온 화면으로, 실패하면 화면에 남아 모달을 띄운다.
    private func saveHistory(from vc: DrugIdentificationVC) {
        // 지운 번호는 `완료` 때만 보낸다 — 저장하지 않고 나간 사진은 비어(null) 있어 끝까지 본 사진인지 가른다(NM-568).
        // 기록 저장과는 따로 가는 베스트 에포트다. 다시 시도로 또 와도 서버가 덮어쓴다.
        if let imageId {
            labelUseCase.sendDeletedIndexes(imageId: imageId, deletedIndexes: vc.deletedModelPillIds())
        }
        let pillCodes = vc.finalizedResults().map(\.candidate.pillCode)
        guard let historyId, !pillCodes.isEmpty else {
            exitToEntry()
            return
        }
        vc.setSaving(true)
        historyUseCase.saveHistory(historyId: historyId, pillCodes: pillCodes)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak vc] completion in
                guard case .failure(let error) = completion, let self, let vc else { return }
                vc.setSaving(false)
                // 400 은 같은 요청이 같은 결과라 다시 시도를 두지 않는다.
                vc.showSaveFailure(
                    canRetry: !(error is PillHistoryRejectedError),
                    onExit: { [weak self] in self?.exitToEntry() },
                    onRetry: { [weak self, weak vc] in
                        guard let vc else { return }
                        self?.saveHistory(from: vc)
                    }
                )
            } receiveValue: { [weak self, weak vc] in
                guard let self else { return }
                // 완주(완료 버튼) — 미확정이 남았어도 종료 확인을 거쳐 끝낸 경우를 함께 세고, 남긴 수를 싣는다.
                if let s = vc?.identificationSummary() {
                    AppAnalytics.track(.pillIdentifyComplete(
                        detectedCount: s.detectedCount, confirmedCount: s.confirmedCount,
                        unconfirmedCount: s.unconfirmedCount,
                        deletedCount: s.deletedCount, manualAddedCount: s.manualAddedCount))
                }
                self.exitToEntry()
            }
            .store(in: &cancelBag)
    }

    // MARK: - 기록 상세 (NM-552)

    private func showHistoryDetail(_ summary: PillHistorySummaryModel) {
        trackButton("history_item", screen: "pill_history")
        let coordinator = PillHistoryDetailCoordinator(navigationController: navigationController, summary: summary)
        coordinator.onFinish = { [weak self, weak coordinator] exit in
            guard let self else { return }
            if let coordinator { self.removeChild(coordinator) }
            // 목록은 보일 때마다 다시 받으므로 지웠거나 없어진 기록은 돌아오면 빠진다.
            if exit == .notFound {
                self.listVC?.showToast("기록을 찾을 수 없어요")
            }
        }
        addChild(coordinator)
        coordinator.start()
    }

    // MARK: - ③ 권한 거부

    private func showPermissionDenied() {
        let vc = PermissionDeniedVC()
        // 뒤로가기 → 들어온 화면으로 (홈 / 알약 탭 기록 목록).
        vc.onBackTapped = { [weak self] in self?.exitToEntry() }
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
