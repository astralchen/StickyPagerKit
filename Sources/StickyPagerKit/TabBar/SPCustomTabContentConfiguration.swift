import UIKit

/// 统一自定义内容的点击、无障碍与状态分发，业务内容不参与命中测试。
internal struct SPCustomTabContentConfiguration {
    let content: any UIContentConfiguration
    let measuredSize: CGSize
    let state: UICellConfigurationState
    let itemIdentifier: ObjectIdentifier
    let accessibilityIdentifier: String
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityValue: String?
    let onTap: @MainActor () -> Void
}
