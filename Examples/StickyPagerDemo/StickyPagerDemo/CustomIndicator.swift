import UIKit
import StickyPagerKit

/// 同一组预设可用于独立标签栏和分页容器。
@MainActor
final class DemoIndicatorProvider: SPTabBarIndicatorLayoutDelegate {
    func menu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "指示器", children: [
            action("默认胶囊", bar: bar, style: .capsule),
            action("底部线条", bar: bar, style: .underline),
            action("隐藏指示器", bar: bar, style: .none),
            UIAction(title: "顶部固定线条") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                var layout = SPTabBarIndicatorLayout()
                layout.width = 24
                layout.height = 4
                layout.verticalAlignment = .top
                bar.standardAppearance.indicatorLayout = layout
            },
            UIAction(title: "跟随内容宽度") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                var layout = SPTabBarIndicatorLayout()
                layout.reference = .content
                layout.height = 3
                layout.verticalAlignment = .bottom
                layout.offset.y = 5
                bar.standardAppearance.indicatorLayout = layout
            },
            UIAction(title: "内容背景") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                var layout = SPTabBarIndicatorLayout()
                layout.reference = .content
                layout.horizontalInset = -6
                layout.verticalInset = -3
                layout.cornerRadius = 6
                bar.indicatorStyle = .capsule
                bar.standardAppearance.indicatorLayout = layout
            },
            UIAction(title: "自由布局与自定义视图") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                var layout = SPTabBarIndicatorLayout()
                layout.placement = .foreground
                bar.standardAppearance.indicatorLayout = layout
                bar.indicatorStyle = .custom
                bar.indicatorLayoutDelegate = self
                bar.indicatorView = DemoIndicatorView()
            }
        ])
    }

    private func action(_ title: String, bar: SPTabBar, style: SPTabBar.IndicatorStyle) -> UIAction {
        UIAction(title: title) { [weak bar] _ in
            guard let bar else {
                return
            }
            self.reset(bar)
            bar.indicatorStyle = style
        }
    }

    private func reset(_ bar: SPTabBar) {
        bar.indicatorStyle = .underline
        bar.indicatorLayoutDelegate = nil
        bar.indicatorView = nil
        bar.standardAppearance.indicatorColor = nil
        bar.standardAppearance.indicatorLayout = nil
    }

    func tabBar(_ tabBar: SPTabBar, indicatorFrameFor context: SPTabBarIndicatorLayoutContext) -> CGRect? {
        // 大小与纵向位置随标签变化，分页时四个 frame 分量一起插值。
        let height: CGFloat = context.index.isMultiple(of: 2) ? 6 : 10
        return CGRect(
            x: context.contentFrame.midX - 16,
            y: context.itemFrame.maxY - height - 2,
            width: 32,
            height: height
        )
    }
}

@MainActor
private final class DemoIndicatorView: SPTabBarIndicatorView {
    private let gradient = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradient)
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(frame:)")
    }

    override func update(_ state: SPTabBarIndicatorState) {
        backgroundColor = .clear
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        gradient.colors = [state.color.cgColor, UIColor.systemPink.cgColor]
        gradient.opacity = Float(0.65 + 0.35 * state.progress)
        CATransaction.commit()
    }
}
