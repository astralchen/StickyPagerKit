import UIKit
import StickyPagerKit

/// 两个 Demo 共用的频道栏操作；业务菜单与框架布局配置分开。
@MainActor
enum DemoTabBarAccessories {
    static func install(on bar: SPTabBar, owner: UIViewController, leading: Bool, trailing: Bool) {
        if leading {
            let search = button(symbol: "magnifyingglass", label: "搜索频道", identifier: "demo.accessory.search")
            search.addAction(UIAction { [weak owner] _ in
                let alert = UIAlertController(
                    title: "搜索频道",
                    message: "这里可以接入你的频道搜索。当前演示不进行网络请求。",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                owner?.present(alert, animated: true)
            }, for: .touchUpInside)
            bar.leadingAccessoryView = search
        } else {
            bar.leadingAccessoryView = nil
        }
        if trailing {
            let more = button(symbol: "line.3.horizontal", label: "更多频道", identifier: "demo.accessory.more")
            more.showsMenuAsPrimaryAction = true
            more.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak bar] completion in
                guard let bar else {
                    completion([]); return
                }
                completion(bar.items.enumerated().map { index, item in
                    let name = [item.title, item.accessibilityLabel].compactMap { $0 }.first { !$0.isEmpty } ?? "未命名"
                    return UIAction(
                        title: "频道 \(index + 1)：\(name)",
                        attributes: item.isEnabled ? [] : [.disabled],
                        state: bar.selectedItem === item ? .on : .off
                    ) { [weak bar, weak item] _ in
                        if let item {
                            bar?.requestSelection(of: item)
                        }
                    }
                })
            }])
            bar.trailingAccessoryView = more
        } else {
            bar.trailingAccessoryView = nil
        }
    }

    static func menu(for bar: SPTabBar, owner: UIViewController) -> UIMenu {
        UIMenu(title: "留白与附件", children: [
            UIMenu(title: "内容留白", children: [
                insetAction("无留白", .zero, bar),
                insetAction("对称留白", NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16), bar),
                insetAction("非对称留白", NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 10, trailing: 32), bar)
            ]),
            UIMenu(title: "固定附件", children: [
                accessoryAction("无附件", bar, owner, false, false),
                accessoryAction("仅搜索", bar, owner, true, false),
                accessoryAction("仅更多频道", bar, owner, false, true),
                accessoryAction("两端附件", bar, owner, true, true)
            ]),
            UIAction(title: "切换附件文字") { [weak bar] _ in
                guard let bar, let button = bar.leadingAccessoryView as? UIButton else {
                    return
                }
                var configuration = button.configuration
                let title = configuration?.title == nil ? "搜索" : nil
                configuration?.title = title
                button.configuration = configuration
                bar.invalidateAccessoryLayout()
            },
            UIAction(title: "切换高附件") { [weak bar] _ in
                guard let bar, let button = bar.trailingAccessoryView as? UIButton,
                      let constraint = button.constraints.first(where: { $0.identifier == "demo.accessory.height" }) else {
                    return
                }
                constraint.constant = constraint.constant == 44 ? 80 : 44
                bar.invalidateAccessoryLayout()
            },
            UIAction(title: "切换布局方向") { [weak bar] _ in
                guard let bar else {
                    return
                }
                bar.semanticContentAttribute = bar
                    .effectiveUserInterfaceLayoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
                bar.invalidateAccessoryLayout()
            }
        ])
    }

    private static func button(symbol: String, label: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
        let height = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        height.identifier = "demo.accessory.height"
        NSLayoutConstraint.activate([button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44), height])
        return button
    }

    private static func insetAction(_ title: String, _ insets: NSDirectionalEdgeInsets, _ bar: SPTabBar) -> UIAction {
        UIAction(title: title) { [weak bar] _ in bar?.layoutConfiguration.contentInsets = insets }
    }

    private static func accessoryAction(
        _ title: String,
        _ bar: SPTabBar,
        _ owner: UIViewController,
        _ leading: Bool,
        _ trailing: Bool
    ) -> UIAction {
        UIAction(title: title) { [weak bar, weak owner] _ in
            guard let bar, let owner else {
                return
            }
            install(on: bar, owner: owner, leading: leading, trailing: trailing)
        }
    }
}
