import UIKit

/// 指示器的值类型布局配置；不参与标签或标签栏测量，允许超出标签，最终裁剪到安全视口。
/// automatic 宽度及 nil 高度跟随参考区域；固定尺寸默认不受参考区域限制，可显式启用尺寸上限。
public struct SPTabBarIndicatorLayout: Codable, Equatable, Sendable {
    public enum Reference: String, Codable, Sendable {
        case item, content
        /// 水平跟随选中态标题（无标题时回退到内容），垂直跟随 Item，指示器高度不超过 Item。
        case title
    }

    /// 指示器宽度策略；参考区域由 reference 独立决定。
    public enum Width: Codable, Equatable, Sendable {
        /// 填充内缩后的参考区域；下划线预设默认参考选中态标题。
        case automatic
        /// 固定宽度；显式启用 limitsSizeToReference 时仍受参考区域上限约束。
        case fixed(CGFloat)
    }

    /// 指示器圆角策略，与宽度及展示样式独立。
    public enum CornerRadius: Codable, Equatable, Sendable {
        /// 使用最终宽高较小值的一半。
        case automatic
        /// 指定圆角；0 为直角，数值限制在 0 与短边一半之间。
        case fixed(CGFloat)
    }

    public enum HorizontalAlignment: String, Codable, Sendable { case leading, center, trailing }
    public enum VerticalAlignment: String, Codable, Sendable { case top, center, bottom }
    public enum Placement: String, Codable, Sendable { case background, foreground }

    public var reference: Reference = .item
    public var horizontalAlignment: HorizontalAlignment = .center
    public var verticalAlignment: VerticalAlignment = .center
    /// 默认填充参考区域；切换宽度模式不改变其他布局配置。
    public var width: Width {
        get { storedWidth.map(Width.fixed) ?? .automatic }
        set {
            switch newValue {
            case .automatic: storedWidth = nil
            case let .fixed(width): storedWidth = width
            }
        }
    }

    public var height: CGFloat?
    /// 为 true 时宽高最多等于参考区域，对 automatic 和 fixed 均生效。
    /// 胶囊预设启用；下划线预设不启用，允许固定宽度超过短标题。
    public var limitsSizeToReference = false
    /// 正数内缩，负数外扩；固定尺寸仍按内缩后的区域对齐。
    public var horizontalInset: CGFloat = 0
    public var verticalInset: CGFloat = 0
    /// 物理坐标偏移；x 正值始终向右。逻辑对齐使用 horizontalAlignment。
    public var offset: CGPoint = .zero
    public var placement: Placement = .background
    /// 默认自动圆角；可指定固定圆角或以 fixed(0) 使用直角。
    public var cornerRadius: CornerRadius {
        get { storedCornerRadius.map(CornerRadius.fixed) ?? .automatic }
        set {
            switch newValue {
            case .automatic: storedCornerRadius = nil
            case let .fixed(radius): storedCornerRadius = radius
            }
        }
    }

    // 归档沿用旧版可选数值字段，兼容历史 Appearance 的数值和缺省宽度／圆角。
    private var storedWidth: CGFloat?
    private var storedCornerRadius: CGFloat?
    private enum CodingKeys: String, CodingKey {
        case reference, horizontalAlignment, verticalAlignment, height, limitsSizeToReference
        case storedWidth = "width"
        case horizontalInset, verticalInset, offset, placement
        case storedCornerRadius = "cornerRadius"
    }

    public init() {}

    public static var capsule: Self {
        var value = Self()
        value.limitsSizeToReference = true
        value.horizontalInset = 4
        value.verticalInset = 4
        return value
    }

    /// 默认频道下划线：与标题等宽，位于 Item 底部，高 3 pt。
    public static var underline: Self {
        underline(width: .automatic)
    }

    /// 下划线预设；固定宽度分页时只移动，跟随内容时同时插值位置和宽度。
    public static func underline(width: Width) -> Self {
        var value = Self()
        value.reference = .title
        value.width = width
        value.height = 3
        value.verticalAlignment = .bottom
        return value
    }

    internal func frame(in context: SPTabBarIndicatorLayoutContext) -> CGRect {
        let reference: CGRect
        switch self.reference {
        case .item: reference = context.itemFrame
        case .content: reference = context.contentFrame
        case .title:
            let left = max(context.itemFrame.minX, context.contentFrame.minX)
            let right = min(context.itemFrame.maxX, context.contentFrame.maxX)
            reference = CGRect(
                x: left,
                y: context.itemFrame.minY,
                width: max(0, right - left),
                height: context.itemFrame.height
            )
        }
        let dx = min(Self.finite(horizontalInset), reference.width / 2)
        let dy = min(Self.finite(verticalInset), reference.height / 2)
        let area = CGRect(
            x: reference.minX + dx,
            y: reference.minY + dy,
            width: max(0, reference.width - 2 * dx),
            height: max(0, reference.height - 2 * dy)
        )
        var w: CGFloat
        switch width {
        case .automatic: w = area.width
        case let .fixed(value): w = max(0, Self.finite(value, fallback: area.width))
        }
        var h = height.map { max(0, Self.finite($0, fallback: area.height)) } ?? area.height
        if limitsSizeToReference {
            w = min(w, reference.width)
            h = min(h, reference.height)
        }
        // 标题下划线保持极矮 Item 的垂直保护，不因固定宽度解除水平上限而越界。
        if self.reference == .title {
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
        value.isFinite ? min(
            SPTabBarGeometryLimits.maximumMagnitude,
            max(-SPTabBarGeometryLimits.maximumMagnitude, value)
        ) : fallback
    }

    internal static func valid(_ rect: CGRect) -> Bool {
        // CGRect.width/height 会返回标准化后的尺寸；检查原始 size 才能拒绝负尺寸。
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
            .allSatisfy { $0.isFinite && abs($0) <= SPTabBarGeometryLimits.maximumMagnitude }
            && rect.size.width >= 0 && rect.size.height >= 0
    }
}

/// 所有 frame 均位于横向滚动内容坐标系；框架负责滚动转换，无需减去 contentOffset。
/// contentFrame 通常为当前状态的图文区域（不含角标）；reference 为 title 时取选中态标题区域。
/// 纯图标回退到图标区域，自定义内容未声明区域时回退到整项。
@MainActor
public struct SPTabBarIndicatorLayoutContext {
    public let item: SPTabBarItem
    public let index: Int
    public let itemFrame: CGRect
    public let contentFrame: CGRect
    /// 扣除固定附件后的标签视口对应的滚动内容区域（包含内容留白）。自由布局回调不得依赖回调次数或修改标签栏。
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
