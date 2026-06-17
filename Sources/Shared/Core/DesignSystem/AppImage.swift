import SwiftUI

// MARK: - App Image

/// Raster 이미지(.imageset) 리소스에 대한 타입-세이프 접근을 제공한다.
///
/// SF Symbols(시스템 아이콘)은 `AppImage`가 아닌 `AppIcon`을 사용한다.
///   Image(appIcon: .house)   // ✅ SF Symbol (에셋 불필요)
///   Image(appImage: .logo)   // ✅ raster imageset
///   Image("logo")            // ❌
///
/// 새 이미지(imageset) 추가 절차:
///   1. Resources/Assets.xcassets 에 .imageset 추가 (예: logo.imageset)
///   2. 아래 enum에 case 추가:
///        case logo
///   3. 코드에서 AppImage.logo.image 사용
///
/// case 이름 == .imageset 폴더 이름.

public enum AppImage {
    // MARK: - Cases
    // case logo           // logo.imageset
    // case iconHome       // iconHome.imageset

    /// .imageset 폴더 이름. case 추가 시 switch에 매핑한다.
    var name: String {
        switch self {}
    }

    public var image: Image {
        Image(name, bundle: .main)
    }
}
