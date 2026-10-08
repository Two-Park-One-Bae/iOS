//
//  ConsentMessage.swift
//  AuthFeature
//

/// 동의 온보딩과 약관 및 동의 화면이 함께 쓰는 안내 문구 정본 (spec: feature/auth/README.md).
///
/// 사용자에게 보이는 자리는 「변경」으로 통일한다 — 계약 서술은 「개정」이지만 화면에서
/// 세 단어(변경·업데이트·개정)가 섞여 있었다.
enum ConsentMessage {
    /// 저장 중 서버가 약관 버전을 올려 400 이 왔다 — 새 버전으로 다시 그린 뒤 띄운다.
    static let reloaded = "약관이 변경되어 다시 불러왔어요. 확인 후 동의해 주세요."
    /// 이 앱이 모르는 필수 항목이 생겼다 — 저장할 수 없다.
    static let updateRequired = "새로운 약관이 추가되었어요. 앱을 최신 버전으로 업데이트해 주세요."
}
