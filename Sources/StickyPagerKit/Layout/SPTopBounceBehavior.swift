import UIKit

/// 顶部下拉越界的呈现归属；不改变列表底部和横向回弹配置。
public enum SPTopBounceBehavior: Sendable {
    /// Header、标签栏和页面整体平移，Header 不拉伸。
    case container
    /// 遵循当前主要滚动视图的业务回弹配置；没有绑定时不回弹。
    case page
}
