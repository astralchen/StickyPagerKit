import UIKit
import StickyPagerKit

/// 同一组预设可用于独立标签栏和分页容器。
@MainActor
final class DemoIndicatorProvider: SPTabBarIndicatorLayoutDelegate {
    func menu(for bar: SPTabBar) -> UIMenu {
        UIMenu(title: "指示器", children: [
            action("默认下划线", bar: bar, style: .underline),
            UIAction(title: "固定宽度下划线（20 pt）") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                bar.standardAppearance.indicatorLayout = .underline(width: .fixed(20))
            },
            UIMenu(title: "指示器圆角", children: [
                radiusAction("自动圆角", radius: .automatic, bar: bar),
                radiusAction("直角", radius: .fixed(0), bar: bar),
                radiusAction("圆角 1 pt", radius: .fixed(1), bar: bar)
            ]),
            action("胶囊", bar: bar, style: .capsule),
            action("隐藏指示器", bar: bar, style: .none),
            UIAction(title: "顶部固定线条") { [weak bar] _ in
                guard let bar else {
                    return
                }
                self.reset(bar)
                var layout = SPTabBarIndicatorLayout()
                layout.width = .fixed(24)
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
                layout.cornerRadius = .fixed(6)
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

    private func radiusAction(
        _ title: String,
        radius: SPTabBarIndicatorLayout.CornerRadius,
        bar: SPTabBar
    ) -> UIAction {
        UIAction(title: title) { [weak bar] _ in
            guard let bar else {
                return
            }
            var layout = bar.standardAppearance
                .indicatorLayout ?? (bar.indicatorStyle == .underline ? .underline : .capsule)
            layout.cornerRadius = radius
            bar.standardAppearance.indicatorLayout = layout
        }
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
final class DemoIndicatorView: SPTabBarIndicatorView {
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
        gradient.cornerRadius = state.cornerRadius
        gradient.colors = [state.color.cgColor, UIColor.systemPink.cgColor]
        gradient.opacity = Float(0.65 + 0.35 * state.progress)
        CATransaction.commit()
    }
}
