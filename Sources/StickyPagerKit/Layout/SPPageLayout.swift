import UIKit

/// Header 与标签栏的高度配置。非法数值在布局时归一化。
public struct SPPageLayout: Equatable, Sendable {
    public var headerHeight: CGFloat
    /// 完全折叠后保留的 Header 高度；默认 0，标签栏停在容器顶部安全区域边缘。
    public var minimumHeaderHeight: CGFloat
    public var tabBarHeight: CGFloat

    public init(headerHeight: CGFloat = 0, minimumHeaderHeight: CGFloat = 0, tabBarHeight: CGFloat = 44) {
        self.headerHeight = headerHeight
        self.minimumHeaderHeight = minimumHeaderHeight
        self.tabBarHeight = tabBarHeight
    }

    internal var normalized: Self {
        let height = headerHeight.isFinite ? max(0, headerHeight) : 0
        return .init(headerHeight: height,
                     minimumHeaderHeight: minimumHeaderHeight.isFinite ? min(height, max(0, minimumHeaderHeight)) : 0,
                     tabBarHeight: tabBarHeight.isFinite ? max(0, tabBarHeight) : 44)
    }
    internal var collapseRange: CGFloat { normalized.headerHeight - normalized.minimumHeaderHeight }
}

/// Header 的离散状态；连续变化通过代理的 progress 参数提供。
public enum SPHeaderState: Sendable {
    case expanded, collapsing, collapsed
}
