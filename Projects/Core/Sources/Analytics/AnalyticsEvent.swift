import Foundation

/*
 앱 분석 이벤트 택소노미 (Firebase Analytics 단독).

 - 이름은 snake_case·40자 이내, 문자열 파라미터 값은 100자 이내(GA4 제약)로 맞춘다.
 - 리포트에서 파라미터를 보려면 GA4 콘솔에서 "커스텀 측정기준"으로 등록해야 한다(이벤트범위 최대 50개).
 - 내부 빌드에선 FirebaseService.setAnalyticsCollectionEnabled(false)로 수집이 꺼져 있어 track()이 no-op이 된다(NM-364).
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
    /// 분석 시도의 최종 결과 — 식별 성공률(분모)·퍼널 상단. outcome: success/empty/failure.
    /// (한도초과는 여기 안 들어감 — 별도 pill_limit_reached)
    case pillIdentifyResult(outcome: String, pillCount: Int)
    /// 속성 수정 1회.
    case pillAttrEdit(attribute: String, pillIndex: Int)
    /// 알약 1개 확정(후보 선택) — 몇 번째 후보·수정 횟수·수정한 속성·확정까지 체류시간.
    case pillConfirm(pillIndex: Int, candidateIndex: Int, editCount: Int, editedAttrs: String, dwellMs: Int)
    /// 확정 없이 알약 수정 화면을 이탈 — 어떤 알약·어떤 속성 입력 중이었나.
    case pillFlowExit(pillIndex: Int, editingAttribute: String, enteredValues: String, editCount: Int)
    /// 사용 한도 도달 — source: gate(요청 전 게이트) / server(429).
    case pillLimitReached(source: String)
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

    var name: String {
        switch self {
        case .buttonTap:        return "button_tap"
        case .share:            return "share"
        case .permissionResult: return "permission_result"
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
        case let .pillIdentifyResult(outcome, pillCount):
            return ["outcome": outcome, "pill_count": pillCount]
        case let .pillAttrEdit(attribute, pillIndex):
            return ["attribute": attribute, "pill_index": pillIndex]
        case let .pillConfirm(pillIndex, candidateIndex, editCount, editedAttrs, dwellMs):
            return ["pill_index": pillIndex, "candidate_index": candidateIndex,
                    "edit_count": editCount, "edited_attrs": editedAttrs, "dwell_ms": dwellMs]
        case let .pillFlowExit(pillIndex, editingAttribute, enteredValues, editCount):
            return ["pill_index": pillIndex, "editing_attribute": editingAttribute,
                    "entered_values": enteredValues, "edit_count": editCount]
        case let .pillLimitReached(source):
            return ["source": source]
        case let .pillIdentifyComplete(detectedCount, confirmedCount, deletedCount, manualAddedCount):
            return ["detected_count": detectedCount, "confirmed_count": confirmedCount,
                    "deleted_count": deletedCount, "manual_added_count": manualAddedCount]
        case let .pillIdentifySessionExit(detectedCount, confirmedCount, unconfirmedCount, deletedCount, manualAddedCount, elapsedSec):
            return ["detected_count": detectedCount, "confirmed_count": confirmedCount,
                    "unconfirmed_count": unconfirmedCount, "deleted_count": deletedCount,
                    "manual_added_count": manualAddedCount, "elapsed_sec": elapsedSec]
        case let .timerStart(source, presetLabel, category, durationSec):
            return ["source": source, "preset_label": presetLabel,
                    "category": category, "duration_sec": durationSec]
        case let .timerComplete(category, durationSec):
            return ["category": category, "duration_sec": durationSec]
        case let .timerCancel(category, elapsedSec, remainingSec):
            return ["category": category, "elapsed_sec": elapsedSec, "remaining_sec": remainingSec]
        }
    }
}

/// 분석 전송 파사드 — 현재는 Firebase 단독. (필요 시 여기서 Amplitude 등 다중 라우팅 추가)
public enum AppAnalytics {
    public static func track(_ event: AnalyticsEvent) {
        FirebaseService.log(event: event.name, event.parameters)
    }
}
