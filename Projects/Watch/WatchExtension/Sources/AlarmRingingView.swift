import SwiftUI
import TimerDomain

// W3 만료 전체화면 알림 (spec/design e0iD7H "시스템 알람").
// 검정 배경 · 원형 종(주황) · 타이머명 · 주황 [완료]. 리스트 인라인 카드(RingingCardRow)와 달리
// 화면 전체를 덮어 "울림"을 강하게 알린다. 진동은 RingingCoordinator 가 담당.
struct AlarmRingingView: View {
    let timer: TreatmentTimerModel
    let onComplete: () -> Void

    @ScaledMetric private var bell: CGFloat = 60

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 2)

            ZStack {
                Circle().fill(WT.ringingBg)
                WIcon(name: "ic_bell", size: bell * 0.48, color: WT.bell)
            }
            .frame(width: bell, height: bell)

            Text(timer.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(WT.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            Spacer(minLength: 6)

            Button(action: onComplete) {
                HStack(spacing: 6) {
                    WIcon(name: "ic_check", size: 18, color: WT.textPrimary)
                    Text("완료")
                        .font(.headline)
                        .foregroundStyle(WT.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WT.ringingAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
