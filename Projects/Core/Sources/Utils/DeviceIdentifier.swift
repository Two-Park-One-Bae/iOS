//
//  DeviceIdentifier.swift
//  Core
//
//  Created by 바견규 on 7/20/26.
//

import Foundation
import Security

/// 기기 식별자(`X-Device-Id`) 제공자 — 식별 횟수 카운트의 키 (NM-322).
///
/// Keychain에 UUID를 저장한다. UserDefaults·identifierForVendor와 달리 **앱 재설치에도 남기 때문에**
/// 재설치로 한도를 초기화하는 우회를 막는다. 공장초기화·기기 복원까지 하면 새로 생성되는데,
/// 이건 로그인 도입 전까지 감수하는 알려진 한계다(설계: docs/알약식별-사용제한-설계.md).
///
/// 카운트·리셋·판정은 전부 서버가 소유하고, 앱은 "누구인지"만 담당한다.
public enum DeviceIdentifier {

    private static let service = "app.nursemate.care.deviceid"
    private static let account = "device_id"

    private static let lock = NSLock()

    /// 저장된 device_id. Keychain에 없으면 생성해 저장한다. 디버그·릴리즈 동일하게 실 Keychain id를 쓴다.
    ///
    /// **Keychain 저장까지 실패하면 nil을 반환한다(fail-closed).** 매 실행 새 UUID로 폴백하면
    /// device_id가 실행마다 바뀌어 서버가 같은 id를 못 봐 429에 영영 안 걸림 → 한도가 무력화된다.
    /// 안정적 식별자를 만들 수 없으면 차라리 식별을 막는다(호출부가 nil을 보고 '잠시 후 다시'로 처리).
    /// 포그라운드 흐름에서 Keychain 실패 자체가 극히 드물어 정상 유저 영향은 사실상 없다.
    public static var current: String? {
        lock.lock()
        defer { lock.unlock() }

        if let saved = read() { return saved }

        // 첫 실행: 생성 후 저장. 저장 성공해야 유효한 id — 실패하면 nil(fail-closed).
        let generated = UUID().uuidString
        return save(generated) ? generated : nil
    }

    // MARK: - Keychain

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }

        return value
    }

    /// 저장 성공 여부를 반환한다 — 실패(Keychain 불가)면 current가 nil로 fail-closed.
    @discardableResult
    private static func save(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // 재설치 후에도 남아야 하므로 기기 잠금해제 이후 접근 가능.
        // ThisDeviceOnly — 백업·기기 이관으로 식별자가 복제되지 않게.
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        SecItemDelete(attributes as CFDictionary)
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
