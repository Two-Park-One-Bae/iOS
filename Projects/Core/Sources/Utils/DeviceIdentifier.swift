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

    private static let service = "app.nursemate.deviceid"
    private static let account = "device_id"

    private static let lock = NSLock()

    /// 저장된 UUID를 반환한다. 없으면 생성해 저장한다.
    ///
    /// Keychain 접근에 실패해도 요청 자체는 나가야 하므로(식별을 막지 않는다) 생성한 값을 그대로 쓴다.
    /// 이 경우 앱 재실행 시 값이 달라져 카운트가 분리되지만, 최종 판정은 서버 429라 치명적이지 않다.
    public static var current: String {
        lock.lock()
        defer { lock.unlock() }

        if let saved = read() { return saved }

        let generated = UUID().uuidString
        save(generated)
        return generated
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

    private static func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

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
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
