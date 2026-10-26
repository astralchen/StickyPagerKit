import UIKit

/// 同步提供页面快照。每个页面必须具有唯一且稳定的标识。
@MainActor
public protocol SPPageViewControllerDataSource: AnyObject {
    func numberOfPages(in pageViewController: SPPageViewController) -> Int
    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable
    /// 返回内容页。根视图顶部始终与标签栏顶部对齐，铺满容器宽度并延伸至底边。
    /// 标签栏位于页面上方；框架为子控制器附加安全区域叠加实际栏高，移除页面时恢复业务值。
    /// 页面高度随 Header 折叠变化；内部控件使用 safeAreaLayoutGuide 避让标签栏和系统安全区域。
    /// 主要滚动视图优先使用自动 inset，框架仅补足尚未避让的标签栏遮挡，不重复叠加。
    func pageViewController(_ pageViewController: SPPageViewController, viewControllerAt index: Int) -> UIViewController
    /// 在页面首次绑定前提供选择，默认自动发现。缓存重建时为新控制器重新查询。
    /// 运行时设置的绑定选择优先；显式列表必须属于传入控制器的视图树。
    func pageViewController(
        _ pageViewController: SPPageViewController,
        scrollViewBindingFor viewController: UIViewController,
        at index: Int
    ) -> SPScrollViewBinding
    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem
}

public extension SPPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: SPPageViewController,
        scrollViewBindingFor viewController: UIViewController,
        at index: Int
    ) -> SPScrollViewBinding {
        .automatic
    }

    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem {
        SPTabBarItem(title: "\(index + 1)")
    }
}

/// 转场完成后通知选中项；进度不会改变 selectedIndex。
@MainActor
public protocol SPPageViewControllerDelegate: AnyObject {
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int)
    func pageViewController(
        _ pageViewController: SPPageViewController,
        didScrollFrom fromIndex: Int,
        to toIndex: Int,
        progress: CGFloat
    )
    func pageViewController(
        _ pageViewController: SPPageViewController,
        didChangeHeaderState state: SPHeaderState,
        progress: CGFloat
    )
}

public extension SPPageViewControllerDelegate {
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {}
    func pageViewController(
        _ pageViewController: SPPageViewController,
        didScrollFrom fromIndex: Int,
        to toIndex: Int,
        progress: CGFloat
    ) {}
    func pageViewController(
        _ pageViewController: SPPageViewController,
        didChangeHeaderState state: SPHeaderState,
        progress: CGFloat
    ) {}
}
