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
    }

    public struct Features {
        public struct Base {
            public static let Base = TargetDependency.project(
                target: "BaseFeatureDependency",
                path: .relativeToRoot("Projects/Features/BaseFeatureDependency")
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
    }
}
