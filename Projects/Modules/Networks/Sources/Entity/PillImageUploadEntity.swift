//
//  PillImageUploadEntity.swift
//  Networks
//
//  Created by 바견규 on 7/26/26.
//

import Foundation

// POST /api/v0/pill-images/upload-url 응답 (NM-348).
// 학습데이터용 원본 이미지를 S3에 직접 올릴 presigned PUT URL. 키는 서버가 발급해 URL에 포함한다.
public struct PillImageUploadURLEntity: Decodable {
    public let uploadUrl: String   // presigned PUT URL (Content-Type image/jpeg 만 허용)
    public let expiresAt: String   // 만료 시각(발급 후 10분). 즉시 업로드하므로 클라 로직엔 미사용
}
