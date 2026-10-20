//
//  PillLabelModel.swift
//  Domain
//

import Foundation

/// 속성 추출에 보낼 알약 한 개 — 크롭과, 학습용 라벨 값(NM-568).
public struct PillAttributeInput: Equatable {
    /// 응답과 짝짓는 키. 라벨을 보낼 때는 0~99 정수 문자열이고 그대로 라벨의 `pillIndex` 가 된다.
    public let pillId: String
    /// 마스크를 알파에 담은 RGBA PNG, base64.
    public let croppedImage: String
    /// 크롭 위치 — 업로드한 원본 픽셀 기준. 너비 · 높이가 크롭 크기와 같아야 서버가 저장한다.
    public let box: PillBox?
    /// 알약 찾기 점수(0~1).
    public let score: Double?

    public init(pillId: String, croppedImage: String, box: PillBox? = nil, score: Double? = nil) {
        self.pillId = pillId
        self.croppedImage = croppedImage
        self.box = box
        self.score = score
    }
}

/// 원본에서 잘린 위치 `[x, y, 너비, 높이]` — 픽셀 정수.
public struct PillBox: Equatable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 사진 한 장의 라벨 키와 원본 정보. 속성 추출에 함께 보내면 서버가 크롭 · 알약 행 · 알약 위치 행을 저장한다.
public struct PillImageCapture: Equatable {
    /// 앱이 만든 UUID v7(소문자) — upload-url 과 속성 추출에 같은 값을 보낸다.
    public let imageId: String
    /// 업로드한 원본(가공본) 픽셀 크기.
    public let imageWidth: Int
    public let imageHeight: Int
    /// 알약 찾기 모델 버전(ML 레포 모델 폴더 이름).
    public let segModel: String

    public init(imageId: String, imageWidth: Int, imageHeight: Int, segModel: String) {
        self.imageId = imageId
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.segModel = segModel
    }
}

/// 「선택」한 알약 하나의 라벨 (spec label.md 「라벨 — 「선택」 할 때」).
public struct PillLabelModel: Equatable {
    /// 사용자가 고른 품목.
    public let pillCode: String
    /// 수동 추가 알약 — `model` 이 없다.
    public let manual: Bool
    /// 모델이 처음 뽑은 값 — 첫 후보 조회 요청 그대로. 수동 추가는 nil.
    public let model: PillCandidateQuery?
    /// 사용자가 마지막으로 찾은 값 — 마지막 후보 조회 요청 그대로.
    public let userInput: PillCandidateQuery

    public init(pillCode: String, manual: Bool, model: PillCandidateQuery?, userInput: PillCandidateQuery) {
        self.pillCode = pillCode
        self.manual = manual
        self.model = model
        self.userInput = userInput
    }
}

/// 라벨 키 `pillIndex` 의 범위 — 모델 알약은 속성 추출의 `pillId`(0~99), 수동 추가 알약은 100부터.
public enum PillLabelIndex {
    public static let model = 0...99
    public static let manual = 100...199
}

/// 사진 한 장의 id — UUID v7 (RFC 9562).
///
/// 앞 48비트가 만든 시각(밀리초)이라 서버가 이 값만으로 원본 키 `raw/{yyyy}/{MM}/{dd}/{imageId}.jpg` 를 다시 만든다.
public enum PillImageId {
    public static func make(at date: Date = Date()) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }

        let millis = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        for i in 0..<6 {
            bytes[i] = UInt8((millis >> (8 * (5 - i))) & 0xFF)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70   // 버전 7
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // 변형 10

        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid.uuidString.lowercased()
    }
}
