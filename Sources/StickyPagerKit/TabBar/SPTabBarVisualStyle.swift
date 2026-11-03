import UIKit

/// 与内容类型、颜色和指示器布局独立的内置视觉预设；不改变测量、命中区域或逻辑选择。
/// 赋给 SPTabBar.visualStyle 时归一化；预设为值类型，可在副本上调整。
public struct SPTabBarVisualStyle: Equatable, Sendable {
    public enum IndicatorMotion: Sendable {
        /// 两端以相同进度移动，保持现有位置及宽高插值。
        case linear
        /// 水平前缘先行、后缘跟进；按物理端点判断方向，自动适配 RTL 与反向拖动。
        /// 起终点保持布局配置的尺寸，中间态允许拉长；不产生弹簧越界或额外计时器。
        case stretch
    }

    /// 未选中内容的整体透明度，选中时为 1；包含图文、角标或自定义内容。
    /// 有限值限制在 0.2...1，避免内容容器因完全透明而退出触摸命中；非有限值回退到 1。
    /// 禁用项保留自身外观，不叠加淡化；降低透明度设置启用时也不叠加淡化。
    public var unselectedAlpha: CGFloat
    /// 指示器的形变方式；减少动态效果启用时按 linear 呈现。
    /// 对内置和自定义指示器均生效；不改变其颜色、层级或最终端点几何。
    public var indicatorMotion: IndicatorMotion

    public init(unselectedAlpha: CGFloat = 1, indicatorMotion: IndicatorMotion = .linear) {
        self.unselectedAlpha = unselectedAlpha
        self.indicatorMotion = indicatorMotion
    }

    /// 保持现有外观与动画，默认值。
    public static var standard: Self {
        Self()
    }

    /// 未选中内容使用 0.55 透明度，连续过渡到选中态；不改变字体或显式颜色。
    public static var fade: Self {
        Self(unselectedAlpha: 0.55)
    }

    /// 内容保持原样，只让指示器拉伸跟随。
    public static var stretch: Self {
        Self(indicatorMotion: .stretch)
    }

    /// 同时使用内容淡化与指示器拉伸。
    public static var fadeAndStretch: Self {
        Self(unselectedAlpha: 0.55, indicatorMotion: .stretch)
    }

    internal var normalized: Self {
        Self(
            unselectedAlpha: unselectedAlpha.isFinite ? min(1, max(0.2, unselectedAlpha)) : 1,
            indicatorMotion: indicatorMotion
        )
    }

    internal func alpha(progress: CGFloat, enabled: Bool, reduceTransparency: Bool) -> CGFloat {
        guard enabled, !reduceTransparency else {
            return 1
        }
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        let minimum = normalized.unselectedAlpha
        return minimum + (1 - minimum) * p
    }

    internal func motion(reduceMotion: Bool) -> IndicatorMotion {
        reduceMotion ? .linear : indicatorMotion
    }

    internal static func indicatorFrame(
        from a: CGRect,
        to b: CGRect,
        progress p: CGFloat,
        motion: IndicatorMotion
    ) -> CGRect {
        var result = CGRect(
            x: a.minX + (b.minX - a.minX) * p,
            y: a.minY + (b.minY - a.minY) * p,
            width: a.width + (b.width - a.width) * p,
            height: a.height + (b.height - a.height) * p
        )
        guard motion == .stretch, !a.isEmpty, !b.isEmpty, a.midX != b.midX else {
            return result
        }
        let slow = p * p
        let fast = 1 - (1 - p) * (1 - p)
        let leftProgress = b.midX > a.midX ? slow : fast
        let rightProgress = b.midX > a.midX ? fast : slow
        let left = a.minX + (b.minX - a.minX) * leftProgress
        let right = a.maxX + (b.maxX - a.maxX) * rightProgress
        result.origin.x = left
        result.size.width = max(0, right - left)
        return result
    }
}
