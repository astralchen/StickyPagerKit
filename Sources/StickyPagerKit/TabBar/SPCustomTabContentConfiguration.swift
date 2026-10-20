import UIKit

/// 统一自定义内容的点击、无障碍与状态分发，业务内容不参与命中测试。
internal struct SPCustomTabContentConfiguration: UIContentConfiguration {
    let content: any UIContentConfiguration
    let measuredSize: CGSize
    let state: UICellConfigurationState
    let itemIdentifier: ObjectIdentifier
    let accessibilityIdentifier: String
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityValue: String?
    let onTap: @MainActor () -> Void

    func makeContentView() -> UIView & UIContentView {
        SPCustomTabContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

@MainActor
private final class SPCustomTabContentView: UIView, UIContentView {
    private var storedConfiguration: SPCustomTabContentConfiguration
    private var customView: (UIView & UIContentView)?
    private let button = ActivationButton(type: .custom)
    private var applyingConfiguration = false

    var configuration: any UIContentConfiguration {
        get { storedConfiguration }
        set {
            guard let value = newValue as? SPCustomTabContentConfiguration else {
                return
            }
            let changedItem = storedConfiguration.itemIdentifier != value.itemIdentifier
            storedConfiguration = value
            applyingConfiguration = true
            if changedItem {
                button.isHighlighted = false
            }
            applyAccessibility()
            applyingConfiguration = false
            updateContent()
        }
    }

    init(configuration: SPCustomTabContentConfiguration) {
        storedConfiguration = configuration
        super.init(frame: .zero)
        addSubview(button)
        button.addAction(UIAction { [weak self] _ in self?.storedConfiguration.onTap() }, for: .touchUpInside)
        button.highlightDidChange = { [weak self] in
            guard let self, !self.applyingConfiguration else {
                return
            }
            self.updateContent()
        }
        applyAccessibility()
        updateContent()
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(configuration:)")
    }

    private func applyAccessibility() {
        let value = storedConfiguration
        button.isEnabled = !value.state.isDisabled
        button.accessibilityIdentifier = value.accessibilityIdentifier
        button.accessibilityLabel = value.accessibilityLabel
        button.accessibilityHint = value.accessibilityHint
        button.accessibilityValue = value.accessibilityValue
        button.accessibilityTraits = value.state.isSelected ? [.button, .selected] : .button
        if value.state.isDisabled {
            button.accessibilityTraits.insert(.notEnabled)
        }
    }

    private func updateContent() {
        var state = storedConfiguration.state
        state.isHighlighted = button.isHighlighted && button.isEnabled
        let content = storedConfiguration.content.updated(for: state)
        let compatible: Bool
        if let customView {
            if #available(iOS 16, *) {
                compatible = customView.supports(content)
            } else {
                compatible = type(of: customView.configuration) == type(of: content)
            }
        } else {
            compatible = false
        }
        if compatible {
            customView?.configuration = content
        } else {
            customView?.removeFromSuperview()
            let view = content.makeContentView()
            customView = view
            insertSubview(view, belowSubview: button)
        }
        // 一个标签只有一个激活入口；业务子视图不能拦截点击或重复暴露无障碍元素。
        customView?.isUserInteractionEnabled = false
        customView?.accessibilityElementsHidden = true
        customView?.frame = bounds
        setNeedsLayout()
    }

    // 业务内容已由标签栏独立测量；Cell 的额外 fitting 查询只返回布局分配的尺寸。
    // 不让内部 Auto Layout 再从手动布局的宿主推导高度，保持整栏 Cell 等高。
    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        CGSize(
            width: bounds.width > 0 ? bounds.width : storedConfiguration.measuredSize.width,
            height: bounds.height > 0 ? bounds.height : storedConfiguration.measuredSize.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        customView?.frame = bounds
        button.frame = bounds
    }

    private final class ActivationButton: UIButton {
        var highlightDidChange: (() -> Void)?
        override var isHighlighted: Bool {
            didSet {
                if oldValue != isHighlighted {
                    highlightDidChange?()
                }
            }
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled else {
                return false
            }
            sendActions(for: .touchUpInside)
            return true
        }
    }
}
