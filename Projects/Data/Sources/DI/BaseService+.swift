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
    // TODO: 인증 구현 후 AccessTokenPlugin + ReissueInterceptor 추가
    public static var standard: BaseService {
        BaseService<Target>(
            plugins: [Moya.NetworkLoggerPlugin.verbose]
        )
    }
}
