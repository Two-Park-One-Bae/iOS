import UIKit
import CoreText
import Domain

// ⑨ 식별 결과 공유 콘텐츠 생성.
//
// 사용자 인터뷰(간호사): "파일 추출해도 다시 병원 컴퓨터에 입력해야 하고, 보안 때문에
// 외부 파일이 아예 안 열리는 경우가 많다. 폰에서 쉽게 열리는 일반 텍스트나 PDF가 좋다."
// → 공유 시트에 (1) 폰에서 바로 읽고 재입력·메신저 붙여넣기 좋은 **일반 텍스트**를 기본으로,
//   (2) 문서로 필요할 때를 위한 **PDF**를 함께 제공한다.
enum PillShareComposer {

    // MARK: - Plain text

    static func plainText(
        pills: [IdentifiedPill],
        candidates: [Int: PillCandidateModel]
    ) -> String {
        let entries: [Entry] = pills.sorted { $0.index < $1.index }.map { pill in
            guard let candidate = candidates[pill.index] else { return .unselected(number: pill.index) }
            return .pill(number: pill.index, name: candidate.pillName, company: candidate.companyName, code: candidate.pillCode)
        }
        return plainText(date: Date(), entries: entries)
    }

    /// 기록 상세 공유 — 식별 결과와 같은 모양, 날짜는 식별 시각 (NM-552).
    static func plainText(history: PillHistoryModel) -> String {
        let entries: [Entry] = history.pills.enumerated().map { offset, pill in
            .pill(number: offset + 1, name: pill.pillName, company: pill.companyName, code: pill.pillCode)
        }
        return plainText(date: history.identifiedAt ?? Date(), entries: entries)
    }

    private enum Entry {
        case pill(number: Int, name: String?, company: String?, code: String)
        case unselected(number: Int)
    }

    private static func plainText(date: Date, entries: [Entry]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"

        var lines: [String] = [
            "널스메이트 · 알약 식별 결과",
            formatter.string(from: date),
            "",
            "식별된 알약 \(entries.count)개",
            "────────────────",
        ]
        for entry in entries {
            switch entry {
            case let .pill(number, name, company, code):
                lines.append("\(number). \(name ?? "이름 미상")")
                if let company, !company.isEmpty {
                    lines.append("   제조사: \(company)")
                }
                lines.append("   품목코드: \(code)")
            case let .unselected(number):
                lines.append("\(number). (후보 미선택)")
            }
            lines.append("")
        }
        lines.append("────────────────")
        lines.append("※ 참고용입니다. 실제 복약·처치는 반드시 의사·약사와 상의하세요.")
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF

    /// 텍스트를 A4 PDF 로 렌더해 임시 파일 URL 을 반환. CoreText 로 페이지 넘김 처리.
    static func pdfURL(text: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 @72dpi
        let margin: CGFloat = 44

        let body = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: "AppleSDGothicNeo-Regular", size: 13)
                    ?? UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black,
            ]
        )
        // 첫 줄(제목)만 굵게.
        if let newline = text.firstIndex(of: "\n") {
            let titleLength = text.distance(from: text.startIndex, to: newline)
            body.addAttribute(
                .font,
                value: UIFont(name: "AppleSDGothicNeo-Bold", size: 17)
                    ?? UIFont.boldSystemFont(ofSize: 17),
                range: NSRange(location: 0, length: titleLength)
            )
        }

        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("널스메이트_알약식별결과.pdf")

        UIGraphicsBeginPDFContextToFile(url.path, pageRect, nil)
        defer { UIGraphicsEndPDFContext() }

        var range = CFRange(location: 0, length: 0)
        let total = body.length
        repeat {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
            // CoreText 는 좌하단 원점 → PDF(UIKit) 좌표계를 뒤집는다.
            ctx.textMatrix = .identity
            ctx.translateBy(x: 0, y: pageRect.height)
            ctx.scaleBy(x: 1, y: -1)

            let column = CGRect(
                x: margin, y: margin,
                width: pageRect.width - margin * 2,
                height: pageRect.height - margin * 2
            )
            let path = CGMutablePath()
            path.addRect(column)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, ctx)

            let visible = CTFrameGetVisibleStringRange(frame)
            range = CFRange(location: range.location + visible.length, length: 0)
        } while range.location < total

        return url
    }
}
