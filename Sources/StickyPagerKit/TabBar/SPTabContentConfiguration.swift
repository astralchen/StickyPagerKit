import UIKit

/// 测量与显示共用角标尺寸，包含中文回退字体的实际行高和胶囊内边距。
@MainActor
internal enum SPTabBadgeMetrics {
    static func size(for value: String?, font: UIFont) -> CGSize {
        guard let value else {
            return .zero
        }
        guard !value.isEmpty else {
            return CGSize(width: 8, height: 8)
        }
        let label = UILabel()
        label.font = font
        label.text = value
        let text = label.intrinsicContentSize
        let height = max(18, ceil(text.height) + 4)
        return CGSize(width: max(height, ceil(text.width) + 10), height: height)
    }

    /// 角标向内容内重叠 4 pt，其余向尾端延伸；两侧对称留白保持图文居中。
    static func additionalWidth(for size: CGSize) -> CGFloat {
        2 * max(0, size.width - 4 - 16)
    }
}

/// 已按标签栏选中项、外观和 traits 解析的内容快照，不持有可变的 Item 或 Appearance。
internal struct SPTabContentConfiguration: UIContentConfiguration {
    let buttonConfiguration: UIButton.Configuration
    let layoutDirection: UIUserInterfaceLayoutDirection
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
internal protocol SPTabIndicatorContentGeometry: AnyObject {
    var indicatorContentRect: CGRect { get }
}

@MainActor
private final class SPTabContentView: UIView, UIContentView, SPTabIndicatorContentGeometry {
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
        // 配置可能用于新建、复用或脱离 Collection View 的测量视图，不依赖 UIKit 的内部继承链。
        semanticContentAttribute = value.layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        button.semanticContentAttribute = semanticContentAttribute
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

    var indicatorContentRect: CGRect {
        layoutIfNeeded()
        button.layoutIfNeeded()
        let frames = [button.titleLabel, button.imageView].compactMap { view -> CGRect? in
            guard let view, !view.isHidden, !view.bounds.isEmpty else {
                return nil
            }
            return view.convert(view.bounds, to: self)
        }
        return frames.reduce(CGRect.null) { $0.union($1) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = bounds
        button.layoutIfNeeded()
        let size = SPTabBadgeMetrics.size(for: storedConfiguration.badgeValue, font: storedConfiguration.badgeFont)
        guard size != .zero else {
            badge.frame = .zero
            return
        }
        // 上下图文跟随图标；纯文字与横向图文跟随整体内容。尾端角标在 RTL 下镜像到左上角。
        var anchor = CGRect.null
        if let title = button.titleLabel, !(button.configuration?.title ?? "").isEmpty {
            anchor = title.convert(title.bounds, to: self)
        }
        if let icon = button.imageView, button.configuration?.image != nil {
            let imageFrame = icon.convert(icon.bounds, to: self)
            anchor = button.configuration?.imagePlacement == .top ? imageFrame : anchor.union(imageFrame)
        }
        if anchor.isNull || anchor.isEmpty {
            anchor = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        }
        let x = storedConfiguration.layoutDirection == .rightToLeft ? anchor.minX + 4 - size.width : anchor.maxX - 4
        badge.frame = CGRect(
            x: max(0, min(x, bounds.width - size.width)),
            y: max(0, min(anchor.minY - size.height / 2, bounds.height - size.height)),
            width: size.width,
            height: size.height
        )
        badge.layer.cornerRadius = size.height / 2
    }
}
