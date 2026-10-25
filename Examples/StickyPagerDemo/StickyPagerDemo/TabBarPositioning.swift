import UIKit
import StickyPagerKit

/// 独立标签栏与分页 Demo 共用的布局和内置内容尺寸菜单。
@MainActor
enum DemoTabBarPositioning {
    static func menu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "标签布局模式", children: [UIDeferredMenuElement.uncached { [weak bar] completion in
            guard let bar else {
                completion([]); return
            }
            let modes: [(String, SPTabBarLayoutConfiguration.ItemSizing, SPTabBarLayoutConfiguration.Alignment)] = [
                ("均衡分配", .balanced, .leading),
                ("等宽填充", .equal, .leading),
                ("内容居中", .content, .center),
                ("起始对齐", .content, .leading),
                ("末尾对齐", .content, .trailing),
                ("固定宽度居中", .fixed(80), .center)
            ]
            completion(modes.map { title, sizing, alignment in
                let selected = bar.layoutConfiguration.itemSizing == sizing && bar.layoutConfiguration
                    .alignment == alignment
                return UIAction(title: title, state: selected ? .on : .off) { [weak bar] _ in
                    guard let bar else {
                        return
                    }
                    var layout = bar.layoutConfiguration
                    layout.itemSizing = sizing
                    layout.alignment = alignment
                    bar.layoutConfiguration = layout
                }
            })
        }])
    }

    static func contentMenu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "默认内容尺寸", children: [
            UIAction(title: "恢复默认尺寸") { [weak bar] _ in
                bar?.defaultContentLayout = SPTabBarDefaultContentLayout()
            },
            UIAction(title: "紧凑图文") { [weak bar] _ in
                var content = SPTabBarDefaultContentLayout()
                content.imagePlacement = .inline
                content.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                content.minimumHeight = 32
                content.iconSize = CGSize(width: 20, height: 20)
                content.imageTitleSpacing = 8
                bar?.defaultContentLayout = content
            },
            UIAction(title: "宽松图文") { [weak bar] _ in
                var content = SPTabBarDefaultContentLayout()
                content.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
                content.iconSize = CGSize(width: 32, height: 32)
                content.imageTitleSpacing = 8
                bar?.defaultContentLayout = content
            }
        ])
    }
}
