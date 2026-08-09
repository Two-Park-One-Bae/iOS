import UIKit
import Domain

// 런처 위젯 진입 — 전체 프리셋 중 하나를 골라 타이머 시작 (NM-302). 네이티브 UIKit.
final class TimerQuickStartPickerViewController: UITableViewController {

    private let presets: [TimerPresetModel]
    private let onStart: (TimerPresetModel) -> Void

    init(presets: [TimerPresetModel], onStart: @escaping (TimerPresetModel) -> Void) {
        self.presets = presets
        self.onStart = onStart
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "타이머 시작"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let preset = presets[indexPath.row]
        cell.textLabel?.text = preset.label
        cell.detailTextLabel?.text = durationText(preset.duration)
        cell.imageView?.image = UIImage(systemName: "play.circle.fill")
        cell.imageView?.tintColor = .systemBlue
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 닫기는 호출측(SceneDelegate)이 처리한다 — 알람 권한 시트를 이어서 띄우므로
        // 여기서 self를 dismiss하면 표시 충돌이 난다 (NM-360).
        onStart(presets[indexPath.row])
    }

    private func durationText(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}
