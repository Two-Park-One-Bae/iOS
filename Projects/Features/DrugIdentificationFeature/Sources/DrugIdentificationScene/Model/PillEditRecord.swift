//
//  PillEditRecord.swift
//  DrugIdentificationFeature
//

import Foundation

/// 알약 1개의 조건 수정 기록 (`pill_confirm` · `pill_flow_exit` 의 `edit_count` / `edited_attrs`).
///
/// 수정 화면은 전에 고친 조건을 이어서 연다. 기록이 화면(ViewModel)에만 있으면 다시 열 때 0 부터 세서,
/// 고치고 → 나갔다 → 다시 열어 확정한 알약이 "수정 없이 확정"으로 잡힌다(NM-535).
/// 그래서 조건과 같이 결과 화면이 알약별로 들고 있다가 수정 화면을 열 때 넘긴다.
struct PillEditRecord: Equatable {
    private(set) var count = 0
    private(set) var attributes: Set<String> = []

    mutating func record(_ attribute: String) {
        count += 1
        attributes.insert(attribute)
    }

    /// 확정까지 수정한 속성 종류(≤100자).
    /// 수정 없이 확정하는 게 다수 케이스인데 빈 문자열을 보내면 GA4 에서 (not set) 으로 보여
    /// "파라미터가 안 왔다"와 구분이 안 된다 — entered_values 와 같이 "none" 으로 명시한다.
    var joinedAttributes: String {
        let joined = attributes.isEmpty ? "none" : attributes.sorted().joined(separator: ",")
        return String(joined.prefix(100))
    }
}
