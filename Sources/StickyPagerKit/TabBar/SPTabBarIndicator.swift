import UIKit

/// 指示器的值类型布局配置；不参与标签或标签栏测量，允许超出标签，最终裁剪到安全视口。
/// nil 宽高跟随参考区域；固定宽高不受参考区域限制。负尺寸归零，非有限值使用默认值。
public struct SPTabBarIndicatorLayout: Codable, Equatable, Sendable {
    public enum Reference: String, Codable, Sendable { case item, content }
    public enum HorizontalAlignment: String, Codable, Sendable { case leading, center, trailing }
    public enum VerticalAlignment: String, Codable, Sendable { case top, center, bottom }
    public enum Placement: String, Codable, Sendable { case background, foreground }

    public var reference: Reference = .item
    public var horizontalAlignment: HorizontalAlignment = .center
    public var verticalAlignment: VerticalAlignment = .center
    public var width: CGFloat?
    public var height: CGFloat?
    /// 为 true 时宽高最多等于参考区域；内置预设启用，避免极小标签产生越界。
    public var limitsSizeToReference = false
    /// 正数内缩，负数外扩；固定尺寸仍按内缩后的区域对齐。
    public var horizontalInset: CGFloat = 0
    public var verticalInset: CGFloat = 0
    /// 物理坐标偏移；x 正值始终向右。逻辑对齐使用 horizontalAlignment。
    public var offset: CGPoint = .zero
    public var placement: Placement = .background
    /// nil 使用高度的一半；显式值限制到宽高较小值的一半。
    public var cornerRadius: CGFloat?

    public init() {}

    public static var capsule: Self {
        var value = Self()
        value.limitsSizeToReference = true
        value.horizontalInset = 4
        value.verticalInset = 4
        return value
    }

    public static var underline: Self {
        var value = Self()
        value.limitsSizeToReference = true
        value.horizontalInset = 12
        value.height = 3
        value.verticalAlignment = .bottom
        return value
    }

    internal func frame(in context: SPTabBarIndicatorLayoutContext) -> CGRect {
        let reference = reference == .item ? context.itemFrame : context.contentFrame
        let dx = min(Self.finite(horizontalInset), reference.width / 2)
        let dy = min(Self.finite(verticalInset), reference.height / 2)
        let area = CGRect(
            x: reference.minX + dx,
            y: reference.minY + dy,
            width: max(0, reference.width - 2 * dx),
            height: max(0, reference.height - 2 * dy)
        )
        var w = width.map { max(0, Self.finite($0, fallback: area.width)) } ?? area.width
        var h = height.map { max(0, Self.finite($0, fallback: area.height)) } ?? area.height
        if limitsSizeToReference {
            w = min(w, reference.width)
            h = min(h, reference.height)
        }
        let rtl = context.layoutDirection == .rightToLeft
        let x: CGFloat
        switch horizontalAlignment {
        case .leading: x = rtl ? area.maxX - w : area.minX
        case .center: x = area.midX - w / 2
        case .trailing: x = rtl ? area.minX : area.maxX - w
        }
        let y: CGFloat
        switch verticalAlignment {
        case .top: y = area.minY
        case .center: y = area.midY - h / 2
        case .bottom: y = area.maxY - h
        }
        return CGRect(x: x + Self.finite(offset.x), y: y + Self.finite(offset.y), width: w, height: h)
    }

    internal static func finite(_ value: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        value.isFinite ? min(1_000_000, max(-1_000_000, value)) : fallback
    }

    internal static func valid(_ rect: CGRect) -> Bool {
        // CGRect.width/height 会返回标准化后的尺寸；检查原始 size 才能拒绝负尺寸。
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
            .allSatisfy { $0.isFinite && abs($0) <= 1_000_000 }
            && rect.size.width >= 0 && rect.size.height >= 0
    }
}

/// 所有 frame 均位于横向滚动内容坐标系；框架负责滚动转换，无需减去 contentOffset。
/// contentFrame 为当前状态的图文区域（不含角标）；自定义内容未声明区域时回退到整项。
@MainActor
public struct SPTabBarIndicatorLayoutContext {
    public let item: SPTabBarItem
    public let index: Int
    public let itemFrame: CGRect
    public let contentFrame: CGRect
    /// 安全视口对应的滚动内容区域。自由布局回调不得依赖回调次数或修改标签栏。
    public let viewportFrame: CGRect
    public let layoutDirection: UIUserInterfaceLayoutDirection
    public let traitCollection: UITraitCollection
    public let layout: SPTabBarIndicatorLayout
}

/// 自定义几何扩展点，业务方持有，标签栏弱引用；优先于 Appearance 中的布局配置。
@MainActor
public protocol SPTabBarIndicatorLayoutDelegate: AnyObject {
    /// 返回 nil 或非法矩形时使用配置计算的 frame；零尺寸可隐藏某项指示器。
    /// 回调同步且无副作用；可能为屏幕外标签执行，不可依赖可见 Cell。
    func tabBar(_ tabBar: SPTabBar, indicatorFrameFor context: SPTabBarIndicatorLayoutContext) -> CGRect?
}

/// 渲染状态；静止时 fromIndex 与 toIndex 相同，progress 为 1。转场进度已经过动画曲线处理。
/// 索引为 nil 表示对应端点没有选中项。
@MainActor
public struct SPTabBarIndicatorState {
    public let fromIndex: Int?
    public let toIndex: Int?
    public let progress: CGFloat
    public let frame: CGRect
    public let color: UIColor
    public let cornerRadius: CGFloat
}

/// 可替换的装饰视图。框架管理 frame、层级、隐藏及交互，子类在 update 中更新显示内容。
/// 不修改自身 frame/transform，不触发布局回调；需要 Auto Layout 时只约束内部子视图。
@MainActor
open class SPTabBarIndicatorView: UIView {
    open func update(_ state: SPTabBarIndicatorState) {
        backgroundColor = state.color
        layer.cornerRadius = state.cornerRadius
    }
}
