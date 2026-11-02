import UIKit

private let selectionProgressKey = UIConfigurationStateCustomKey("StickyPagerKit.selectionProgress")

public extension UICellConfigurationState {
    /// 标签内容的连续选择程度，范围为 0...1；1 表示完整选中外观，0 表示未选中外观。
    /// 开启 SPTabBarContent.tracksSelectionProgress 后，显示配置随分页及程序动画更新。
    /// 测量或未携带此值的状态按 isSelected 返回 0 或 1；不表示逻辑选择已经提交。
    /// 跨页跳转只插值起终项；动画被接管时从各项当前程度继续，可能同时有多个部分选中项。
    var spSelectionProgress: CGFloat {
        guard let value = self[selectionProgressKey] as? CGFloat, value.isFinite else {
            return isSelected ? 1 : 0
        }
        return min(1, max(0, value))
    }
}

internal extension UICellConfigurationState {
    mutating func setSPSelectionProgress(_ progress: CGFloat) {
        self[selectionProgressKey] = progress
    }
}
