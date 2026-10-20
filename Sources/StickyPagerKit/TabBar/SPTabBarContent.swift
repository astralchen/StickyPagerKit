import UIKit

/// 自定义标签的配置与测量上下文；由标签栏创建，是本次回调的环境快照。
/// 测量可能使用尚未应用到标签栏的建议宽度，不表示当前显示尺寸已发生变化。
@MainActor
public struct SPTabBarContentContext {
    /// 保证包含当前 traits、选中和禁用状态；回调测量时高亮为 false。
    /// 真实按压高亮由配置的 `updated(for:)` 接收，不重新测量尺寸。
    /// 不保证传递 Cell 的其他状态；业务不应依赖焦点、编辑或多选状态。
    public let state: UICellConfigurationState
    /// 标签栏当前生效的 tintColor，包含从父视图继承的颜色。
    public let tintColor: UIColor
    /// 本次布局的视觉方向；RTL 不改变 Item 的逻辑索引。
    public let layoutDirection: UIUserInterfaceLayoutDirection
    /// 扣除左右安全区域后的视口宽度；尚未布局时可能为 0，不代表每项必须填满视口。
    public let availableWidth: CGFloat
    /// 当前生效外观的独立副本，修改它不会改变标签栏外观。
    public let appearance: SPTabBarAppearance
}

/// 一项自定义内容。尺寸包含业务内边距，框架不再添加默认图文样式的留白。
@MainActor
public struct SPTabBarContent {
    /// 负责显示的内容配置；框架通过 `makeContentView()` 创建视图并通过 configuration 更新。
    /// 内容视图须适应实际 bounds，不应保存旧状态或在更新时重复添加子视图。
    /// 内部控件不接受触摸，也不单独暴露无障碍入口；整项交互由框架维护。
    public var configuration: any UIContentConfiguration
    /// 可选的理想尺寸覆盖；nil（默认）由 UIContentView 的 Auto Layout 自动测量。
    /// 自动测量先求首选宽度，再按实际分配宽度定宽测高。
    /// 测量宿主以优先级 999 尝试视口内的首选宽度；业务 required 最小宽度可超出视口并横向滚动。
    /// 内容须允许根视图随分配宽度扩展；固定根宽度或自身矛盾的 required 约束不受支持。
    /// 内容须具备完整内部约束或固有尺寸；不会假定普通 UIView 自动转调 sizeThatFits(_:)。
    /// 显式尺寸包含业务内边距，并非最终 Cell 尺寸。
    /// 每个分量必须为有限正数且不超过 1,000,000 pt，否则整项回退到默认内容。
    /// 理想尺寸不包含框架的宽度下限；最终 Cell 宽度受 SPTabBar.minimumItemWidth 和空间分配规则影响。
    /// 显式尺寸不限制到视口；自动测量可能压缩可换行内容。内容高度不额外设下限。
    /// 容器中的实际栏高取内容需求与 SPPageLayout.tabBarHeight 的较大值；配置为 0 时隐藏。
    /// 独立使用标签栏时，由宿主根据 sizeThatFits(_:) 的测量结果设置最终高度。
    /// 所有 Cell 高度等于栏的实际高度；状态相关内容宜返回各状态所需尺寸的最大值。
    public var size: CGSize?
    /// nil 使用 Item 的无障碍描述；选中、禁用和按钮 traits 由框架维护。
    public var accessibilityLabel: String?
    /// 整项无障碍提示；nil 使用 Item.accessibilityHint。
    public var accessibilityHint: String?
    /// 整项无障碍值；nil 使用 Item.badgeValue，空角标表示“有新内容”。
    public var accessibilityValue: String?

    /// 创建自动测量的内容；无障碍覆盖值初始均为 nil。
    public init(configuration: any UIContentConfiguration) {
        self.configuration = configuration
        size = nil
    }

    /// 使用显示配置和显式理想尺寸创建内容，跳过自动测量。
    public init(configuration: any UIContentConfiguration, size: CGSize) {
        self.configuration = configuration
        self.size = size
    }
}

/// 提供自定义标签内容，业务方需自行持有代理。回调应为同步、无副作用的配置与测量过程。
/// 仅在 `.custom` 模式下调用；配置和尺寸按内容版本及环境缓存，不保证每次布局都回调。
/// Item 和环境变化由框架刷新；业务自有数据变化后调用 `reloadContent()`。
@MainActor
public protocol SPTabBarContentDelegate: AnyObject {
    /// 返回 nil 时该项使用默认内容。不得在回调内修改标签栏或 Item、触发布局或重新加载。
    /// 配置的 updated(for:) 接收 UICellConfigurationState；高亮变化不会重新测量尺寸。
    /// sizeThatFits(_:) 也会以候选宽度调用此方法；只需返回配置，框架负责创建独立测量视图。
    /// 自动测量会调用 updated(for:) 和 makeContentView()，结果按版本与环境缓存。
    /// 异步内容、约束或固有尺寸变化后，业务应调用 reloadContent() 使框架测量缓存失效。
    /// - Parameters:
    ///   - tabBar: 请求内容的标签栏。
    ///   - item: 当前 Item，按对象身份区分。
    ///   - index: Item 的逻辑索引，RTL 下保持不变。
    ///   - context: 本次配置与测量的状态、外观及可用空间。
    /// - Returns: 显示配置和理想尺寸；nil 或无效尺寸使该项回退到默认图文。
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent?
}
