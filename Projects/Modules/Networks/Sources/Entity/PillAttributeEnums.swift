//
//  PillAttributeEnums.swift
//  Networks
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

// 서버가 새 케이스를 추가해도 앱이 크래시 나지 않도록 unknown 처리
public enum PillColor: String, Codable {
    case white      = "WHITE"
    case yellow     = "YELLOW"
    case orange     = "ORANGE"
    case pink       = "PINK"
    case red        = "RED"
    case brown      = "BROWN"
    case lightGreen = "LIGHT_GREEN"
    case green      = "GREEN"
    case teal       = "TEAL"
    case blue       = "BLUE"
    case navy       = "NAVY"
    case magenta    = "MAGENTA"
    case purple     = "PURPLE"
    case gray       = "GRAY"
    case black      = "BLACK"
    case colorless  = "COLORLESS"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PillColor(rawValue: value) ?? .unknown
    }
}

public enum PillShape: String, Codable {
    case round       = "ROUND"
    case oval        = "OVAL"
    case oblong      = "OBLONG"
    case semicircle  = "SEMICIRCLE"
    case triangle    = "TRIANGLE"
    case square      = "SQUARE"
    case diamond     = "DIAMOND"
    case pentagon    = "PENTAGON"
    case hexagon     = "HEXAGON"
    case octagon     = "OCTAGON"
    case other       = "OTHER"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PillShape(rawValue: value) ?? .unknown
    }
}

public enum PillFormulation: String, Codable {
    case tablet      = "TABLET"
    case hardCapsule = "HARD_CAPSULE"
    case softCapsule = "SOFT_CAPSULE"
    case other       = "OTHER"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PillFormulation(rawValue: value) ?? .unknown
    }
}

// 구분선. 각인 텍스트에서 파생 (십자분할선 → PLUS, 분할선 → MINUS)
public enum DividingLine: String, Codable {
    case plus  = "PLUS"
    case minus = "MINUS"
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = DividingLine(rawValue: value) ?? .unknown
    }
}
