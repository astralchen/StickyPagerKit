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

- `headerView` / `headerViewController`：互斥，设置新内容替换旧内容。设置当前入口为 nil 清空 Header；无 Header 时有效 Header 高度为 0。
- `layout`：默认高度为 0、0、44；负数和非有限数归一化，保留高度不超过总高度。
- `minimumHeaderHeight`：Header 完全折叠后仍显示的高度。默认 `0`，标签栏停在容器顶部安全区域边缘（导航容器内即导航栏下方）；只有需要保留部分 Header 时才设置非零值。Demo 和快速接入示例使用 `0`。
- `selectedIndex`：只读；无页面时为 nil。
- `setSelectedIndex(_:animated:)`：越界请求忽略，快速连续请求以最后目标为准。
- `isPagingEnabled`：控制横向滑动，标签点击和程序化切页仍然可用。
- `maximumCachedPageCount`：默认 3，最小有效值为 1；转场期间保护当前页、目标页及最多两个可见中间页，允许暂时超过限制。
- `reloadData()`：同步读取完整快照，稳定标识相同则复用已有控制器。
- `setScrollView(_:forPageAt:)`：指定页面视图树内的滚动视图；nil 恢复自动发现。
- `rediscoverScrollView(forPageAt:)`：内容页异步创建或替换滚动视图后调用。

### 自定义标签栏

继承 `SPTabBar`，重写 `setItems(_:)`、`setSelectedIndex(_:animated:)` 和 `setTransitionProgress(from:to:progress:)`。自定义视图收到用户选择后调用 `onSelect?(index)`。通过 `pager.tabBar = CustomTabBar()` 替换。逻辑索引与数据源一致，RTL 仅改变视觉页序。

### 滚动坐标与布局

令 Header 折叠范围 `C = headerHeight - minimumHeaderHeight`，当前页归一化位移 `q = contentOffset.y + adjustedContentInset.top`：

- `Header 折叠量 = clamp(q, 0...C)`。
- `内容位移 = max(0, q - C)`。
- 向上先消耗 Header 距离，再滚动内容；向下先回到内容顶部，再展开 Header。
- 负位移为列表自身回弹，Header 不额外拉伸。

页面视口固定在折叠后标签栏下方，框架添加 `C` 的顶部 inset，Header 与标签栏覆盖预留区域。页面内部应以自身 bounds 布局列表，避免再次加入同一 Header 占位。业务自有 inset 和 Safe Area 调整保留；短内容额外补足可折叠范围，不修改业务 contentSize。

`viewControllerAt` 返回的内容页根视图延伸至容器底边，不扣除底部 Safe Area；容器全屏显示时即与屏幕底边对齐。Header 展开、折叠及切页时保持这一底部边界。滚动内容通过 UIKit 的 `adjustedContentInset` 避开底部安全区域及系统栏，普通页面可用 `safeAreaLayoutGuide` 布局需避让的控件；框架保留业务指定的 inset 调整策略。

框架只持有自己添加的 inset 增量，解绑时移除并恢复原有纵向回弹配置。业务需要更新 inset 时，赋值完整的业务基准值，框架随后重新叠加自身贡献；不要将读取到的、已经含框架贡献的 inset 再作为新基准写回。

列表原生拖动保留 UIKit 的减速和回弹。Header / 标签栏纵向拖动由框架 pan 识别器驱动同一坐标，使用 display link 完成惯性及边界回弹。Header 内按钮、输入控件和独立手势区域优先处理自身操作。

### 页面切换与更新

- 切页保留共享 Header 折叠量。完全折叠时恢复目标页内容位置；部分展开时目标页对齐共享 Header，不显示与 Header 冲突的历史深层内容。
- 开始切页时终止旧页减速；旧页观察回调不能改变当前 Header。
- 重排保留选中标识。删除当前页时选择原索引的新页面，越界则选择最后一页；零页面清空选中状态。
- 重复标识拒绝整次 reload，并打印调试诊断；旧快照保持不变。
- 缓存淘汰解除观察并释放控制器，保留轻量内容位置。再次访问向数据源重新请求控制器。
- 相同标识的 reload 不重新创建控制器；业务内容刷新由页面控制器负责。删除标识会清除对应状态。
- Header 高度变化保留并钳制折叠距离；仍完全折叠时保留内容位移。尺寸变化取消未完成转场并对齐已选页面。

### 自动发现和复杂页面

检查根视图并递归遍历子视图，排除隐藏、透明、不可交互、禁用滚动的子树；优先具有纵向滚动证据的候选，其次是短列表及空列表，排除明显只横向滚动的视图。同级候选按可见面积和遍历顺序排序。

复杂页面应显式指定一个主要纵向滚动视图，框架不同时协调同页多个独立纵向列表。框架保留业务 `UIScrollViewDelegate` 和原有手势 delegate。没有滚动视图的页面保持 Header 状态，不额外包装滚动容器。

### 下拉刷新

在内容滚动视图上安装 `UIRefreshControl`，正常监听 `.valueChanged`，完成后调用 `endRefreshing()`。先展开 Header，再由列表的原生下拉触发刷新；刷新期间 Header 保持展开。Header 区域的拖动不手动触发刷新。各页自行持有刷新任务，切到其他页面不取消后台业务请求。

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
