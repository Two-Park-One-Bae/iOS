import UIKit
import SnapKit
import DSKit
import Domain

// TABLE 블록 렌더 — HTML 표 병합 시맨틱(colspan/rowspan). 병합 셀은 시작 슬롯에 한 번만,
// 점유된 나머지 슬롯은 빈 셀로 그려 열 정렬을 유지한다(true 세로 병합은 MVP 근사).
final class PillDetailTableView: UIView {

    private struct Placement {
        let cell: TableCellModel
        let row: Int
        let col: Int
    }

    init(rows: [TableRowModel], caption: [SpanModel]?) {
        super.init(frame: .zero)
        build(rows: rows, caption: caption)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(rows: [TableRowModel], caption: [SpanModel]?) {
        let (placements, columnCount, rowCount) = layout(rows: rows)
        guard columnCount > 0, rowCount > 0 else { return }

        // 시작 슬롯 조회용: [row][col] → placement
        var originAt: [[Placement?]] = Array(
            repeating: Array(repeating: nil, count: columnCount),
            count: rowCount
        )
        for p in placements { originAt[p.row][p.col] = p }

        let table = UIStackView()
        table.axis = .vertical
        table.spacing = 0
        table.layer.borderWidth = 0.5
        table.layer.borderColor = DSColor.border.cgColor
        table.layer.cornerRadius = 8
        table.clipsToBounds = true

        for r in 0..<rowCount {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 0
            rowStack.distribution = .fill

            var c = 0
            while c < columnCount {
                if let p = originAt[r][c] {
                    let cellView = makeCell(p.cell)
                    rowStack.addArrangedSubview(cellView)
                    cellView.snp.makeConstraints {
                        $0.width.equalTo(rowStack.snp.width).multipliedBy(CGFloat(p.cell.colspan) / CGFloat(columnCount))
                    }
                    c += max(1, p.cell.colspan)
                } else {
                    // 점유(rowspan 아래) 또는 빈 슬롯 — 정렬 유지용 빈 셀
                    let filler = makeCell(nil)
                    rowStack.addArrangedSubview(filler)
                    filler.snp.makeConstraints {
                        $0.width.equalTo(rowStack.snp.width).multipliedBy(1.0 / CGFloat(columnCount))
                    }
                    c += 1
                }
            }
            table.addArrangedSubview(rowStack)
        }

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        if let caption, !caption.isEmpty {
            let cap = UILabel()
            cap.numberOfLines = 0
            cap.attributedText = PillDetailRenderer.attributedString(
                from: caption,
                font: DSKitFontFamily.Pretendard.semiBold.font(size: 13),
                color: DSColor.textSecondary,
                lineHeightMultiple: 1.3
            )
            container.addArrangedSubview(cap)
        }
        container.addArrangedSubview(table)

        addSubview(container)
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func makeCell(_ cell: TableCellModel?) -> UIView {
        let container = UIView()
        container.backgroundColor = (cell?.header == true) ? DSColor.Neutral._100 : DSColor.surface
        container.layer.borderWidth = 0.5
        container.layer.borderColor = DSColor.border.cgColor

        guard let cell else { return container }

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.attributedText = PillDetailRenderer.attributedString(
            from: cell.content,
            font: cell.header
                ? DSKitFontFamily.Pretendard.semiBold.font(size: 13)
                : DSKitFontFamily.Pretendard.regular.font(size: 13),
            color: cell.header ? DSColor.textPrimary : DSColor.textSecondary,
            lineHeightMultiple: 1.3
        )
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(9)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        return container
    }

    // 병합을 고려한 셀 배치 계산. columnCount·rowCount·시작 배치 목록 반환.
    private func layout(rows: [TableRowModel]) -> (placements: [Placement], columns: Int, rowCount: Int) {
        var occupied = Set<String>()
        var placements: [Placement] = []
        var columnCount = 0
        func key(_ r: Int, _ c: Int) -> String { "\(r),\(c)" }

        for (r, row) in rows.enumerated() {
            var c = 0
            for cell in row.cells {
                while occupied.contains(key(r, c)) { c += 1 }
                placements.append(Placement(cell: cell, row: r, col: c))
                let colspan = max(1, cell.colspan)
                let rowspan = max(1, cell.rowspan)
                for dr in 0..<rowspan {
                    for dc in 0..<colspan {
                        occupied.insert(key(r + dr, c + dc))
                    }
                }
                c += colspan
                columnCount = max(columnCount, c)
            }
        }
        // rowspan이 마지막 행을 넘어갈 수 있으므로 실제 점유 행 수 계산
        let rowCount = occupied
            .compactMap { Int($0.split(separator: ",").first ?? "") }
            .max().map { $0 + 1 } ?? rows.count
        return (placements, columnCount, rowCount)
    }
}
