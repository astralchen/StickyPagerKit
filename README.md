# StickyPagerKit

支持 iOS 15+ 的 UIKit 粘性 Header 与横向分页容器。以 Swift Package Manager 分发，使用 Swift tools 6.3、Swift 6 语言模式和主 actor 隔离，不依赖第三方运行时库。

## 代码格式

框架、Demo 和测试共用根目录 [`.swiftformat`](.swiftformat)，已使用 **SwiftFormat 0.64.0** 验证。配置逐项附有中文说明，按 Swift 6.3 工具链与 Swift 6 语言模式处理源码。

API 设计参考 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)；4 空格缩进、120 字符目标行宽、参数和语句体换行属于本项目排版约定，不是 Apple 发布的统一格式化配置。仅启用显式列出的排版规则，保留 API、访问控制、声明顺序、`self`、表达式、字面量、分号和注释正文；不启用 SwiftFormat 默认的语法简化规则。

`Package.swift` 已将 [SwiftFormat 官方 SwiftPM Command Plugin](https://github.com/nicklockwood/SwiftFormat/tree/0.64.0/Plugins/SwiftFormatPlugin) 精确锁定到 **0.64.0**。它是开发工具，不链接到框架或 Demo 产品。首次使用需要联网解析依赖并编译工具，无需全局安装 `swiftformat`。

Demo target 在 `Compile Sources` 之前配置了 `SwiftFormat` Build Phase，Debug / Release 构建均自动调用 [Scripts/format.sh](Scripts/format.sh)，直接修复框架、测试与 Demo 的代码格式；格式化失败会使构建失败。该阶段每次构建执行，不依赖输出文件判断是否跳过。仅 Demo target 关闭 `ENABLE_USER_SCRIPT_SANDBOXING`，以允许插件写入源码及 SwiftPM 缓存；脚本使用 macOS SDK 构建宿主工具，避免继承 iOS SDK。

该 Build Phase 属于 Demo target，不是 Swift Package 的构建插件；单独构建框架不会自动运行它。Xcode 可先编译 Package 依赖，再执行 Demo 的阶段；若需要在整个依赖图开始构建前完成格式化，先手动运行下方脚本。

在仓库根目录使用支持 Swift tools 6.3 的 Xcode 工具链执行：

```sh
# 手动格式化框架、测试、独立 Demo 和 Package 清单。
Scripts/format.sh

# 只检查，不修改源码。
Scripts/format.sh --lint
```

脚本调用 `swift package -c release plugin --allow-writing-to-package-directory swiftformat`，以 Release 配置编译格式化工具；不改变应用的构建配置。官方插件默认只遍历 Package 源码 target，因此脚本选择 `StickyPagerKit`，并显式补入 `Examples`、`Tests` 与 `Package.swift`，一次覆盖整个仓库的自有 Swift 源码。`--allow-writing-to-package-directory` 用于满足插件声明的写入权限；是否实际修改代码由 `--lint` 控制。需要指定本机工具链时，可在命令前设置 `DEVELOPER_DIR`，例如 `/Applications/Xcode-26.6.app/Contents/Developer`。

也可以使用 [SwiftFormat 官方发布的 0.64.0 命令行工具](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.64.0)：

```sh
# 确认使用已验证的工具版本。
swiftformat --version

# 格式化框架、Demo、测试和 Package 清单。
swiftformat Package.swift Sources Tests Examples --config .swiftformat --cache ignore

# 只检查，不写入源码；退出码 0 表示符合配置。
swiftformat Package.swift Sources Tests Examples --config .swiftformat --cache ignore --lint
git diff --check
```

使用独立 CLI 只修改部分文件时，将其输入路径替换为对应 Swift 文件即可。配置排除依赖、生成源码、构建缓存、验证产物和 `xcuserdata`。升级 SwiftFormat 后需同步 Package 的精确版本与 `.swiftformat` 的最低版本，并重新检查 diff 和验证构建；独立 CLI 的实际版本仍需自行确认。

## 快速开始

将当前仓库作为本地或 Git Swift Package 添加到应用，链接 `StickyPagerKit` 产品。所有容器操作都在主 actor 上进行。

```swift
import UIKit
import StickyPagerKit

@MainActor
final class PagesController: SPPageViewController, SPPageViewControllerDataSource {
    private let ids = ["posts", "favorites"]

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        let header = UILabel()
        header.text = "我的页面"
        header.textAlignment = .center
        headerView = header
        layout = SPPageLayout(headerHeight: 220)
        reloadData()
    }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int { ids.count }

    func pageViewController(_ pageViewController: SPPageViewController,
                            identifierForPageAt index: Int) -> AnyHashable { ids[index] }

    func pageViewController(_ pageViewController: SPPageViewController,
                            tabBarItemAt index: Int) -> SPTabBarItem {
        SPTabBarItem(title: index == 0 ? "作品" : "收藏")
    }

    func pageViewController(_ pageViewController: SPPageViewController,
                            viewControllerAt index: Int) -> UIViewController {
        let controller = UIViewController()
        let scrollView = UIScrollView()
        scrollView.contentSize = CGSize(width: 1, height: 1500)
        controller.view = scrollView
        return controller
    }
}
```

独立父控制器中的完整 containment 接入见 [MinimalIntegration.swift](Examples/StickyPagerDemo/StickyPagerDemo/MinimalIntegration.swift)，该文件参与 Demo 构建。数据源返回未归属于其他父控制器的页面；容器负责加载视图、添加子控制器及 appearance 转发。

## Demo

打开 [StickyPagerDemo.xcodeproj](Examples/StickyPagerDemo/StickyPagerDemo.xcodeproj)，选择共享 scheme `StickyPagerDemo`，选择 iOS 模拟器并运行。真机运行需自行在 Xcode 中配置 Team。

首页提供两个纵向排列的入口：「打开演示」继续使用原有导航栈；「系统容器演示」全屏打开 `UITabBarController → UINavigationController → DemoPager`，其中 `DemoPager` 是 `SPPageViewController` 的子类。系统标签分为「联动演示」和「布局说明」，两个标签各自持有导航控制器，均可通过「关闭」回到首页。实现见 [DemoSystemContainer.swift](Examples/StickyPagerDemo/StickyPagerDemo/DemoSystemContainer.swift)。

系统容器场景把状态移到导航栏并隐藏原有底部工具栏，便于观察系统 Tab Bar 的安全区域贡献。Header 背景及子页面根视图仍延伸到容器边界，组件标签栏在顶部安全区域下缘吸顶；列表保留 UIKit 自动 `adjustedContentInset` 和滚动指示器安全区域处理，不手动叠加系统栏高度。系统标签控件可位于底部、iPad 顶部或 Duo 侧边，布局与验证以实际安全区域和控件 frame 为准，不仅凭设备方向推断其位置。「页面」菜单仍可切换 Header 类型、高度和页面配置。

- 网格、长列表、短列表、空列表、普通页面和可动态创建滚动视图的异步页面。
- “收藏”与“更多专题与活动”之间的“组合布局”标签使用 `UICollectionViewCompositionalLayout`：包含 `.continuous`、`.groupPaging` 横向 Section 和 30 项纵向内容；也可从“页面 → 组合布局 · 嵌套滚动”直接进入。
- 导航栏 `Header` 切换 UIView / UIViewController，`高度` 切换 220 / 300。
- `页面` 菜单可重排、删除、添加或清空页面。
- 列表原生下拉刷新，底部状态显示当前页、Header 类型和高度。
- 返回上一级可检查系统交互式返回；启动参数 `--rtl` 可切换 Demo 到 RTL。
- 嵌套横向 Section 尚有可滚动空间时优先处理内部滚动；到达起点／终点后，下一次向外横滑切换相邻标签。手势归属在开始时判定，一次从内部开始的拖动不会在中途突然转为分页；容器也已到首尾时保留内部弹性滚动。
- 启动参数 `--open-demo --compositional` 可直接打开组合布局页。横向卡片用于检查 Section 内部滚动及两端边界，纵向内容区域用于检查 Header 联动和容器横向分页。`CompositionalGestureTests` 通过真实触摸、内部布局偏移及分页轨迹验证这些行为。

工程由 XcodeBuildMCP 创建，使用 `PBXFileSystemSynchronizedRootGroup` 文件系统同步分组。Demo 工程包含 `StickyPagerDemo`（应用）、`StickyPagerDemoTests`（Demo 单元测试）和 `StickyPagerDemoUITests`（UI 测试）三个 target，分别对应同名文件夹；已关联目录中的新文件通常自动参与所属 target，具体以目录关联和成员排除配置为准，无需逐文件添加引用。新增 target 或调整目录与 target 的关联时仍需更新工程配置。应用通过本地 Package 依赖链接 `StickyPagerKit`，共享 scheme `StickyPagerDemo` 使用应用 target 进行构建和运行，其 Test Action 配置了两个测试 target：`StickyPagerDemoTests` 和 `StickyPagerDemoUITests`。库测试位于根目录 `Tests/StickyPagerKitTests`，由根目录 `Package.swift` 独立管理；不要将库测试源码加入 Demo 的任何 target，也不要将 `StickyPagerKitTests` 加入 Demo scheme。应用、Demo 单元测试和 UI 测试使用的 `.xcconfig` 位于 Demo 的 `Config` 目录。

## 公开接口

| 接口 | 用途 |
| --- | --- |
| `SPPageViewController` | 容器入口，可直接使用或继承 |
| `SPPageViewControllerDataSource` | 页面数量、唯一稳定标识、控制器和标签数据 |
| `SPPageViewControllerDelegate` | 完成选中、连续分页进度、Header 状态与进度 |
| `SPPageLayout` | Header 总高度、保留高度、标签栏高度 |
| `SPHeaderState` | `expanded`、`collapsing`、`collapsed` |
| `SPTabBar` / `SPTabBarItem` | 可滚动标签栏与继承 UIBarItem 的动态标签对象 |
| `SPTabBarContentDelegate` / `SPTabBarContent` / `SPTabBarContentContext` | 自定义标签 UI 的配置、尺寸及当前环境 |

数据源和代理均为弱引用；需要由业务方持有。选择与分页事件代理提供默认实现；自定义内容代理需要实现内容提供方法。

- `headerView` / `headerViewController`：互斥，设置新内容替换旧内容。设置当前入口为 nil 清空 Header；无 Header 时不保留可折叠区域，标签栏直接停在顶部安全区域边缘。
- `layout`：默认高度为 0、0、44；负数和非有限数归一化，保留高度不超过总高度。
- `headerHeight`：从容器顶部算起的 Header 总高度，包含顶部安全区域。Header 背景铺到容器顶边及左右边界；内部文字和按钮可使用 Header 自身的 `safeAreaLayoutGuide` 避让系统栏。容器全屏延伸时，初始化 Header 即从屏幕顶部开始。
- `minimumHeaderHeight`：Header 完全折叠后仍显示的高度。默认 `0`，标签栏停在容器顶部安全区域边缘（导航容器内即导航栏下方）；只有需要保留部分 Header 时才设置非零值。Demo 和快速接入示例使用 `0`。
- `selectedIndex`：只读；无页面时为 nil。
- `setSelectedIndex(_:animated:)`：越界请求忽略。相邻选择在 `animated: true` 时滚动切页；非相邻选择直接显示目标页，不加载或滚过中间页，仅标签栏执行同步动画。新请求取消未完成的旧转场；已经直达并提交的页面会正常发送一次选中回调。`animated: false` 同时关闭内容页和标签栏动画。
- `isPagingEnabled`：控制横向滑动，标签点击和程序化切页仍然可用。
- `maximumCachedPageCount`：默认 3，最小有效值为 1；转场期间保护当前页、目标页及最多两个可见中间页，允许暂时超过限制。
- `reloadData()`：同步读取完整快照，稳定标识相同则复用已有控制器。
- `setScrollView(_:forPageAt:)`：指定页面视图树内的滚动视图；nil 恢复自动发现。
- `rediscoverScrollView(forPageAt:)`：内容页异步创建或替换滚动视图后调用。

### 标签内容、选择与外观

| 类型 | 基类／形态 | 职责 |
| --- | --- | --- |
| `SPTabBar` | `UIView` | 自绘、可滚动、分页进度联动 |
| `SPTabBarItem` | `UIBarItem` | 标签内容、对象身份、动态更新 |
| `SPTabBarAppearance` | `UIBarAppearance` | 栏背景、阴影、选中标识、复制与安全归档 |
| `SPTabBarItemAppearance` | `struct` | 图文排列和状态集合 |
| `SPTabBarItemStateAppearance` | `struct` | 单个状态的文字、图标和角标样式 |

`UIBarItem` 是抽象基类，本库显式实现其属性存储、变更通知和归档；Item／State 外观不负责栏背景，因此不继承 `UIBarAppearance`。

`SPTabBarItem` 是 `@MainActor final class`，继承 `UIBarItem`，按对象身份区分标签。沿用基类的可选 `title`、`image`、`tag`、`isEnabled`、状态文字属性及无障碍属性，增加 `selectedImage`、`badgeValue`、`badgeColor`、`standardAppearance`。修改属性后自动刷新所有宿主，无需重载页面。宿主采用弱引用；同一对象可用于多个标签栏，同一个栏内不允许重复对象。它不再具有值语义，属性读写均受 `MainActor` 隔离。

```swift
let favorites = SPTabBarItem(
    title: "收藏",
    image: UIImage(systemName: "star"),
    selectedImage: UIImage(systemName: "star.fill")
)
favorites.badgeValue = "12" // nil 隐藏，空字符串显示圆点
let tabs = SPTabBar()
tabs.items = [SPTabBarItem(title: "推荐"), favorites]
tabs.selectedItem = favorites
favorites.title = "我的收藏" // 自动更新标题和布局
```

默认角标采用顶部尾端悬浮布局：上下图文以图标为定位基准，纯文字与横向图文以整体内容为基准；LTR 显示在右上角，阿拉伯文等 RTL 界面镜像到左上角，方向由布局环境决定，与角标字符串的语言无关。数字、`99+` 和“上新”等中文短文本按实际字体测量并居中显示，宽度至少等于高度，多字符自然扩展为胶囊。框架优先使用标签原有留白，空间不足时对称扩展理想宽度，保持图文居中；角标不计入指示器的内容区域。`nil` 隐藏、空字符串显示圆点的语义不变。自定义 `UIContentConfiguration` 仍自行绘制角标，框架仅提供 Item 的无障碍值回退，不额外叠加默认角标。

`items` 可以直接设置，也可调用 `setItems(_:)`；重复对象导致整次更新被拒绝。重排按对象身份保留选择，选中对象被移除则清空。`selectedItem` 可以设为 nil；不属于 items 的对象会被拒绝并保留原选择。`selectedIndex` 是只读索引映射；索引选择方法仍作为便利入口保留。分页容器的 `setSelectedIndex(_:animated:)` 和稳定页面 ID 规则不变。

`delegate` 是弱引用，必须由业务方持有。`tabBar(_:shouldSelect:)` 可以否决标签点击；`tabBar(_:didSelect:)` 只在标签点击成功提交后调用，重复点击当前项也通知一次。程序化选择不会发送标签栏代理事件。独立标签栏自行提交选择；嵌入 `SPPageViewController` 后由容器在切页完成时提交，取消、中断、重载或替换栏会废弃旧点击请求。页面手势和程序化切页由 `SPPageViewControllerDelegate` 报告。`isEnabled = false` 仅禁止点击和无障碍激活，不阻止滑动或程序化进入对应页面。

`SPTabBarAppearance` 继承 `UIBarAppearance`，复用背景材质、颜色、图片、阴影和三种 configureWith…Background 方法，支持 NSCopying 与 NSSecureCoding；`SPTabBarItemAppearance`、`SPTabBarItemStateAppearance` 保持主线程值类型。赋值给栏或 Item 时复制 Appearance，后续修改原对象不会影响宿主；通过宿主的 `standardAppearance` getter 修改当前实例或嵌套状态会立即刷新。选中 Item 的 `standardAppearance` 非 nil 时覆盖栏级外观，取消覆盖后回退到栏级设置。Item 的 `setTitleTextAttributes(_:for:)` 支持 font、foregroundColor、shadow，并优先于相应外观状态；未配置的状态使用 normal 属性。

```swift
let appearance = SPTabBarAppearance()
appearance.configureWithOpaqueBackground() // 也可使用默认材质或透明背景配置
appearance.backgroundColor = .secondarySystemBackground
tabs.standardAppearance = appearance // 复制配置，不共享可变外观

tabs.standardAppearance.itemAppearance.layout = .automatic
tabs.tintColor = .systemBlue // 默认选中文字和模板图标跟随 tintColor
// 显式外观可覆盖默认颜色：
tabs.standardAppearance.itemAppearance.selected.titleColor = .systemPurple
tabs.indicatorStyle = .capsule
```

### 标签宽度分配

`SPTabBar.itemPositioning` 使用框架自己的 `SPTabBar.ItemPositioning`，属性及已有枚举值命名参考 UIKit，并扩展 `.leading`：

| 模式 | 宽度与排列 |
| --- | --- |
| `.automatic`（默认） | 保留原策略：优先满足各项内容宽度，其余项尽量等宽，铺满可用区域；总需求超宽时横向滚动。 |
| `.fill` | 扣除间距后均分可用宽度，每项不小于 `minimumItemWidth`；最小宽度与间距之和超宽时横向滚动。长内容不撑开单项。 |
| `.centered` | 每项使用内容测量宽度与 `minimumItemWidth` 的较大值，不拉伸；放得下时整组居中，超宽时横向滚动。 |
| `.leading` | 与 `.centered` 使用相同项宽和固定间距，整组靠逻辑起始端排列，余量全部留在 trailing；超宽时横向滚动。 |

```swift
tabs.itemPositioning = .automatic // 默认，兼容原有布局
tabs.itemPositioning = .fill      // 强制等宽
tabs.itemPositioning = .centered  // 按内容宽度，整组居中
tabs.itemPositioning = .leading   // 按内容宽度，靠逻辑起始端
```

可用宽度先扣除左右安全区域、固定附件及 `contentInsets` 水平留白；`itemSpacing` 在所有模式中均生效。RTL 仅镜像排列，不改变逻辑索引。`.automatic` 保持框架原策略，不采用系统 UITabBar 按设备类型选择布局的规则。

`.leading` 从扣除安全区域、附件后的 `contentInsets.leading` 开始排列；RTL 下从右侧开始，余量留在左侧。单项不拉伸，空列表不产生额外滚动范围；超宽时与 `.centered` 的布局相同。选中项仍沿用现有滚动定位规则，不会强制贴到起始边缘。

默认内容、自定义内容与回退项共用此策略。自定义自动测量内容在 `.centered` 和 `.leading` 下使用自然首选宽度，不受视口宽度限制；其他模式沿用视口内的首选宽度测量。内容高度按最终分配宽度重新测量。`.fill` 下内置长标题按按钮配置截断；自定义内容应支持压缩或换行，业务 required 最小宽度不能撑开 Cell，可能超出其布局区域。显式 `SPTabBarContent.size` 的高度仍由业务提供。运行时切换自动刷新测量、滚动范围和指示器，保留 Item 身份、选择与分页进度，不发送选择回调。

Demo 的“页面 → 标签布局模式”和“标签外观 → 配置 → 标签布局模式”均可切换四种模式，菜单每次打开时根据当前模式显示勾选。切换只改变宽度分配，不重置内容、间距、附件、方向或当前选择。手机上可先在独立“标签外观 → 配置”选择“紧凑编号内容”，观察 `.centered` 两侧留白与 `.leading` 单侧留白的区别；“默认内容”恢复图文，“自定义卡片”恢复卡片。通过“留白与附件 → 切换布局方向”可对比 RTL；分页页保留原有多频道内容，适合观察超宽滚动。自定义卡片在 `.fill` 分配宽度不足时隐藏编号并缩小留白，标题和副标题居中、最多两行；恢复充足宽度后重新显示编号。此布局选择在配置阶段完成，自动测量与显示保持一致。“自动图文排列”只调整标签内部图文关系，与整栏的“自动分配”相互独立。

### 运行时属性更新与布局刷新

布局相关属性可在显示后直接修改；框架会按影响范围自动更新测量、布局或渲染，无需重新设置 `items` 或手动调用 `reloadContent()`。需要同步读取最终 frame 时，在修改完成后对标签栏调用 `layoutIfNeeded()`。同一轮属性修改之间即使发生指示器刷新，最终指示器仍按最新 Item frame 定位。

| 属性或输入 | 影响范围 | 刷新方式 |
| --- | --- | --- |
| `itemPositioning`、`itemSpacing`、`minimumItemWidth`、`contentInsets` | Item 宽度分配、位置、滚动范围；上下留白也影响建议栏高 | setter 自动重新测量并安排布局；归一化后相同值不重复刷新 |
| `contentStyle`、`contentDelegate` | 内容配置、理想尺寸和内容指示器区域 | 模式变化或自定义模式下更换代理自动刷新；业务自有数据变化调用 `reloadContent()` |
| `leadingAccessoryView`、`trailingAccessoryView` | 固定附件、剩余标签视口、建议栏高 | 替换自动刷新；已有附件的内容、约束或 `isHidden` 变化调用 `invalidateAccessoryLayout()` |
| Item 的 `title`、`image`、`selectedImage`、`landscapeImagePhone`、`badgeValue`、状态文字属性中的字体 | 内容测量、栏高、Item 几何及内容指示器区域 | 自动通知所有宿主重新测量、配置内容并安排布局 |
| Item 的 `imageInsets`、`landscapeImagePhoneInsets` | 图标绘制及内容配置 | 自动刷新；图标槽位仍按默认的 24 pt 规则测量 |
| 栏级／所选 Item 的 `standardAppearance`，其中的 `itemAppearance.layout` 和各状态 `font` | 图文排列、字体测量、建议栏高及指示器 | 赋值时复制；通过宿主 getter 修改嵌套值也自动刷新 |
| `indicatorStyle`、`indicatorLayoutDelegate`、`indicatorView`、Appearance 的 `indicatorLayout` 全部字段 | 指示器参考区域、对齐、宽高、内缩、偏移、圆角和层级 | 自动重算指示器，不参与标签测量；外部几何数据变化调用 `reloadIndicator()` |
| Appearance 的 `indicatorColor` | 指示器颜色 | 仅刷新渲染，保留选择动画与分页进度 |
| `tintColor`，Item 的颜色、启用状态、无障碍和大内容查看属性，Appearance 的状态颜色、背景和阴影 | 默认内容渲染、交互和装饰；自定义内容也可能据此改变尺寸 | 自动更新；通用内容刷新会核对实际测量，几何不变时不打断滚动或选择动画；阴影图片高度在布局时更新 |
| `bounds`／`frame` 尺寸、Safe Area、布局方向、Dynamic Type、相关 traits | 视口、排列、内容尺寸与指示器内容区域 | 使用 UIView 布局／环境回调自动更新；布局方向由 `semanticContentAttribute` 和宿主环境解析 |
| `items`、`selectedItem`／`setSelectedIndex(_:animated:)`、分页进度 | Item 身份及顺序、选中内容状态、指示器端点和滚动目标 | 使用各自更新入口，保持对象身份与原有选择回调语义；Item 的 `tag` 仅为业务标记，不影响布局 |

Item 和 Appearance 的通用属性刷新与间距、留白使用相同的内容更新策略：保留选中对象和分页端点／进度；实际几何变化时，将手动偏移限制到新范围，正在执行的程序选择动画落到已选项；内容及指示器端点几何不变时保留动画与手动偏移。即使 Item 宽度未变，标题内容区域或替换 Appearance 后的指示器几何变化也会使程序动画落到最新选中项，并清除分页接管时保存的旧几何起点。默认内容因 Dynamic Type 等字体／图文布局环境变化而改变几何时，仍重新对齐选中项。“减少动态效果”状态通知会结束正在执行的程序选择动画；单纯的透明度设置通知不打断几何未变的动画。指示器几何配置变更或显式 `reloadIndicator()` 仍按该入口的约定结束程序选择动画并重算当前指示器。未启用指示器时，内容与分页仍正常刷新。

### 内容留白与固定附件

`contentInsets: NSDirectionalEdgeInsets` 默认 `.zero`；`leadingAccessoryView` 和 `trailingAccessoryView` 默认 nil。三者都属于标签栏布局配置，不属于 Appearance，不参与其复制或归档。没有配置附件或留白时，布局和选择行为保持原样。

```swift
let tabs = pager.tabBar
// 水平首尾留白随标签内容滚动，上下留白参与建议栏高。
tabs.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)

let more = UIButton(type: .system)
more.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
more.accessibilityLabel = "更多频道"
NSLayoutConstraint.activate([
    more.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
    more.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
])
more.addAction(UIAction { _ in
    // 展示业务频道菜单；可通过 tabs.requestSelection(of:) 请求频道选择。
}, for: .touchUpInside)
tabs.trailingAccessoryView = more

// leadingAccessoryView 同样支持搜索按钮、UILabel 或完整约束的自定义容器。
// 修改已有附件的文字、约束或 isHidden 后，请求重新测量和更新宿主栏高。
more.setTitle("频道", for: .normal)
tabs.invalidateAccessoryLayout()
```

布局先从栏的 bounds 扣除左右 Safe Area，再为两端附件预留空间，其余部分作为标签视口。背景、材质及底部分隔线仍铺满整栏。`contentInsets` 仅作用于标签内容，附件内边距由附件自己配置。水平留白和项间距共同计入滚动宽度；到开头／结尾时显示对应留白，滚动到中间后留白随内容移出视口。上下留白内缩 Item，内置指示器跟随内缩后的 Item／内容区域。负数及非有限 inset 分量归零，每个分量最多 1,000,000 pt。空列表不会因水平留白单独产生滚动或渐隐。

附件通过普通 UIView 承载视图使用 `systemLayoutSizeFitting(UIView.layoutFittingCompressedSize, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)` 测量。提供固有尺寸、完整的内部约束或显式宽高约束即可；不读取 frame，也不调用 `sizeThatFits(_:)` 回退。没有尺寸依据、测量结果非法（非有限、非正或超过 1,000,000 pt）以及 `isHidden` 的附件按零占位。框架用极低优先级的零尺寸测量约束避免无约束 UIView 返回旧 bounds，业务约束与固有尺寸均优先。测量时临时连接附件与承载视图四边，由承载视图求解，避免配置式 UIButton 的 fitting 重写忽略外加尺寸约束；实际布局解除四边连接以支持裁切。业务自行提供足够的点击区域；示例的 44 pt 是业务最小尺寸，不是库的强制下限。

附件由标签栏强持有，框架管理 frame、承载区域和裁切，不应与其他宿主共享，也不要添加连接附件与标签栏的外部定位约束。同一对象不能同时用于两端，跨端重复赋值会忽略该次操作并保留原状态；替换或移除后旧附件从框架层级移除。正常情况下附件保持理想尺寸并垂直居中；两端理想宽度总和超过安全宽度时，按宽度比例分配不重叠的区域，分别朝逻辑外侧对齐并裁切，标签视口可以缩为零。恢复宽度后恢复正常显示；固定栏高不足时也在栏内裁切，不扩大栏外点击范围。

建议高度为 `max(标签内容高度 + top + bottom, leading 附件高度, trailing 附件高度)`。内容高度使用扣除附件和水平留白后的宽度测量。容器仍将 `SPPageLayout.tabBarHeight` 作为最小栏高，0 隐藏整个标签栏及附件。候选 `sizeThatFits(_:)` 不修改当前附件 frame、Cell、偏移或指示器。附件内容、内部约束或可见性变化后调用 `invalidateAccessoryLayout()`；替换附件、修改留白、旋转、安全区域和相关 traits 变化由框架安排更新。

#### UI／UX 行为

- 附件固定、标签独立滚动。RTL 下 leading 位于右侧、trailing 位于左侧；逻辑频道索引不变。选中项围绕剩余标签视口的中心对齐，首尾受实际滚动范围限制。
- 标签视口的某一侧还有隐藏内容时，该侧显示透明度渐隐，接近端点连续减弱，到端点消失。附件始终清晰；渐隐适配浅色、深色、透明及材质背景。
- 附件按钮独立处理动作、菜单和无障碍说明，不占用标签索引。点击留白和项间距不会选择标签；附件点击不会自动触发选择或分页回调。业务菜单若要切页，显式调用 `requestSelection(of:)`，保留禁用项和选择代理语义。
- 内容几何变化保留选中 Item：手动偏移限制到新范围，程序选择动画落到选中项，分页按原端点与进度重新定位。无几何变化的刷新不打断动画或手动滚动。旋转、布局方向变化沿用原有对齐策略。
- 附件承载视图不额外成为无障碍元素；按钮名称、动作及 Dynamic Type 适配由业务设置。窄窗口中的裁切不会扩大可点击区域，业务应避免使用过宽附件。

#### Demo 操作

“标签外观”→“配置”和分页 Demo 的“页面”菜单均提供“留白与附件”：可选择无／对称／非对称留白、无／仅搜索／仅更多频道／两端附件，并切换附件文字、高附件和布局方向。“搜索频道”展示本地演示提示；“更多频道”按当前 Item 生成菜单，标题为空时使用无障碍名称（例如纯图标频道“通知”），两者均为空时显示“未命名”。禁用频道不可选，选择可用频道后通过既有 API 切换。没有网络搜索或频道管理持久化。

在 Duo 外屏或较小窗口中，“页面”菜单可能不能一次显示所有操作；在菜单内部上滑即可找到下方的“重排页面”“删除当前页”“清空页面”等选项。返回控件的位置由系统导航容器决定，Duo 上可能出现在侧边；附件按钮和页面菜单不替代系统返回操作。

`--open-gallery --accessories` 直接进入带两端按钮和较多频道的独立示例；`--open-demo --accessories` 进入分页示例。可附加 `--rtl` 或 `--dark`；深色模式应用到整个窗口，让导航栏、菜单与内容保持一致。独立示例还支持 `--narrow-tabs`（将栏宽限制为 240 pt，用于复现内容裁切，不等同于系统分屏）。原有自定义内容、长标题、栏高及隐藏菜单继续可用。UI 验证截图与执行范围见 [Validation/README.md](Validation/README.md)。

### 选中指示器

`SPTabBar.IndicatorStyle` 定义在标签栏中，包含 `.capsule`、`.underline`、`.custom`、`.none`，默认 `.capsule`。它与 `ContentStyle` 独立：两种内置样式直接提供默认布局和颜色；`.custom` 启用几何代理与自定义视图；`.none` 表示不使用指示器，跳过几何计算和渲染，不调用自定义扩展点，标签选择、文字状态和分页照常工作。

未显式覆盖时，胶囊在标签四周内缩 4 pt，使用 `.tertiarySystemFill`；线条左右内缩 12 pt、底部对齐、高 3 pt，跟随选中文字颜色。两种内置布局均保护极小尺寸。自定义模式缺少几何代理时使用布局配置或胶囊几何，缺少视图时使用内置绘制，默认颜色跟随选中文字。切回内置样式或 `.none` 保留自定义对象，但不调用代理或视图更新。

Appearance 的 `indicatorLayout` 和 `indicatorColor` 默认均为 nil，表示采用当前样式的默认值；显式配置优先于样式，切换样式不会清除配置，设回 nil 恢复当前样式默认值。指示器是否启用统一由 `SPTabBar.indicatorStyle` 控制；`.none` 表示不需要指示器，切回其他模式时按当前选择或分页进度恢复显示。

```swift
// 内置底部线条；nil 颜色跟随选中文字颜色，最终回退到 tintColor。
tabs.indicatorStyle = .underline

// 切回胶囊，不需要同步修改布局或颜色。
tabs.indicatorStyle = .capsule

// 再使用线条，并按业务需要覆盖位置和尺寸。
tabs.indicatorStyle = .underline

// 顶部居中、固定尺寸；只调位置和尺寸无需创建自定义视图。
var layout = SPTabBarIndicatorLayout()
layout.width = 24
layout.height = 4
layout.verticalAlignment = .top
layout.offset.y = 2
layout.cornerRadius = 2
tabs.standardAppearance.indicatorLayout = layout

// 跟随实际图文宽度，放在内容下方。
layout.reference = .content
layout.width = nil
layout.height = 3
layout.verticalAlignment = .bottom
layout.offset.y = 5
tabs.standardAppearance.indicatorLayout = layout

// 内容背景：负内缩表示外扩。
layout.height = nil
layout.verticalAlignment = .center
layout.offset = .zero
layout.horizontalInset = -6
layout.verticalInset = -3
layout.placement = .background
tabs.standardAppearance.indicatorLayout = layout
tabs.standardAppearance.indicatorColor = .tertiarySystemFill

// 不需要指示器；标签选择与分页继续工作。
tabs.indicatorStyle = .none

// 清除覆盖，再恢复线条预设。
tabs.standardAppearance.indicatorLayout = nil
tabs.standardAppearance.indicatorColor = nil
tabs.indicatorStyle = .underline
```

`indicatorColor = nil` 时，胶囊使用系统填充色；线条和自定义模式依次使用 Item 的选中文字属性、`itemAppearance.selected.titleColor`、`tintColor`。显式颜色在样式切换时保持。Appearance 的指示器归档配置仅包含 `indicatorColor` 和 `indicatorLayout`。缺少配置时保持 nil，由当前样式提供默认值。指示器样式及是否启用属于运行中的标签栏，不编码到 Appearance，应由宿主恢复 `indicatorStyle`。

布局以 `.item` 或 `.content` 为参考区域，支持 leading/center/trailing、top/center/bottom、独立可选宽高、水平/垂直内缩及物理偏移。nil 宽高填充内缩后的区域，固定宽高默认可超出参考区域；`limitsSizeToReference` 可显式限制到参考区域。leading/trailing 跟随 RTL，`offset.x` 始终按物理方向计算。负尺寸归零、非有限尺寸使用参考尺寸、非有限内缩/偏移使用 0；标量限制到 ±1,000,000 pt。`cornerRadius = nil` 使用指示器最终宽高较小值的一半，使横向胶囊、圆形和纵向胶囊采用一致的自动圆角规则；显式值也限制到该上限。

默认内容区域来自独立布局副本中 UIButton 实际呈现的文字和图片，不含角标；屏幕外标签也可解析。自定义内容通过 `SPTabBarContent.indicatorContentRect` 提供最终 Cell 局部坐标的区域，nil 或非法值回退到整项。随可用宽度变化的复杂区域可以在下面的几何代理中根据 `itemFrame` 自行计算。

```swift
@MainActor
final class IndicatorGeometry: SPTabBarIndicatorLayoutDelegate {
    func tabBar(
        _ tabBar: SPTabBar,
        indicatorFrameFor context: SPTabBarIndicatorLayoutContext
    ) -> CGRect? {
        CGRect(
            x: context.contentFrame.midX - 16,
            y: context.itemFrame.maxY - 8,
            width: 32,
            height: 6
        )
    }
}

// 宿主通过属性强持有 geometry，标签栏仅弱引用它。
tabs.indicatorStyle = .custom
tabs.indicatorLayoutDelegate = geometry
// 如需自定义绘制，再设置 SPTabBarIndicatorView 子类。
tabs.indicatorView = customIndicatorView
```

几何代理优先于布局配置；返回 nil 或含负尺寸、非有限值等非法 CGRect 时回退到配置布局，零尺寸可隐藏某项。上下文包括 Item、逻辑索引、标签区域、内容区域、安全视口对应区域、布局方向、traits 和布局配置。所有 frame 使用 Collection View 的滚动内容坐标系，框架负责滚动转换，不要再次减去 contentOffset。回调可能处理屏幕外项，应保持同步、无副作用，不修改标签栏、不依赖调用次数。外部数据变化后调用 `reloadIndicator()`。

自定义视图继承 `SPTabBarIndicatorView`，在 `update(_:)` 中读取来源/目标索引、连续进度、当前 frame、颜色和圆角；索引为 nil 表示对应端点没有选中项。框架强持有视图并管理 frame、隐藏、层级与交互；业务只布局内部子视图，不修改根视图 frame/transform。替换或设为 nil 会移除旧视图；不能把同一视图交给多个标签栏。代理和视图不进入 Appearance 的复制与归档；布局值和颜色可以复制与安全归档。

指示器是装饰，不参与标签宽度、栏高或点击区域测量；需要预留空间时，在标签内容中提供留白，并用 `SPPageLayout.tabBarHeight` 或独立宿主栏高保证空间。允许超出单项，但始终随内容滚动并裁剪到扣除附件后的标签视口，不能跨到附件、Header 或页面上。前景/背景层都不拦截触摸，也不增加无障碍焦点。

点击、程序化切换和分页共享位置与宽高插值。标签栏的滚动动画独立于指示器是否存在，`.none` 或零尺寸指示器不会关闭标签栏的滚动动画。自定义指示器在程序动画开始时先接收 `progress = 0` 和起始 frame，再按动画进度更新；连续点击从当前 frame 接续，不提前发送目标完成态。取消返回选中项；分页期间修改指示器配置或栏尺寸会保留进度并重新计算端点，程序动画期间修改配置则落到当前选中项，保留已有滚动偏移。每项几何使用该 Item 的 Appearance 或栏级回退；颜色、层级和圆角使用当前已选 Item 的外观，提交选择时更新；Item 外观不会改变标签栏的 `indicatorStyle`。交互分页按手势进度更新，减少动态效果时程序化选择直接完成。

独立“标签外观”和分页“页面”菜单的“指示器”子菜单展示六种效果：默认胶囊、底部线条、顶部固定线条、跟随内容宽度、内容背景、自由布局与自定义视图；另提供不使用指示器的隐藏选项。

默认使用系统材质背景和胶囊指示器。`.automatic` 在常规垂直尺寸类中上下排列图文，在紧凑垂直尺寸类中左右排列；`.stacked`、`.inline` 可显式指定。纯文字和纯图标项仅布局实际内容。选中指示器支持布局预设、自定义几何，并通过 `.none` 关闭。图标保持比例放入 24 pt 区域，紧凑高度可使用 `landscapeImagePhone`，支持相应 imageInsets；保留基类的大内容图片属性供自定义呈现使用；默认栏已随 Dynamic Type 增高，不额外启用长按大内容查看手势。普通图片保留 renderingMode；默认 SF Symbol 在缩放后仍按模板着色，显式 `.alwaysOriginal` 保留原色。

默认文字和模板图标采用 UITabBar 风格：未选中为 `.secondaryLabel`，选中跟随标签栏的 `tintColor`（包括从父视图继承的颜色），禁用为 `.tertiaryLabel`。显式状态颜色优先；`titleColor`、`iconColor` 设为 nil 时恢复该状态的默认颜色。默认模式下，运行时改变 tint 会立即刷新可见标签，不改变滚动位置和选中动画。深浅色使用动态颜色解析。

默认标签宽度按正常、选中、禁用状态的最大内容尺寸预留，避免选择时字体变化导致跳动。先满足每项的内容宽度和 `minimumItemWidth` 下限，再让其余项尽量等宽；总需求超出视口则横向滚动。默认最小项宽为 44 pt，默认图文高度仍至少 44 pt；选中项尽量居中，首尾受内容边界限制。布局和字体变化重新对齐，普通刷新保留用户手动滚动位置。RTL 仅反转视觉顺序，逻辑索引不变。

`SPTabBar.itemSpacing` 控制相邻 Item 布局区域之间的固定水平间距，默认 `0`，适用于默认、自定义和回退内容。它不属于 Item 内部留白，不计入 `minimumItemWidth`，也不替代标签栏两侧 Safe Area；首尾不额外增加间距。负值和非有限值归零，超过 1,000,000 pt 截到该上限。

```swift
tabs.itemSpacing = 16 // 相邻 Item 之间留出 16 pt
tabs.minimumItemWidth = 44 // 单个 Item 的最小布局宽度，不含间距
```

有 n 个 Item 时，总间距为 `max(0, n - 1) × itemSpacing`。先从扣除附件后的标签视口中减去水平内容留白和总间距，再按现有策略分配 Item 宽度；超出视口时，滚动内容宽度为 Item 宽度之和、总间距及水平首尾留白之和。自动内容按扣除间距后实际分配的宽度计算高度；空列表和单项不产生额外间距。间隙不属于任意 Item 的点击区域，也不增加无障碍元素。

运行时修改间距无需重设 Items，保留对象身份、当前选择和选择回调语义。几何变化时，手动偏移限制到新滚动范围，程序动画落到当前选中项，分页交互保持进度并重算端点；归一化后的间距未变化时不触发刷新。居中、边缘渐隐和指示器均跟随最终布局，`.none` 下滚动动画照常工作。Demo 的“页面”及“标签外观 → 配置”中均可通过“标签间距”选择 0、8、16、24 pt。

背景铺满容器，内部 Collection View 和指示器共用扣除左右安全区域及固定附件后的标签视口；附件在各自区域独立接收点击。超出视口的内容在仍有隐藏项的一侧使用 16 pt 渐隐；材质背景不参与渐隐。`tabBarHeight` 是最小高度（0 隐藏），实际高度综合内容测量、上下内容留白和附件理想高度；变化后容器更新页面边界并保留滚动位置。独立宿主应在布局时使用 `sizeThatFits(_:)`。降低透明度时改用不透明系统背景，减少动态效果时关闭程序化选中动画。角标、选中和禁用状态同步无障碍信息。

分页和非相邻选择继续共享选中标识与居中偏移的连续进度；连续点击从当前位置接续。按住标签按钮后横向拖动时允许 Collection View 接管手势。自定义栏可重写 `setItems(_:)`、`setSelectedItem(_:animated:)` 和 `setTransitionProgress(from:to:progress:)`，调用 super 保持模型同步，使用 `requestSelection(of:)` 发送用户请求。通过 `pager.tabBar = CustomTabBar()` 替换。

迁移旧代码：将 `onSelect` 替换为 `SPTabBarDelegate`；自定义点击调用 `requestSelection(of:)`；持有并修改 Item 对象，避免复制结构体的假设；读取 title 时处理 nil。Demo 启动页的“标签外观”提供独立标签栏，分页 Demo 的“页面”菜单可切换图文、角标、禁用和指示器样式。首版未提供 scrollEdgeAppearance、More 导航或系统编辑排序。NSCoding 保存 Item 的基类属性、自定义图片、角标与 Appearance；Appearance 的复制和安全归档保留背景、选中标识、布局和状态样式。

例如，旧 `onSelect` 中的业务通知迁移到代理。嵌入分页容器时，代理无需再调用容器切页；内部协调负责完成该操作。

```swift
final class ScreenController: UIViewController, SPTabBarDelegate {
    let pager = SPPageViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        pager.tabBar.delegate = self
    }

    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool {
        true // 业务方可在此否决点击
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        // 此时已提交选择；item 是原始对象，selectedIndex 是当前索引映射。
        print(item.title ?? "", tabBar.selectedIndex as Any)
    }
}
```

### 自定义标签 UI

`SPTabBar.ContentStyle` 将内容展示分为 `.default` 和 `.custom`，默认值为 `.default`。已有接入无需修改。设置 `.custom` 后，由弱引用 `contentDelegate` 为每项提供 `SPTabBarContent`；切回 `.default` 恢复内置图文样式，保留 Item 身份和当前选择。内容样式与 `indicatorStyle` 独立，背景、指示器和分页进度仍由标签栏维护。

每项内容以 `UIContentConfiguration` 描述 UI，默认由内容视图的 Auto Layout 自动测量。可以返回系统的 `UIListContentConfiguration`，也可以自行实现配置及 `UIView & UIContentView`，在视图中任意组合编号、图片、标题、副标题或角标。框架继续使用标准 `UICollectionViewCell` 和 `CellRegistration`，业务方无需注册 Cell 或继承 Cell。

```swift
@MainActor
final class TabContentProvider: SPTabBarContentDelegate {
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        let font = UIFont.preferredFont(
            forTextStyle: .headline,
            compatibleWith: context.state.traitCollection
        )
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        configuration.textProperties.font = font
        configuration.textProperties.color = context.state.isDisabled ? .tertiaryLabel
            : (context.state.isSelected ? context.tintColor : .label)
        configuration.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 12, leading: 16, bottom: 12, trailing: 16
        )
        // 不需要计算文字宽高；也可以返回自己实现的 UIView & UIContentView 配置。
        return SPTabBarContent(configuration: configuration)
    }
}

// 在控制器中强引用 provider；contentDelegate 本身为弱引用。
let contentProvider = TabContentProvider()
pager.tabBar.contentDelegate = contentProvider
pager.tabBar.contentStyle = .custom
// 业务自有数据发生变化时：
pager.tabBar.reloadContent()
```

配置与测量遵循以下约定：

- `context` 提供当前 `UICellConfigurationState`、tintColor、视觉方向、扣除左右安全区域、固定附件和水平内容留白后的可用宽度，以及当前生效 Appearance 的独立副本。尚未布局时宽度可能为 0。业务决定如何使用 Item 和 Appearance；框架不会把默认样式强加给自定义内容。
- `SPTabBarContent(configuration:)` 默认自动测量，`size == nil`。框架用独立的内容视图调用 `systemLayoutSizeFitting`：先以压缩目标求首选宽度，再由普通 Auto Layout 测量宿主以水平优先级 999 尝试视口内的首选宽度（未知视口或 `.centered`／`.leading` 时使用内容首选宽度）；业务 required 最小宽度可以影响首选宽度，但不会改变 `.fill` 的最终项宽。然后由布局应用 `minimumItemWidth` 和 `itemPositioning` 分配宽度，以水平 `.required`、垂直 `.fittingSizeLevel` 定宽求高度；`.fill` 的水平测量优先级为 999，以避免与业务 required 最小宽度冲突，Cell 仍严格使用分配宽度。所有 Cell 高度取各项所需高度的最大值，并受容器最低栏高约束；`tabBarHeight == 0` 仍隐藏标签栏。
- 自定义视图需要完整的内部 Auto Layout 约束或能参与求解的 `intrinsicContentSize`。例如多行 UILabel 应连接内容视图四边，框架不额外添加业务内边距。`targetSize` 本身不是最大尺寸；普通 UIView 只重写 `sizeThatFits` 也不代表它一定参与 Auto Layout 测量。手动布局视图可继续提供显式尺寸，或自行实现 `systemLayoutSizeFitting`。
- 仍可使用 `SPTabBarContent(configuration: configuration, size: CGSize(width: 160, height: 76))` 跳过自动测量；它是理想尺寸覆盖，最终宽度由 `itemPositioning` 决定，可扩展，也可在 `.fill` 下小于理想宽度。`size` 现在为 `CGSize?`，旧的显式尺寸初始化调用保持可用，读取属性的代码需要处理 nil；赋值 nil 可恢复自动测量。显式尺寸和自动测量结果必须为有限正数且不超过 1,000,000 pt，否则该项回退到默认内容；理想尺寸不再混入 Cell 最小宽度，高度不额外设下限（自动测量尺寸向上取整到 pt）。显式尺寸不限制到视口；自动测量可能压缩可换行内容。
- `SPPageLayout.tabBarHeight` 是最小栏高，默认 44，设为 0 时隐藏。正值时实际栏高为 `max(tabBarHeight, 内容所需高度 + 上下内容留白, 两端附件理想高度)`，不是固定高度。例如自定义内容需要 28 pt 时，配置 32 / 60 / 44，实际栏高分别为 32 / 60 / 44；内容需要 80 pt 时，这三个配置都得到 80。默认图文及回退项保留自身至少 44 pt 的规则，因此混用时仍可能把整栏撑高。宽度由标签栏自身的 `itemPositioning`、`minimumItemWidth`、`itemSpacing` 和分配规则控制，不由 `SPPageLayout` 控制。
- `SPTabBar.minimumItemWidth` 默认 44 pt，同时作用于默认、自定义及回退项。0 表示不额外设下限，负数归零，非有限值恢复为 44，超过 1,000,000 pt 截到该上限。它是 Cell 最小布局宽度，不改变业务返回的理想尺寸，也不扩大 Cell 外的命中区域。较小的宽度或栏高属于业务主动选择的紧凑交互，不能据此认为仍有 44 × 44 pt 点击区域。
- `.automatic` 的宽度分配连续：320 pt 视口中，理想宽度 `[160, 44]` 得到 `[160, 160]`，变成 `[161, 44]` 后得到 `[161, 159]`，不会再跳到 `[218.5, 101.5]`。这是对原“固有宽度加平均剩余空间”策略的行为调整。减少最小宽度不会关闭剩余空间分配，两个短标签仍可能等宽填满整栏。
- 内容根视图须适应实际分配宽度，包括 `.fill` 下的压缩。其他模式允许内部 required 最小宽度撑开单项并横向滚动；`.fill` 不会因此增宽，业务需自行降级内容或约束。根视图的 required 固定宽度、自身矛盾的 required 约束不受支持。有限正数检查不负责诊断业务约束冲突。自动内容在实际分配宽度下重新测高，业务自定义内边距由内容视图负责。
- 未设置代理、代理释放后下一次标签栏布局、返回 nil 或尺寸无效时，对应项回退到默认内容。允许同一栏混用默认项和自定义项。
- 内容和尺寸会缓存。Item、选择、Appearance、tint、traits、可用宽度、RTL 或模式变化会重新获取配置；业务自有数据变化需调用 `reloadContent()`。提供方法应同步、无副作用，不得在其中修改标签栏或 Item、触发布局或重载。自动测量由框架构造独立视图；不要在代理回调中自行构造或缓存正在显示的视图。状态样式宜保持约束尺寸稳定，或为显式尺寸取各状态最大值。
- `reloadContent()` 不发送选择回调。内容及指示器端点几何不变时保留手动滚动偏移、正在进行的选择动画和分页进度；几何变化时将手动偏移限制到新的可滚动范围，选择动画落到已选项，分页则按相同逻辑进度在新布局中重新定位。`.default` 下调用此方法或设置 `contentDelegate` 不改变当前显示和交互。弱引用释放不会主动触发布局，需要立即回退时可显式清空代理或请求标签栏布局。
- `sizeThatFits(_:)` 只测量建议宽度对应的高度，不提交配置、不改变当前 Cell 布局、偏移或指示器。实际布局时才采用实际视口的配置与尺寸。显示快照与最近一次候选测量分开缓存，重复询问相同宽度不会反复调用代理或构造测量视图；候选宽度变化仍可能触发代理，所以回调不能假定标签栏已经改变 frame。
- 测量视图处于隐藏、无交互和无障碍入口的独立宿主中，继承标签栏 traits、tint 和视觉方向，完成测量后移除；不会借用正在显示的 Cell。`makeContentView()` 和配置更新可能用于测量，不能依赖可见性或触发业务副作用。配置需独立描述完整内容。业务异步数据变化后调用 `reloadContent()`；仅在某个显示视图上调用 `invalidateIntrinsicContentSize()` 不会自动清除标签栏缓存。
- 自定义配置的 `updated(for:)` 接收 `UICellConfigurationState`，其中包含选中、禁用和真实按压高亮。高亮变化仅更新内容配置，不重新询问尺寸。提供方法的 `context.state` 高亮为 false；框架只保证 traits、选中、禁用和运行时按压高亮，不承诺同步 Cell 的焦点、编辑或多选状态。`UIContentView.configuration` 应覆盖旧状态并复用子视图。默认、自定义及回退模式共用同一个框架内容容器和激活按钮；切换模式不会重建整个 Cell 内容容器。兼容的业务配置通过 `configuration` 原位更新；业务配置不兼容时仅替换内部自定义视图。iOS 16+ 使用 `supports(_:)` 判断业务配置兼容性，iOS 15 按配置类型判断。离开自定义模式会释放业务视图，恢复时按当前配置重新创建，不隐藏缓存旧内容。
- 每个标签保留一个由框架管理的整项点击和无障碍入口。自定义视图内部控件不参与命中测试或独立无障碍导航；如需标签内的独立按钮，当前接口不提供该交互模型。点击否决、禁用、程序化选择和分页手势的回调语义均沿用原规则。
- `SPTabBarContent.accessibilityLabel`、`accessibilityHint`、`accessibilityValue` 可覆盖描述；nil 沿用 Item 标题／描述与角标值。选中和禁用 traits 由框架维护，避免重复暴露内部标签。

完整自定义视图示例见 [CustomTabContent.swift](Examples/StickyPagerDemo/StickyPagerDemo/CustomTabContent.swift)：编号、标题、副标题组成卡片，演示按压、选中、禁用、Dynamic Type 与 RTL。Demo 首页“标签外观”→“配置”→“自定义卡片”，或分页 Demo“页面”→“切换自定义标签”即可查看；`--open-demo --custom-tabs` 可直接启动。Demo 的卡片内部使用 Auto Layout 和 UILabel 固有尺寸，不再手算文字宽高。“页面”→“切换多行副标题”使用包含换行的两段文字，确保宽屏也能演示多行测量、栏高增长与恢复；“刷新自定义内容”演示同尺寸更新后保持手动滚动位置。“切换紧凑标签”使用仅含 UILabel 的 `UIContentView`，通过字体固有尺寸和内边距约束自动测量；“标签栏最小高度”菜单可选择 32、60、隐藏或默认 44，演示紧凑内容低于 44 和隐藏后恢复。该菜单不限制大字号所需高度。“页面”→“标签宽度”提供紧凑编号内容、24／44／120 最小项宽，以及首项内部 required 最小宽度为 `max(480, availableWidth + 80)` pt 的示例；后者在 `.automatic`、`.centered` 和 `.leading` 下可超出视口并横向滚动，不适用于要求内容可压缩的 `.fill`。最小项宽是下限，默认 `.automatic` 模式下内容较少时余量仍会均分。

容器中设置最小栏高，无需业务计算内容高度：

```swift
pager.tabBar.contentDelegate = provider
pager.tabBar.contentStyle = .custom
pager.layout.tabBarHeight = 32 // 内容较小时栏高为 32，需要更多空间时自动增高
pager.tabBar.minimumItemWidth = 24 // 按需选择紧凑项宽；默认仍为 44
pager.tabBar.itemSpacing = 8 // 相邻 Item 间距；默认 0
// pager.layout.tabBarHeight = 0 // 隐藏；恢复为 44 即恢复默认下限
```

独立标签栏应在布局中使用 `sizeThatFits(view.bounds.size)` 取得当前宽度对应的内容高度，并由宿主设置最终高度。独立使用不读取 `SPPageLayout`；需要最小 44 pt 时，宿主使用 `max(44, measuredHeight)`。

### 滚动坐标与布局

令顶部安全区域高度为 `S`，Header 折叠范围 `C = max(0, headerHeight - S - minimumHeaderHeight)`，当前页归一化位移 `q = contentOffset.y + adjustedContentInset.top`。实际 Header 总高度至少为 `S + minimumHeaderHeight`，保证短 Header 的标签栏也不会进入系统栏区域；无 Header 时标签栏直接位于 `S`：

- `Header 折叠量 = clamp(q, 0...C)`。
- `内容位移 = max(0, q - C)`。
- 向上先消耗 Header 距离，再滚动内容；向下先回到内容顶部，再展开 Header。
- 负位移为列表自身回弹，Header 不额外拉伸。

所有内容页的根视图顶部始终与当前 `SPTabBar` 顶部对齐，底边固定在容器底边；标签栏显示在页面上方，并优先接收重叠区域内的触摸。令当前 Header 折叠量为 `c`、标签栏实际高度为 `T`，分页视口从 `S + minimumHeaderHeight` 开始，根视图在其中下移 `C - c`，因此根视图顶部为 `headerHeight - c`。这是真实 frame 布局，不使用 transform 或单独移动滚动内容模拟。

框架为子控制器的 `additionalSafeAreaInsets.top` 叠加 `T`，让使用 Safe Area 的固定控件以及 UIKit 自动调整的滚动内容避让标签栏。主要滚动视图的框架顶部 inset 仍包含折叠量 `c`；若滚动视图与标签栏存在重叠且自动 inset 没有完全避让（例如 `.never`），绑定只补足剩余遮挡高度。位于固定 Label 下方、与标签栏无重叠的滚动视图不额外添加 `T`。更新页面尺寸和 inset 时保留归一化位移 `q`，正文在 Header 折叠期间保持在标签栏下方，完全折叠后再滚动正文。短内容补齐量同时扣除自动及手动避让，保证 UIKit 的实际可滚动范围足以折叠 Header，不修改业务 contentSize。

业务修改 `additionalSafeAreaInsets.top` 时应设置业务需要的顶部值，不把 getter 中已包含的标签栏贡献再算入基准；框架随后叠加当前 `T`。只修改其他方向时，框架保留原业务 top，不重复叠加栏高。其他方向的业务 inset 保留，标签栏隐藏／高度变化时更新贡献，页面移除、缓存淘汰或容器释放时恢复最新业务基准。仅替换或解绑主要滚动视图不会移除页面仍需保留的标签栏安全区域。

根视图为普通 `UIView` 且 `UILabel` 与 `UIScrollView` 同级时，Label 可约束到根视图的 `safeAreaLayoutGuide.topAnchor`，滚动视图可约束在 Label 下方；也支持滚动视图铺满根视图。框架不修改业务子视图约束，不需要业务重复添加 Header 高度或监听折叠进度来移动 Label。页面高度随 Header 折叠连续变化，内部布局应响应 bounds 变化；固定 frame 不随父视图变化的子视图仍由业务负责更新。

展开时 Header 从容器 `y = 0` 开始，标签栏紧接 Header；折叠后标签栏位于 `S + minimumHeaderHeight`。旋转或安全区域变化会重新计算 `C`，保留已吸顶状态和页面内容滚动位置。嵌入其他控制器时，应把容器约束到父视图边界；若约束到父视图安全区域，Header 只能从该容器顶边开始。

Header 内部由禁用用户滚动的 `UIScrollView` 承载，其 `contentOffset` 由共享折叠逻辑驱动，并通过 `setContentScrollView(_:for: .top)` 关联导航栏。iOS 26+ 使用 `topEdgeEffect.style = .soft`，在导航栏后方提供系统渐变模糊效果；Header 的 UIView / UIViewController 接入方式不变。

在导航容器内展示全屏 Header 时，宿主需允许根视图向顶部延伸。iOS 26+ 保留系统导航栏外观即可，避免透明 `UIBarAppearance` 定制干扰原生效果；旧系统可配置当前页面的透明导航外观，并按需求处理 Header 前景内容在导航栏下方的裁剪。Demo 已实现这两条路径，框架不修改业务导航栏外观。

`viewControllerAt` 返回的内容页根视图铺满容器宽度并延伸至容器底边，不扣除左右及底部 Safe Area；容器全屏显示时即与屏幕左右边界和底边对齐，嵌入较窄的父容器时以实际容器宽度为准。Header 展开、折叠及切页时保持这些边界。横向分页步长随容器宽度更新。页面背景可铺满根视图，普通页面的文字和按钮应使用 `safeAreaLayoutGuide` 避让安全区域，滚动内容按 UIKit 的 `adjustedContentInset` 及业务指定的 inset 调整策略避让。框架保留业务配置；使用 `.never` 的主要滚动视图由框架补足标签栏遮挡，但仍需业务自行处理系统安全区域。直接把固定控件约束到根视图 `topAnchor` 会进入标签栏覆盖区域；需要避让的控件应使用 `safeAreaLayoutGuide.topAnchor`。原先按标签栏底部作为根视图起点手写 frame 的页面，应改为依据新的根视图范围与 Safe Area 布局。

使用 `UICollectionViewFlowLayout` 的网格页还需让 Cell 布局遵循安全区域。Demo 将 `sectionInsetReference` 设为 `.fromSafeArea`，并按同一边界扣除 section 间距和列间距后计算三列宽度；在布局和安全区域变化时更新尺寸。仅保证 Collection View 根视图全宽，或直接用其 `bounds.width` 计算 Cell 宽度，并不能保证 Cell 内容避开横屏安全区域。

框架只持有自己添加的 inset 增量，解绑时移除。业务列表的 `bounces`、`alwaysBounceVertical` 和 `alwaysBounceHorizontal` 由业务配置，框架在绑定、布局与解绑时均不改写。`contentInset` 按方向维护业务基准：外部赋值中数值发生变化的方向按新的业务基准处理，未变化方向保留原基准，随后重新叠加框架贡献。因此可直接设置 `contentInset.bottom = 20`，不会重复计入未修改的 top；原值整组回写也不重复叠加。规则按各分量的新旧数值判断，整组赋值中与当前实际值相同的分量同样保留原基准。getter 返回含框架贡献的实际值，不将 `contentInset.top += 10` 等同方向读改写解释为业务基准增量；这类更新应从业务自行保存的基准计算后赋值。外部 setter 回调中再次更新 inset 时，等待嵌套赋值结束后统一叠加贡献；框架写入 inset 的同步回调中发生的业务赋值也会保留。

解绑只移除框架 inset 贡献，并将折叠坐标还原为业务正文坐标：归一化位移 `q` 转为 `q - clamp(q, 0...C)`。已滚动的正文位置和负向位移保留，部分折叠 Header 的距离不带入业务正文；折叠范围为 0 时不会将负位移归零。目标偏移相同时不额外回写；业务在框架 inset 写入的同步回调中解绑后，旧几何更新不再覆盖已还原的正文坐标。框架不结束业务刷新，也不在解绑时主动纠正越界；inset 与安全区域变化仍由 UIKit 参与布局，此契约不承诺解绑期间屏幕像素完全静止。

短／空内容只有在 Header 折叠范围大于 0 时才添加底部补齐 inset，以保证 Header 能完整折叠。折叠范围为 0（包括没有 Header）时，框架不补齐底部空白，保留业务底部 inset；顶部标签栏避让、系统安全区域与内容位置协调仍正常工作。运行时移除或恢复折叠范围，会相应移除或恢复这部分底部贡献。

纵向滚动指示器避让标签栏覆盖区域，不重复添加 Header 避让距离；启用 UIKit 自动指示器 inset 时利用 Safe Area，关闭自动调整时由绑定补足标签栏遮挡高度。保留业务 `verticalScrollIndicatorInsets`、横向指示器 inset 及 UIKit 的自动安全区域调整。`verticalScrollIndicatorInsets` 使用相同的按方向基准规则，修改 bottom／left／right 不会重复计入 top 避让；同方向读改写的限制也相同。隐藏的纵向指示器不更新轨道，恢复显示时再计算边距。

`SPPageViewController.scrollIndicatorVisibilityPolicy` 默认 `.preserve`：绑定、布局、分页和解绑均不改写业务列表的 `showsVerticalScrollIndicator`、`showsHorizontalScrollIndicator`。短列表、空列表与长列表遵循相同规则，框架不再根据正文滚动范围自动隐藏指示器；实际绘制由 UIKit 决定。

业务可以明确选择分页期间临时隐藏：

```swift
pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
// 随时恢复由业务管理显隐（也是默认值）。
pager.scrollIndicatorVisibilityPolicy = .preserve
```

`.hideDuringPaging` 在横向分页拖动、减速及切页转场期间临时隐藏两个方向的指示器，覆盖缓存页及途中加载、重新绑定的主要滚动视图。完成、取消、解绑或切回 `.preserve` 时恢复最新业务设置；没有分页时不接管显隐。隐藏期间读取显隐属性得到实际值 `false`，业务赋值会更新待恢复配置，包括再次赋值 `false` 及显隐回调中的嵌套赋值，并在本次分页内继续保持隐藏。该策略不改变列表滚动位置、回弹、刷新和指示器 inset 契约，也不影响框架自身的分页滚动视图或标签栏选中指示器。

列表原生拖动保留 UIKit 的减速和回弹。Header / 标签栏纵向拖动由框架 pan 识别器驱动同一坐标，Header 完全折叠后可继续滚动正文；拖动与 display link 惯性均限制在合法滚动范围内，到达边界即停止，不模拟列表越界或弹簧回弹；同一次拖动到达边界后立即反向移动即可响应，不需要先抵消越界距离。Header 内按钮、输入控件和独立手势区域优先处理自身操作。

Header／标签栏开始纵向拖动或横向分页开始时，仅在业务列表 `isDecelerating == true` 时发送停止原生减速的定位请求。同一次分页的开始、候选页建立与候选页变化共用一次交接，不重复停止；每次新的分页拖动仍会取消框架自身的旧拖动和惯性。静止列表与业务程序化滚动动画不额外发送停止请求。后续用户拖动正文、必要布局及切页位置恢复仍可写入坐标，不保证业务动画跨这些位置协调继续运行。

这里的业务滚动开关指 `viewControllerAt` 返回的内容页内部主要 `UITableView`／`UICollectionView`／`UIScrollView` 的 `isScrollEnabled`，不是数据源方法，也不同于容器控制横向切页的 `isPagingEnabled`。

已绑定的业务列表设置 `isScrollEnabled = false` 后，Header／标签栏暂停整次纵向联动，不再通过这些手势折叠／展开 Header 或推进正文。关闭开关时立即终止正在进行的框架拖动和惯性；重新启用后由新手势恢复，旧拖动和旧惯性不会续接，包括业务滚动视图在框架开始拖动的同步定位回调中关闭后立即重新开启的情况。框架不修改业务开关，也不把它作为坐标冻结：必要的布局、切页位置恢复和业务程序化位置更新继续协调。没有绑定滚动视图的普通页面保留原有 Header 交互。若列表在自动发现之前就已禁用，现有自动发现规则仍会跳过它；需要布局与位置协调时，通过 `setScrollView(_:forPageAt:)` 显式绑定。

一次 Header 拖动只由开始该次交互的识别器驱动，其他识别器不能改写位置或提前结束交互。替换标签栏、切页、重新绑定或布局变化会使旧拖动失效，后续新拖动可以重新开始。

### 页面切换与更新

- 切页保留共享 Header 折叠量。完全折叠时恢复目标页内容位置；部分展开时目标页对齐共享 Header，不显示与 Header 冲突的历史深层内容。
- 开始切页时只交接旧页正在进行的原生减速，同一次分页不重复停止；旧页观察回调不能改变当前 Header。
- 重排保留选中标识。删除当前页时选择原索引的新页面，越界则选择最后一页；零页面清空选中状态。
- 重复标识拒绝整次 reload，并打印调试诊断；旧快照保持不变。
- 缓存淘汰解除观察并释放控制器，保留轻量内容位置。再次访问向数据源重新请求控制器。
- 内容位置由当前页滚动记录；后台页因 Header 布局而临时对齐、重新绑定或被淘汰时，不以临时偏移覆盖该记录。父控制器出现或消失期间淘汰页面，先完成该页未结束的 appearance 回调，再解除父子关系。
- 相同标识的 reload 不重新创建控制器；业务内容刷新由页面控制器负责。删除标识会清除对应状态。
- Header 高度变化保留并钳制折叠距离；仍完全折叠时保留内容位移。尺寸变化取消未完成转场并对齐已选页面；有效范围内保留内容位置，视口放大导致可滚动范围缩短时，将当前位置和保存位置钳制到新的底部边界。

### 自动发现和复杂页面

检查根视图并递归遍历子视图，排除隐藏、透明、不可交互、禁用滚动的子树；优先具有纵向滚动证据的候选，其次是短列表及空列表，排除明显只横向滚动的视图。同级候选按可见面积和遍历顺序排序。

复杂页面应显式指定一个主要纵向滚动视图，框架不同时协调同页多个独立纵向列表。框架保留业务 `UIScrollViewDelegate` 和原有手势 delegate。没有滚动视图的页面保留共享 Header 状态，并支持在内容区、Header 和标签栏上下拖动以折叠或展开 Header，不额外包装滚动容器。此时纵向位移仅作用于 Header 折叠范围，松手后惯性运动在边界停止；内容区的按钮、输入控件和独立手势区域优先处理自身操作。异步创建滚动视图并重新发现后，自动恢复由列表驱动的联动。

### 下拉刷新

业务在内容滚动视图上安装 `UIRefreshControl`，监听 `.valueChanged`，管理刷新任务并在完成后调用 `endRefreshing()`。短／空列表若需要原生下拉回弹，由业务自行设置 `alwaysBounceVertical` 等配置；Demo 的列表页显式开启纵向回弹。

先展开 Header，再由列表的原生下拉触发刷新。框架不读取刷新状态，不因刷新而强制展开 Header、重置正文位置或禁止 Header / 标签栏拖动；刷新期间仍按实际滚动位置协调，向上滚动可正常折叠 Header。Header / 标签栏拖动仅在合法范围内协调，不制造下拉越界，也不手动触发刷新。

后台页的滚动回调不改变当前 Header；切页到正在刷新的页面时，沿用普通页面的共享 Header 对齐和位置恢复规则，取消切页则保留原页状态。框架不主动开始或结束刷新，也不管理或取消业务请求。

## 测试与证据

主工具链验证命令：

```sh
# 根目录 Package 库测试。
SP_SCOPE=library Scripts/validate.sh test
# Demo 单元测试和 UI 测试。
SP_SCOPE=demo Scripts/validate.sh test
# Release 库测试允许 @testable 导入。
SP_SCOPE=library SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES
# 指定工具链构建 Demo。
SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/validate.sh build
```

`SP_SCOPE=library` 先以根 Swift Package 的 `StickyPagerKit` scheme 执行 `build-for-testing`，再将同次测试包嵌入 `Tests/UIKitTestHost` 的独立最小应用，通过生成的 `Hosted.xctestrun` 执行 `test-without-building`。测试定义及编译仍由 `Package.swift` 管理，宿主不链接 StickyPagerKit，也不包含 Demo 页面；库测试及其宿主均独立于 Demo 工程。`SP_SCOPE=demo`（默认）使用共享 scheme `StickyPagerDemo`，执行 `test` 时运行 `StickyPagerDemoTests` 和 `StickyPagerDemoUITests`，不包含根目录库测试。两种流程都要求显式核对 `SP_DEVELOPER_DIR` 和 `SP_SIMULATOR_ID`，不修改全局 `xcode-select`。

`StickyPagerDemoTests` 是以 `StickyPagerDemo` 应用为宿主的单元测试 target，适合测试 Demo 自身的逻辑、视图控制器和框架接入行为。需要访问 Demo 的内部类型时，可使用 `@testable import StickyPagerDemo`；涉及 UIKit 的测试需在主 actor 上执行。框架自身的回归测试仍放在根目录 `StickyPagerKitTests`，真实点击、拖动和分页手势使用 `StickyPagerDemoUITests`。

`StickyPagerDemoTests` 使用 Swift Testing 覆盖最小接入的数据源与页面独立性、容器安装与布局、切页和导航过程中的 appearance 回调，以及退出导航后的控制器和视图释放。窗口用例在主 actor 上串行运行，挂载到宿主的真实 `UIWindowScene`，结束时恢复原 key window。库测试、Demo 单元测试与 Demo UI 测试的验证范围应分别报告。

```sh
# 仅运行 Demo 单元测试。
SP_SCOPE=demo Scripts/validate.sh test -only-testing:StickyPagerDemoTests
# Release 下使用 @testable import StickyPagerDemo 需要为应用启用可测试性。
SP_SCOPE=demo SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES -only-testing:StickyPagerDemoTests
```

UIKit 库测试需要真实 `UIApplication` 生命周期。直接在 Xcode 中对裸 Package 执行 Test，或直接运行 SwiftPM 生成的无宿主 `xctest`，不作为本仓库的 UIKit 验收入口：这种进程没有 application，系统 observation 的提交后清理与场景安全区域不能代表 App。新增环境回归会明确拒绝无宿主运行；导航栏安全区域夹具连接宿主的 `UIWindowScene`；窗口夹具在测试方法的挂载步骤显示（异步 `setUp` 只创建），显示后提交布局并推进运行循环，关闭时在窗口仍可见的阶段移除根控制器、完成消失回调，再隐藏窗口。固定宽度算法用例也连接真实 scene，但由 `SPTestWindow` 固定窗口尺寸并将屏幕安全区域设为零，仅通过 `additionalSafeAreaInsets` 注入测试条件；系统导航安全区域使用未覆盖安全区域的原生 UIWindow。库依赖 UIKit，不能以 macOS 为目标执行 `swift test`。

`SP_SCOPE=library Scripts/validate.sh build-for-testing` 也会准备宿主和测试包，保存 `Build.xcresult`、`Hosted.xctestrun` 及独立的 `host-build.log`；完整 `test` 另保存 `Result.xcresult`。冻结的宿主／测试包位于忽略的 `Validation/Products/LibraryHosted/<运行名>/`，运行名应唯一。`-only-testing:` 和 `-skip-testing:` 参数继续生效；Release 库测试仍需 `ENABLE_TESTABILITY=YES`。

验证脚本分别扫描日志中的 `Observation tracking feedback loop detected!` 和 appearance transition 不平衡诊断，以及不兼容 content configuration 引起的整个 Cell 内容视图替换提示，保存 `runtime-diagnostics.json`；即使 XCTest 通过，出现其中任一诊断也返回非零退出码。摘要分别保留 XCTest 结果、`runtimeDiagnostics` 和 `sourceChangedSinceRun`（包含运行后新增、修改及删除的输入文件），不能以“无此诊断”代替测试通过。诊断修复的对照证据见 [验证记录](Validation/README.md)。脚本自身回归使用 `python3 -m unittest discover -s Scripts/Tests -v`。

系统 `UITabBar` 的角标截图和内部标签坐标只作为视觉参照，不对其私有视图副本数量建立测试契约。StickyPagerKit 自身的角标 RTL 方向、内容锚点、文字尺寸、点击和无障碍行为仍由库测试直接断言；图层快照不能替代真实 UI 视觉验收。

Demo 的 `--window-regression` 参数让分页页和标签外观页通过无障碍状态值提供当前 `UIWindowScene` 的实际界面方向，仅供测试诊断。iOS 26+ 同时提供 `interfaceOrientationLocked`（`1` 为场景锁定、`0` 为未锁定、`unknown` 为场景尚不可用），旧系统记录 `unavailable`，不改变方向策略。旋转用例必须等待实际界面方向与目标一致；发送 `XCUIDevice.orientation` 请求或转动 Device Hub 外框不代表旋转已完成。系统容器旋转后的滚动检查按当前可见视口高度计算拖动距离，并保留实际位移断言。真实触摸使用窗口与控件的可见交集，并避开覆盖按钮和浮动工具栏内容；系统工具栏的无障碍容器 frame 可能覆盖整个窗口，不能直接将其上边界当作可触摸区域下边界。各设备的实际通过、失败和未覆盖范围见 [验证记录](Validation/README.md)。

“页面”菜单专项使用 `--window-regression --paging-trace` 记录触摸序号、`pointerScrollEvents` 和 `lastPointerScrollTimestamp`。触摸轨迹只接受 `.touches`，不会把 hover／scroll 携带的区域事件混入触摸样本。触摸专项用例每次只点击一次入口，断言菜单出现、无输入时保持、动作生效，以及取消后的再次打开；收到额外滚轮／触控板输入直接失败，不自动重开菜单、不重试用例、不关闭动画。另设 iPad pointer 用例，验证已送达的滚轮事件不会污染触摸样本；该用例不预设滚轮应当关闭菜单。普通 Demo 不启用这些观测，也不拦截任何事件。

UI 自动化运行期间应由一个执行端独占设备输入；电脑操作和设备交互 MCP 在独立诊断阶段使用，结束交互会话后再启动 XCTest。外部旋转是按下述请求协议串行操作的例外，不能在菜单断言期间滚动设备窗口。若菜单丢失，应同时核对录屏、合成输入记录、App 与 `testmanagerd` 的统一日志；末帧没有菜单不代表入口未响应。CoreDevice 输入通道只能说明事件来源通道，不能单凭它判定具体操作者。

旋转后的系统返回手势使用实际窗口作为坐标锚点，并通过 Demo 现有的触摸记录确认边缘输入确实到达；不能把未收到触摸后的页面不变当作取消返回成功。附件栏高回归保留增长、恢复及页面衔接断言；80 pt 的下界比较仅容纳 `0.000001 pt` 浮点坐标误差，不改变框架的尺寸规则。

对于 `XCUIDevice` 方向事件不能驱动界面、但 Device Hub 的 `Device → Orientation` 菜单可用的环境，可显式使用外部旋转模式。先为目标设备执行 `build-for-testing`（也可用官方 Xcode MCP 的 `BuildProject(buildForTesting: true)`），再运行：

```sh
DEVELOPER_DIR="<实际 Xcode.app 路径>/Contents/Developer" \
python3 Scripts/run_external_rotation.py \
  --xctestrun "<同次构建生成的 .xctestrun 绝对路径>" \
  --device "<模拟器 UUID>" --run-name "<新的验证目录名>"
```

脚本复制 `.xctestrun`，仅在副本的 UI 测试运行器中设置 `SP_UI_EXTERNAL_ROTATION=1`，不修改 scheme 或应用方向策略；可重复传入 `--only-testing Target/Class/testMethod` 缩小范围。电脑操作者须持续读取运行目录的 `rotation-request.json`，根据其中 `orientation`（`1` 竖屏、`2` 倒置竖屏、`3` 左横向、`4` 右横向）操作 **Device → Orientation**，随后将同一请求 JSON 原子写入 `rotation-response.json`。唯一 `id` 防止复用旧确认；120 秒没有确认即失败。脚本只桥接文件，不自行合成系统输入。 使用电脑插件驱动时，Mac 须在整轮测试期间保持解锁；锁屏导致控件无法操作时，不得写入确认，应保留失败／中断证据，解锁后另起运行目录复测。

折叠设备需先按当前屏幕姿态核对菜单与实际场景方向的对应关系，不能直接沿用外屏菜单名称。本机 `24A94232` 运行时的 Duo Open 内屏中，菜单 Landscape Left 对应 App Portrait，Portrait Upside Down 对应 App Landscape Right，Portrait 对应 App Landscape Left；这是该运行时下的同进程实测结果，切换运行时或重启后应重新核实。外部驱动应按请求所需的实际场景方向选择已核验的菜单，并另外记录实际菜单与姿态，原样回写请求，不改动用例的方向预期。

外部确认表示菜单操作完成，或新鲜的 Demo 状态明确显示当前实际场景方向已满足请求；后一种情况须单独记录为无需转向，不能冒充一次实际旋转。Home 画面、历史缓存方向和单纯的窗口宽高不足以走该分支。各旋转用例仍按原超时等待实际场景方向并检查布局、滚动与触摸。外部驱动结果与默认 `XCUIDevice` 路径分别报告，不能将前者通过描述为后者已修复。运行目录保留命令、源码哈希、`rotation-events.jsonl`、日志及 `.xcresult`，结束后仍需执行 `Scripts/summarize_validation.py` 核对终态与 `sourceChangedSinceRun`。

若 Device Hub 的电脑控制读取超时，可先在设备侧栏搜索目标设备名称，选中目标后收起侧栏，再核对方向菜单和实际 App 状态。本机完整设备列表的一次读取耗时约 34.5 秒，筛选 Duo 并收起侧栏后多次读取降到约 0.2～2.8 秒；这是本机诊断观察，不保证适用于其他环境。旋转过渡期间若暂时没有窗口层级，应重新读取确认，不能直接回写完成。正常退出 Device Hub 也可能一并关闭模拟器，应避免在回归中途用退出应用代替读取重试；重启后须重新核对运行时、屏幕姿态和方向映射。具体终态和未覆盖范围以验证记录为准。

脚本默认使用本机 Xcode 26.6 和 iPhone 17 Pro / iOS 26.5 的已知 UDID；其他机器请通过 `SP_DEVELOPER_DIR`、`SP_SIMULATOR_ID` 指定自己的环境。`SP_RUN_NAME` 可指定独立运行目录，每次测试保留工具链、源码 SHA-256、完整日志和 `.xcresult`。生成目录不进入 Git。

最终执行结果及未覆盖范围见 [Validation/README.md](Validation/README.md)。Swift tools 6.3 声明、Swift 6 语言模式、Swift 6.3 编译器通过和 iOS 15 实际运行是不同的验证项。

## 目录

- `Sources/StickyPagerKit`：Container、Interfaces、TabBar、Layout、Internal。
- `Tests/StickyPagerKitTests`：由根目录 Swift Package 管理的纯状态计算及 UIKit 行为测试。
- `Tests/UIKitTestHost`：模拟器库测试专用的最小 UIKit 应用，仅提供 application／scene 生命周期。
- `Examples/StickyPagerDemo`：应用、完整最小接入、Demo 单元测试和 UI 测试工程。
- `Scripts`：可复现验证和结果汇总脚本。
- `Validation`：验证记录与本地产物。

当前首版不包含网络、登录、个人资料模型、嵌套多级分页或 Header 自动测高。Header 高度由接入方显式提供。iOS 15 实际运行、真机、VoiceOver 全流程与性能基准需在相应环境独立验证。
