import UIKit

/// 同步提供页面快照。每个页面必须具有唯一且稳定的标识。
@MainActor
public protocol SPPageViewControllerDataSource: AnyObject {
    func numberOfPages(in pageViewController: SPPageViewController) -> Int
    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable
    /// 返回内容页。根视图顶部始终跟随标签栏底部，铺满容器宽度并延伸至底边。
    /// 页面高度随 Header 折叠变化；内部控件使用 safeAreaLayoutGuide 或滚动视图的自动 inset 避让系统安全区域。
    func pageViewController(_ pageViewController: SPPageViewController, viewControllerAt index: Int) -> UIViewController
    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem
}

public extension SPPageViewControllerDataSource {
    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem {
        SPTabBarItem(title: "\(index + 1)")
    }
}

/// 转场完成后通知选中项；进度不会改变 selectedIndex。
@MainActor
public protocol SPPageViewControllerDelegate: AnyObject {
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int)
    func pageViewController(_ pageViewController: SPPageViewController, didScrollFrom fromIndex: Int, to toIndex: Int, progress: CGFloat)
    func pageViewController(_ pageViewController: SPPageViewController, didChangeHeaderState state: SPHeaderState, progress: CGFloat)
}

public extension SPPageViewControllerDelegate {
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {}
    func pageViewController(_ pageViewController: SPPageViewController, didScrollFrom fromIndex: Int, to toIndex: Int, progress: CGFloat) {}
    func pageViewController(_ pageViewController: SPPageViewController, didChangeHeaderState state: SPHeaderState, progress: CGFloat) {}
}
