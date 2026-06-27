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
        "Clarity": .framework,
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
        .package(url: "https://github.com/microsoft/clarity-apps", .branch("main")),
    ]
)
