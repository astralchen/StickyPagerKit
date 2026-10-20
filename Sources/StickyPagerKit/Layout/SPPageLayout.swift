import UIKit

/// Header 与标签栏的高度配置。非法数值在布局时归一化。
public struct SPPageLayout: Equatable, Sendable {
    /// 从容器顶部算起的 Header 总高度，包含顶部安全区域；不足吸顶基线时自动补足。
    public var headerHeight: CGFloat
    /// 完全折叠后在顶部安全区域下方保留的 Header 高度；默认 0，标签栏停在安全区域边缘。
    public var minimumHeaderHeight: CGFloat
    /// 标签栏最小高度，默认 44 pt；实际高度取此值与内容所需高度的较大值，并非固定高度。
    /// 自定义内容允许低于 44 pt；默认图文仍保留自身至少 44 pt 的高度规则。
    /// 内容可因多行文字或 Dynamic Type 增高；0 表示隐藏，无论内容所需高度为多少。
    public var tabBarHeight: CGFloat

    public init(headerHeight: CGFloat = 0, minimumHeaderHeight: CGFloat = 0, tabBarHeight: CGFloat = 44) {
        self.headerHeight = headerHeight
        self.minimumHeaderHeight = minimumHeaderHeight
        self.tabBarHeight = tabBarHeight
    }

    internal var normalized: Self {
        let height = headerHeight.isFinite ? max(0, headerHeight) : 0
        return .init(
            headerHeight: height,
            minimumHeaderHeight: minimumHeaderHeight.isFinite ? min(height, max(0, minimumHeaderHeight)) : 0,
            tabBarHeight: tabBarHeight.isFinite ? max(0, tabBarHeight) : 44
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
