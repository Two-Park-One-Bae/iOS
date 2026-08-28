//
//  DSBrandImage.swift
//  DSKit
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

/// 브랜드·공급자 로고. 아이콘(`DSIcon`)과 달리 **원색을 유지**해야 하는 이미지다.
///
/// 애플 로고는 SF Symbol `apple.logo` 로 충분해 에셋을 두지 않는다(`appleLogo` 참고).
public enum DSBrandImage: String {

    /// 널스메이트 로고 마크. 스플래시·로그인 화면이 같은 이미지를 쓴다.
    case logoMark = "Brand/logo_mark"
    /// 구글 "G" — 브랜드 가이드상 원색을 바꾸면 안 되므로 template 이 아니다.
    case google = "Brand/logo_google"
    /// 카카오 말풍선. template 이라 버튼 전경색(검정)으로 tint 된다.
    case kakao = "Brand/logo_kakao"

    public var uiImage: UIImage {
        UIImage(named: rawValue, in: .module, compatibleWith: nil) ?? UIImage()
    }

    /// 애플 로고는 시스템 심볼을 쓴다 — 별도 에셋 관리가 필요 없고 굵기도 버튼 폰트에 맞출 수 있다.
    public static func appleLogo(pointSize: CGFloat) -> UIImage? {
        UIImage(
            systemName: "apple.logo",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        )
    }
}
