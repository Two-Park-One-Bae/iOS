import Foundation

/*
 앱 분석 이벤트 택소노미 (Firebase Analytics 단독).

 - 이름은 snake_case·40자 이내, 문자열 파라미터 값은 100자 이내(GA4 제약)로 맞춘다.
 - 리포트에서 파라미터를 보려면 GA4 콘솔에서 "커스텀 측정기준"으로 등록해야 한다(이벤트범위 최대 50개).
 - 내부 빌드(DEBUG·beta_internal)는 dev Firebase 프로젝트로 수집된다 — 운영 속성은 오염되지 않는다.
 */
public enum AnalyticsEvent {

    // MARK: 공통
    /// 각종 버튼 탭 — target 에 버튼 종류(share/back/edit …), screen 에 화면명.
    case buttonTap(target: String, screen: String)
    /// 공유 완료 (UIActivityViewController).
    case share(method: String, contentType: String)
    /// 권한 프롬프트 응답 — permission: camera/alarm · result: granted/denied · gate: 진입 기능.
    case permissionResult(permission: String, result: String, gate: String)

    // MARK: 알약 인식
    /// 분석 시작 — 사진을 확정해 분석에 들어간 순간. **식별 성공률의 분모.**
    ///
    /// 로딩 화면엔 나갈 방법이 없다(`PillLoadingVC` 가 back 버튼을 숨긴다). 그래서 대기 중 이탈은
    /// 앱 강제 종료뿐인데, 그 순간엔 이벤트 전송이 보장되지 않아 이탈 시점에 직접 찍을 수가 없다.
    /// 대신 분모를 남겨 **`started` − `result` 로 빼서** 센다.
    case pillIdentifyStarted
    /// 분석 시도의 최종 결과 — outcome: success/empty/failure. (한도초과는 별도 `pill_limit_reached`)
    ///
    /// **이건 분모가 아니다.** 결과가 나와야 찍히므로 로딩 중 이탈한 시도는 여기 없다.
    /// 성공률을 낼 땐 `pill_identify_started` 를 분모로 쓸 것.
    ///
    /// `analysisMs` 는 로딩 화면 진입부터 이 결과가 나오기까지, 즉 **사용자가 기다린 시간**이다
    /// (온디바이스 세그멘테이션 + 서버 왕복 포함). 실패에도 붙어 "얼마나 빨리 실패하는가"를 본다.
    case pillIdentifyResult(outcome: String, pillCount: Int, analysisMs: Int)
    /// 속성 수정 1회.
    case pillAttrEdit(attribute: String, pillIndex: Int)
    /// 알약 1개 확정(후보 선택) — 몇 번째 후보·수정 횟수·수정한 속성·확정까지 체류시간.
    /// `candidateIndex` 는 **1 기반**으로 넘긴다(리포트에서 "1번째 후보"로 읽히게).
    case pillConfirm(pillIndex: Int, candidateIndex: Int, editCount: Int, editedAttrs: String, dwellMs: Int)
    /// 확정 없이 알약 수정 화면을 이탈 — 어떤 알약·어떤 속성 입력 중이었나.
    case pillFlowExit(pillIndex: Int, editingAttribute: String, enteredValues: String, editCount: Int)
    /// 사용 한도 **소진** — 마지막 1회를 쓴 요청이 성공으로 돌아온 순간 1회.
    ///
    /// 파라미터가 없다. 발화 조건이 "잔여 0 도달" 하나뿐이라 어떤 값을 붙여도 상수가 되고,
    /// 상수 축은 이벤트 수를 세는 것과 같은 정보를 되풀이할 뿐이다.
    /// (~2026-09 에는 `limit_source` 로 `gate`·`server` 를 실어 **막힌 시도**마다 발사했는데,
    /// 그러면 소진 후 재시도하지 않은 사용자가 통째로 빠지고 재시도한 사용자는 중복으로 잡혔다.)
    case pillLimitReached
    /// 알약 식별 완주 — ⑨ 완료 버튼. (완료 수 / 시작 수). 완주 시 미확정=0.
    case pillIdentifyComplete(detectedCount: Int, confirmedCount: Int, deletedCount: Int, manualAddedCount: Int)
    /// 알약 식별 중도이탈 — ⑤ 인식결과에서 확정 없이 나감. 미확정 개수·경과시간 포함.
    case pillIdentifySessionExit(detectedCount: Int, confirmedCount: Int, unconfirmedCount: Int, deletedCount: Int, manualAddedCount: Int, elapsedSec: Int)

    // MARK: 타이머
    /// 타이머 시작 — source(iphone/watch)·프리셋.
    case timerStart(source: String, presetLabel: String, category: String, durationSec: Int)
    /// 타이머 완료 — 끝까지 울린 뒤 [완료]. (완료율 = complete / start)
    case timerComplete(category: String, durationSec: Int)
    /// 타이머 중도 취소 — 울리기 전 정지. elapsed/remaining 로 언제 껐는지.
    case timerCancel(category: String, elapsedSec: Int, remainingSec: Int)
    /// 프리셋 생성 — label(사용자 입력 텍스트)·category·durationSec.
    case presetCreate(label: String, category: String, durationSec: Int)
    /// 프리셋 수정.
    case presetEdit(label: String, category: String, durationSec: Int)
    /// 프리셋 삭제.
    case presetDelete(label: String, category: String, durationSec: Int)

    var name: String {
        switch self {
        case .buttonTap:        return "button_tap"
        case .share:            return "share"
        case .permissionResult: return "permission_result"
        case .pillIdentifyStarted: return "pill_identify_started"
        case .pillIdentifyResult: return "pill_identify_result"
        case .pillAttrEdit:     return "pill_attr_edit"
        case .pillConfirm:      return "pill_confirm"
        case .pillFlowExit:     return "pill_flow_exit"
        case .pillLimitReached: return "pill_limit_reached"
        case .pillIdentifyComplete:    return "pill_identify_complete"
        case .pillIdentifySessionExit: return "pill_identify_session_exit"
        case .timerStart:       return "timer_start"
        case .timerComplete:    return "timer_complete"
        case .timerCancel:      return "timer_cancel"
        case .presetCreate:     return "preset_create"
        case .presetEdit:       return "preset_edit"
        case .presetDelete:     return "preset_delete"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .buttonTap(target, screen):
            return ["target": target, "screen": screen]
        case let .share(method, contentType):
            return ["method": method, "content_type": contentType]
        case let .permissionResult(permission, result, gate):
            return ["permission": permission, "result": result, "gate": gate]
        case .pillIdentifyStarted:
            return [:]
        case let .pillIdentifyResult(outcome, pillCount, analysisMs):
            return ["outcome": outcome, "pill_count": pillCount,
                    "analysis_ms": analysisMs, "analysis_bucket": Self.analysisBucket(analysisMs)]
        case let .pillAttrEdit(attribute, pillIndex):
            return ["attribute": attribute,
                    "pill_index": pillIndex, "pill_index_label": Self.pillIndexLabel(pillIndex)]
        case let .pillConfirm(pillIndex, candidateIndex, editCount, editedAttrs, dwellMs):
            return ["pill_index": pillIndex, "pill_index_label": Self.pillIndexLabel(pillIndex),
                    "candidate_index": candidateIndex,
                    "candidate_index_label": Self.candidateIndexLabel(candidateIndex),
                    "edit_count": editCount, "edit_count_bucket": Self.editCountBucket(editCount),
                    "edited_attrs": editedAttrs, "dwell_ms": dwellMs]
        case let .pillFlowExit(pillIndex, editingAttribute, enteredValues, editCount):
            return ["pill_index": pillIndex, "pill_index_label": Self.pillIndexLabel(pillIndex),
                    "editing_attribute": editingAttribute, "entered_values": enteredValues,
                    "edit_count": editCount, "edit_count_bucket": Self.editCountBucket(editCount)]
        case .pillLimitReached:
            return [:]
        case let .pillIdentifyComplete(detectedCount, confirmedCount, deletedCount, manualAddedCount):
            return ["detected_count": detectedCount, "confirmed_count": confirmedCount,
                    "deleted_count": deletedCount, "manual_added_count": manualAddedCount]
        case let .pillIdentifySessionExit(detectedCount, confirmedCount, unconfirmedCount, deletedCount, manualAddedCount, elapsedSec):
            // timer_cancel.elapsed_sec(타이머 경과)와 겹치지 않게 별도 키 사용.
            return ["detected_count": detectedCount, "confirmed_count": confirmedCount,
                    "unconfirmed_count": unconfirmedCount, "deleted_count": deletedCount,
                    "manual_added_count": manualAddedCount, "session_elapsed_sec": elapsedSec]
        case let .timerStart(source, presetLabel, category, durationSec):
            return ["source": source, "preset_label": presetLabel,
                    "category": category, "duration_sec": durationSec]
        case let .timerComplete(category, durationSec):
            return ["category": category, "duration_sec": durationSec]
        case let .timerCancel(category, elapsedSec, remainingSec):
            return ["category": category, "elapsed_sec": elapsedSec, "remaining_sec": remainingSec]
        case let .presetCreate(label, category, durationSec):
            return ["preset_label": label, "category": category, "duration_sec": durationSec]
        case let .presetEdit(label, category, durationSec):
            return ["preset_label": label, "category": category, "duration_sec": durationSec]
        case let .presetDelete(label, category, durationSec):
            return ["preset_label": label, "category": category, "duration_sec": durationSec]
        }
    }

    // MARK: - GA4 인코딩

    /*
     순번·횟수는 **숫자와 문자열 두 벌**로 보낸다. GA4 는 파라미터 하나를 측정기준 또는 측정항목
     한쪽으로만 등록할 수 있는데, 두 쓰임이 다 필요하기 때문이다.

     - `pill_index`·`candidate_index`·`edit_count`(Int) → **측정항목**. 평균을 본다.
     - `*_label`·`edit_count_bucket`(String) → **측정기준**. 분포를 보거나 다른 지표를 쪼갠다.

     측정기준이 문자열이어야 하는 건 GA4 가 값을 `string_value`/`int_value` 에 따로 담고
     측정기준은 `string_value` 만 읽기 때문 — Int 로 보내면 분류 축에서 전부 `(not set)` 이 된다.

     라벨 규칙:
     - **두 자리 제로 패딩** — 문자열은 사전순 정렬이라("10" < "2") 패딩해야 리포트 축이 숫자 순서로 선다
     - **상한 초과는 한 칸에**("21+"/"16+") — 카디널리티를 닫아 (other) 버킷을 막는다.
       라벨 숫자가 곧 "여기부터 묶임"이라 20·15 는 제 라벨을 갖는다
     - **1 미만은 "unknown"** — 계측 오류를 정상값에 뭉개지 않는다
     */

    /// 1 기반 순번을 제로 패딩 문자열로.
    ///
    /// `lastLabeled` 까지는 개별 라벨(`01`·`02` …), **그 위**는 `"<lastLabeled+1>+"` 한 칸에 모은다.
    /// 오버플로 라벨이 `lastLabeled+1` 인 건 경계를 값 그대로 읽히게 하려는 것 —
    /// `lastLabeled: 20` 이면 `20` 은 제 라벨을 갖고 21 이상만 `21+` 로 묶인다.
    /// (`20+` 로 쓰면 20 이 어느 쪽인지 리포트만 보고는 알 수 없다)
    private static func indexLabel(_ value: Int, lastLabeled: Int) -> String {
        guard value >= 1 else { return "unknown" }
        return value > lastLabeled ? "\(lastLabeled + 1)+" : String(format: "%02d", value)
    }

    /// 알약 순번 — 수동 추가로 늘어날 수 있어 20 까지 개별, 21 부터 묶는다.
    private static func pillIndexLabel(_ value: Int) -> String { indexLabel(value, lastLabeled: 20) }

    /// 후보 순번 — 호출부에서 1 기반으로 맞춰 넘긴다(`firstIndex` 는 0 기반).
    private static func candidateIndexLabel(_ value: Int) -> String { indexLabel(value, lastLabeled: 15) }

    /// 수정 횟수 분포용 구간. 라벨이 전부 숫자로 시작해 사전순 정렬이 곧 구간 순서가 된다.
    private static func editCountBucket(_ count: Int) -> String {
        switch count {
        case ..<0:  return "unknown"
        case 0:     return "0회"
        case 1:     return "1회"
        case 2...3: return "2-3회"
        case 4...5: return "4-5회"
        default:    return "6회+"
        }
    }

    /// 분석 대기시간 구간(`pill_identify_result.analysis_bucket`).
    ///
    /// `analysis_ms` 와 짝으로 보낸다 — Int 는 GA4 **측정항목**으로만 등록되어 평균은 보이지만
    /// 분류 축으로 쓰면 전부 `(not set)` 이 된다. 분포를 보려면 문자열 구간이 필요하다.
    ///
    /// 짧은 쪽을 촘촘히 나눈 건 **대기 이탈이 앞쪽에서 갈리기 때문**이다. 3초와 5초의 차이는
    /// 체감이 크지만 40초와 50초의 차이는 이미 "너무 느림" 한 덩어리다.
    /// (2026-09-02 시뮬레이터 실측 1건: 알약 25개 인식에 12.9초)
    private static func analysisBucket(_ ms: Int) -> String {
        switch ms {
        case ..<0:       return "unknown"
        case ..<3_000:   return "00:00-00:03"
        case ..<5_000:   return "00:03-00:05"
        case ..<10_000:  return "00:05-00:10"
        case ..<15_000:  return "00:10-00:15"
        case ..<20_000:  return "00:15-00:20"
        case ..<30_000:  return "00:20-00:30"
        case ..<60_000:  return "00:30-01:00"
        default:         return "01:00+"
        }
    }
}

/// 분석 전송 파사드 — 현재는 Firebase 단독. (필요 시 여기서 Amplitude 등 다중 라우팅 추가)
public enum AppAnalytics {
    public static func track(_ event: AnalyticsEvent) {
        FirebaseService.log(event: event.name, event.parameters)
    }
}
