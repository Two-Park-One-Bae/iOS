import UIKit
import SnapKit
import DSKit
import Domain

// ⑩ 세부정보 문서 블록(HEADING/PARAGRAPH/TABLE/IMAGE)을 UIView로 렌더하는 헬퍼.
// 서버가 이미 구조화한 블록이라 파싱 없이 그리기만 한다.
enum PillDetailRenderer {

    // MARK: - Span → AttributedString (SUP/SUB 첨자)

    static func attributedString(
        from spans: [SpanModel],
        font: UIFont,
        color: UIColor,
        lineHeightMultiple: CGFloat = 1.45
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple

        let result = NSMutableAttributedString()
        for span in spans {
            var attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
            switch span.style {
            case .sup:
                attrs[.font] = font.withSize(font.pointSize * 0.7)
                attrs[.baselineOffset] = font.pointSize * 0.35
            case .sub:
                attrs[.font] = font.withSize(font.pointSize * 0.7)
                attrs[.baselineOffset] = -font.pointSize * 0.2
            case .none:
                attrs[.font] = font
            }
            result.append(NSAttributedString(string: span.text, attributes: attrs))
        }
        return result
    }

    // MARK: - Block → View

    static func headingLabel(_ spans: [SpanModel]) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = attributedString(
            from: spans,
            font: DSKitFontFamily.Pretendard.bold.font(size: 16),
            color: DSColor.textPrimary,
            lineHeightMultiple: 1.3
        )
        return label
    }

    static func paragraphLabel(_ spans: [SpanModel]) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = attributedString(
            from: spans,
            font: DSKitFontFamily.Pretendard.regular.font(size: 14),
            color: DSColor.textSecondary
        )
        return label
    }

    static func imageView(src: String) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = DSColor.Neutral._100
        imageView.layer.cornerRadius = 8
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        if let image = decodeImage(src: src) {
            imageView.image = image
        } else if let url = URL(string: src), url.scheme?.hasPrefix("http") == true {
            // MVP는 data URI. 서버 호스팅 URL로 바뀔 수 있어 http도 처리.
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { imageView.image = image }
            }.resume()
        }
        // 원본 비율 유지 — 최대 높이만 제한
        imageView.snp.makeConstraints { $0.height.lessThanOrEqualTo(320) }
        return imageView
    }

    // data:image/png;base64,XXXX → UIImage
    private static func decodeImage(src: String) -> UIImage? {
        guard src.hasPrefix("data:"),
              let commaIndex = src.firstIndex(of: ","),
              let data = Data(base64Encoded: String(src[src.index(after: commaIndex)...]))
        else { return nil }
        return UIImage(data: data)
    }
}
