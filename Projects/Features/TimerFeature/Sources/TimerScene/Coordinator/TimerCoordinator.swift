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

    // MARK: - C3 프리셋 시트

    private func showPresetSheet() {
        let sheet = PresetSheetVC()
        presetSheet = sheet
        sheet.updatePresets(viewModel?.currentPresets ?? [])

        sheet.onSelectPreset = { [weak self, weak sheet] preset in
            self?.viewModel?.start(preset: preset) // 원탭 즉시 시작
            sheet?.dismiss(animated: true)
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
            } else {
                self.viewModel?.addPreset(label: label, category: category, duration: duration)
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
