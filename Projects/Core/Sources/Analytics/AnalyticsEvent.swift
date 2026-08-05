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

    // MARK: 타이머
    /// 타이머 시작 — source(iphone/watch)·프리셋.
    case timerStart(source: String, presetLabel: String, category: String, durationSec: Int)

    var name: String {
        switch self {
        case .buttonTap:        return "button_tap"
        case .share:            return "share"
        case .pillIdentifyResult: return "pill_identify_result"
        case .pillAttrEdit:     return "pill_attr_edit"
        case .pillConfirm:      return "pill_confirm"
        case .pillFlowExit:     return "pill_flow_exit"
        case .timerStart:       return "timer_start"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .buttonTap(target, screen):
            return ["target": target, "screen": screen]
        case let .share(method, contentType):
            return ["method": method, "content_type": contentType]
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
        case let .timerStart(source, presetLabel, category, durationSec):
            return ["source": source, "preset_label": presetLabel,
                    "category": category, "duration_sec": durationSec]
        }
    }
}

/// 분석 전송 파사드 — 현재는 Firebase 단독. (필요 시 여기서 Amplitude 등 다중 라우팅 추가)
public enum AppAnalytics {
    public static func track(_ event: AnalyticsEvent) {
        FirebaseService.log(event: event.name, event.parameters)
    }
}
