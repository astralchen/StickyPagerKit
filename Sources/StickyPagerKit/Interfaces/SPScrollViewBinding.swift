import UIKit

/// 页面主要滚动视图的绑定选择，不改变业务滚动视图自身的交互开关。
@MainActor
public enum SPScrollViewBinding {
    /// 按默认规则自动发现主要纵向滚动视图。
    case automatic
    /// 不绑定业务滚动视图；保留页面布局、分页及 Header／标签栏自身的折叠交互。
    case unbound
    /// 仅绑定指定的页面内滚动视图；失效后不自动选择其他列表。
    case explicit(UIScrollView)
}

/// 保存选择与弱引用，显式对象释放后仍保留“仅绑定指定对象”的意图。
@MainActor
internal final class SPScrollViewBindingSelection {
    enum Mode { case automatic, unbound, explicit }
    let mode: Mode
    weak var scrollView: UIScrollView?

    init(_ selection: SPScrollViewBinding) {
        switch selection {
        case .automatic: mode = .automatic
        case .unbound: mode = .unbound
        case let .explicit(scroll):
            mode = .explicit
            scrollView = scroll
        }
    }
}
