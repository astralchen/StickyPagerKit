import UIKit

/// 标签组的尺寸与位置配置；赋值到标签栏时统一归一化，并作为一次布局更新应用。
public struct SPTabBarLayoutConfiguration: Equatable, Sendable {
    public enum ItemSizing: Equatable, Sendable {
        /// 按内容理想宽度排列；可通过 maximumItemWidth 限制长标题。
        case content
        /// 均分可用宽度；仍遵守 minimumItemWidth，必要时横向滚动。
        case equal
        /// 先满足较宽项，再将余量均分给较窄项。
        case balanced
        /// 固定项宽，仍遵守 minimumItemWidth；内容应支持压缩。
        case fixed(CGFloat)
    }

    public enum Alignment: Equatable, Sendable { case leading, center, trailing }

    public var itemSizing: ItemSizing = .content
    /// 仅在整组内容未填满视口时生效，遵循 RTL。
    public var alignment: Alignment = .leading
    /// 所有宽度策略的下限，不扩大 Item 之外的点击区域。
    public var minimumItemWidth: CGFloat = 44
    /// 仅限制 content 策略；nil 不限制，小于 minimumItemWidth 时以下限为准。
    public var maximumItemWidth: CGFloat?
    public var itemSpacing: CGFloat = 0
    /// 水平留白随标签内容滚动；上下留白内缩 Item 并参与建议栏高，不作用于附件。
    public var contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    public init() {}

    internal var normalized: Self {
        var value = self
        value.minimumItemWidth = SPLayoutValue.length(minimumItemWidth, fallback: 44)
        value.maximumItemWidth = maximumItemWidth.flatMap {
            $0.isFinite ? max(value.minimumItemWidth, SPLayoutValue.length($0)) : nil
        }
        value.itemSpacing = SPLayoutValue.length(itemSpacing)
        value.contentInsets = SPLayoutValue.insets(contentInsets)
        if case let .fixed(width) = itemSizing {
            value.itemSizing = .fixed(SPLayoutValue.length(width, fallback: 44))
        }
        return value
    }

    internal var constrainsContentWidth: Bool {
        switch itemSizing {
        case .equal, .fixed: true
        case .content: maximumItemWidth != nil
        case .balanced: false
        }
    }
}

/// 默认图文的内部尺寸规范；不应用于业务自定义内容，也不进入 Appearance 归档。
public struct SPTabBarDefaultContentLayout: Equatable, Sendable {
    public enum ImagePlacement: Equatable, Sendable { case automatic, stacked, inline }

    public var imagePlacement: ImagePlacement = .automatic
    public var contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16)
    public var minimumHeight: CGFloat = 44
    /// 图标按比例放入此区域；任一分量为零时隐藏图标。
    public var iconSize = CGSize(width: 24, height: 24)
    public var imageTitleSpacing: CGFloat = 4

    public init() {}

    internal var normalized: Self {
        var value = self
        value.contentInsets = SPLayoutValue.insets(contentInsets)
        value.minimumHeight = SPLayoutValue.length(minimumHeight, fallback: 44)
        value.iconSize = CGSize(
            width: SPLayoutValue.length(iconSize.width, fallback: 24),
            height: SPLayoutValue.length(iconSize.height, fallback: 24)
        )
        value.imageTitleSpacing = SPLayoutValue.length(imageTitleSpacing, fallback: 4)
        return value
    }

    internal func height(for contentHeight: CGFloat) -> CGFloat {
        max(minimumHeight, contentHeight + contentInsets.top + contentInsets.bottom)
    }
}

internal enum SPLayoutValue {
    static func length(_ value: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        value.isFinite ? min(1_000_000, max(0, value)) : fallback
    }

    static func insets(_ value: NSDirectionalEdgeInsets) -> NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(
            top: length(value.top),
            leading: length(value.leading),
            bottom: length(value.bottom),
            trailing: length(value.trailing)
        )
    }
}
