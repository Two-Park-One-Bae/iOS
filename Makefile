# NurseMate iOS — 로컬 CI/CD (GitHub Actions → 로컬 이관)
#
# 모든 빌드·배포는 이 Makefile 을 단일 진입점으로 거친다.
# 수동 실행(A)·git hook(B)·젠킨스 Job 이 전부 이 타깃을 호출한다 → 경로가 하나뿐이라 어긋나지 않는다.
#
# 시크릿은 git 밖(~/.nursemate-secrets)에 두고 빌드 직전 작업 트리로 복사한다(ⓑ 고정 경로 방식).

SECRETS := $(HOME)/.nursemate-secrets
# 팀 ID 는 시크릿 원본에서 읽는다(작업 트리 복사본이 아직 없을 수도 있으므로).
export DEVELOPMENT_TEAM := $(shell grep '^DEVELOPMENT_TEAM' $(SECRETS)/Secrets.xcconfig 2>/dev/null | sed 's/.*=[[:space:]]*//')

.PHONY: help secrets generate doctor test verify beta beta-external release open

help:
	@echo "NurseMate iOS — 로컬 CI/CD"
	@echo "  make doctor         환경이 CI 와 맞는지 검사"
	@echo "  make test           유닛 테스트 (구 ci.yml)"
	@echo "  make verify         업로드 없이 서명·아카이브만 검증"
	@echo "  make beta           내부 TestFlight 배포 (구 cd-beta)      ← 개발 중 아무 때나"
	@echo "  make beta-external  외부 TestFlight 배포 (구 cd-beta-external)"
	@echo "  make release        App Store 제출 (구 cd-release)         ← 버전 확정 후"

## 시크릿을 작업 트리에 배치 (gitignore 대상 — 커밋 안 됨)
secrets:
	@test -d "$(SECRETS)" || { echo "❌ $(SECRETS) 없음 — 시크릿 디렉터리를 먼저 만들어야 합니다"; exit 1; }
	@cp "$(SECRETS)/Secrets.xcconfig" XCConfig/Secrets.xcconfig
	@mkdir -p Projects/App/Firebase/Debug Projects/App/Firebase/Release
	@cp "$(SECRETS)/GoogleService-Info.Debug.plist"   Projects/App/Firebase/Debug/GoogleService-Info.plist
	@cp "$(SECRETS)/GoogleService-Info.Release.plist" Projects/App/Firebase/Release/GoogleService-Info.plist
	@cp "$(SECRETS)/api_key.json" fastlane/api_key.json
	@echo "✅ 시크릿 배치 완료"

## Tuist 프로젝트 재생성 — 브랜치 전환 후 필수(안 하면 낡은 파일 참조로 빌드 실패)
generate:
	tuist install
	tuist generate --no-open

## 환경이 CI(과거 GitHub 러너)와 맞는지 검사. 새 맥·업데이트 후 여기서 어긋남을 잡는다.
doctor:
	@ruby -v | grep -q 'ruby 3.3' && echo "✅ Ruby 3.3" || echo "⚠️  Ruby 3.3 아님: $$(ruby -v)"
	@bundle exec fastlane --version >/dev/null 2>&1 && echo "✅ fastlane(gem)" || echo "❌ gem 미설치 — 'bundle install' 필요"
	@xcrun simctl list devices available | grep -q 'iPhone 16 ' && echo "✅ iPhone 16 시뮬레이터" || echo "❌ iPhone 16 시뮬 없음 — 'xcrun simctl create' 필요"
	@test -f "$(SECRETS)/api_key.json" && echo "✅ ASC API 키" || echo "❌ $(SECRETS)/api_key.json 없음"
	@test -n "$(DEVELOPMENT_TEAM)" && echo "✅ DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM)" || echo "❌ DEVELOPMENT_TEAM 못 읽음"

## 유닛 테스트 (구 ci.yml)
test: secrets generate
	bundle exec fastlane test

## 업로드 없이 서명·아카이브만 검증 (배포 전 안전 점검)
verify: secrets generate
	bundle exec fastlane verify_signing

## 내부 TestFlight 배포 (구 cd-beta) — dev Firebase·dev 서버·INTERNAL
beta: secrets generate
	bundle exec fastlane beta_internal

## 외부 TestFlight 배포 (구 cd-beta-external) — prod. 실사용자 노출이니 QA 후.
beta-external: secrets generate
	bundle exec fastlane beta_external

## App Store 제출 (구 cd-release) — prod. 버전 확정·최종 QA 후.
release: secrets generate
	bundle exec fastlane release

## Xcode 로 워크스페이스 열기
open: secrets generate
	open Application.xcworkspace
