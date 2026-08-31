//
//  BaseService+.swift
//  Data
//
//  Created by 바견규 on 7/2/26.
//

import Foundation

import Networks
import Moya

extension BaseService {
    public static var standard: BaseService {
        BaseService<Target>(
            plugins: [
                Moya.NetworkLoggerPlugin.verbose,
                // 서버 장애 징후(5xx·연결 실패)를 보면 Remote Config 를 즉시 확인한다(NM-423).
                // 점검 플래그가 켜져 있으면 AppGate 가 차단 화면을 띄운다.
                OutageDetectionPlugin(),
            ],
            // App Check(NM-322)·Bearer(NM-410) 토큰은 발급이 async라 헤더가 아닌 interceptor로 붙인다.
            // 401 강제 갱신 재시도도 여기에 들어 있다.
            interceptor: APIRequestInterceptor()
        )
    }
}
