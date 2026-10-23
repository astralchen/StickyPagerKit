import UIKit
import StickyPagerKit

/// 独立标签栏与分页 Demo 共用的宽度分配菜单。
@MainActor
enum DemoTabBarPositioning {
    static func menu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "标签布局模式", children: [UIDeferredMenuElement.uncached { [weak bar] completion in
            guard let bar else {
                completion([])
                return
            }
            let modes: [(String, SPTabBar.ItemPositioning)] = [
                ("自动分配 · automatic", .automatic),
                ("强制等宽 · fill", .fill),
                ("内容居中 · centered", .centered),
                ("起始对齐 · leading", .leading)
            ]
            completion(modes.map { title, mode in
                UIAction(title: title, state: bar.itemPositioning == mode ? .on : .off) { [weak bar] _ in
                    bar?.itemPositioning = mode
                }
            })
        }])
    }
}
