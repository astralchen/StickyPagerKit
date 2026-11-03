import UIKit
import StickyPagerKit

/// 通用视觉预设示例；独立栏与分页容器使用同一个公开配置。
@MainActor
enum DemoTabBarVisualStyles {
    static func installLaunchStyle(on bar: SPTabBar) {
        if ProcessInfo.processInfo.arguments.contains("--visual-effects") {
            bar.visualStyle = .fadeAndStretch
        }
    }

    static func menu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "视觉与动画", children: [UIDeferredMenuElement.uncached { [weak bar] completion in
            guard let bar else {
                completion([]); return
            }
            let presets: [(String, SPTabBarVisualStyle)] = [
                ("标准效果", .standard),
                ("内容淡化", .fade),
                ("指示器拉伸", .stretch),
                ("淡化与拉伸", .fadeAndStretch)
            ]
            completion(presets.map { title, style in
                UIAction(title: title, state: bar.visualStyle == style ? .on : .off) { [weak bar] _ in
                    bar?.visualStyle = style
                }
            })
        }])
    }
}
