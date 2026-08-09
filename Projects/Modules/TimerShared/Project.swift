import ProjectDescription
import ProjectDescriptionHelpers
import DependencyPlugin

// 타이머 Live Activity·AlarmKit 공유 계약 모듈.
// TimerFeature(생성자)와 TimerWidget(익스텐션 렌더러)가 "같은 모듈의 같은 타입"을
// 링크해야 ActivityKit/AlarmKit이 서로를 매칭한다. 소스 복제는 모듈명이 달라져
// 매칭이 깨지므로, 시스템 프레임워크만 의존하는 leaf 모듈로 분리한다.
let project = Project.makeModule(
    name: "TimerShared",
    targets: [.staticFramework]
)
