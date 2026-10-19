import UIKit
import Combine
import SnapKit
import Then
import DSKit
import Domain

// 홈 (V2.1.0 — 디자인 `홈 · V2.1.0 (NM-585)` ① 기본 `nJv0k` · ② 빈 상태 · ③ 한도 소진 · ④ 타이머 많음 · ⑤ 일시정지 · ⑥ 남은 횟수 모름)
// 위에서 아래로: 워드마크 → 기능 카드 두 장 → 진행 중인 타이머 → 최근 식별.
// 카드는 내용이 없어도 자리를 지킨다 — 타이머가 생기거나 없어져도 아래 카드가 위아래로 움직이지 않게.
public final class HomeVC: UIViewController {

    // MARK: - Properties

    private let viewModel: HomeViewModel
    private var cancelBag = Set<AnyCancellable>()

    private let viewWillAppearSubject = PassthroughSubject<Void, Never>()
    private let captureSubject = PassthroughSubject<Void, Never>()
    private let pillCardSubject = PassthroughSubject<Void, Never>()
    private let newTimerSubject = PassthroughSubject<Void, Never>()
    private let timerCardSubject = PassthroughSubject<Void, Never>()
    private let recentHistorySubject = PassthroughSubject<Void, Never>()

    /// 남은 시간은 초 단위로 줄어든다 — 화면이 보이는 동안만 1초마다 다시 그린다.
    private var ticker: Timer?
    private var timerList = HomeViewModel.TimerList(rows: [], totalCount: 0)

    // MARK: - UI

    private let scrollView = UIScrollView().then {
        $0.showsVerticalScrollIndicator = false
        $0.alwaysBounceVertical = true
    }

    private let contentStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 18
    }

    private let pillTile = HomeTile(title: "알약 식별", icon: .pill, iconTint: DSColor.Primary._500, label: "오늘 남은 횟수")
    private let timerTile = HomeTile(title: "처치 타이머", icon: .timer, iconTint: DSColor.Secondary._500, label: "진행 중인 타이머")
    private let captureButton = HomeTileButton(title: "사진 찍기", icon: .camera)
    private let newTimerButton = HomeTileButton(title: "새 타이머", icon: .plus)
    private let timersCard = HomeTimersCard()
    private let recentRow = DSListRow(style: .compact, icon: .history, title: "", subtitle: "최근 식별")

    // MARK: - Init

    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.surface
        setLayout()
        bind()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 식별을 마치고 돌아왔을 때 남은 횟수 · 최근 식별을 갱신한다.
        viewWillAppearSubject.send()
        startTicker()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - Layout

    private func setLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints {
            $0.top.equalTo(scrollView.contentLayoutGuide).offset(8)
            $0.bottom.equalTo(scrollView.contentLayoutGuide).offset(-20)
            $0.leading.trailing.equalTo(scrollView.frameLayoutGuide).inset(20)
        }

        let wordmark = UIImageView(image: DSBrandImage.wordmark.uiImage).then {
            $0.contentMode = .scaleAspectFit
            $0.accessibilityLabel = "NurseMate"
        }
        wordmark.snp.makeConstraints {
            $0.width.equalTo(152)
            $0.height.equalTo(26)
        }
        let header = UIStackView(arrangedSubviews: [wordmark, UIView()]).then {
            $0.axis = .horizontal
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 8, right: 0)
        }

        pillTile.setAction(captureButton)
        timerTile.setAction(newTimerButton)
        let tiles = UIStackView(arrangedSubviews: [pillTile, timerTile]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.distribution = .fillEqually
        }
        tiles.snp.makeConstraints { $0.height.equalTo(204) }

        [header, tiles, timersCard, recentRow].forEach(contentStack.addArrangedSubview)

        captureButton.addAction(UIAction { [weak self] _ in self?.captureSubject.send() }, for: .touchUpInside)
        newTimerButton.addAction(UIAction { [weak self] _ in self?.newTimerSubject.send() }, for: .touchUpInside)
        pillTile.addAction(UIAction { [weak self] _ in self?.pillCardSubject.send() }, for: .touchUpInside)
        timerTile.addAction(UIAction { [weak self] _ in self?.timerCardSubject.send() }, for: .touchUpInside)
        timersCard.addAction(UIAction { [weak self] _ in self?.timerCardSubject.send() }, for: .touchUpInside)
        recentRow.onTap { [weak self] in self?.recentHistorySubject.send() }
    }

    // MARK: - Bind

    private func bind() {
        let output = viewModel.transform(input: .init(
            viewWillAppear: viewWillAppearSubject.eraseToAnyPublisher(),
            captureTapped: captureSubject.eraseToAnyPublisher(),
            pillCardTapped: pillCardSubject.eraseToAnyPublisher(),
            newTimerTapped: newTimerSubject.eraseToAnyPublisher(),
            timerCardTapped: timerCardSubject.eraseToAnyPublisher(),
            recentHistoryTapped: recentHistorySubject.eraseToAnyPublisher()
        ))

        output.usage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.renderUsage($0) }
            .store(in: &cancelBag)

        output.timerCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.timerTile.setValue("\(count)", unit: "개", caption: nil)
            }
            .store(in: &cancelBag)

        output.timerList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.timerList = list
                self?.timersCard.render(list)
            }
            .store(in: &cancelBag)

        output.recentHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.renderRecent($0) }
            .store(in: &cancelBag)
    }

    // MARK: - Render

    /// - 1회 이상: `12/15`, `매일 00:00 초기화`
    /// - 0회: 숫자와 초기화 줄을 경고색으로 `내일 00:00 초기화`, `사진 찍기` 비활성(팝업 없음)
    /// - 모름: `–`, `사진 찍기`는 활성 — 막을지는 서버가 판정한다
    private func renderUsage(_ usage: PillUsageModel?) {
        guard let usage else {
            pillTile.setValue("–", unit: nil, caption: HomeText.resetCaption(resetAt: nil, exhausted: false))
            captureButton.isEnabled = true
            return
        }
        let exhausted = usage.isExhausted
        pillTile.setValue(
            "\(usage.remaining)",
            unit: "/\(usage.limit)",
            caption: HomeText.resetCaption(resetAt: usage.resetAt, exhausted: exhausted),
            warning: exhausted
        )
        captureButton.isEnabled = !exhausted
    }

    private func renderRecent(_ state: HomeViewModel.RecentHistory) {
        switch state {
        case .loading:
            // 처음 들어와 응답을 기다리는 동안 — 자리만 지킨다.
            recentRow.setSubtitle("최근 식별")
            recentRow.setTitle(" ")
            recentRow.setTitleAccessory(nil)
            recentRow.setChevronHidden(true)
        case .item(let summary):
            let time = summary.identifiedAt.map(HomeText.recentTime)
            recentRow.setSubtitle(time.map { "최근 식별 · \($0)" } ?? "최근 식별")
            recentRow.setTitle(summary.firstPillName)
            recentRow.setTitleAccessory(summary.othersText)
            recentRow.setTitleColor(DSColor.textPrimary)
            recentRow.setChevronHidden(false)
        case .empty:
            renderRecentMessage("아직 식별 기록이 없어요")
        case .failed:
            renderRecentMessage("기록을 불러오지 못했어요")
        }
    }

    /// 기록이 없거나 불러오지 못했을 때 — 카드는 누르지 않는다(chevron 숨김, 눌러도 VM 이 무시).
    private func renderRecentMessage(_ text: String) {
        recentRow.setSubtitle("최근 식별")
        recentRow.setTitle(text)
        recentRow.setTitleAccessory(nil)
        recentRow.setTitleColor(DSColor.textTertiary)
        recentRow.setChevronHidden(true)
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, !self.timerList.rows.isEmpty else { return }
            self.timersCard.updateTimes()
        }
    }
}

// MARK: - Text

enum HomeText {

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    /// `매일 00:00 초기화` · 0회면 `내일 00:00 초기화`. 시각은 `resetAt`(기기 시간대), 모르면 00:00.
    static func resetCaption(resetAt: Date?, exhausted: Bool) -> String {
        let time = resetAt.map { formatter("HH:mm").string(from: $0) } ?? "00:00"
        return "\(exhausted ? "내일" : "매일") \(time) 초기화"
    }

    /// 최근 식별 시각: 오늘 `오후 2:14` · 어제 `어제 오후 6:40` · 그 전 `10월 7일` · 올해가 아니면 `2025년 10월 7일`.
    static func recentTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let time = formatter("a h:mm").string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제 \(time)"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? "M월 d일" : "yyyy년 M월 d일").string(from: date)
    }

    /// 전체 시간: 900→`15분`, 7200→`2시간`, 5400→`1시간 30분`
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }

    /// 남은 시간: 754→`12:34`, 4360→`1:12:40`
    static func countdown(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Tile

/// 기능 카드(유리) — 제목 · 아이콘 / 라벨 · 큰 숫자 · 단위 / 보조 줄 / 버튼. 높이 204, padding 16, gap 14.
/// 카드 자체가 눌리고(탭 이동), 안의 버튼은 따로 눌린다.
private final class HomeTile: UIControl {

    private let surface = DSSurfaceView(spec: .glassCard)
    // 한도가 큰 계정(dev)처럼 숫자가 길면 카드 폭에 맞춰 줄인다 — 단위는 잘리지 않게 둔다.
    private let numberLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 34)
        $0.textColor = DSColor.textPrimary
        $0.adjustsFontSizeToFitWidth = true
        $0.minimumScaleFactor = 0.4
        $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    private let unitLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 14)
        $0.textColor = DSColor.textSecondary
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    private let captionLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 11)
        $0.textColor = DSColor.textTertiary
    }
    private let stack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 14
    }

    init(title: String, icon: DSIcon, iconTint: UIColor, label: String) {
        super.init(frame: .zero)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        let titleLabel = UILabel().then {
            $0.text = title
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 15)
            $0.textColor = DSColor.textPrimary
        }
        let iconView = UIImageView(image: icon.uiImage).then {
            $0.tintColor = iconTint
            $0.contentMode = .scaleAspectFit
        }
        iconView.snp.makeConstraints { $0.width.height.equalTo(22) }
        let top = UIStackView(arrangedSubviews: [titleLabel, UIView(), iconView]).then {
            $0.axis = .horizontal
            $0.alignment = .center
        }

        let labelView = UILabel().then {
            $0.text = label
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
        // 단위는 숫자 바닥에서 7pt 올린다(디자인 Unit Wrap).
        let unitWrap = UIView()
        unitWrap.addSubview(unitLabel)
        unitLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(7)
        }
        let value = UIStackView(arrangedSubviews: [numberLabel, unitWrap, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 2
            $0.alignment = .bottom
        }
        let number = UIStackView(arrangedSubviews: [labelView, value, captionLabel, UIView()]).then {
            $0.axis = .vertical
        }

        [top, number].forEach(stack.addArrangedSubview)
        stack.isUserInteractionEnabled = true
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setAction(_ button: UIView) {
        stack.addArrangedSubview(button)
    }

    func setValue(_ number: String, unit: String?, caption: String?, warning: Bool = false) {
        numberLabel.text = number
        numberLabel.textColor = warning ? DSColor.Error._600 : DSColor.textPrimary
        unitLabel.text = unit
        unitLabel.isHidden = unit == nil
        captionLabel.text = caption
        captionLabel.isHidden = caption == nil
        captionLabel.textColor = warning ? DSColor.Error._600 : DSColor.textTertiary
    }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }

    // 카드 안의 글 · 숫자는 누름을 받지 않고 카드로 넘긴다 — 버튼만 따로 받는다.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if let hit, hit is UIControl { return hit }
        return hit == nil ? nil : self
    }
}

/// 기능 카드 안의 버튼 — 흰 볼록, padding (9, 12), 아이콘 17 · Bold 13 Primary700.
/// 비활성(한도 소진): Neutral100 평면 + Neutral200 테두리, 내용 45%.
private final class HomeTileButton: UIButton {

    private let surface = DSSurfaceView(spec: .raisedNeutral(), cornerRadius: DSRadius.md)

    init(title: String, icon: DSIcon) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.Primary._700
        config.background.backgroundColor = .clear
        // 아이콘 에셋은 24pt 기준 — 17pt 로 줄여 템플릿으로 그린다.
        let size = CGSize(width: 17, height: 17)
        config.image = UIGraphicsImageRenderer(size: size).image { _ in
            icon.uiImage.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        var attributed = AttributedString(title)
        attributed.font = DSKitFontFamily.Pretendard.bold.font(size: 13)
        config.attributedTitle = attributed
        config.titleLineBreakMode = .byTruncatingTail
        configuration = config

        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(surface, at: 0)

        configurationUpdateHandler = { [weak self] button in
            guard let self else { return }
            let disabled = !button.isEnabled
            self.surface.spec = disabled
                ? .flat(DSColor.Neutral._100, stroke: DSColor.Neutral._200)
                : .raisedNeutral()
            self.surface.alpha = button.isHighlighted ? 0.85 : 1
            var updated = button.configuration
            updated?.baseForegroundColor = DSColor.Primary._700.withAlphaComponent(disabled ? 0.45 : 1)
            button.configuration = updated
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Timers Card

/// 진행 중인 타이머 — 최대 3줄. 4개 이상이면 제목 오른쪽 `전체 보기`. 없으면 `진행 중인 타이머가 없어요`(누르지 않는다).
private final class HomeTimersCard: UIControl {

    private let surface = DSSurfaceView(spec: .glassCard)
    private let allLabel = UILabel().then {
        $0.text = "전체 보기"
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 13)
        $0.textColor = DSColor.Primary._700
    }
    private let rowsStack = UIStackView().then { $0.axis = .vertical }
    private var rows: [HomeTimerRow] = []

    init() {
        super.init(frame: .zero)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        let title = UILabel().then {
            $0.text = "진행 중인 타이머"
            $0.font = DSKitFontFamily.Pretendard.bold.font(size: 16)
            $0.textColor = DSColor.textPrimary
        }
        let head = UIStackView(arrangedSubviews: [title, UIView(), allLabel]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)
        }
        let stack = UIStackView(arrangedSubviews: [head, rowsStack]).then {
            $0.axis = .vertical
            $0.isUserInteractionEnabled = false
        }
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalToSuperview().inset(6)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func render(_ list: HomeViewModel.TimerList) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows = list.rows.map { HomeTimerRow(timer: $0) }
        allLabel.isHidden = !list.showsAll
        isEnabled = !list.rows.isEmpty

        guard !rows.isEmpty else {
            let empty = UILabel().then {
                $0.text = "진행 중인 타이머가 없어요"
                $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
                $0.textColor = DSColor.textTertiary
            }
            let wrap = UIView()
            wrap.addSubview(empty)
            empty.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 0, bottom: 14, right: 0)) }
            rowsStack.addArrangedSubview(wrap)
            return
        }
        rows.forEach(rowsStack.addArrangedSubview)
    }

    func updateTimes() {
        rows.forEach { $0.update() }
    }

    override var isHighlighted: Bool {
        didSet { surface.alpha = isHighlighted ? 0.85 : 1 }
    }
}

/// 타이머 한 줄 — 진행 원 44 · 라벨 + 분류 태그 / 설정 시간 · 남은 시간 20.
/// 만료: 진행 원 · 남은 시간 살구색(`00:00`). 일시정지: 회색, 설정 시간 뒤 `· 일시정지`.
private final class HomeTimerRow: UIView {

    private let timer: TreatmentTimerModel
    private let ring = HomeProgressRing()
    private let timeLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 20)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        $0.setContentHuggingPriority(.required, for: .horizontal)
    }

    init(timer: TreatmentTimerModel) {
        self.timer = timer
        super.init(frame: .zero)

        let name = UILabel().then {
            $0.text = timer.label
            $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
            $0.textColor = DSColor.textPrimary
            $0.lineBreakMode = .byTruncatingTail
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let tag = DSTag(text: timer.category.displayName, style: Self.tagStyle(timer.category))
        let nameRow = UIStackView(arrangedSubviews: [name, tag, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 6
            $0.alignment = .center
        }
        let sub = UILabel().then {
            let duration = HomeText.duration(timer.duration)
            $0.text = timer.state == .paused ? "\(duration) · 일시정지" : duration
            $0.font = DSKitFontFamily.Pretendard.regular.font(size: 12)
            $0.textColor = DSColor.textSecondary
        }
        let texts = UIStackView(arrangedSubviews: [nameRow, sub]).then {
            $0.axis = .vertical
            $0.spacing = 1
        }
        ring.snp.makeConstraints { $0.width.height.equalTo(44) }

        let row = UIStackView(arrangedSubviews: [ring, texts, timeLabel]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
        }
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)) }
        update()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(now: Date = Date()) {
        let remaining = timer.remainingSeconds(at: now)
        // 진행 중이어도 끝에 닿으면 만료로 보인다 — 상태 전이는 타이머 쪽이 맡는다.
        let expired = timer.state == .ringing || (timer.state == .running && remaining == 0)
        let color: UIColor
        if expired {
            color = DSColor.Caution._500
        } else if timer.state == .paused {
            color = DSColor.Neutral._400
        } else {
            color = DSColor.Primary._500
        }
        ring.set(progress: timer.duration > 0 ? CGFloat(remaining) / CGFloat(timer.duration) : 0, color: color)
        timeLabel.text = HomeText.countdown(expired ? 0 : remaining)
        timeLabel.textColor = expired ? DSColor.Caution._600 : (timer.state == .paused ? DSColor.textTertiary : DSColor.textPrimary)
    }

    private static func tagStyle(_ category: TimerCategory) -> DSTag.Style {
        switch category {
        case .medication:  return .primary
        case .treatment:   return .secondary
        case .examination: return .info
        }
    }
}

/// 진행 원 — 트랙 Neutral100, 두께 4. 12시에서 시계 방향으로 남은 비율만큼 채운다.
private final class HomeProgressRing: UIView {

    private let track = CAShapeLayer()
    private let progress = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        [track, progress].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.lineWidth = 4
            $0.lineCap = .round
            layer.addSublayer($0)
        }
        track.strokeColor = DSColor.Neutral._100.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = (min(bounds.width, bounds.height) - track.lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        [track, progress].forEach {
            $0.frame = bounds
            $0.path = path
        }
    }

    func set(progress value: CGFloat, color: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progress.strokeEnd = max(0, min(1, value))
        progress.strokeColor = color.cgColor
        CATransaction.commit()
    }
}
