#if DEBUG
import SwiftUI
import UIKit

/// 임시 아이콘 갤러리 — 새로 추가한 DSIcon 들을 여러 tintColor 로 렌더해
/// 색 변경(template tint)이 실제로 되는지 Xcode Preview 로 확인하는 용도.
/// ⚠️ 확인 후 이 파일 삭제.
struct DSIconGalleryView: View {

    private let icons: [(String, DSIcon)] = [
        // App & Domain (16)
        ("pill", .pill), ("syringe", .syringe), ("timer", .timer),
        ("clipboardList", .clipboardList), ("history", .history), ("shapes", .shapes),
        ("bellRing", .bellRing), ("stickyNote", .stickyNote), ("square", .square),
        ("heartPulse", .heartPulse), ("batteryFull", .batteryFull), ("flashlight", .flashlight),
        ("vibrate", .vibrate), ("fileSearch", .fileSearch), ("fileX", .fileX),
        ("circlePlay", .circlePlay),
        // System & State (7)
        ("signal", .signal), ("battery", .battery), ("wifiOff", .wifiOff),
        ("cameraOff", .cameraOff), ("searchX", .searchX), ("zap", .zap), ("circle", .circle),
    ]

    private let tints: [(String, UIColor)] = [
        ("primary", DSColor.Primary._500),
        ("secondary", DSColor.Secondary._500),
        ("error", DSColor.Error._500),
        ("tertiary", DSColor.textTertiary),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("DSIcon 색 변경 테스트 · \(icons.count)종")
                    .font(.headline)
                    .padding(.bottom, 10)

                HStack(spacing: 0) {
                    Text("이름").frame(width: 96, alignment: .leading)
                    ForEach(tints, id: \.0) { name, _ in
                        Text(name).frame(maxWidth: .infinity)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

                Divider()

                ForEach(icons, id: \.0) { name, icon in
                    HStack(spacing: 0) {
                        Text(name)
                            .font(.caption)
                            .frame(width: 96, alignment: .leading)
                        ForEach(tints, id: \.0) { _, color in
                            Image(uiImage: icon.uiImage)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .foregroundColor(Color(uiColor: color))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 7)
                    Divider()
                }
            }
            .padding(20)
        }
    }
}

#Preview("DSIcon Gallery") {
    DSIconGalleryView()
}
#endif
