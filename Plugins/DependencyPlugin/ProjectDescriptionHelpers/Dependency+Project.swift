import ProjectDescription

public struct Dep {
    public struct App {}

    public struct Core {
        public static let Core = TargetDependency.project(
            target: "Core",
            path: .relativeToRoot("Projects/Core")
        )
    }

    public struct Domain {
        public static let Domain = TargetDependency.project(
            target: "Domain",
            path: .relativeToRoot("Projects/Domain")
        )
    }

    public struct Data {
        public static let Data = TargetDependency.project(
            target: "Data",
            path: .relativeToRoot("Projects/Data")
        )
    }

    public struct Modules {
        public struct Networks {
            public static let Networks = TargetDependency.project(
                target: "Networks",
                path: .relativeToRoot("Projects/Modules/Networks")
            )
        }
        public struct DSKit {
            public static let DSKit = TargetDependency.project(
                target: "DSKit",
                path: .relativeToRoot("Projects/Modules/DSKit")
            )
        }
        public struct SegmentationKit {
            public static let SegmentationKit = TargetDependency.project(
                target: "SegmentationKit",
                path: .relativeToRoot("Projects/Modules/SegmentationKit")
            )
        }
        public struct TimerShared {
            public static let TimerShared = TargetDependency.project(
                target: "TimerShared",
                path: .relativeToRoot("Projects/Modules/TimerShared")
            )
        }
        public struct TimerDomain {
            public static let TimerDomain = TargetDependency.project(
                target: "TimerDomain",
                path: .relativeToRoot("Projects/Modules/TimerDomain")
            )
        }
    }

    public struct Features {
        public struct Base {
            public static let Base = TargetDependency.project(
                target: "BaseFeatureDependency",
                path: .relativeToRoot("Projects/Features/BaseFeatureDependency")
            )
        }
        public struct Auth {
            public static let Feature = TargetDependency.project(
                target: "AuthFeature",
                path: .relativeToRoot("Projects/Features/AuthFeature")
            )
            public static let Interface = TargetDependency.project(
                target: "AuthFeatureInterface",
                path: .relativeToRoot("Projects/Features/AuthFeature")
            )
        }
        public struct Home {
            public static let Feature = TargetDependency.project(
                target: "HomeFeature",
                path: .relativeToRoot("Projects/Features/HomeFeature")
            )
            public static let Interface = TargetDependency.project(
                target: "HomeFeatureInterface",
                path: .relativeToRoot("Projects/Features/HomeFeature")
            )
        }
        public struct TabBar {
            public static let Feature = TargetDependency.project(
                target: "TabBarFeature",
                path: .relativeToRoot("Projects/Features/TabBarFeature")
            )
            public static let Interface = TargetDependency.project(
                target: "TabBarFeatureInterface",
                path: .relativeToRoot("Projects/Features/TabBarFeature")
            )
        }
        public struct DrugIdentification {
            public static let Feature = TargetDependency.project(
                target: "DrugIdentificationFeature",
                path: .relativeToRoot("Projects/Features/DrugIdentificationFeature")
            )
            public static let Interface = TargetDependency.project(
                target: "DrugIdentificationFeatureInterface",
                path: .relativeToRoot("Projects/Features/DrugIdentificationFeature")
            )
        }
        public struct Timer {
            public static let Feature = TargetDependency.project(
                target: "TimerFeature",
                path: .relativeToRoot("Projects/Features/TimerFeature")
            )
            public static let Interface = TargetDependency.project(
                target: "TimerFeatureInterface",
                path: .relativeToRoot("Projects/Features/TimerFeature")
            )
        }
    }
}
