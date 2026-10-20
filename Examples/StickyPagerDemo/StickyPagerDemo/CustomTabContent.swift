import UIKit
import StickyPagerKit

/// 业务方持有内容代理；同一份卡片配置可用于独立标签栏和分页容器。
@MainActor
final class DemoTabContentProvider: SPTabBarContentDelegate {
    var subtitle = "浏览专题"
    var usesCompactContent = false
    var usesNumberContent = false
    var usesWideContent = false

    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        if usesCompactContent {
            // 内容只有文字与内边距；UILabel 固有尺寸和完整约束负责测高。
            return SPTabBarContent(configuration: DemoCompactConfiguration(
                title: usesNumberContent ? "\(index + 1)" : (item.title ?? "未命名"),
                font: UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: context.state.traitCollection),
                tintColor: context.tintColor,
                minimumWidth: usesWideContent && index == 0 ? 480 : 0
            ))
        }
        let traits = context.state.traitCollection
        let titleFont = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traits)
        let subtitleFont = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        let title = item.title?.isEmpty == false ? item.title! : (item.accessibilityLabel ?? "未命名")
        let subtitle = item.isEnabled ? (item.badgeValue.map { $0.isEmpty ? "有新内容" : "\($0) 条更新" } ?? self.subtitle) : "暂不可用"
        let configuration = DemoCardConfiguration(
            number: "\(index + 1)",
            title: title,
            subtitle: subtitle,
            titleFont: titleFont,
            subtitleFont: subtitleFont,
            tintColor: context.tintColor,
            direction: context.layoutDirection
        )
        // 只提供内容配置；内部完整约束同时用于显示和 systemLayoutSizeFitting 测量。
        return SPTabBarContent(configuration: configuration)
    }
}

private struct DemoCardConfiguration: UIContentConfiguration {
    let number: String
    let title: String
    let subtitle: String
    let titleFont: UIFont
    let subtitleFont: UIFont
    let tintColor: UIColor
    let direction: UIUserInterfaceLayoutDirection
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
        let badge = UIView()
        badge.addSubview(number)
        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 4
        let row = UIStackView(arrangedSubviews: [badge, text])
        row.alignment = .center
        row.spacing = 10
        card.addSubview(row)
        for view in [card, row, number] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        title.numberOfLines = 2
        subtitle.numberOfLines = 2
        number.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let preferredWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
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
        let alignment: NSTextAlignment = value.direction == .rightToLeft ? .right : .left
        title.textAlignment = alignment
        subtitle.textAlignment = alignment
        setNeedsLayout()
    }
}

/// 紧凑样式不声明固定高度；容器可把测量结果提升到业务配置的最小栏高。
private struct DemoCompactConfiguration: UIContentConfiguration {
    let title: String
    let font: UIFont
    let tintColor: UIColor
    var minimumWidth: CGFloat = 0
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
        addSubview(label)
        NSLayoutConstraint.activate([
            minimumWidth,
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
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
        label.textColor = value.disabled ? .tertiaryLabel : (value.selected ? value.tintColor : .label)
        backgroundColor = value.highlighted ? value.tintColor.withAlphaComponent(0.12) : .clear
    }
}
