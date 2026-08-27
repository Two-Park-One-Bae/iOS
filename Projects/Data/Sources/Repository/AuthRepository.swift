//
//  AuthRepository.swift
//  Data
//
//  Created by 바견규 on 8/28/26.
//

import Foundation

import Core
import Domain
import Networks

public final class AuthRepository: AuthRepositoryProtocol {

    private let service: AuthService
    private let providers: [AuthProvider: SocialSignInProviding]

    public init(service: AuthService) {
        self.service = service
        self.providers = [
            .google: GoogleSignInProvider(),
            .apple: AppleSignInProvider(),
            // 카카오만 서버 교환이 필요해 service 를 함께 받는다.
            .kakao: KakaoSignInProvider(service: service),
        ]
    }

    public var isSignedIn: Bool {
        FirebaseAuthService.isSignedIn
    }

    public func signIn(with provider: AuthProvider) async throws {
        guard let socialProvider = providers[provider] else {
            throw AuthError.unknown
        }
        do {
            try await socialProvider.signIn()
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func fetchMe() async throws -> AuthUser {
        do {
            return try await service.fetchMe().toDomain()
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func fetchConsentDefinitions() async throws -> [ConsentDefinition] {
        do {
            // 모르는 항목(서버가 새 ConsentType 을 추가)은 버린다 — 화면에 빈 줄이 뜨는 것보다 낫고,
            // 필수 충족 판정은 어차피 서버의 onboardingRequired 가 한다.
            return try await service.fetchConsentDefinitions().compactMap { $0.toDomain() }
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func saveConsents(_ agreements: [ConsentAgreement]) async throws -> AuthUser {
        do {
            return try await service.saveConsents(agreements.map { $0.toRequest() }).toDomain()
        } catch {
            throw AuthErrorMapper.mapConsentSave(error)
        }
    }

    public func signOut() throws {
        try FirebaseAuthService.signOut()
    }

    public func deleteAccount() async throws {
        do {
            try await service.deleteMe()
        } catch {
            // 500 이면 계정이 남아 있을 수 있다. 여기서 성공처럼 처리하면 "삭제됐다"고 잘못 안내하게 된다
            // — 상위는 이 에러를 받고 로그아웃하지 않은 채 재시도를 안내한다(spec: domains/auth.md §탈퇴).
            // 서버가 멱등이라 다시 눌러도 안전하다.
            throw AuthError.accountDeletionFailed
        }
    }
}
