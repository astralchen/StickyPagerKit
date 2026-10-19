# StickyPagerKit

支持 iOS 15+ 的 UIKit 粘性 Header 与横向分页容器。以 Swift Package Manager 分发，使用 Swift tools 6.3、Swift 6 语言模式和主 actor 隔离，不依赖第三方运行时库。

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

数据源和代理均为弱引用；需要由业务方持有。代理方法具有默认空实现。

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
tabs.standardAppearance.selectionStyle = .capsule
// 需要旧版下划线时：
tabs.standardAppearance.selectionStyle = .underline
tabs.standardAppearance.selectionColor = nil
```

`SPTabBarAppearance.SelectionStyle` 是公开枚举，外部可在运行时切换原来的线条或胶囊，不需要替换标签栏：

```swift
// 两端圆角的线条指示器，默认跟随选中文字颜色
tabs.standardAppearance.selectionStyle = .underline
tabs.standardAppearance.selectionColor = nil

// 胶囊选中背景，默认使用系统填充色
tabs.standardAppearance.selectionStyle = .capsule
tabs.standardAppearance.selectionColor = nil

// 隐藏指示器
tabs.standardAppearance.selectionStyle = .none
```

`selectionColor` 控制指示器背景色，默认为 nil，按样式自动解析：`.underline` 跟随选中文字颜色（Item 文字属性、selected.titleColor、tintColor 依次优先），`.capsule` 使用 `.tertiarySystemFill`。显式设置颜色可独立覆盖，设回 nil 恢复自动颜色；切换样式无需手动换色。线条高度为 3 pt、圆角为 1.5 pt，两端呈胶囊形；分页和选中动画期间仍保留圆角。

```swift
// 单独修改指示器颜色，不影响选中文字和图标
tabs.standardAppearance.selectionColor = .systemOrange
// 恢复样式默认颜色
tabs.standardAppearance.selectionColor = nil
```

默认使用系统材质背景和胶囊选中背景。`.automatic` 在常规垂直尺寸类中上下排列图文，在紧凑垂直尺寸类中左右排列；`.stacked`、`.inline` 可显式指定。纯文字和纯图标项仅布局实际内容。选中标识支持 `.capsule`、`.underline`、`.none`。图标保持比例放入 24 pt 区域，紧凑高度可使用 `landscapeImagePhone`，支持相应 imageInsets；保留基类的大内容图片属性供自定义呈现使用；默认栏已随 Dynamic Type 增高，不额外启用长按大内容查看手势。普通图片保留 renderingMode；默认 SF Symbol 在缩放后仍按模板着色，显式 `.alwaysOriginal` 保留原色。

默认文字和模板图标采用 UITabBar 风格：未选中为 `.secondaryLabel`，选中跟随标签栏的 `tintColor`（包括从父视图继承的颜色），禁用为 `.tertiaryLabel`。显式状态颜色优先；`titleColor`、`iconColor` 设为 nil 时恢复该状态的默认颜色。运行时改变 tint 会立即刷新可见标签，不改变滚动位置和选中动画。深浅色使用动态颜色解析。

标签宽度按正常、选中、禁用状态的最大内容尺寸预留，避免选择时字体变化导致跳动。最长项能容纳时均分宽度，否则按固有宽度分配剩余空间；超出一屏则横向滚动。点击区域最小 44 pt；选中项尽量居中，首尾受内容边界限制。布局和字体变化重新对齐，普通刷新保留用户手动滚动位置。RTL 仅反转视觉顺序，逻辑索引不变。

背景铺满容器，内部 Collection View、点击区域和选中背景共用左右安全视口。超出视口的内容在仍有隐藏项的一侧使用 16 pt 渐隐；材质背景不参与渐隐。`tabBarHeight` 是最小高度（0 隐藏），实际高度由图文和 Dynamic Type 字体测量；变化后容器更新页面边界并保留滚动位置。独立宿主应在布局时使用 `sizeThatFits(_:)`。降低透明度时改用不透明系统背景，减少动态效果时关闭程序化选中动画。角标、选中和禁用状态同步无障碍信息。

分页和非相邻选择继续共享选中标识与居中偏移的连续进度；连续点击从当前位置接续。按住标签按钮后横向拖动时允许 Collection View 接管手势。自定义栏可重写 `setItems(_:)`、`setSelectedItem(_:animated:)` 和 `setTransitionProgress(from:to:progress:)`，调用 super 保持模型同步，使用 `requestSelection(of:)` 发送用户请求。通过 `pager.tabBar = CustomTabBar()` 替换。

迁移旧代码：将 `onSelect` 替换为 `SPTabBarDelegate`；自定义点击调用 `requestSelection(of:)`；持有并修改 Item 对象，避免复制结构体的假设；读取 title 时处理 nil。Demo 启动页的“标签外观”提供独立标签栏，分页 Demo 的“页面”菜单可切换图文、角标、禁用和选中样式。首版未提供 scrollEdgeAppearance、More 导航或系统编辑排序。NSCoding 保存 Item 的基类属性、自定义图片、角标与 Appearance；Appearance 的复制和安全归档保留背景、选中标识、布局和状态样式。

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
