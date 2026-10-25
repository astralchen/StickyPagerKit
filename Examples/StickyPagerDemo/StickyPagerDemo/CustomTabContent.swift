import UIKit
import StickyPagerKit

/// 业务方持有内容代理；同一份卡片配置可用于独立标签栏和分页容器。
@MainActor
final class DemoTabContentProvider: SPTabBarContentDelegate {
    var subtitle = "浏览专题"
    var usesCompactContent = false
    var usesNumberContent = false
    var usesWideContent = false
    var fixedHeight: CGFloat?

    /// 更新业务配置后只刷新一次；切入自定义模式时由属性 setter 完成刷新。
    func showCustomContent(on bar: SPTabBar) {
        if bar.contentStyle == .custom {
            bar.reloadContent()
        } else {
            bar.contentStyle = .custom
        }
    }

    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        makeContent(
            on: tabBar,
            item: item,
            index: index,
            traits: context.state.traitCollection,
            tintColor: context.tintColor,
            direction: context.layoutDirection,
            width: context.availableWidth
        )
    }

    private func makeContent(
        on tabBar: SPTabBar,
        item: SPTabBarItem,
        index: Int,
        traits: UITraitCollection,
        tintColor: UIColor,
        direction: UIUserInterfaceLayoutDirection,
        width: CGFloat
    ) -> SPTabBarContent {
        if usesCompactContent {
            // 内容只有文字与内边距；UILabel 固有尺寸和完整约束负责测高。
            return SPTabBarContent(configuration: DemoCompactConfiguration(
                title: usesNumberContent ? "\(index + 1)" : (item.title ?? "未命名"),
                font: UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits),
                tintColor: tintColor,
                minimumWidth: usesWideContent && index == 0 ? max(480, width + 80) : 0
            ))
        }
        let titleFont = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traits)
        let subtitleFont = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        let title = item.title?.isEmpty == false ? item.title! : (item.accessibilityLabel ?? "未命名")
        let subtitle = item.isEnabled ? (item.badgeValue.map { $0.isEmpty ? "有新内容" : "\($0) 条更新" } ?? self.subtitle) : "暂不可用"
        // 固定栏高不足时收起编号和说明，优先保留标题；恢复内容策略后自动回到完整卡片。
        let fullHeight = max(76, 2 * titleFont.lineHeight + 2 * subtitleFont.lineHeight + 34)
        let insets = tabBar.layoutConfiguration.contentInsets
        // 栏高包含外围留白；内容只使用 Item 高度，留白变化时由标签栏重新获取配置。
        let availableHeight = fixedHeight.map { max(0, $0 - insets.top - insets.bottom) }
        if let availableHeight, availableHeight < fullHeight {
            let scale = min(1, max(1, availableHeight - 8) / titleFont.lineHeight)
            return SPTabBarContent(configuration: DemoCompactConfiguration(
                title: title,
                font: titleFont.withSize(titleFont.pointSize * scale),
                tintColor: tintColor,
                isCard: true
            ))
        }
        // equal 的公开分配规则可在配置阶段确定项宽，测量与实际显示使用同一布局。
        let count = CGFloat(max(1, tabBar.items.count))
        let equalWidth = max(
            tabBar.layoutConfiguration.minimumItemWidth,
            (width - max(0, count - 1) * tabBar.layoutConfiguration.itemSpacing) / count
        )
        let compact = tabBar.layoutConfiguration.itemSizing == .equal && equalWidth < max(160, titleFont.lineHeight * 6)
        let configuration = DemoCardConfiguration(
            number: "\(index + 1)",
            title: title,
            subtitle: subtitle,
            titleFont: titleFont,
            subtitleFont: subtitleFont,
            tintColor: tintColor,
            direction: direction,
            compact: compact
        )
        // 只提供内容配置；内部完整约束同时用于显示和 systemLayoutSizeFitting 测量。
        return SPTabBarContent(configuration: configuration)
    }

    /// 使用同一内容配置计算可见区域，支持屏幕外端点，不依赖当前 Cell。
    func indicatorContentFrame(on bar: SPTabBar, context: SPTabBarIndicatorLayoutContext) -> CGRect {
        let insets = bar.layoutConfiguration.contentInsets
        let content = makeContent(
            on: bar,
            item: context.item,
            index: context.index,
            traits: context.traitCollection,
            tintColor: bar.tintColor,
            direction: context.layoutDirection,
            width: max(0, context.viewportFrame.width - insets.leading - insets.trailing)
        )
        if content.configuration is DemoCardConfiguration {
            return context.itemFrame.insetBy(
                dx: DemoCardConfiguration.horizontalInset,
                dy: DemoCardConfiguration.verticalInset
            )
        }
        guard let compact = content.configuration as? DemoCompactConfiguration, !compact.isCard else {
            return context.itemFrame
        }
        let text = (compact.title as NSString).size(withAttributes: [.font: compact.font])
        let width = min(
            ceil(text.width),
            max(0, context.itemFrame.width - 2 * DemoCompactConfiguration.horizontalInset)
        )
        let height = min(
            ceil(text.height),
            max(0, context.itemFrame.height - 2 * DemoCompactConfiguration.verticalInset)
        )
        return CGRect(
            x: context.itemFrame.midX - width / 2,
            y: context.itemFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private struct DemoCardConfiguration: UIContentConfiguration {
    static let horizontalInset: CGFloat = 4
    static let verticalInset: CGFloat = 5
    let number: String
    let title: String
    let subtitle: String
    let titleFont: UIFont
    let subtitleFont: UIFont
    let tintColor: UIColor
    let direction: UIUserInterfaceLayoutDirection
    let compact: Bool
    var selected = false
    var highlighted = false
    var disabled = false

    func makeContentView() -> UIView & UIContentView {
        DemoCardContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else {
            return self
        }
        var result = self
        result.selected = state.isSelected
        result.highlighted = state.isHighlighted
        result.disabled = state.isDisabled
        return result
    }
}

@MainActor
private final class DemoCardContentView: UIView, UIContentView {
    private var value: DemoCardConfiguration
    private let card = UIView()
    private let number = UILabel()
    private let title = UILabel()
    private let subtitle = UILabel()
    private let badge = UIView()
    private let row = UIStackView()
    private var rowInsets: [NSLayoutConstraint] = []

    var configuration: any UIContentConfiguration {
        get { value }
        set {
            guard let configuration = newValue as? DemoCardConfiguration else {
                return
            }
            value = configuration
            apply()
        }
    }

    init(configuration: DemoCardConfiguration) {
        value = configuration
        super.init(frame: .zero)
        addSubview(card)
        badge.addSubview(number)
        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 4
        row.addArrangedSubview(badge)
        row.addArrangedSubview(text)
        row.alignment = .center
        row.spacing = 10
        card.addSubview(row)
        for view in [card, row, number] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        title.numberOfLines = 2
        subtitle.numberOfLines = 2
        // 初次布局或栏高受限时优先保留标题，避免两段文字以相同优先级争用高度。
        subtitle.setContentCompressionResistancePriority(UILayoutPriority(749), for: .vertical)
        number.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let preferredWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        preferredWidth.priority = .defaultHigh
        rowInsets = [
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            card.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: 10)
        ]
        // 配置可能先于新 Cell frame 生效；内部留白允许暂时压缩，避免宽内容与旧窄 frame 冲突。
        // 正常分配宽度下仍恢复理想留白，内容测量与最终布局使用同一组约束。
        rowInsets.forEach { $0.priority = UILayoutPriority(999) }
        NSLayoutConstraint.activate(rowInsets)
        NSLayoutConstraint.activate([
            preferredWidth,
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DemoCardConfiguration.horizontalInset),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DemoCardConfiguration.horizontalInset),
            card.topAnchor.constraint(equalTo: topAnchor, constant: DemoCardConfiguration.verticalInset),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DemoCardConfiguration.verticalInset),
            row.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 10),
            row.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            number.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 10),
            number.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -10),
            number.topAnchor.constraint(equalTo: badge.topAnchor, constant: 8),
            number.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -8)
        ])
        card.layer.cornerRadius = 12
        number.textAlignment = .center
        number.layer.cornerRadius = 10
        number.clipsToBounds = true
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(configuration:)")
    }

    private func apply() {
        // 从 arrangedSubviews 移除编号，避免 UIStackView 的隐藏零宽约束与编号约束冲突。
        if value.compact {
            row.removeArrangedSubview(badge)
            badge.removeFromSuperview()
        } else if badge.superview == nil {
            row.insertArrangedSubview(badge, at: 0)
        }
        rowInsets.forEach { $0.constant = value.compact ? 4 : 10 }
        number.text = value.number
        title.text = value.title
        subtitle.text = value.subtitle
        number.font = value.titleFont
        title.font = value.titleFont
        subtitle.font = value.subtitleFont
        number.backgroundColor = value.tintColor.withAlphaComponent(value.selected ? 0.2 : 0.08)
        number.textColor = value.tintColor
        title.textColor = value.selected ? value.tintColor : .label
        subtitle.textColor = .secondaryLabel
        card.backgroundColor = value.highlighted ? value.tintColor.withAlphaComponent(0.2) : .secondarySystemBackground
        card.layer.borderWidth = value.selected ? 1.5 : 0
        card.layer.borderColor = value.tintColor.cgColor
        card.alpha = value.disabled ? 0.4 : 1
        semanticContentAttribute = value.direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        let alignment: NSTextAlignment = value.compact ? .center : (value.direction == .rightToLeft ? .right : .left)
        title.textAlignment = alignment
        subtitle.textAlignment = alignment
        setNeedsLayout()
    }
}

/// 紧凑样式不声明固定高度；容器可把测量结果提升到业务配置的最小栏高。
private struct DemoCompactConfiguration: UIContentConfiguration {
    static let horizontalInset: CGFloat = 12
    static let verticalInset: CGFloat = 2
    let title: String
    let font: UIFont
    let tintColor: UIColor
    var minimumWidth: CGFloat = 0
    var isCard = false
    var selected = false
    var highlighted = false
    var disabled = false

    func makeContentView() -> UIView & UIContentView {
        DemoCompactContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else {
            return self
        }
        var result = self
        result.selected = state.isSelected
        result.highlighted = state.isHighlighted
        result.disabled = state.isDisabled
        return result
    }
}

@MainActor
private final class DemoCompactContentView: UIView, UIContentView {
    private var value: DemoCompactConfiguration
    private let label = UILabel()
    private lazy var minimumWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
    var configuration: any UIContentConfiguration {
        get { value }
        set {
            guard let value = newValue as? DemoCompactConfiguration else {
                return
            }
            self.value = value
            apply()
        }
    }

    init(configuration: DemoCompactConfiguration) {
        value = configuration
        super.init(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.accessibilityIdentifier = "demo.compactTabTitle"
        addSubview(label)
        NSLayoutConstraint.activate([
            minimumWidth,
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DemoCompactConfiguration.horizontalInset),
            label.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -DemoCompactConfiguration.horizontalInset
            ),
            label.topAnchor.constraint(equalTo: topAnchor, constant: DemoCompactConfiguration.verticalInset),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DemoCompactConfiguration.verticalInset)
        ])
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(configuration:)")
    }

    private func apply() {
        minimumWidth.constant = value.minimumWidth
        label.text = value.title
        label.font = value.font
        label.adjustsFontSizeToFitWidth = value.isCard
        label.minimumScaleFactor = value.isCard ? 0.5 : 1
        label.textColor = value.disabled ? .tertiaryLabel : (value.selected ? value.tintColor : .label)
        backgroundColor = value.highlighted ? value.tintColor.withAlphaComponent(0.12) :
            (value.isCard ? .secondarySystemBackground : .clear)
        layer.cornerRadius = value.isCard ? 8 : 0
        layer.borderWidth = value.isCard && value.selected ? 1.5 : 0
        layer.borderColor = value.tintColor.cgColor
    }
}
