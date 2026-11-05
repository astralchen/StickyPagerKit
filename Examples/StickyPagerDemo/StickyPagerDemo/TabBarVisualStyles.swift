import UIKit
import StickyPagerKit

/// 通用视觉预设示例；独立栏与分页容器使用同一个公开配置。
@MainActor
enum DemoTabBarVisualStyles {
    static func installLaunchStyle(on bar: SPTabBar) {
        if ProcessInfo.processInfo.arguments.contains("--spring-effects") {
            bar.selectionAnimationStyle = .spring
            bar.visualStyle = .scale
            bar.visualStyle.interpolatesDefaultColors = true
        } else if ProcessInfo.processInfo.arguments.contains("--scale-effects") {
            bar.visualStyle = .scale
            bar.visualStyle.interpolatesDefaultColors = true
        } else if ProcessInfo.processInfo.arguments.contains("--color-transition") {
            bar.visualStyle = .colorTransition
        } else if ProcessInfo.processInfo.arguments.contains("--visual-effects") {
            bar.visualStyle = .fadeAndStretch
        }
        if ProcessInfo.processInfo.arguments.contains("--icon-only-colors") {
            // 诊断入口：固定标题并显式指定模板图标两端颜色，覆盖局部颜色更新路径。
            bar.visualStyle.interpolatesDefaultColors = true
            var appearance = bar.standardAppearance.itemAppearance
            appearance.normal.titleColor = .red
            appearance.selected.titleColor = .red
            appearance.normal.iconColor = .red
            appearance.selected.iconColor = .blue
            bar.standardAppearance.itemAppearance = appearance
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
                ("图文颜色过渡", .colorTransition),
                ("内容缩放", .scale),
                ("指示器拉伸", .stretch),
                ("淡化与拉伸", .fadeAndStretch)
            ]
            var actions: [UIMenuElement] = presets.map { title, style in
                UIAction(title: title, state: bar.visualStyle == style ? .on : .off) { [weak bar] _ in
                    bar?.visualStyle = style
                }
            }
            actions.append(UIMenu(title: "选择动画", children: [
                UIAction(title: "平滑动画", state: bar.selectionAnimationStyle == .standard ? .on : .off) { [weak bar] _ in
                    bar?.selectionAnimationStyle = .standard
                },
                UIAction(title: "弹簧动画", state: bar.selectionAnimationStyle == .spring ? .on : .off) { [weak bar] _ in
                    bar?.selectionAnimationStyle = .spring
                }
            ]))
            completion(actions)
        }])
    }
}
