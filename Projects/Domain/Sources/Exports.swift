//
//  Exports.swift
//  Domain
//
//  타이머 도메인(TreatmentTimerModel·TimerPresetModel·TimerCategory·TimerSyncSnapshot 등)은
//  폰·워치 공용 멀티플랫폼 모듈 TimerDomain 으로 분리됐다. 기존 iOS 코드가 `import Domain`
//  만으로 그 타입을 그대로 쓰도록 재노출한다.
@_exported import TimerDomain
