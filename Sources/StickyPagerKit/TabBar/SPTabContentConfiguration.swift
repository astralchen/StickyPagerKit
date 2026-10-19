import UIKit

/// 已按标签栏选中项、外观和 traits 解析的内容快照，不持有可变的 Item 或 Appearance。
internal struct SPTabContentConfiguration: UIContentConfiguration {
    let buttonConfiguration: UIButton.Configuration
    let iconColor: UIColor
    let isEnabled: Bool
    let accessibilityIdentifier: String
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityTraits: UIAccessibilityTraits
    let largeContentImage: UIImage?
    let largeContentImageInsets: UIEdgeInsets
    let badgeValue: String?
    let badgeFont: UIFont
    let badgeTextColor: UIColor
    let badgeBackgroundColor: UIColor
    let onTap: @MainActor () -> Void

    func makeContentView() -> UIView & UIContentView {
        SPTabContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        // 选中与禁用由 SPTabBar 解析，高亮由 UIButton 管理；Cell 状态不覆盖这两者。
        self
    }
}

@MainActor
private final class SPTabContentView: UIView, UIContentView {
    private var storedConfiguration: SPTabContentConfiguration
    var configuration: UIContentConfiguration {
        get { storedConfiguration }
        set {
            guard let value = newValue as? SPTabContentConfiguration else {
                return
            }
            storedConfiguration = value
            applyConfiguration()
        }
    }

    private let button = UIButton(type: .system)
    private let badge = UILabel()

    init(configuration: SPTabContentConfiguration) {
        storedConfiguration = configuration
        super.init(frame: .zero)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        // 只安装一次 action，执行时读取最新配置，避免复用时累积回调或引用旧 Item。
        button.addAction(UIAction { [weak self] _ in self?.storedConfiguration.onTap() }, for: .touchUpInside)
        addSubview(button)
        badge.textAlignment = .center
        badge.clipsToBounds = true
        badge.isUserInteractionEnabled = false
        badge.isAccessibilityElement = false
        addSubview(badge)
        applyConfiguration()
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(configuration:)")
    }

    private func applyConfiguration() {
        let value = storedConfiguration
        button.tintColor = value.iconColor
        button.configuration = value.buttonConfiguration
        button.isEnabled = value.isEnabled
        button.accessibilityIdentifier = value.accessibilityIdentifier
        button.accessibilityLabel = value.accessibilityLabel
        button.accessibilityHint = value.accessibilityHint
        button.accessibilityTraits = value.accessibilityTraits
        button.accessibilityValue = value.badgeValue.map { $0.isEmpty ? "有新内容" : $0 }
        button.largeContentTitle = value.accessibilityLabel
        button.largeContentImage = value.largeContentImage
        button.largeContentImageInsets = value.largeContentImageInsets
        badge.text = value.badgeValue
        badge.isHidden = value.badgeValue == nil
        badge.font = value.badgeFont
        badge.textColor = value.badgeTextColor
        badge.backgroundColor = value.badgeBackgroundColor
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let badgeWidth: CGFloat = badge.isHidden ? 0 : (badge.text?.isEmpty == true ? 8 : max(
            18,
            ceil(badge.intrinsicContentSize.width) + 10
        ))
        let badgeHeight: CGFloat = badge.text?.isEmpty == true ? 8 : max(18, ceil(badge.font.lineHeight) + 2)
        let reserve = badgeWidth > 0 ? badgeWidth + 4 : 0
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        button.frame = bounds
        // 为角标预留内容空间，同时让按钮覆盖整个点击区域；不修改存储的配置快照。
        if var config = button.configuration, config.contentInsets.trailing != 16 + reserve {
            config.contentInsets.trailing = 16 + reserve
            button.configuration = config
        }
        badge.frame = CGRect(
            x: rtl ? 12 : max(12, bounds.width - 12 - badgeWidth),
            y: max(4, (bounds.height - badgeHeight) / 2),
            width: badgeWidth,
            height: badgeHeight
        )
        badge.layer.cornerRadius = badgeHeight / 2
    }
}
