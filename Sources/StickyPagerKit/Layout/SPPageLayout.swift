import UIKit

/// 容器标签栏的高度策略。固定高度裁切超出的内容；默认随内容增高。
public enum SPTabBarSizing: Equatable, Sendable {
    case content(minimum: CGFloat)
    case fixed(CGFloat)
    case hidden

    internal var normalized: Self {
        switch self {
        case let .content(minimum): .content(minimum: SPLayoutValue.length(minimum, fallback: 44))
        case let .fixed(height): .fixed(SPLayoutValue.length(height, fallback: 44))
        case .hidden: .hidden
        }
    }

    internal var configuredHeight: CGFloat {
        switch normalized {
        case let .content(minimum): minimum
        case let .fixed(height): height
        case .hidden: 0
        }
    }
}

/// Header 与标签栏的高度配置。非法数值在布局时归一化。
public struct SPPageLayout: Equatable, Sendable {
    /// 从容器顶部算起的 Header 总高度，包含顶部安全区域；不足吸顶基线时自动补足。
    public var headerHeight: CGFloat
    /// 完全折叠后在顶部安全区域下方保留的 Header 高度；默认 0，标签栏停在安全区域边缘。
    public var minimumHeaderHeight: CGFloat
    /// 默认随内容增高且不低于 44 pt；可显式固定高度或隐藏。
    public var tabBarSizing: SPTabBarSizing

    /// 旧高度入口：正值转为内容最小高度，0 或负值隐藏。新代码使用 tabBarSizing。
    /// 读取 content 返回下限，fixed 返回固定值，hidden 返回 0；不是实际测量高度。
    public var tabBarHeight: CGFloat {
        get { tabBarSizing.configuredHeight }
        set { tabBarSizing = Self.legacySizing(newValue) }
    }

    public init(
        headerHeight: CGFloat = 0,
        minimumHeaderHeight: CGFloat = 0,
        tabBarSizing: SPTabBarSizing = .content(minimum: 44)
    ) {
        self.headerHeight = headerHeight
        self.minimumHeaderHeight = minimumHeaderHeight
        self.tabBarSizing = tabBarSizing
    }

    /// 兼容旧的最小高度初始化；0 表示隐藏。
    public init(headerHeight: CGFloat = 0, minimumHeaderHeight: CGFloat = 0, tabBarHeight: CGFloat) {
        self.init(
            headerHeight: headerHeight,
            minimumHeaderHeight: minimumHeaderHeight,
            tabBarSizing: Self.legacySizing(tabBarHeight)
        )
    }

    private static func legacySizing(_ height: CGFloat) -> SPTabBarSizing {
        let height = SPLayoutValue.length(height, fallback: 44)
        return height == 0 ? .hidden : .content(minimum: height)
    }

    internal var normalized: Self {
        let height = headerHeight.isFinite ? max(0, headerHeight) : 0
        return .init(
            headerHeight: height,
            minimumHeaderHeight: minimumHeaderHeight.isFinite ? min(height, max(0, minimumHeaderHeight)) : 0,
            tabBarSizing: tabBarSizing.normalized
        )
    }

    internal var collapseRange: CGFloat {
        normalized.headerHeight - normalized.minimumHeaderHeight
    }
}

/// Header 的离散状态；连续变化通过代理的 progress 参数提供。
public enum SPHeaderState: Sendable {
    case expanded, collapsing, collapsed
}
