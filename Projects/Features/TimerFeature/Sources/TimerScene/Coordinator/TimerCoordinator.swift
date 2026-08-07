import UIKit
import Combine
import BaseFeatureDependency
import Core
import Domain

// C1 리스트 → (FAB) 권한 체크 → A3 안내/거부 → C3 프리셋 시트 → 원탭 즉시 시작
public final class TimerCoordinator: BaseCoordinator {

    private var viewModel: TimerListViewModel?
    private weak var presetSheet: PresetSheetVC?
    private var cancelBag = Set<AnyCancellable>()
    private var pendingPermissionFlow = false

    public override func start() {
        // 타이머는 AlarmKit(26.1+) 전용 — 그 미만은 알람을 보장할 수 없어 안내만 띄운다.
        guard #available(iOS 26.1, *) else {
            navigationController.pushViewController(TimerUnavailableVC(), animated: false)
            return
        }

        let viewModel = TimerListViewModel()
        self.viewModel = viewModel

        let vc = TimerListVC(viewModel: viewModel)
        vc.onAddTapped = { [weak self] in self?.checkPermissionThenOpenSheet() }
        navigationController.pushViewController(vc, animated: false)

        bindPermission(viewModel)
        bindPresets(viewModel)
    }

    // MARK: - 권한 (spec: 첫 타이머 실행 직전 요청, 거부 시 시작 차단)

    private func checkPermissionThenOpenSheet() {
        pendingPermissionFlow = true
        viewModel?.fetchAlarmPermission()
    }

    private func bindPermission(_ viewModel: TimerListViewModel) {
        viewModel.transformOutputForCoordinator()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, self.pendingPermissionFlow else { return }
                self.pendingPermissionFlow = false
                switch status {
                case .authorized:
                    self.showPresetSheet()
                case .notDetermined:
                    self.showPermission(mode: .prompt)
                case .denied:
                    self.showPermission(mode: .denied)
                }
            }
            .store(in: &cancelBag)
    }

    private func bindPresets(_ viewModel: TimerListViewModel) {
        viewModel.presetsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presets in
                self?.presetSheet?.updatePresets(presets)
            }
            .store(in: &cancelBag)
    }

    private func showPermission(mode: TimerPermissionVC.Mode) {
        let vc = TimerPermissionVC(mode: mode)
        vc.onAllow = { [weak self, weak vc] in
            guard let self else { return }
            // OS 팝업 → 허용 시 시트, 거부 시 차단
            self.pendingPermissionFlow = true
            vc?.dismiss(animated: true) { self.viewModel?.requestAlarmPermission() }
        }
        vc.onLater = { [weak vc] in vc?.dismiss(animated: true) }
        vc.onOpenSettings = { [weak vc] in
            vc?.dismiss(animated: true)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
        vc.onBack = { [weak vc] in vc?.dismiss(animated: true) }
        presentAsSheet(vc, height: 325)
    }

    // MARK: - 첫 시작 — 울림 방식 선택 (YbkNe)

    // 첫 타이머 시작이면 울림 방식 시트를 먼저 띄우고, 확인 시 시작. 이후부턴 바로 시작.
    private func startPreset(_ preset: TimerPresetModel) {
        guard !RingModeStore.shared.hasChosen else {
            startTimer(preset)
            return
        }
        let ringSheet = RingModeSheetViewController()
        ringSheet.onConfirm = { [weak self] _ in self?.startTimer(preset) }
        navigationController.present(ringSheet, animated: true)
    }

    // 인앱 프리셋 원탭 시작 + 분석 이벤트(timer_start, source=iphone).
    // (위젯 딥링크·워치 시작은 각 진입점에서 별도 계측 — 후속)
    private func startTimer(_ preset: TimerPresetModel) {
        viewModel?.start(preset: preset)
        AppAnalytics.track(.timerStart(
            source: "iphone",
            presetLabel: preset.label,
            category: preset.category.displayName,
            durationSec: preset.duration
        ))
    }

    // MARK: - C3 프리셋 시트

    private func showPresetSheet() {
        let sheet = PresetSheetVC()
        presetSheet = sheet
        sheet.updatePresets(viewModel?.currentPresets ?? [])

        sheet.onSelectPreset = { [weak self, weak sheet] preset in
            sheet?.dismiss(animated: true) { self?.startPreset(preset) }
        }
        sheet.onAddPreset = { [weak self, weak sheet] in
            guard let sheet else { return }
            self?.showPresetForm(preset: nil, over: sheet)
        }
        sheet.onEditPreset = { [weak self, weak sheet] preset in
            guard let sheet else { return }
            self?.showPresetForm(preset: preset, over: sheet)
        }
        sheet.onDeletePreset = { [weak self, weak sheet] preset in
            guard let sheet else { return }
            self?.showDeleteConfirm(preset: preset, over: sheet)
        }
        presentAsSheet(sheet, height: nil)
    }

    // MARK: - C3 프리셋 추가/편집

    private func showPresetForm(preset: TimerPresetModel?, over presenter: UIViewController) {
        let vc = PresetFormVC(preset: preset)
        vc.onSave = { [weak self, weak vc] label, category, duration in
            guard let self else { return }
            if let editing = vc?.editingPreset {
                var updated = editing
                updated.label = label
                updated.category = category
                updated.duration = duration
                self.viewModel?.updatePreset(updated)
                AppAnalytics.track(.presetEdit(label: label, category: category.displayName, durationSec: duration))
            } else {
                self.viewModel?.addPreset(label: label, category: category, duration: duration)
                AppAnalytics.track(.presetCreate(label: label, category: category.displayName, durationSec: duration))
            }
            vc?.dismiss(animated: true)
        }
        vc.onCancel = { [weak vc] in vc?.dismiss(animated: true) }

        if let sheetPresentation = vc.sheetPresentationController {
            sheetPresentation.detents = [.large()]
            sheetPresentation.prefersGrabberVisible = true
        }
        presenter.present(vc, animated: true)
    }

    // MARK: - C3 삭제 확인

    private func showDeleteConfirm(preset: TimerPresetModel, over presenter: UIViewController) {
        let dim = UIView(frame: presenter.view.bounds).then {
            $0.backgroundColor = UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 0.6)
        }
        let card = PresetDeleteConfirmView()
        card.onCancel = { dim.removeFromSuperview() }
        card.onDelete = { [weak self] in
            dim.removeFromSuperview()
            self?.viewModel?.deletePreset(id: preset.id)
            AppAnalytics.track(.presetDelete(label: preset.label, category: preset.category.displayName, durationSec: preset.duration))
        }
        dim.addSubview(card)
        presenter.view.addSubview(dim)
        card.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    // MARK: - Helper

    private func presentAsSheet(_ vc: UIViewController, height: CGFloat?) {
        if let sheet = vc.sheetPresentationController {
            if let height {
                sheet.detents = [.custom { _ in height }]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.preferredCornerRadius = 24
            sheet.prefersGrabberVisible = true
        }
        navigationController.present(vc, animated: true)
    }
}

// MARK: - ViewModel Coordinator 브릿지

extension TimerListViewModel {
    func transformOutputForCoordinator() -> AnyPublisher<TimerAlarmAuthorizationStatus, Never> {
        alarmPermissionPublisher
    }
}
