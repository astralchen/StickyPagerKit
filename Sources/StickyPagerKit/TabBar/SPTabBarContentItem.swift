import UIKit

/// 一次内容请求中的单项快照；不持有原 Item，也不提供修改标签栏的入口。
/// 身份仅在原 Item 生命周期内稳定；外部数据变化后仍需调用 reloadContent()。
@MainActor
public struct SPTabBarContentItem {
    /// 原 Item 的对象身份；不能作为跨生命周期或持久化标识。
    public let identifier: ObjectIdentifier
    /// 本次请求时的标题、图像与选中图像。
    public let title: String?
    public let image: UIImage?
    public let selectedImage: UIImage?
    /// 原 Item 是否允许激活；视觉预览状态由内容配置的 updated(for:) 接收。
    public let isEnabled: Bool
    /// 原 Item 的通用标记；修改原 Item.tag 会使本项内容失效。
    public let tag: Int
    /// 角标文本与显式颜色；nil／空字符串保持 SPTabBarItem 的角标语义。
    public let badgeValue: String?
    public let badgeColor: UIColor?
    /// 原 Item 的无障碍描述；内容返回值可以覆盖这些描述。
    public let accessibilityLabel: String?
    public let accessibilityHint: String?
    /// 原 Item 的横屏及大内容查看器图像设置，不包含实时视图状态。
    public let landscapeImagePhone: UIImage?
    public let imageInsets: UIEdgeInsets
    public let landscapeImagePhoneInsets: UIEdgeInsets
    public let largeContentSizeImage: UIImage?
    public let largeContentSizeImageInsets: UIEdgeInsets

    private let storedAppearance: SPTabBarAppearance?
    /// 每次读取返回独立副本；修改副本不会改变快照或原 Item。
    public var standardAppearance: SPTabBarAppearance? {
        storedAppearance.map { SPTabBarAppearance(barAppearance: $0) }
    }

    private let attributes: [UInt: [NSAttributedString.Key: Any]]
    /// 返回单项支持的文字属性；可变阴影使用独立副本。
    public func titleTextAttributes(for state: UIControl.State) -> [NSAttributedString.Key: Any]? {
        attributes[state.rawValue].map(Self.copyAttributes)
    }

    internal init(_ item: SPTabBarItem) {
        identifier = ObjectIdentifier(item)
        title = item.title
        image = item.image
        selectedImage = item.selectedImage
        isEnabled = item.isEnabled
        tag = item.tag
        badgeValue = item.badgeValue
        badgeColor = item.badgeColor
        accessibilityLabel = item.accessibilityLabel
        accessibilityHint = item.accessibilityHint
        landscapeImagePhone = item.landscapeImagePhone
        imageInsets = item.imageInsets
        landscapeImagePhoneInsets = item.landscapeImagePhoneInsets
        largeContentSizeImage = item.largeContentSizeImage
        largeContentSizeImageInsets = item.largeContentSizeImageInsets
        storedAppearance = item.standardAppearance.map { SPTabBarAppearance(barAppearance: $0) }
        attributes = item.contentTitleAttributes.mapValues(Self.copyAttributes)
    }

    private static func copyAttributes(_ value: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        value.mapValues { ($0 as? NSCopying)?.copy(with: nil) ?? $0 }
    }
}
