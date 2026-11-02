import UIKit

/// 无 UIKit 写入的几何计算；调用方在每次布局事务内提供当前测量值。
@MainActor
internal enum SPPageGeometry {
    static func effectiveLayout(
        _ configuration: SPPageLayout,
        measuredTabHeight: CGFloat?,
        hasHeader: Bool,
        safeTop: CGFloat
    ) -> SPPageLayout {
        var value = configuration.normalized
        if case let .content(minimum) = value.tabBarSizing, let measuredTabHeight {
            value.tabBarSizing = .fixed(max(minimum, measuredTabHeight))
        }
        if !hasHeader {
            value.headerHeight = 0
            value.minimumHeaderHeight = 0
        }
        value.minimumHeaderHeight += safeTop
        value.headerHeight = max(value.headerHeight, value.minimumHeaderHeight)
        return value
    }

    static func viewport(size: CGSize, layout: SPPageLayout) -> CGRect {
        CGRect(
            x: 0,
            y: layout.minimumHeaderHeight,
            width: size.width,
            height: max(0, size.height - layout.minimumHeaderHeight)
        )
    }

    static func physicalIndex(_ logical: Int, count: Int, isRTL: Bool) -> CGFloat {
        CGFloat(isRTL ? count - 1 - logical : logical)
    }

    static func pageFrame(physicalIndex: CGFloat, viewport: CGSize, top: CGFloat) -> CGRect {
        CGRect(
            x: physicalIndex * viewport.width,
            y: top,
            width: viewport.width,
            height: max(0, viewport.height - top)
        )
    }
}
