// swift-tools-version: 5.10
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "Alamofire": .framework,
        "Moya": .framework,
        "CombineMoya": .framework,
        "SnapKit": .framework,
        "Kingfisher": .framework,
        "AmplitudeSwift": .framework,
        "Lottie": .framework,
        "Then": .framework,
        // 소셜 로그인 (NM-410).
        // GoogleSignIn 은 .framework 로 올리지 않는다 — AppCheckCore·GTMSessionFetcher 등 정적 의존을
        // Core(Firebase)와 공유해서, 동적으로 만들면 같은 ObjC 클래스가 두 벌 링크된다.
        "KakaoSDKCommon": .framework,
        "KakaoSDKAuth": .framework,
        "KakaoSDKUser": .framework,
    ]
)
#endif

let package = Package(
    name: "AppPackages",
    platforms: [
        .iOS("17.0")
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.10.0")),
        .package(url: "https://github.com/Moya/Moya", .upToNextMajor(from: "15.0.0")),
        .package(url: "https://github.com/SnapKit/SnapKit", .upToNextMajor(from: "5.7.0")),
        .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/amplitude/Amplitude-Swift", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
        .package(url: "https://github.com/airbnb/lottie-ios", .upToNextMajor(from: "4.5.0")),
        .package(url: "https://github.com/devxoul/Then", .upToNextMajor(from: "3.0.0")),
        // 소셜 로그인 (NM-410). 구글·애플은 Firebase 네이티브라 GoogleSignIn 으로 credential 만 얻고,
        // 카카오는 비네이티브라 액세스 토큰을 서버에 넘겨 Custom Token 을 받는다 (spec: domains/auth.md).
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/kakao/kakao-ios-sdk", .upToNextMajor(from: "2.24.0")),
    ]
)
