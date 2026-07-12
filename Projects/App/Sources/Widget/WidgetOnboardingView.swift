import SwiftUI

// 위젯 미설정("탭하여 설정") 탭 → 위젯 설정 방법 온보딩 (NM-302).
struct WidgetOnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "lock.rectangle.on.rectangle")
                        .font(.system(size: 48)).foregroundStyle(.blue)
                        .padding(.top, 8)
                    Text("잠금화면 위젯 설정")
                        .font(.title2.bold())

                    VStack(spacing: 20) {
                        step(1, "plus.rectangle.on.rectangle", "위젯 추가",
                             "잠금화면 편집 → 위젯 영역에 ‘처치 타이머’ 를 추가하세요.")
                        step(2, "hand.tap", "위젯 누르기",
                             "위젯 편집화면에서 ‘탭하여 설정’ 위젯을 누르면 편집(설정) 화면이 열려요.")
                        step(3, "checklist", "프리셋 선택",
                             "목록에서 프리셋을 고르면 그 위젯에 표시됩니다. 위젯마다 다르게 지정할 수 있어요.")
                    }
                }
                .padding(24)
            }
            .navigationTitle("사용 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("확인") { dismiss() } }
            }
        }
    }

    private func step(_ num: Int, _ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(.blue.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("STEP \(num)").font(.caption2.bold()).foregroundStyle(.blue)
                Text(title).font(.headline)
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
