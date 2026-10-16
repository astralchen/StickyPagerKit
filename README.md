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
- 导航栏 `Header` 切换 UIView / UIViewController，`高度` 切换 220 / 300。
- `页面` 菜单可重排、删除、添加或清空页面。
- 列表原生下拉刷新，底部状态显示当前页、Header 类型和高度。
- 返回上一级可检查系统交互式返回；启动参数 `--rtl` 可切换 Demo 到 RTL。

工程由 XcodeBuildMCP 创建，使用 Xcode 文件系统同步分组。`StickyPagerDemo` 和 `StickyPagerDemoUITests` 对应真实文件夹，新增源码会自动加入对应 target，无需重新生成工程。Demo 工程只包含应用和 UI 测试两个 target，应用通过本地 Package 依赖链接 `StickyPagerKit`。库测试位于根目录 `Tests/StickyPagerKitTests`，完全由根目录 `Package.swift` 管理，不再加入 Demo 工程或 Demo 的测试 scheme。构建配置位于 Demo 的 `Config` 目录。

## 公开接口

| 接口 | 用途 |
| --- | --- |
| `SPPageViewController` | 容器入口，可直接使用或继承 |
| `SPPageViewControllerDataSource` | 页面数量、唯一稳定标识、控制器和标签数据 |
| `SPPageViewControllerDelegate` | 完成选中、连续分页进度、Header 状态与进度 |
| `SPPageLayout` | Header 总高度、保留高度、标签栏高度 |
| `SPHeaderState` | `expanded`、`collapsing`、`collapsed` |
| `SPTabBar` / `SPTabBarItem` | 默认标签栏与标签标题 |

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

### 自定义标签栏

非相邻选择时，标签栏居中偏移与指示器位置由同一帧进度驱动；相邻动画和手势翻页时，两者跟随分页进度，切页结束后不再补一段居中滚动。连续选择从当前动画位置继续；用户手动拖动标签栏时停止自动动画，尺寸、字体、方向或数据变化时结束旧动画并按新布局对齐。按住标签按钮后再横向移动时，标签栏允许取消按钮的触摸跟踪并接管滚动；单击仍正常选择页面。

默认 `SPTabBar` 使用 `UICollectionView` 和自定义 Layout：先按每个标题的实际宽度加左右各 16 pt 计算固有宽度；只有最长标题也能放入均分项时才均分可用宽度；总宽度能放下但不能等宽时，保留各项固有宽度并均摊剩余空间；超出一屏时保留各自固有宽度并横向滚动。空标题等较窄项的最小点击宽度为 44 pt。选中项尽量滚动到中央，首尾受内容边界限制，不添加额外留白。旋转、容器尺寸和 Dynamic Type 变化后重新计算宽度并对齐选中项；普通布局刷新保留用户手动滚动的位置。RTL 反转视觉顺序，逻辑索引保持不变。Cell 在创建及显示前同步当前状态，保留 `sp.tab.<index>` 按钮无障碍标识和选中态，分页过渡指示器使用 Layout 几何信息，支持屏幕外目标。

标签栏背景铺满容器宽度，内部 Collection View 仅占左右安全区域，文字、指示器和点击区域共用这一视口；两侧背景不接收标签栏触摸。滚动内容在仍有隐藏标签的一侧使用 16 pt 渐隐，接近首尾时逐步恢复不透明；到达端点或内容无需滚动时，首尾标题保持清晰。渐隐跟随物理滚动边界，不改变点击范围。安全区域变化时重新对齐选中项，RTL 仅改变内容顺序，不交换物理左右 inset。`tabBarHeight` 是最小高度（0 隐藏），默认标签栏通过 `sizeThatFits(_:)` 为大字体提供单行文字、上下留白和底部指示器所需高度；容器同步调整页面边界。独立使用 `SPTabBar` 时，宿主需采用该测量高度。自定义标签栏同样收到全宽 frame，应自行遵循安全区域，可重写 `sizeThatFits(_:)` 提供高度。

默认标签栏在数据缩减使原索引失效，或直接收到越界选中索引时清空选中态；`SPPageViewController` 仍按原有页面快照规则决定最终选中页。

继承 `SPTabBar`，重写 `setItems(_:)`、`setSelectedIndex(_:animated:)` 和 `setTransitionProgress(from:to:progress:)`。自定义视图收到用户选择后调用 `onSelect?(index)`。通过 `pager.tabBar = CustomTabBar()` 替换。逻辑索引与数据源一致，RTL 仅改变视觉页序。

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
