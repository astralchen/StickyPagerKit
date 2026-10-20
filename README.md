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

系统容器场景把状态移到导航栏并隐藏原有底部工具栏，便于观察系统 Tab Bar 的安全区域贡献。Header 背景及子页面根视图仍延伸到容器边界，组件标签栏在顶部安全区域下缘吸顶；列表保留 UIKit 自动 `adjustedContentInset` 和滚动指示器安全区域处理，不手动叠加系统栏高度。iPad 的系统 Tab Bar 可按系统规则位于顶部，布局以实际安全区域为准。「页面」菜单仍可切换 Header 类型、高度和页面配置。

- 网格、长列表、短列表、空列表、普通页面和可动态创建滚动视图的异步页面。
- “收藏”与“更多专题与活动”之间的“组合布局”标签使用 `UICollectionViewCompositionalLayout`：包含 `.continuous`、`.groupPaging` 横向 Section 和 30 项纵向内容；也可从“页面 → 组合布局 · 嵌套滚动”直接进入。
- 导航栏 `Header` 切换 UIView / UIViewController，`高度` 切换 220 / 300。
- `页面` 菜单可重排、删除、添加或清空页面。
- 列表原生下拉刷新，底部状态显示当前页、Header 类型和高度。
- 返回上一级可检查系统交互式返回；启动参数 `--rtl` 可切换 Demo 到 RTL。
- 嵌套横向 Section 尚有可滚动空间时优先处理内部滚动；到达起点／终点后，下一次向外横滑切换相邻标签。手势归属在开始时判定，一次从内部开始的拖动不会在中途突然转为分页；容器也已到首尾时保留内部弹性滚动。
- 启动参数 `--open-demo --compositional` 可直接打开组合布局页。横向卡片用于检查 Section 内部滚动及两端边界，纵向内容区域用于检查 Header 联动和容器横向分页。`CompositionalGestureTests` 通过真实触摸、内部布局偏移及分页轨迹验证这些行为。

工程由 XcodeBuildMCP 创建，使用 Xcode 文件系统同步分组。`StickyPagerDemo` 和 `StickyPagerDemoUITests` 对应真实文件夹，新增源码会自动加入对应 target，无需重新生成工程。Demo 工程只包含应用和 UI 测试两个 target，应用通过本地 Package 依赖链接 `StickyPagerKit`。库测试位于根目录 `Tests/StickyPagerKitTests`，完全由根目录 `Package.swift` 管理，不再加入 Demo 工程或 Demo 的测试 scheme。构建配置位于 Demo 的 `Config` 目录。

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

布局以 `.item` 或 `.content` 为参考区域，支持 leading/center/trailing、top/center/bottom、独立可选宽高、水平/垂直内缩及物理偏移。nil 宽高填充内缩后的区域，固定宽高默认可超出参考区域；`limitsSizeToReference` 可显式限制到参考区域。leading/trailing 跟随 RTL，`offset.x` 始终按物理方向计算。负尺寸归零、非有限尺寸使用参考尺寸、非有限内缩/偏移使用 0；标量限制到 ±1,000,000 pt。`cornerRadius = nil` 使用高度的一半，显式值限制到宽高较小值的一半。

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

指示器是装饰，不参与标签宽度、栏高或点击区域测量；需要预留空间时，在标签内容中提供留白，并用 `SPPageLayout.tabBarHeight` 或独立宿主栏高保证空间。允许超出单项，但始终随内容滚动并裁剪到标签栏安全视口，不能跨到 Header 或页面上。前景/背景层都不拦截触摸，也不增加无障碍焦点。

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

有 n 个 Item 时，总间距为 `max(0, n - 1) × itemSpacing`。先从视口扣除总间距，再按现有策略分配 Item 宽度；超出视口时，滚动内容宽度为 Item 宽度之和加总间距。自动内容按扣除间距后实际分配的宽度计算高度；空列表和单项不产生额外间距。间隙不属于任意 Item 的点击区域，也不增加无障碍元素。

运行时修改间距无需重设 Items，保留对象身份、当前选择和选择回调语义。几何变化时，手动偏移限制到新滚动范围，程序动画落到当前选中项，分页交互保持进度并重算端点；归一化后的间距未变化时不触发刷新。居中、边缘渐隐和指示器均跟随最终布局，`.none` 下滚动动画照常工作。Demo 的“页面”及“标签外观 → 配置”中均可通过“标签间距”选择 0、8、16、24 pt。

背景铺满容器，内部 Collection View、点击区域和指示器共用左右安全视口。超出视口的内容在仍有隐藏项的一侧使用 16 pt 渐隐；材质背景不参与渐隐。`tabBarHeight` 是最小高度（0 隐藏），实际高度由图文和 Dynamic Type 字体测量；变化后容器更新页面边界并保留滚动位置。独立宿主应在布局时使用 `sizeThatFits(_:)`。降低透明度时改用不透明系统背景，减少动态效果时关闭程序化选中动画。角标、选中和禁用状态同步无障碍信息。

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

- `context` 提供当前 `UICellConfigurationState`、tintColor、视觉方向、扣除左右安全区域后的视口宽度，以及当前生效 Appearance 的独立副本。尚未布局时宽度可能为 0。业务决定如何使用 Item 和 Appearance；框架不会把默认样式强加给自定义内容。
- `SPTabBarContent(configuration:)` 默认自动测量，`size == nil`。框架用独立的内容视图调用 `systemLayoutSizeFitting`：先以压缩目标求首选宽度，再由普通 Auto Layout 测量宿主以水平优先级 999 尝试视口内的首选宽度（未知视口时使用内容首选宽度）；业务 required 最小宽度可以超出视口。然后由布局应用 `minimumItemWidth`，先满足较宽项、再让较窄项尽量等宽，以水平 `.required`、垂直 `.fittingSizeLevel` 定宽求高度。所有 Cell 高度取各项所需高度的最大值，并受容器最低栏高约束；`tabBarHeight == 0` 仍隐藏标签栏。
- 自定义视图需要完整的内部 Auto Layout 约束或能参与求解的 `intrinsicContentSize`。例如多行 UILabel 应连接内容视图四边，框架不额外添加业务内边距。`targetSize` 本身不是最大尺寸；普通 UIView 只重写 `sizeThatFits` 也不代表它一定参与 Auto Layout 测量。手动布局视图可继续提供显式尺寸，或自行实现 `systemLayoutSizeFitting`。
- 仍可使用 `SPTabBarContent(configuration: configuration, size: CGSize(width: 160, height: 76))` 跳过自动测量；它是理想尺寸覆盖，最终宽度可能由标签栏扩展。`size` 现在为 `CGSize?`，旧的显式尺寸初始化调用保持可用，读取属性的代码需要处理 nil；赋值 nil 可恢复自动测量。显式尺寸和自动测量结果必须为有限正数且不超过 1,000,000 pt，否则该项回退到默认内容；理想尺寸不再混入 Cell 最小宽度，高度不额外设下限（自动测量尺寸向上取整到 pt）。显式尺寸不限制到视口；自动测量可能压缩可换行内容。
- `SPPageLayout.tabBarHeight` 是最小栏高，默认 44，设为 0 时隐藏。正值时实际栏高为 `max(tabBarHeight, 内容所需高度)`，不是固定高度。例如自定义内容需要 28 pt 时，配置 32 / 60 / 44，实际栏高分别为 32 / 60 / 44；内容需要 80 pt 时，这三个配置都得到 80。默认图文及回退项保留自身至少 44 pt 的规则，因此混用时仍可能把整栏撑高。宽度由标签栏自身的 `minimumItemWidth`、`itemSpacing` 和分配规则控制，不由 `SPPageLayout` 控制。
- `SPTabBar.minimumItemWidth` 默认 44 pt，同时作用于默认、自定义及回退项。0 表示不额外设下限，负数归零，非有限值恢复为 44，超过 1,000,000 pt 截到该上限。它是 Cell 最小布局宽度，不改变业务返回的理想尺寸，也不扩大 Cell 外的命中区域。较小的宽度或栏高属于业务主动选择的紧凑交互，不能据此认为仍有 44 × 44 pt 点击区域。
- 宽度分配连续：320 pt 视口中，理想宽度 `[160, 44]` 得到 `[160, 160]`，变成 `[161, 44]` 后得到 `[161, 159]`，不会再跳到 `[218.5, 101.5]`。这是对原“固有宽度加平均剩余空间”策略的行为调整。减少最小宽度不会关闭剩余空间分配，两个短标签仍可能等宽填满整栏。
- 内容根视图须允许随实际分配宽度扩展。内部可设置 required 的最小宽度，超出视口时横向滚动；根视图的 required 固定宽度、自身矛盾的 required 约束不受支持。有限正数检查不负责诊断业务约束冲突。自动内容在实际分配宽度下重新测高，业务自定义内边距由内容视图负责。
- 未设置代理、代理释放后下一次标签栏布局、返回 nil 或尺寸无效时，对应项回退到默认内容。允许同一栏混用默认项和自定义项。
- 内容和尺寸会缓存。Item、选择、Appearance、tint、traits、可用宽度、RTL 或模式变化会重新获取配置；业务自有数据变化需调用 `reloadContent()`。提供方法应同步、无副作用，不得在其中修改标签栏或 Item、触发布局或重载。自动测量由框架构造独立视图；不要在代理回调中自行构造或缓存正在显示的视图。状态样式宜保持约束尺寸稳定，或为显式尺寸取各状态最大值。
- `reloadContent()` 不发送选择回调。尺寸不变时保留手动滚动偏移、正在进行的选择动画和分页进度；尺寸变化时将手动偏移限制到新的可滚动范围，选择动画落到已选项，分页则按相同逻辑进度在新布局中重新定位。`.default` 下调用此方法或设置 `contentDelegate` 不改变当前显示和交互。弱引用释放不会主动触发布局，需要立即回退时可显式清空代理或请求标签栏布局。
- `sizeThatFits(_:)` 只测量建议宽度对应的高度，不提交配置、不改变当前 Cell 布局、偏移或指示器。实际布局时才采用实际视口的配置与尺寸。显示快照与最近一次候选测量分开缓存，重复询问相同宽度不会反复调用代理或构造测量视图；候选宽度变化仍可能触发代理，所以回调不能假定标签栏已经改变 frame。
- 测量视图处于隐藏、无交互和无障碍入口的独立宿主中，继承标签栏 traits、tint 和视觉方向，完成测量后移除；不会借用正在显示的 Cell。`makeContentView()` 和配置更新可能用于测量，不能依赖可见性或触发业务副作用。配置需独立描述完整内容。业务异步数据变化后调用 `reloadContent()`；仅在某个显示视图上调用 `invalidateIntrinsicContentSize()` 不会自动清除标签栏缓存。
- 自定义配置的 `updated(for:)` 接收 `UICellConfigurationState`，其中包含选中、禁用和真实按压高亮。高亮变化仅更新内容配置，不重新询问尺寸。提供方法的 `context.state` 高亮为 false；框架只保证 traits、选中、禁用和运行时按压高亮，不承诺同步 Cell 的焦点、编辑或多选状态。`UIContentView.configuration` 应覆盖旧状态并复用子视图；更换不兼容配置类型时框架会替换内容视图。iOS 16+ 使用 `supports(_:)` 判断兼容性，iOS 15 按配置类型判断。
- 每个标签保留一个由框架管理的整项点击和无障碍入口。自定义视图内部控件不参与命中测试或独立无障碍导航；如需标签内的独立按钮，当前接口不提供该交互模型。点击否决、禁用、程序化选择和分页手势的回调语义均沿用原规则。
- `SPTabBarContent.accessibilityLabel`、`accessibilityHint`、`accessibilityValue` 可覆盖描述；nil 沿用 Item 标题／描述与角标值。选中和禁用 traits 由框架维护，避免重复暴露内部标签。

完整自定义视图示例见 [CustomTabContent.swift](Examples/StickyPagerDemo/StickyPagerDemo/CustomTabContent.swift)：编号、标题、副标题组成卡片，演示按压、选中、禁用、Dynamic Type 与 RTL。Demo 首页“标签外观”→“配置”→“自定义卡片”，或分页 Demo“页面”→“切换自定义标签”即可查看；`--open-demo --custom-tabs` 可直接启动。Demo 的卡片内部使用 Auto Layout 和 UILabel 固有尺寸，不再手算文字宽高。“页面”→“切换多行副标题”演示内容自动换行、栏高增长与恢复；“刷新自定义内容”演示同尺寸更新后保持手动滚动位置。“切换紧凑标签”使用仅含 UILabel 的 `UIContentView`，通过字体固有尺寸和内边距约束自动测量；“标签栏最小高度”菜单可选择 32、60、隐藏或默认 44，演示紧凑内容低于 44 和隐藏后恢复。该菜单不限制大字号所需高度。“页面”→“标签宽度”提供紧凑编号内容、24／44／120 最小项宽，以及首项内部 required 最小宽度 480 pt 的示例；后者可以超出视口并横向滚动。

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

所有内容页的根视图始终紧接当前标签栏底部，底边固定在容器底边。令当前 Header 折叠量为 `c`，根视图在分页视口内下移 `C - c`，框架为主要滚动视图添加 `c` 的顶部 inset；两者合计承担完整折叠距离。更新页面尺寸和 inset 时保留归一化位移 `q`，因此 Header 折叠过程中正文保持在滚动视口顶部，完全折叠后再滚动正文。短内容按当前滚动视口高度加上剩余折叠距离计算底部补齐量，保证 UIKit 的实际可滚动范围足以折叠 Header，不修改业务 contentSize。

根视图为普通 `UIView` 且 `UILabel` 与 `UIScrollView` 同级时，Label 可约束到根视图的 `safeAreaLayoutGuide.topAnchor`，滚动视图可约束在 Label 下方；也支持滚动视图铺满根视图。框架不修改业务子视图约束，不需要业务重复添加 Header 高度或监听折叠进度来移动 Label。页面高度随 Header 折叠连续变化，内部布局应响应 bounds 变化；固定 frame 不随父视图变化的子视图仍由业务负责更新。

展开时 Header 从容器 `y = 0` 开始，标签栏紧接 Header；折叠后标签栏位于 `S + minimumHeaderHeight`。旋转或安全区域变化会重新计算 `C`，保留已吸顶状态和页面内容滚动位置。嵌入其他控制器时，应把容器约束到父视图边界；若约束到父视图安全区域，Header 只能从该容器顶边开始。

Header 内部由禁用用户滚动的 `UIScrollView` 承载，其 `contentOffset` 由共享折叠逻辑驱动，并通过 `setContentScrollView(_:for: .top)` 关联导航栏。iOS 26+ 使用 `topEdgeEffect.style = .soft`，在导航栏后方提供系统渐变模糊效果；Header 的 UIView / UIViewController 接入方式不变。

在导航容器内展示全屏 Header 时，宿主需允许根视图向顶部延伸。iOS 26+ 保留系统导航栏外观即可，避免透明 `UIBarAppearance` 定制干扰原生效果；旧系统可配置当前页面的透明导航外观，并按需求处理 Header 前景内容在导航栏下方的裁剪。Demo 已实现这两条路径，框架不修改业务导航栏外观。

`viewControllerAt` 返回的内容页根视图铺满容器宽度并延伸至容器底边，不扣除左右及底部 Safe Area；容器全屏显示时即与屏幕左右边界和底边对齐，嵌入较窄的父容器时以实际容器宽度为准。Header 展开、折叠及切页时保持这些边界。横向分页步长随容器宽度更新。页面背景可铺满根视图，普通页面的文字和按钮应使用 `safeAreaLayoutGuide` 避让安全区域，滚动内容按 UIKit 的 `adjustedContentInset` 及业务指定的 inset 调整策略避让。框架保留业务配置；使用 `.never` 的页面需自行处理安全区域。

使用 `UICollectionViewFlowLayout` 的网格页还需让 Cell 布局遵循安全区域。Demo 将 `sectionInsetReference` 设为 `.fromSafeArea`，并按同一边界扣除 section 间距和列间距后计算三列宽度；在布局和安全区域变化时更新尺寸。仅保证 Collection View 根视图全宽，或直接用其 `bounds.width` 计算 Cell 宽度，并不能保证 Cell 内容避开横屏安全区域。

框架只持有自己添加的 inset 增量，解绑时移除并恢复原有纵向回弹配置。业务需要更新 inset 时，赋值完整的业务基准值，框架随后重新叠加自身贡献；不要将读取到的、已经含框架贡献的 inset 再作为新基准写回。

纵向滚动指示器随页面视口位于标签栏下方，不再重复添加 Header 避让距离；保留业务 `verticalScrollIndicatorInsets`、横向指示器配置及 UIKit 的自动安全区域调整。短列表、空列表若只有 Header 折叠范围而没有正文滚动范围，则暂时隐藏纵向指示器，避免顶部折叠 inset 与底部补齐 inset 产生误导性的长条。内容或视口尺寸变化后，框架按业务 `showsVerticalScrollIndicator` 设置恢复显示；解绑时恢复最新的业务设置。更新指示器 inset 时同样应赋值完整的业务基准值。

横向分页拖动、减速和程序化切页动画期间，子页面的横向、纵向滚动指示器均暂时隐藏，包括途中加载或重新绑定的页面。切页完成或取消后恢复业务设置，短列表和空列表仍遵循上述纵向指示器规则。

原本已隐藏的指示器不重复写入显隐属性，也不更新隐藏的纵向指示器轨道；仅在需要显示时计算其边距。

列表原生拖动保留 UIKit 的减速和回弹。Header / 标签栏纵向拖动由框架 pan 识别器驱动同一坐标，使用 display link 完成惯性及边界回弹。Header 内按钮、输入控件和独立手势区域优先处理自身操作。

一次 Header 拖动只由开始该次交互的识别器驱动，其他识别器不能改写位置或提前结束交互。替换标签栏、切页、重新绑定或布局变化会使旧拖动失效，后续新拖动可以重新开始。

### 页面切换与更新

- 切页保留共享 Header 折叠量。完全折叠时恢复目标页内容位置；部分展开时目标页对齐共享 Header，不显示与 Header 冲突的历史深层内容。
- 开始切页时终止旧页减速；旧页观察回调不能改变当前 Header。
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

在内容滚动视图上安装 `UIRefreshControl`，正常监听 `.valueChanged`，完成后调用 `endRefreshing()`。先展开 Header，再由列表的原生下拉触发刷新；刷新期间 Header 保持展开。Header 区域的拖动不手动触发刷新。各页自行持有刷新任务，切到其他页面不取消后台业务请求。

只有已选中的刷新页会展开共享 Header；后台刷新页参与布局或作为切页候选时不改变当前 Header。取消该次切页保留原页折叠状态，提交到刷新页后再展开。

## 测试与证据

主工具链验证命令：

```sh
SP_SCOPE=library Scripts/validate.sh test
SP_SCOPE=demo Scripts/validate.sh test
SP_SCOPE=library SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES
SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/validate.sh build
```

`SP_SCOPE=library` 在仓库根目录运行 Swift Package 的 `StickyPagerKit` scheme；`SP_SCOPE=demo`（默认）运行 Demo 的应用及 UI 测试 scheme。在 Xcode 中单独打开根目录 `Package.swift`，选择 `StickyPagerKit` scheme 和 iOS 模拟器，也可运行库测试。库依赖 UIKit，不能以 macOS 为目标直接执行 `swift test`。

脚本默认使用本机 Xcode 26.6 和 iPhone 17 Pro / iOS 26.5 的已知 UDID；其他机器请通过 `SP_DEVELOPER_DIR`、`SP_SIMULATOR_ID` 指定自己的环境。`SP_RUN_NAME` 可指定独立运行目录，每次测试保留工具链、源码 SHA-256、完整日志和 `.xcresult`。生成目录不进入 Git。

最终执行结果及未覆盖范围见 [Validation/README.md](Validation/README.md)。Swift tools 6.3 声明、Swift 6 语言模式、Swift 6.3 编译器通过和 iOS 15 实际运行是不同的验证项。

## 目录

- `Sources/StickyPagerKit`：Container、Interfaces、TabBar、Layout、Internal。
- `Tests/StickyPagerKitTests`：由根目录 Swift Package 管理的纯状态计算及 UIKit 行为测试。
- `Examples/StickyPagerDemo`：应用、完整最小接入和 UI 测试工程。
- `Scripts`：可复现验证和结果汇总脚本。
- `Validation`：验证记录与本地产物。

当前首版不包含网络、登录、个人资料模型、嵌套多级分页或 Header 自动测高。Header 高度由接入方显式提供。iOS 15 实际运行、真机、VoiceOver 全流程与性能基准需在相应环境独立验证。
