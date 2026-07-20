import UIKit
import Domain

// MARK: - 알약 색상 스와치 팔레트
//
// 낱알식별 색상(PillColorModel) 16종을 화면에 찍는 실제 색.
// 브랜드 팔레트(DSColor)와 목적이 다르다 — 이건 "약 색을 눈으로 구분"시키는 값이라
// 디자인의 색상 칩 스펙을 그대로 따르며, DSColor 토큰과 독립적으로 관리한다.
//
// 색상 칩 디자인이 바뀌면 이 파일만 고치면 된다.

extension PillColorModel {

    /// 색상 칩·스와치에 쓰는 색. `.colorless` / `.unknown` 은 색이 없어 nil.
    var swatchColor: UIColor? {
        Self.palette[self]
    }

    private static let palette: [PillColorModel: UIColor] = [
        .white:      hex(0xFFFFFF),
        .yellow:     hex(0xFACC15),
        .orange:     hex(0xFB923C),
        .pink:       hex(0xF9A8D4),
        .red:        hex(0xEF4444),
        .brown:      hex(0x92400E),
        .lightGreen: hex(0x86EFAC),
        .green:      hex(0x22C55E),
        .teal:       hex(0x14B8A6),
        .blue:       hex(0x3B82F6),
        .navy:       hex(0x1E3A8A),
        .magenta:    hex(0xDB2777),
        .purple:     hex(0x8B5CF6),
        .gray:       hex(0x9CA3AF),
        .black:      hex(0x1F2937),
        // .colorless / .unknown 은 팔레트에 없음 → swatchColor == nil
    ]

    private static func hex(_ value: UInt32) -> UIColor {
        UIColor(
            red:   CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue:  CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
