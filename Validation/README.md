# StickyPagerKit 验证记录

验证日期：2026-10-15。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

## 自适应标签宽度

标签固有宽度改为当前 Dynamic Type 字体下的标题测量宽度向上取整，加左右各 16 pt。固有宽度总和不超过容器宽度时均分；超出时使用各项固有宽度。布局缓存按视觉顺序排列的几何信息，并按边界二分检索可见项；RTL 反转逻辑索引映射，标题对应的宽度保持不变。标签栏未指定语义方向时显式采用容器方向，显式指定方向时保留自身设置。

居中偏移和指示器直接使用每项实际 frame；指示器位置、宽度和标签栏偏移继续由同一动画进度或分页进度更新。保留首尾偏移钳制、手动拖动接管、连续选择中断、尺寸及字体变化后的重新对齐。Demo 保留 12 个长短不同的标题，UI 测试显式滚动至屏幕外标签后点击。

- 新增库覆盖：逐项标题宽度与 RTL 镜像、可见区域边界查询、尺寸变化跨越均分阈值、不同宽度指示器与偏移同步、手势接管及取消。旧居中断言改用屏幕像素容差，避免把 UIScrollView 的像素对齐误判为布局错误。
- UI 覆盖：短标题与长标题的跨项居中，以及 RTL 下的远距离选择；继续执行现有分页、吸顶、刷新、旋转和手势回归。新增远距离 RTL 检查发现了内容页 RTL 与标签栏方向不一致的问题，现已修正并补充方向继承库测试。UI 查找屏幕外标签采用小幅拖动，避免快速 swipe 惯性反复越过短标签。
- **通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 **53 项库测试 + 13 项 UI 测试 = 66 通过、0 失败、0 跳过**。两份终态结果已读取，28 个输入文件的源码快照相同且与最终文件匹配，`sourceChangedSinceRun` 均为空；`git diff --check` 通过。Demo 已重新构建并打开。
  - [最终库结果](Results/adaptive-tabs-accepted-library/Result.xcresult) · [库结果摘要](Results/adaptive-tabs-accepted-library/summary.json)
  - [最终 UI 结果](Results/adaptive-tabs-accepted-ui/Result.xcresult) · [UI 结果摘要](Results/adaptive-tabs-accepted-ui/summary.json)
- `adaptive-tabs-library` 和 `adaptive-tabs-final-*` 保留为修正像素容差、方向继承及自动化定位前的中间证据，不代表最终结果。
- **未执行：** Release、iPad、iOS 15 实际运行、真机、VoiceOver 全流程和性能基准。下方为历史源码结果。

## 非相邻直达与标签动画同步

非相邻的标签点击及程序化选择直接设置内容页偏移，不创建或滚过中间页，不产生中间页滚动进度。目标页立即完成选中回调和 appearance；相邻选择与手势翻页继续沿用连续分页。`animated: false` 同时关闭内容页与标签栏动画。

默认标签栏以同一个 CADisplayLink 进度更新指示器和居中偏移；相邻分页及手势过渡由分页进度同步驱动两者。新的选择从当前动画位置继续，手动拖动停止自动动画；布局、字体、方向、数据变化或移出窗口会终止旧动画，重新挂载时对齐当前选择。动画目标弱引用标签栏，移出窗口和释放时停止 displayLink。

- **行为契约变化：** 非相邻选择立即提交，因此连续请求中已经直达的目标会各自发送一次选中回调；仅尚未完成的相邻转场可以取消。旧的“长距离滚过中间页”测试已替换为验证目标直接可见、只创建起点与终点、无中间进度、回调与生命周期次数、Header 偏移、缓存边界和 RTL 几何的测试。
- **新增覆盖：** 在真实 UIWindow 中采样动画起点、中点和终点，断言指示器与实际 contentOffset 同步；覆盖连续选择重定向、相邻分页接管未完成标签动画时的连续性、分页进度及取消、手动拖动接管、尺寸变化、清空数据、移出后重新挂载及对象释放。新增 UI 用例验证吸顶状态下非相邻切换后继续左右手势翻页。
- **通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 **49 项库测试 + 13 项 UI 测试 = 62 通过、0 失败、0 跳过**。两份终态结果已读取，28 个输入文件的源码哈希快照完全一致且与最终文件匹配，`sourceChangedSinceRun` 均为空；`git diff --check` 通过。
  - [最终库结果](Results/direct-switch-accepted-library/Result.xcresult) · [库结果摘要](Results/direct-switch-accepted-library/summary.json)
  - [最终 UI 结果](Results/direct-switch-accepted-ui/Result.xcresult) · [UI 结果摘要](Results/direct-switch-accepted-ui/summary.json)
- 验证期间补齐了移出窗口后重新挂载的对齐，以及相邻分页接管未完成标签动画时的位置连续性。`direct-switch-final-*` 和 `direct-switch-verified-*` 为中间源码结果，最终验收使用上述 `direct-switch-accepted-*`。
- **未执行：** Release、iPad、iOS 15 实际运行、真机、VoiceOver 全流程和性能基准。下方记录均为此前源码的历史结果。

## 提交前复查：同步预取 Cell 的显示状态

复查发现，选择更新只覆盖可见 Cell；系统提前准备但尚未显示的 Cell 可能保留旧选中态或字体。按 [Apple 的预取说明](https://developer.apple.com/documentation/uikit/uicollectionview/isprefetchingenabled)，新增 `collectionView(_:willDisplay:forItemAt:)`，在显示前同步当前标题、字体、颜色、选中态、无障碍标识和回调。数据源与 delegate 共用内部适配器，适配器对标签栏持弱引用。

- **修复前证据：** 新增测试在 UIWindow 中确定性模拟 Cell 的旧状态，并调用显示前生命周期回调；原实现缺少该回调，测试失败。该用例验证状态同步边界，不声称复现了系统预取调度时序。见 [修复前结果](Results/tabbar-review-before/Result.xcresult)。
- **通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 43 项库测试（34 项原有测试 + 9 项标签栏测试），0 失败、0 跳过；最终源码哈希校验无变化。见 [库测试结果](Results/tabbar-review-final-library/Result.xcresult) 和 [摘要](Results/tabbar-review-final-library/summary.json)。
- **通过：** 同一环境下完整 12 项 UI 测试通过，0 失败、0 跳过，覆盖居中动画、左右滚动可达性、纵向拖动吸顶、分页、连续选择、重排与删除、刷新、旋转、RTL 和侧滑返回。见 [UI 结果](Results/tabbar-review-final-ui/Result.xcresult) 和 [摘要](Results/tabbar-review-final-ui/summary.json)。
- **最终复查结果：** 合计 **55 通过、0 失败、0 跳过**。两份终态结果已读取，28 个输入文件的源码哈希快照完全一致且与当前文件匹配，`sourceChangedSinceRun` 均为空；`git diff --check` 通过。完成改动范围、引用关系和待提交文件审计后，未发现其他阻塞提交的问题。
- **未执行：** Release、iPad、iOS 15 实际运行、真机、VoiceOver 全流程及性能基准。下方迁移阶段的结果对应本次显示前状态同步修复之前的源码。

## SPTabBar Collection View 迁移

默认标签栏由 `UIScrollView + UIStackView` 改为 `UICollectionView + SPTabBarLayout`，保留等宽规则及公开更新接口。内容超出可用宽度时，选中项尽量居中并限制在合法滚动范围；首尾不增加留白。尺寸、字体或方向变化重新对齐，普通布局刷新保留手动滚动位置。指示器通过 Layout 获取屏幕外项的几何信息，布局刷新保留分页过渡进度；复用时更新标题、颜色、按钮无障碍标识、选中态及点击回调。

- **通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 42 项库测试（原有 34 项 + 新增 8 项），0 失败、0 跳过。见 [库测试结果](Results/tabbar-collection-final-library-verified/Result.xcresult) 和 [摘要](Results/tabbar-collection-final-library-verified/summary.json)。终态结果已读取，源码哈希校验无变化。
- 新增库测试在 UIWindow 中覆盖 LTR / RTL 的居中与首尾边界、不足一屏均分、容器尺寸变化、手动偏移保持、100 项 Cell 复用、回调和无障碍选中态、屏幕外指示器插值、重布局保留过渡、缩减与空数据、非法索引、首次布局前选择、非动画选择中断连续动画请求、Dynamic Type 宽度及居中。
- **测试边界：** 初始动画终点断言失败；独立原生 UIScrollView 对照也未推进动画，异步等待复核结果相同，因此无应用宿主的 Package 测试不用于证明系统滚动动画完成。最终库测试验证非动画选择中断此前动画请求后的落点，实际动画交由 Demo UI 测试验证。原始诊断保留于 `Results/tabbar-animation-diagnostic` 和 `Results/tabbar-animation-async`。Dynamic Type 下的滚动偏移按屏幕像素取整，断言使用一个物理像素的精度。
- **通过：** 同一工具链与模拟器上，完整 12 项 Demo UI 测试（原有 11 项 + 新增 1 项），0 失败、0 跳过。新增用例在具备足够滚动余量的场景中验证选中项动画居中、选中态、左右拖动后首尾标签可点击、拖动不误切页面及再次点击切页。原有吸顶边界、纵向拖动标签栏、分页、重排与删除、刷新、旋转、返回手势和 RTL 测试全部通过。见 [UI 结果](Results/tabbar-collection-final-ui-verified/Result.xcresult) 和 [摘要](Results/tabbar-collection-final-ui-verified/summary.json)。
- **UI 测试场景修正：** 首轮为 11 通过、1 失败。原有 6 个短标签仅略宽于屏幕，测试所选标签受内容边界限制而无法严格居中；增加一个标签后，选取有足够左右余量的中间项，保持居中精度断言并增加首尾可点击断言。框架实现未因该测试调整而改变。原始结果见 [首轮 UI 结果](Results/tabbar-collection-final-ui/Result.xcresult)。
- **迁移阶段验收：** 42 项库测试 + 12 项 UI 测试，合计 **54 通过、0 失败、0 跳过**。最终两份结果包均已读取，均对应当时的源码与测试文件，当时 `sourceChangedSinceRun` 为空；`git diff --check` 通过。
- **未执行：** 本次 Release、iPad、iOS 15 实际运行、真机、VoiceOver 全流程和性能基准。

## 内容页底边对齐修复

分页视口不再从高度中扣除 `safeAreaInsets.bottom`，数据源返回的内容页根视图延伸至容器底边；全屏 Demo 中即为屏幕底边。展开与折叠期间保持同一底部边界。UIKit 的滚动视图自动 inset 继续负责底部安全区域避让，普通页可通过 `safeAreaLayoutGuide` 布局控件。Demo 异步页的底部按钮同步改用安全区域定位。

- **修复前复现：** 新增真实 UIWindow 几何测试，在 24pt 底部安全区域下测得页面底边 `820`，容器底边 `844`；80pt 安全区域时相差 80pt。见 [原始失败结果](Results/page-bottom-before/Result.xcresult)。
- **中间回归：** 库测试 34 项通过；首轮 UI 测试 10 通过、1 失败，异步页按钮使用原有 bounds 底部定位，页面延伸后被工具栏覆盖。改用 Safe Area 定位后重新执行完整测试，未放宽或删除断言。见 [中间失败结果](Results/page-bottom-full-ui/Result.xcresult)。
- **最终通过：** iPhone 18 Pro Max / iOS 27.0，Xcode 27.1（27A9275）/ Swift 6.4 / Debug，完整 **34 项库测试 + 11 项 UI 测试 = 45 通过、0 失败、0 跳过**。两份终态结果均已读取，最终源码哈希校验无变化。
  - [最终库测试](Results/page-bottom-final-library/Result.xcresult) · [库测试摘要](Results/page-bottom-final-library/summary.json)
  - [最终 UI 测试](Results/page-bottom-final-ui/Result.xcresult) · [UI 测试摘要](Results/page-bottom-final-ui/summary.json)
- 新增库测试覆盖展开、部分折叠、完全折叠、普通页切换和底部 Safe Area 动态变化，并验证业务底部 inset 与内容末端可见位置。UI 测试新增页面底边等于屏幕底边的断言，覆盖连续滚动、切页、Header 类型与高度变化、横竖屏旋转；其余滚动、刷新、分页、RTL 和返回手势测试全部通过。
- **未执行：** Release、其他设备和系统矩阵、真机验证。本节结果取代下方较早源码的回归结果，旧证据保留。

## 标签栏悬浮位置修复

Demo、最小接入示例和 README 原先将 `minimumHeaderHeight` 设为 `32`，导致 Header 完全折叠后仍保留 32pt 色块。现使用默认保留高度 `0`，标签栏停在顶部安全区域边缘；补充属性说明，非零保留高度仍供业务按需设置。

- **修复前复现：** iPhone 18 Pro Max / iOS 27.0 上，新 UI 回归测试在折叠进度达到 1 后测得标签栏顶部 `y=148`、导航栏底部 `y=116`，精确相差 32pt。见 [原始失败结果](Results/sticky-position-before/Result.xcresult)。
- **通过：** 同一模拟器、Xcode 27.1（27A9275）、Debug 下，修复后 **4 项 UI 测试通过、0 失败、0 跳过**。新增测试核对连续滚动、切页、Header 类型和高度切换、横竖屏旋转后的导航栏／标签栏／列表视口边界；另执行 Header 拖动与列表滚动、短列表斜向拖动与回弹、原生下拉刷新。见 [最终结果](Results/sticky-position-after/Result.xcresult) 和 [源码校验摘要](Results/sticky-position-after/summary.json)，`sourceChangedSinceRun` 为空。
- **通过：** 修复后 Demo 在该模拟器重新构建、安装并启动。
- **完整回归通过：** 随后在同一 iPhone 18 Pro Max / iOS 27.0、Xcode 27.1（27A9275）/ Swift 6.4、Debug 环境中，无测试筛选地执行根目录 Package 的全部 **33 项库测试**与 Demo 的全部 **11 项 UI 测试**，合计 **44 通过、0 失败、0 跳过**。库与 UI 测试依次执行，均已读取终态 `.xcresult`；两组 `sourceChangedSinceRun` 均为空，测试期间未修改实现或测试源码。
  - [库测试结果](Results/sticky-position-full-library/Result.xcresult) · [库测试摘要](Results/sticky-position-full-library/summary.json)
  - [UI 测试结果](Results/sticky-position-full-ui/Result.xcresult) · [UI 测试摘要](Results/sticky-position-full-ui/summary.json)
  - 覆盖滚动位移分配、位置恢复、短内容与回弹、刷新、动态 Header、横向分页、快速切页、转场中断、页面重排与删除、缓存释放、异步滚动视图替换、Safe Area、RTL、旋转及返回手势；现有测试范围内未发现本次配置修改引入回归。
- **未执行：** 本次未重跑 Release、其他设备和系统矩阵，未执行真机验证。

## UIScene 启动修复

原 Demo 在 AppDelegate 中创建窗口，缺少 Scene Manifest。用户报告新 SDK 下触发 `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` 并拒绝启动。现由 AppDelegate 返回使用 SceneDelegate 的场景配置，SceneDelegate 通过 `UIWindow(windowScene:)` 创建窗口；Debug / Release 均启用 Scene Manifest 生成，保留 `--rtl` 与 `--open-demo` 启动参数。

- **通过：** Xcode 27.1（27A9275）/ iOS 27.1 SDK / Debug 构建，产物 Info.plist 已包含 `UIApplicationSceneManifest`。
- **通过：** iPhone 17 Pro / iOS 26.5 安装、启动；现有 `testRTLHorizontalPaging` 与 `testRotationAndBackGesture` 共 **2 通过、0 失败、0 跳过**，已读取终态 [Result.xcresult](Results/scene-lifecycle/Result.xcresult)。这两项测试覆盖普通入口、RTL 重新启动、分页、旋转和返回。
- **通过：** `--open-demo` 启动后截图确认演示页面显示。截图、构建日志和源码 SHA-256 位于 [本次证据目录](Results/scene-lifecycle/)。
- **被环境阻塞：** iPhone 18 Pro Max / iOS 27.0 的 `simctl install` 长时间未完成，本次安装进程已终止；未进入 App 启动，不能将其计为 iOS 27.0 运行通过或代码运行失败。
- **未执行：** 本次修复后的 Release 构建、真机与全量测试矩阵。下方历史结果保留其原有源码和环境边界。

## 环境与执行方式

- 主工具链：Xcode 26.6（17F113），Apple Swift 6.3.3。
- 兼容性工具链：Xcode 27.1（27A9275），Apple Swift 6.4。
- 主要模拟器：iPhone 17 Pro / iOS 26.5。
- 适配模拟器：iPad Pro 11-inch (M5) (16GB) / iOS 26.5。
- Package tools version 6.3、Swift 6 语言模式；Swift 编译命令中的目标为 `arm64-apple-ios15.0-simulator`。
- Release 测试使用 `ENABLE_TESTABILITY=YES` 暴露内部测试入口，保留 Release 的 `-O` 优化。

`Scripts/validate.sh` 为每次运行保存工具链、源文件哈希、完整日志和 `.xcresult`。`Scripts/summarize_validation.py` 从终态结果读取实际执行数量，并检查运行后源码是否变化。`Validation/Results` 和 `Validation/Products` 为本地忽略目录。

## 当前结构：库测试独立于 Demo

2026-10-15 从 Demo 工程彻底移除 `StickyPagerKitTests` 的目录引用、测试 target、产品、构建配置、依赖和共享 scheme 测试项。Demo 只保留 `StickyPagerDemo` 与 `StickyPagerDemoUITests` 两个 target。库测试由根目录 `Package.swift` 的 `.testTarget` 管理，源码仍在 `Tests/StickyPagerKitTests`。

- **通过：** Xcode 导航器确认 Demo 工程下无库测试引用。
- **通过：** XcodeBuildMCP `build_sim(buildForTesting: true)` 构建 Demo 应用及 UI 测试；生成的 `.xctestrun` 只有 `StickyPagerDemoUITests`。
- **通过：** 根目录直接运行 `StickyPagerKit` Package scheme，33 项库测试通过、0 失败、0 跳过；Xcode 27.1 / Swift 6.4，iPhone 17 Pro / iOS 26.5。读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。见 [独立 Package 测试结果](Results/package-independent-tests/Result.xcresult)。
- **未执行：** 本次移除 target 后未重跑 10 项 Demo UI 测试，仅构建其测试产物。未重新执行 Release、iPad 或 Swift 6.3 矩阵。

验证脚本用 `SP_SCOPE=library` 运行根目录库测试，用 `SP_SCOPE=demo` 运行 Demo；两者使用独立的构建目录。以下宿主型测试结果保留为历史记录，不代表当前 scheme 的组成。

## XcodeBuildMCP 工程迁移验证（移除库测试 target 前）

2026-10-15 使用 `scaffold_ios_project` 创建新工程，迁入既有 UIKit Demo 和 UI 测试，采用 `PBXFileSystemSynchronizedRootGroup`。库源码仍在 `Sources/StickyPagerKit`，库测试仍在 `Tests/StickyPagerKitTests`；当时 Demo 的宿主型单元测试 target 与 SPM 共用这份测试（现已移除该 target）。12 个 Swift 实现和测试文件内容未改变，`Package.swift` 保持标准测试目录配置。旧工程生成脚本已移除。

验证环境：Xcode 27.1 / Swift 6.4，iPhone 17 Pro / iOS 26.5，Debug。新工程经 XcodeBuildMCP 构建、安装及启动，运行时 UI 快照确认演示页面已显示；Xcode 导航器已检查应用与 UI 测试的真实目录分组。

| 阶段 | 结果 | 证据 |
| --- | --- | --- |
| 首轮迁移测试 | 42 通过、1 失败；旋转后侧滑返回断言失败 | [首轮结果](Results/mcp-project-migration/Result.xcresult) |
| 目录调整过程中的全量复测 | 43 通过、0 失败、0 跳过；测试代码未改动 | [全量复测](Results/mcp-project-migration-final/Result.xcresult) |
| 库测试恢复到根目录后的最终定向复测 | **34 通过、0 失败、0 跳过**：33 项库测试 + 旋转及侧滑返回 UI 测试 | [最终目录复测](Results/mcp-project-migration-library-tests/Result.xcresult) |

最后一组在当时核验时 `sourceChangedSinceRun` 为空；本次移除 target 后工程和验证脚本已变化。最终目录调整后未再次执行其余 9 项 UI 测试，不能将中间目录的 43 项全量结果记为最终目录的全量执行。首轮失败原因尚未确定，后续两次旋转及返回测试均通过，原始失败证据保留。工程迁移后未重跑 Swift 6.3、Release 或 iPad 矩阵。

## 工程迁移前的结果

| 工具链 / 配置 | 目标 | 结果 | 结果包 |
| --- | --- | --- | --- |
| Swift 6.3.3 / Debug | iPhone 17 Pro · iOS 26.5 | **通过：43/43，失败 0，跳过 0** | [Debug xcresult](Results/swift63-debug-accepted-14/Result.xcresult) |
| Swift 6.3.3 / Release | iPad Pro 11-inch (M5) · iOS 26.5 | **通过：43/43，失败 0，跳过 0** | [Release xcresult](Results/swift63-release-ipad-accepted-15/Result.xcresult) |
| Swift 6.4 / Debug | iOS Simulator，部署目标 iOS 15.0 | **构建通过**，本行不计为测试执行 | [构建 xcresult](Results/swift64-accepted-16/Result.xcresult) |

每组完整测试为 **33 项核心测试 + 10 项 UI 测试**。两组均重新构建并执行，未复用重复测试配置。已读取终态 `.xcresult` 验证实际数量；三组在迁移前核验时 `sourceChangedSinceRun` 均为空；迁移改变了工程、Package 测试路径和验证脚本，旧结果不代表新工程已经通过同样的验证矩阵。

迁移前的 Debug Demo 已安装并启动于指定 iPhone 17 Pro 模拟器，启动后截图见 [demo-preview.jpg](demo-preview.jpg)。

机器可读结果、工具链版本、设备和源码哈希文件位置见 [final-evidence.json](final-evidence.json)。各运行目录中的 `source-hashes.json`、`xcodebuild.log` 和 `summary.json` 保留了具体证据。

## 覆盖内容

核心测试在真实 UIWindow 中验证：Header 和内容偏移分配、Safe Area 与 frame、短内容滚动范围、业务 delegate 保留、inset 解绑恢复、显式绑定及自动发现、页面缓存淘汰与释放、重排和删除、重复标识、动态 Header、刷新固定 Header、RTL 页序、连续切页取消、尺寸变化取消转场、父容器出现期间更换 Header 和选中页、长距离分页的可见页加载及缓存边界。

UI 测试执行：Header 拖动、标签栏拖动、列表及短内容拖动、斜向拖动与回弹、点击和横向分页、Header 类型和高度更新、普通页面、页面重排及删除、原生下拉刷新、异步滚动视图替换、旋转、系统侧滑返回和 RTL 右滑。UI 测试结束时将实际截图附加到 `.xcresult`。

## 失败与修复记录

1. 初次窗口测试在 UIKit 完成 appearance 之前断言，释放测试也未隔离 autorelease 生命周期。补充主运行循环和 autorelease pool 后，生命周期、缓存释放和容器释放断言通过；未通过放宽几何或回调断言掩盖问题。
2. 首次 Swift 6.3 工程构建中，应用尝试编译 x86_64，但 Package 仅为当前 arm64 目标生成模块。验证脚本使用 `ONLY_ACTIVE_ARCH=YES`，Debug 工程也启用当前架构。
3. Demo 网格列宽的浮点舍入导致只排出两列；取整后恢复三列。列表采用自动行高，避免副标题裁切。
4. RTL 运行测试曾失败：Demo 只设置窗口方向，导航中的分页容器仍是 LTR。将 RTL 开关显式应用于容器，增加方向断言后，右滑翻页和标签选择复测通过。
5. iPad 的返回手势测试原本使用宽度 1% 作为起点，实际触发横向翻页。改为距边缘 1pt 的起点后，保持原返回成功断言，聚焦复测通过。
6. 补齐父容器 appearance 尚未结束时更换选中页的转发；切换绑定时终止旧 Header 惯性动画。长距离程序化分页按可见范围加载中间页，避免空白过渡。

失败运行与修复运行保留为独立目录。两次 RTL 失败后的 `simctl diagnose` 长时间等待，已只终止该次测试创建的诊断收集子进程，使 xcodebuild 保存原始失败结果；未删除失败证据。后续验证使用 `-collect-test-diagnostics never`，仍保留测试结果、日志和截图。

## 未验证与边界

- **未执行：** iOS 15 实际运行、真机安装和交互、VoiceOver 全流程、性能与长时间压力测试。现有 iOS 15 证据为部署目标与 API 编译检查，不是 iOS 15 运行通过。
- **版本边界：** 实测编译器为 Swift 6.3.3，不宣称精确 Swift 6.3.0 的独立验证；Swift 6.4 为另一次兼容性构建。
- **集成边界：** 每页只协调一个主要纵向滚动视图；复杂多滚动视图页面应显式指定。Header 高度由业务方提供，不做自动测高。
- **测试边界：** 实际手势测试与状态测试覆盖了列出的路径，不等同于所有速度、角度、系统版本和第三方滚动组件组合的穷举验证。
- 原 Demo 使用 UIApplicationDelegate 窗口入口，在新 SDK / 系统组合下会因缺少 UIScene 生命周期而启动失败；此前 iOS 26.5 上的启动结果不能证明新系统兼容性。现已在 Debug / Release 开启 Scene Manifest 生成，由 AppDelegate 提供 SceneDelegate 配置，并在 SceneDelegate 中通过 UIWindow(windowScene:) 创建窗口。框架本身不依赖应用的窗口入口类型。
