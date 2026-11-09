import UIKit
import StickyPagerKit

/// 系统设置端到端验收的只读快照；只在图库的专用启动参数下读取。
@MainActor
enum DemoTabAccessibilitySnapshot {
    static func read(bar: SPTabBar, commits: Int) -> String {
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let views = descendants(bar)
        let allHosts = views.filter { $0.accessibilityIdentifier == "sp.tab.visualHost" }
        let collection = views.compactMap { $0 as? UICollectionView }.first
        let hosts = (collection?.visibleCells ?? []).flatMap { descendants($0) }
            .filter { $0.accessibilityIdentifier == "sp.tab.visualHost" }
        let alpha = collection?.visibleCells.map { $0.contentView.alpha }.min() ?? 1
        let focused = UIAccessibility.focusedElement(using: .notificationVoiceOver)
        let focusID = (focused as? UIView)?.accessibilityIdentifier ?? "none"
        // 使用 UIKit 公开状态，不替换设置、不发送模拟通知，也不读取按钮的私有子视图。
        return "motion=\(UIAccessibility.isReduceMotionEnabled ? 1 : 0);"
            + "transparency=\(UIAccessibility.isReduceTransparencyEnabled ? 1 : 0);"
            + "voiceOver=\(UIAccessibility.isVoiceOverRunning ? 1 : 0);"
            + "hasFocus=\(focused == nil ? 0 : 1);"
            + "focusType=\(focused.map { String(describing: type(of: $0)) } ?? "none");"
            + "focusAttached=\((focused as? UIView)?.window == nil ? 0 : 1);"
            + "scaleHosts=\(hosts.count);minScale=\(hosts.map { $0.transform.a }.min() ?? 1);"
            + "allScaleHosts=\(allHosts.count);"
            + "minAlpha=\(alpha);commits=\(commits);selected=\(bar.selectedIndex ?? -1);focus=\(focusID);"
    }
}
