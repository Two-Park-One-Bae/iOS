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
            plugins: [Moya.NetworkLoggerPlugin.verbose],
            // App Check(NM-322)·Bearer(NM-410) 토큰은 발급이 async라 헤더가 아닌 interceptor로 붙인다.
            // 401 강제 갱신 재시도도 여기에 들어 있다.
            interceptor: APIRequestInterceptor()
        )
    }
}
