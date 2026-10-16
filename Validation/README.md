# StickyPagerKit 验证记录

验证日期：2026-10-15 至 2026-10-16。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

## 横向分页期间隐藏子页面滚动指示器

2026-10-16，在 `44b5259` 基础上，使用 Xcode 27.1 / Swift 6.4 / Debug、iPhone 18 Pro Max / iOS 27.0 模拟器验证。

- **修复：** 分页容器已关闭横向指示器，但子页面原生指示器仍会随页面横移而出现在两页之间。现从横向拖动开始，直到减速或程序化动画结束，统一隐藏已绑定页面的横向和纵向指示器；中途加载、重新绑定的页面继承该状态，转场候选页变化不提前恢复。完成、取消、重载后按最新业务偏好恢复。
- **隐藏状态不处理：** 原本隐藏的指示器不重复写入显隐属性；隐藏期间不更新纵向指示器轨道。回归通过属性写入计数，确认原本隐藏的滚动视图在绑定、翻页、内容变化、恢复和解绑过程中没有额外指示器属性写入。
- **修复前：** 新增的 3 项分页生命周期回归全部失败，见 [修复前日志](Results/paging-indicator-before/xcodebuild.log)。首轮修复后的库测试暴露了测试夹具依赖动画时钟的终态断言失败；库夹具改为显式驱动终态回调，真实动画另由 Demo UI 测试覆盖，未放宽显隐和恢复断言。
- **最终完整库：81 项通过，0 失败，0 跳过。** 包含原有 77 项及新增 4 项，覆盖拖动／减速阶段、进入页加载、取消、动画终态、绑定替换、重载恢复以及已隐藏时零写入。终态 `.xcresult` 已核验，`sourceChangedSinceRun` 为空。见 [库结果](Results/paging-indicator-library-final/Result.xcresult) · [库摘要](Results/paging-indicator-library-final/summary.json)。
- **定向 UI：3 项通过，0 失败，0 跳过。** 覆盖真实横向手势、快速点击切页、非相邻选择后的翻页和 RTL 翻页。已读取终态结果，源码哈希匹配最终版本；这些 UI 用例验证分页交互，分页各阶段的指示器显隐由上述库断言验证。见 [UI 结果](Results/paging-indicator-ui/Result.xcresult) · [UI 摘要](Results/paging-indicator-ui/summary.json)。
- **边界：** 本轮未执行完整 Demo UI 套件、Release、iPad、其他系统版本和真机；库测试的终态回调驱动不等同于真实触摸或动画帧采样。

## 滚动指示器位置修复

2026-10-16，使用 Xcode 27.1 / Swift 6.4 / Debug，在截图同款 iPhone 18 Pro Max / iOS 27.0 模拟器（`41AF9CED-9BBB-4B60-B563-73AFB035C2D4`）验证。

- **原因：** `SPScrollBinding` 添加 Header 折叠所需的顶部 inset，并给短内容补齐底部 inset；UIKit 将这些区域计入指示器进度。真实 UIWindow 诊断中，216 pt 内容、644 pt 视口、200 pt 折叠距离，在吸顶时仍生成从视口下方约 154.33 pt 开始、长约 486.67 pt 的指示器；显式设置零指示器 inset 无法消除。原始输出见 [几何诊断日志](Results/indicator-probe-native/xcodebuild.log)。
- **修复：** 仅有 Header 折叠范围的短列表和空列表隐藏纵向指示器；长内容保留原生指示器，轨道顶部增加尚未折叠的覆盖高度。内容和尺寸变化时重算显隐，保留最新业务 inset／显隐偏好并在解绑时恢复，不改变横向指示器和自动安全区域策略。
- **修复前回归：3 项失败，0 项通过。** 验证短内容显隐、轨道与标签栏的实际坐标关系、业务配置更新及解绑恢复。见 [修复前结果](Results/indicator-before/Result.xcresult)。
- **修复后完整库：77 项通过，0 失败，0 跳过。** 包含新增 3 项及原有 74 项测试，见 [库结果](Results/indicator-after-library/Result.xcresult) · [摘要](Results/indicator-after-library/summary.json)。库源码、Package 与库测试哈希匹配最终版本；该次运行后仅另行添加了 Demo UI 测试，该文件不属于库 scheme，原始哈希差异如实保留在摘要中。
- **定向 UI：3 项通过，0 失败，0 跳过。** 实际执行 Header／长列表拖动、短列表斜向拖动与回弹、新增短／空／长内容切换和拖动，验证短列表内容可见及新触摸可展开 Header。见 [UI 结果](Results/indicator-after-ui/Result.xcresult) · [摘要](Results/indicator-after-ui/summary.json)。UI 源码快照匹配最终版本，已读取两组终态结果，`git diff --check` 通过。
- **截图复核：** [短列表吸顶](Results/indicator-after-ui/screenshots/ED3CCCE2-690A-41C8-9B46-06ADD8DD9E13.png) 中右侧异常长条已消失；截图为手势结束后的状态，长列表原生指示器的显隐设置与轨道位置另由库回归断言验证。
- **本轮未执行：** 完整 Demo UI 套件、Release、iPad、其他系统版本和真机。此前各节的矩阵属于历史源码，不作为本次修复的全量验收。

## iPhone 17 Pro / iOS 26.5 Release 回归

2026-10-16，从干净的 `de381a2` 工作区开始，按指定设备补跑窗口修复后的回归。使用 Xcode 26.6（17F113）/ Swift 6.3.3，iPhone 17 Pro / iOS 26.5（23F77）模拟器，设备 ID 为 `294027E9-350F-4CA3-8B9F-222AA5281556`。库与 Demo UI 分别 clean 构建并执行完整 Release 套件，未筛选用例；库测试设置 `ENABLE_TESTABILITY=YES`。框架、Demo 和测试目标的编译日志均确认使用 `-O`，见 [库优化证据](Results/window-fix-iphone17-release-library/optimization.json) · [UI 优化证据](Results/window-fix-iphone17-release-ui/optimization.json)。

- **完整库通过：74 通过、0 失败、0 跳过。** 已读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。包含滚动位移分配、共享 Header、切页与缓存位置恢复、Safe Area、尺寸转换、自适应行高、底部钳制、手势归属及生命周期测试。见 [库结果](Results/window-fix-iphone17-release-library/Result.xcresult) · [库摘要](Results/window-fix-iphone17-release-library/summary.json)。
- **完整 UI 套件通过：16 通过、0 失败、2 跳过。** 全部 iPhone 适用用例实际执行并通过；`testSystemSplitWindowsPreservePositionAndPaging` 与 `testSystemWindowResizePreservesPinnedListAndPaging` 仅适用于 iPad，按条件跳过且不计为通过。见 [UI 结果](Results/window-fix-iphone17-release-ui/Result.xcresult) · [UI 摘要](Results/window-fix-iphone17-release-ui/summary.json)。
- **滚动同步与旋转：** Header／列表拖动、共享折叠、短内容回弹、普通页拖动、刷新、快速与非相邻切页、RTL 通过。吸顶用例在连续滚动、切页、替换 Header 和修改高度后往返横竖屏，核验导航栏／标签栏／列表视口与页面底边的实际几何；纵向拖动标签栏没有误切页。
- **返回手势：** 列表吸顶后往返横竖屏，慢拖 80 pt 并停留后取消系统返回，验证新触摸仍可翻页；随后完成侧滑返回、重新进入，验证初始展开状态及再次分页。见 [用例结束截图](Results/window-fix-iphone17-release-ui/rotation-back-screenshots/15633E61-9113-401C-9B61-A655CCFC4134.png)。截图仅表示结束状态，完整过程以结果包中的动作及断言日志为证。
- **最终合计：90 通过、0 失败、2 项 iPad 专用测试跳过。** 两组均取得 `TEST SUCCEEDED` 并读取终态 `.xcresult`，`sourceChangedSinceRun` 均为空。28 个实现、测试、工程及脚本输入文件的 SHA-256 在本轮库与 UI 之间一致，匹配当前源码，也与此前 iPad / iOS 26.5、iPhone 18 Pro Max / iOS 27.0 的最终验收输入一致。`git diff --check` 通过，历史数量不重复计入本轮。
- **改动范围：** 未发现需要修复的新问题，未修改实现或测试，未放宽断言；本轮仅补充验证记录。日志、截图、哈希和 `.xcresult` 留在本地 Git 忽略目录。
- **未执行：** 本轮未重跑其他设备、其他系统、真机、多指同时操作、VoiceOver 全流程或性能压力测试。上述通过结论限定于指定模拟器、Release 配置及现有测试覆盖。

## 窗口修复后的 iPhone Release 回归

2026-10-16，从干净的 `e45c201` 工作区开始，验证下节窗口修复在 iPhone 上的表现。使用 Xcode 27.1（27A9275）/ Swift 6.4，iPhone 18 Pro Max / iOS 27.0（24A434）模拟器，设备 ID 为 `41AF9CED-9BBB-4B60-B563-73AFB035C2D4`。库与 Demo UI 分别 clean 构建并运行完整 Release 套件，未指定测试筛选；库测试使用 `ENABLE_TESTABILITY=YES`。编译日志确认框架、Demo 与测试目标均使用 `-O`，见 [库优化证据](Results/window-fix-iphone-release-library/optimization.json) · [UI 优化证据](Results/window-fix-iphone-release-ui/optimization.json)。

- **完整库通过：74 通过、0 失败、0 跳过。** 已读取终态 `.xcresult`，运行后 `sourceChangedSinceRun` 为空。本轮包含前次新增的 6 项尺寸变化测试，并覆盖滚动位置分配、共享 Header、后台页位置、缓存恢复、刷新、手势归属及生命周期。见 [库结果](Results/window-fix-iphone-release-library/Result.xcresult) · [库摘要](Results/window-fix-iphone-release-library/summary.json)。
- **完整 UI 套件通过：16 通过、0 失败、2 跳过。** 两项跳过分别为 `testSystemSplitWindowsPreservePositionAndPaging`、`testSystemWindowResizePreservesPinnedListAndPaging`，均仅适用于 iPad；iPhone 适用的全部 16 项实际执行并通过。见 [UI 结果](Results/window-fix-iphone-release-ui/Result.xcresult) · [UI 摘要](Results/window-fix-iphone-release-ui/summary.json)。
- **滚动同步与旋转：** Header／列表真实拖动、共享折叠状态、短内容斜向拖动和回弹、普通页拖动、刷新、非相邻选择、快速分页及 RTL 均通过。吸顶用例连续滚动、切页、替换 Header 和修改高度后，往返横竖屏，检查标签栏与导航栏、列表与标签栏以及页面底边的实际几何。
- **返回手势：** `testRotationAndBackGesture` 在列表吸顶后往返横竖屏；慢拖 80 pt 并停留后取消返回，验证页面仍在且新触摸可翻页；随后完成系统侧滑返回，重新进入后验证初始展开状态及再次翻页。见 [用例结束截图](Results/window-fix-iphone-release-ui/rotation-back-screenshots/E768A010-B406-4048-BD29-A5DD61DB7BA6.png)。该截图仅表示用例结束状态，过程以 UI 测试动作和断言日志为证。
- **最终合计：90 通过、0 失败、2 项 iPad 专用测试跳过。** 两组均取得 `TEST SUCCEEDED` 并读取终态 `.xcresult`；28 个实现、测试、工程及脚本输入文件的 SHA-256 在库与 UI 之间一致，匹配当前源码，也与上轮 iPad 最终验收的输入一致。两组 `sourceChangedSinceRun` 均为空，`git diff --check` 通过。
- **改动范围：** 未发现需要修复的新问题，未修改实现或测试，也未放宽断言；本轮只补充验证记录。原始日志、截图、源码哈希和结果包保留在本地 Git 忽略目录。
- **未执行：** 本轮未重跑其他 iPhone 型号、iOS 26.5 或 iOS 15–25、真机、多指同时操作、VoiceOver 全流程和性能压力测试。上轮 iPad 结果保留为同源码的独立验证，不重复计入本轮数量。

本节为窗口修复后的 iPhone 证据；更早章节的 iPhone 结果仍对应其历史源码。

## iPad 系统分屏与连续窗口缩放回归

本轮从干净的 `52481cb` 工作区开始，使用 Xcode 26.6 / Swift 6.3.3 / Release，设备为 iPad Pro 11-inch (M5) (16GB) / iOS 26.5 模拟器。库测试启用 `ENABLE_TESTABILITY=YES`，库与 Demo UI 分别 clean 构建。最终两组编译日志确认框架、应用及测试目标均使用 `-O`，见 [库优化设置](Results/window-accepted-library/optimization.json) · [UI 优化设置](Results/window-accepted-ui/optimization.json)。下节及更早章节的结论只对应各自历史源码。

### 问题与修复

1. **视口放大后恢复越界的底部位置。** 原实现缩放后没有同步钳制保存位置，切页返回可恢复到旧底部。新增用例复现原始位置 1584 pt，而新有效上限为 890 pt；现同时约束实际对齐位置与保存位置。修复前两项专项为 **1 通过、1 失败**，见 [原始结果](Results/window-before-library/Result.xcresult)。
2. **自适应行高布局覆盖位置恢复。** `UITableView` 在更新 inset、定位后仍会结算行高，专项复现归一化位置从 650 变为 639.5 pt。现先完成滚动视图布局，再恢复坐标契约中的内容位移。见 [原始结果](Results/window-self-sizing-stable-baseline/Result.xcresult)。
3. **新尺寸或 Safe Area 生效早于绑定布局。** UIKit 的中间偏移回调会以旧折叠范围改写保存位置。新增两项用例均先失败，包含 22 pt 的偏移差；现检查根视图尺寸和折叠范围是否与最近一次布局一致。见 [原始结果](Results/window-pending-geometry-before/Result.xcresult)。
4. **系统连续缩放的帧间回调污染保存位置。** 尺寸转换期间暂停记录中间偏移，完成后布局并恢复；递增标识防止旧转换的 completion 提前结束新转换的保护。真实窗口拖动仍可在两次转换之间发送回调，因此 iOS 26+ 同时依据 `effectiveGeometry.isInteractivelyResizing` 保护保存位置。加入这一原生状态检查前，系统专项为 **1 通过、1 失败**，连续放大时内容位移 504 pt、期望 546 pt；加入后相同两项专项 **2 通过、0 失败、0 跳过**。见 [检查前结果](Results/window-transition-focused-ui/Result.xcresult) · [检查后结果](Results/window-interactive-resize-ui/Result.xcresult)。专项之后仅整理测试清理逻辑，最终验收以下方完整重建结果为准。

### 新增测试与验收口径

- **6 项库测试：** 真实 UIWindow 中覆盖 LTR / RTL、展开／部分折叠／完全吸顶、连续尺寸变化、横向页偏移、切走返回、底部钳制、原生自适应行高、待布局 Safe Area／尺寸回调，以及重叠尺寸转换结束后的新滚动。夹具矩阵包括 1194 × 834、592 × 834、375 × 700、640 × 480、834 × 1194 pt；该矩阵不充当系统分屏证据。
- **2 项系统 UI 测试：** XCTest 操作系统窗口手柄和窗口菜单；启动“设置”作为第二个应用，使用“左右”布局形成真实双应用分屏。验证两个窗口宽度缩小且互不重叠，并执行列表与短列表间的真实左右滑动。连续缩放用例验证缩小、放大、再次缩小、各阶段往返分页、新触摸滚动，以及恢复全屏后的保存位置。
- **位移定义：** 沿用 README 中的 `q = contentOffset.y + adjustedContentInset.top`，内容位置为 `max(0, q - collapseRange)`。Demo 仅在 `--window-regression` 参数下通过可访问性值暴露原生 q；断言同时检查导航栏、标签栏、列表与窗口的实际坐标，位移误差限为 1 pt。不会通过状态文本代替偏移断言。
- **探索边界：** 早期使用“同一行保持固定屏幕坐标”作为断言，超出了既有内容位移契约；自适应行高重新估算时两者并不等价。相关行锚点和异步恢复尝试已撤回，最终实现不包含这些机制。历史探索结果不计入验收；本轮不承诺内容重排后同一阅读行的像素位置固定。
- 截图使用 `XCUIScreen.main.screenshot()`，保留系统窗口和第二个应用。测试清理会恢复全屏和竖屏，并关闭为分屏启动的“设置”。

### 最终结果

- **完整 Release 库通过：74 通过、0 失败、0 跳过。** 已读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。见 [库结果](Results/window-accepted-library/Result.xcresult) · [库摘要](Results/window-accepted-library/summary.json)。
- **完整 iPad Release UI 通过：18 通过、0 失败、0 跳过。** 无测试筛选，保留原有滚动、刷新、RTL、旋转、返回取消／完成、新触摸恢复及横向分页用例。见 [UI 结果](Results/window-accepted-ui/Result.xcresult) · [UI 摘要](Results/window-accepted-ui/summary.json)。
- **最终合计：92 通过、0 失败、0 跳过。** 两次运行均取得 `TEST SUCCEEDED` 并读取终态 `.xcresult`；28 个实现、测试、工程及脚本输入文件的 SHA-256 在两组之间完全一致，且匹配最终源码，`sourceChangedSinceRun` 均为空。`git diff --check` 通过。
- **实际系统几何：** 双应用窗口分别为 `(0, 0, 412, 1210)`、`(422, 0, 412, 1210)` pt；自由窗口依次为 `(230, 233, 375, 630)`、`(73, 115, 690, 866)`、`(151, 173, 535, 750)` pt，最后恢复 `(0, 0, 834, 1210)` pt 全屏。各阶段内容位移、吸顶边界和往返分页断言通过，恢复前的新滚动仍生效。见 [系统分屏截图](Results/window-accepted-ui/screenshots/56CDB93E-9EF9-4BB7-ACA0-BB73C27DBB36.png) · [窗口缩放截图目录](Results/window-accepted-ui/resize-screenshots/)。完整结果包与截图位于本地 Git 忽略目录，未提交构建产物。
- **未执行：** 真机、旧系统传统 Split View、其他 iPad 型号与窗口布局、多指同时操作、VoiceOver 全流程及性能压力测试。本轮最终源码未重跑 iPhone UI；历史 iPhone 通过结果不作为此次修改后的验收。

## Release 与 iPad 补充回归

从干净的 `4bb93aa` 工作区开始，使用 iPad Pro 11-inch (M5) (16GB) / iOS 26.5，补跑 Xcode 26.6 / Swift 6.3.3 的 Release 回归。库测试设置 `ENABLE_TESTABILITY=YES`；编译日志确认库及库测试均使用 `-O`。Demo 的库、应用和 UI 测试目标同样使用 `-O`，未启用 testability。具体编译日志行号见首轮库与 UI 运行目录的 `optimization.json`。

- **首轮库通过：** 完整 **68 通过、0 失败、0 跳过**，已读取终态结果，运行后源码哈希一致。该轮早于下述 UI 测试修正。见 [库结果](Results/review-release-ipad-library/Result.xcresult) · [摘要](Results/review-release-ipad-library/summary.json)。
- **首轮 UI：12 通过、4 失败、0 跳过。** 滚动同步、吸顶后旋转、普通页拖动、刷新、异步替换及系统侧滑返回通过。失败集中在三个标签居中前置断言，以及一个使用屏幕比例终点的纵向拖动用例。原始结果已保留，修改测试前 `sourceChangedSinceRun` 为空。见 [首轮 UI 结果](Results/review-release-ipad-ui/Result.xcresult) · [摘要](Results/review-release-ipad-ui/summary.json)。
- **居中断言修正：** 失败截图与可访问性记录显示 iPad 视口宽 834 pt，标签 3 的 frame 为 `(201, 220, 77, 44)`，中心为 239.5 pt，内容已停在起点；强制对齐视口中心 417 pt 需要越过内容边界。现按公开约定验证“居中，或对应内容端点与视口边界重合”，保留 1 pt 精度，并要求选中项完整可见。LTR / RTL 共用这一检查，不跳过宽屏用例。长按后的实际位移仍须大于 40 pt，并核验不误切页及新点击恢复。
- **手势坐标修正：** 原纵向拖动终点为屏幕 `(30%, 12%)`，在 iPad 上横向分量大于纵向分量，未满足纵向识别条件。现保持起点的 x 坐标并向上拖动 180 pt，继续断言页面不变、Header 完全折叠，并新增标签栏紧贴导航栏的几何断言。
- **返回覆盖加强：** 在列表滚动吸顶后切换横竖屏，核验标签栏、导航栏和列表视口边界；小幅慢拖并停留后取消系统返回，随后新触摸仍须成功翻页；完成侧滑返回后重新进入，验证初始展开状态及再次翻页。
- **专项通过：** 四项原失败用例及加强的旋转／返回用例，**5 通过、0 失败、0 跳过**；已读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。见 [专项结果](Results/review-release-ipad-focused/Result.xcresult) · [摘要](Results/review-release-ipad-focused/summary.json)。
- **最终 Release 库通过：** 更新 UI 测试后，在同一 iPad 重新执行完整库测试，**68 通过、0 失败、0 跳过**；已读取终态 `.xcresult`，全部输入哈希与最终源码一致。见 [最终库结果](Results/review-release-ipad-final-library/Result.xcresult) · [摘要](Results/review-release-ipad-final-library/summary.json)。
- **最终 iPad Release UI 通过：** 同一 iPad / Xcode 26.6，无测试筛选执行完整 **16 通过、0 失败、0 跳过**。见 [最终 iPad UI 结果](Results/review-release-ipad-final-ui/Result.xcresult) · [摘要](Results/review-release-ipad-final-ui/summary.json)。
- **iPhone Release 对照通过：** Xcode 27.1 / Swift 6.4，iPhone 18 Pro Max / iOS 27.0，完整 **16 通过、0 失败、0 跳过**。同一套边界断言、真实纵向拖动，以及加强的旋转、返回和新触摸恢复测试均通过；编译日志确认框架、Demo、UI 测试均使用 `-O`。见 [iPhone 结果](Results/review-release-iphone-ui/Result.xcresult) · [摘要](Results/review-release-iphone-ui/summary.json) · [优化设置证据](Results/review-release-iphone-ui/optimization.json)。
- **最终合计：100 通过、0 失败、0 跳过**，不重复计入首轮与专项结果。三组最终结果均读取了终态 `.xcresult`，输入文件 SHA-256 一致且匹配最终源码，`sourceChangedSinceRun` 均为空；`git diff --check` 通过。本轮只修正 UI 测试及验证记录，框架实现与 `4bb93aa` 一致。
- **未执行：** iPad 分屏及窗口自由缩放、其他 iPad 尺寸、iOS 15 实际运行、真机、多指实触、VoiceOver 全流程和性能压力测试。上述通过结论限定于记录的模拟器、系统、Release 配置和测试场景。

## 滚动同步、手势归属与控制器生命周期审查

本次审查从干净的 `beb8520` 工作区开始，确认并修复以下问题：

1. Header 高度变化后，后台页仍保留旧范围下的原始偏移；淘汰时重新换算会污染内容位置。复现中 Header 减少 60 pt 后，重新加载页的归一化位置为 500 pt，而正确值为 440 pt。现同步缓存页布局，并仅由当前页滚动更新内容位置记录，后台临时对齐、解绑和淘汰不再覆盖记录。
2. 后台刷新页在 Safe Area 布局或切页准备时调用 `align`，会将共享 Header 错误展开；取消切页后也无法恢复原折叠状态。现只有已选中的刷新页可以展开 Header，提交选择后再应用刷新布局，正向偏移同步回到展开起点。
3. Header 拖动只按页面和绑定判断归属，第二个识别器可覆盖或结束第一个识别器的交互。现记录实际 pan，只允许所属识别器继续或结束；退出后允许新拖动开始。
4. 替换标签栏没有终止旧拖动，旧触摸仍可改变共享 Header。现替换时清理拖动和惯性状态，新手势仍可正常开始。
5. 父控制器正在消失时切页并淘汰旧页，会先解除 containment，再调用旧页 `viewDidDisappear`。现先在父子关系有效时结束该页未完成的 appearance，再移除页面，避免重复回调与延迟保留。

- **修复前复现：** 原实现执行新增 6 项用例，**0 通过、6 失败、0 跳过**，共 14 处断言失败。已读取终态 `.xcresult`，修改实现之前校验 `sourceChangedSinceRun` 为空。见 [失败结果](Results/interaction-review-before/Result.xcresult) · [失败摘要](Results/interaction-review-before/summary.json)。
- **新增覆盖：** 共 7 项真实 UIWindow 夹具测试，覆盖高度变化与缓存淘汰、后台刷新与 Safe Area、刷新目标切页取消及提交、两个 pan 的归属和新交互恢复、标签栏替换、消失期间缓存淘汰时的父子关系，以及后台临时对齐后替换滚动视图的历史位置保留。断言包括实际偏移、页面与标签栏坐标、绑定恢复及回调时父控制器身份。
- **最终库通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 **68 通过、0 失败、0 跳过**。已读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。见 [库结果](Results/interaction-review-final-library/Result.xcresult) · [库摘要](Results/interaction-review-final-library/summary.json)。
- **最终 UI 通过：** Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0，完整 **16 通过、0 失败、0 跳过**。覆盖 Header、列表及普通页真实拖动、短内容回弹、纵横手势、长按标签后滚动、快速与非相邻切页、刷新、异步替换、页面重排删除、RTL、旋转及系统侧滑返回。见 [UI 结果](Results/interaction-review-final-ui/Result.xcresult) · [UI 摘要](Results/interaction-review-final-ui/summary.json)。
- 两组最终结果合计 **84 通过、0 失败、0 跳过**，均已读取完整 `.xcresult`；库与 UI 输入文件 SHA-256 一致，且与最终实现及测试源码匹配，`sourceChangedSinceRun` 均为空。`git diff --check` 通过。
- **测试边界：** 双识别器归属测试确定性注入 pan 状态，不等同于真机双指同时触摸验证。本次未执行 Release、iPad、iOS 15 实际运行、真机、多指实触、VoiceOver 全流程或性能压力测试。

## Header 从屏幕顶部展开

Header 改为从容器顶边和左右边界铺开，`headerHeight` 表示包含顶部安全区域的总高度。标签栏仍在 `safeAreaInsets.top + minimumHeaderHeight` 处吸顶；实际折叠范围、列表顶部 inset、普通页顶部占位共用这一几何关系。高度不足吸顶基线时补足，无 Header 时保留安全区域避让。安全区域变化时重算折叠范围，保持已吸顶状态与内容滚动位置。

Header 使用禁用用户滚动的 UIScrollView 宿主，通过共享折叠量更新 contentOffset，再通过 `setContentScrollView(_:for: .top)` 关联导航栏。iOS 26+ 设置 `topEdgeEffect.style = .soft`，Demo 保留系统导航外观，由原生边缘效果柔化导航栏后方的 Header 内容。旧系统使用当前页面的透明导航外观，并裁剪导航栏后方的标题。Header 的文字按自身安全区域布局，背景保持延伸到屏幕顶部。

- **原问题复现：** 新增 UI 测试在 iPhone 18 Pro Max / iOS 27.0 上失败，初始 Header 的屏幕顶部坐标为 `116 pt`，期望 `0`。见 [修复前结果](Results/header-top-before/Result.xcresult) 和 [摘要](Results/header-top-before/summary.json)。
- **修复后专项：** 同一 UI 用例通过，验证初始顶部为 0、总高度为 220、网格首项与标签栏间距为 12 pt、横向翻页、吸顶后非相邻切页、普通页下拉展开，以及 UIView / UIViewController Header 替换和 300 pt 高度更新。见 [专项结果](Results/header-top-ui/Result.xcresult)。
- **新增库覆盖：** 在真实 UIWindow + UINavigationController 中验证 0 / 40 pt 保留高度、展开 / 部分折叠 / 完整折叠 / 内容滚动时的物理位置、业务 inset 保留、普通页切换、页面底边、安全区域变化后的内容位置、短 Header 及无 Header。
- **验证中补修：** 新增库用例发现普通页首次装载时没有立即应用 Header 占位，位置为 160 pt 而标签栏底部为 284 pt。原因是无滚动视图时绑定路径提前返回；现已在装载后立即更新 Header 与普通页几何。中间库运行日志记录 60 通过、1 失败，但 xcodebuild 在结果收集阶段持续解析 Package Graph，已终止；该运行不作为完整结果包验收。见 [中间日志](Results/header-top-library/xcodebuild.log)。
- **几何修复阶段库通过：** Xcode 26.6 / Debug，iPhone 17 Pro / iOS 26.5，完整 **61 通过、0 失败、0 跳过**；已读取终态 `.xcresult`。此结果早于原生边缘效果接入。见 [库结果](Results/header-top-library-final/Result.xcresult) 和 [摘要](Results/header-top-library-final/summary.json)。
- **中间完整 UI：** Xcode 27.1 / Debug，iPhone 18 Pro Max / iOS 27.0，16 通过、0 失败、0 跳过。此轮构建早于普通页首次占位补修，仅作为中间证据。工具在 300 秒超时后，继续读取同一次运行的日志和 `.xcresult`，确认最终成功。见 [中间 UI 结果](Results/header-top-full-ui.xcresult)。
- **视觉复查与方案调整：** 纯透明导航栏使折叠 Header 的大标题与导航按钮重叠。按用户指出的 iOS 26 `topEdgeEffect` API 改为上述原生滚动宿主；取消新系统上的手动裁剪。运行时截图已确认系统柔化效果与吸顶位置，见 [展开](header-top-expanded.jpg) 和 [折叠](header-top-collapsed.jpg)。新增库断言检查导航栏关联的滚动视图、禁用用户滚动及 contentOffset 与真实折叠量一致。
- **原生效果最终验收通过：** 完整 **61 项库测试 + 16 项 UI 测试 = 77 通过、0 失败、0 跳过**。库测试为 Xcode 26.6 / Debug / iPhone 17 Pro / iOS 26.5；UI 测试为 Xcode 27.1 / Debug / iPhone 18 Pro Max / iOS 27.0。UI 工具等待超时后已读取同一次运行的 `TEST EXECUTE SUCCEEDED` 终态和 `.xcresult`，没有重启该轮测试。
  - [最终库结果](Results/header-native-library/Result.xcresult) · [库摘要](Results/header-native-library/summary.json)
  - [最终 UI 结果](Results/header-native-ui/Result.xcresult) · [UI 摘要](Results/header-native-ui/summary.json)
- 两组 18 个源码、工程及测试输入文件的 SHA-256 一致，并与当前文件匹配；`sourceChangedSinceRun` 均为空。UI 覆盖初始 Header 与网格占位、列表与普通页纵向拖动、吸顶和旋转、横向分页、远距离标签切换、RTL、刷新、页面更新、Header 替换、异步滚动视图发现及返回手势。`git diff --check` 通过，最终 Demo 已重新打开至初始展开状态。
- **未执行：** 本次 Release、iPad、iOS 15–25 兼容分支的实际运行、真机、VoiceOver 全流程和性能基准。

## 标签按钮阻止横向拖动修复

原有屏幕外标签查找失败的直接原因是标签按钮的触摸跟踪阻止滚动接管。标签 Cell 使用 UIButton；UIKit 的默认 `touchesShouldCancel(in:)` 对 UIControl 返回 false。触摸先交付给按钮后再横向移动，标签栏没有滚动，重复拖动也无法使屏幕外标签进入视口。

标签栏现使用私有 UICollectionView 子类，仅对 UIButton 允许取消触摸跟踪，其他视图保留 UIKit 默认行为。原有 UI 测试的查找次数、拖动方式和断言未放宽。

- **修复前库复现：** 新增 `testTabButtonTrackingCanYieldToScrolling` 失败，验证标签按钮无法让出触摸。见 [库失败结果](Results/tab-touch-before-library/Result.xcresult) 和 [摘要](Results/tab-touch-before-library/summary.json)。
- **修复前 UI 复现：** 新增 `testHeldTabButtonYieldsToHorizontalDrag`，按住标签 0.4 秒后向左拖动 80 pt，实际标签位移为 0 pt，未达到大于 40 pt 的断言。见 [最终场景 UI 失败结果](Results/tab-touch-before-ui-left/Result.xcresult) 和 [摘要](Results/tab-touch-before-ui-left/summary.json)。
- 新增测试验证按钮跟踪可由滚动接管、其他控件默认行为、按钮点击回调、真实手势位移、拖动不误选页面及拖动后仍可点击切页。
- **中间场景修正：** 首次新增 UI 用例向右拖动，修复后标签实际移动约 38.7 pt 并到达内容起点，无法满足大于 40 pt 的断言。将手势改为有足够滚动余量的向左方向，保持位移断言不变；并以最终测试场景再次运行旧实现，仍为 0 pt 失败。此轮原有屏幕外标签查找用例已通过。见 [中间结果](Results/tab-touch-focused-ui/Result.xcresult) 和 [摘要](Results/tab-touch-focused-ui/summary.json)。
- **构建产物一致性诊断：** 首轮完整 UI 运行中，新增用例的源码与哈希均为向左 `-80 pt`，但实际执行日志仍记录向右 `+80 pt`。因此该轮不能作为最新测试场景的验收结果（14 通过、1 失败），见 [中间结果](Results/tab-touch-final-ui/Result.xcresult)。随后执行 clean 完整重建，同时核对源码哈希和实际手势日志，最终结果如下。
- **最终完整通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，执行 `clean test` 后完整 **58 项库测试 + 15 项 UI 测试 = 73 通过、0 失败、0 跳过**。原有屏幕外标签查找、LTR / RTL 分页、标签栏纵向拖动及普通页 Header 回归全部通过。
  - [最终库结果](Results/tab-touch-clean-library/Result.xcresult) · [库摘要](Results/tab-touch-clean-library/summary.json)
  - [最终 UI 结果](Results/tab-touch-clean-ui/Result.xcresult) · [UI 摘要](Results/tab-touch-clean-ui/summary.json)
- 两份终态结果均已读取；两组 28 个输入文件的 SHA-256 一致且与当前源码匹配，`sourceChangedSinceRun` 均为空。UI 日志确认测试文件重新编译且实际执行 `-80 pt` 的向左拖动，位移断言与后续页面选择通过；`git diff --check` 通过。
- **未执行：** Release、iPad、其他系统版本、真机、VoiceOver 全流程及性能基准。

## 普通页 Header 纵向拖动

无滚动视图页面现在可以从内容区、Header 和标签栏上下拖动共享 Header。内容区的纵向手势仅在当前页没有滚动绑定且存在折叠范围时启用；不添加滚动容器，不改变页面业务内容。位移限定在 Header 折叠范围内，惯性到边界停止。控件与独立手势区域保持自身交互；切页、重新绑定和布局更新会终止旧的拖动状态。

- **修复前复现：** 新增 UI 测试在普通页上滑后，等待 `progress=1.00` 超时，实际 1 项失败。失败对应未修复实现，运行结束时源码哈希一致。见 [修复前结果](Results/plain-header-before/Result.xcresult) 和 [摘要](Results/plain-header-before/summary.json)。
- 新增 4 项库测试在 UIWindow 中验证：部分折叠、完整折叠与展开、0 / 40 pt 保留高度、内容页上下边界、切页共享位置、切页后旧触摸失效、异步绑定滚动视图后旧触摸失效及新拖动恢复、高度变化钳制、无 Header / 无页面时拒绝手势，以及纵横方向判定。
- 新增 UI 测试验证：内容区连续上滑到吸顶、边界重复上滑、下滑展开、Header 上滑、标签栏下滑、内容页与标签栏及屏幕底边的几何关系、切页状态保留、再次拖动及横向翻页。
- **通过：** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5，完整 57 项库测试，0 失败、0 跳过。终态结果已读取，`sourceChangedSinceRun` 为空。见 [库结果](Results/plain-header-library/Result.xcresult) 和 [摘要](Results/plain-header-library/summary.json)。
- **完整 UI 回归：13 通过、1 失败、0 跳过。** 普通页新增用例通过，列表、短内容、Header 拖动、刷新、切页、页面更新、RTL、旋转返回和标签栏纵向拖动通过。原有 `testScrollableTabSelectionCentersAndHorizontalDragPreservesPage` 查找屏幕外标签 0 失败。见 [完整 UI 结果](Results/plain-header-ui/Result.xcresult) 和 [摘要](Results/plain-header-ui/summary.json)。
- **旧实现对照：** 临时仅将容器源码恢复为 HEAD 的修复前实现，以相同测试、工具链和设备单独运行上述失败用例，也因找不到屏幕外标签失败（本次为标签 9）。说明这类定位失败在旧实现上也存在，当时具体根因尚未定位；该次完整 UI 回归不标记为全通过。后续定位和修复见上方“标签按钮阻止横向拖动修复”。对照结束后已恢复修复源码。见 [旧实现对照](Results/plain-header-tabs-baseline/Result.xcresult) 和 [摘要](Results/plain-header-tabs-baseline/summary.json)。
- **最终专项通过：** 恢复最终源码后重新构建，普通页专项 UI 测试 1 通过、0 失败、0 跳过。见 [专项结果](Results/plain-header-final-focused/Result.xcresult) 和 [摘要](Results/plain-header-final-focused/summary.json)。库测试、完整 UI 测试及最终专项运行的 28 个输入文件哈希一致，并在该阶段核验时与当时源码匹配；`git diff --check` 通过。后续标签栏修复的最终源码结果见上方记录。
- **未执行：** Release、iPad、iOS 15 实际运行、真机、VoiceOver 全流程和性能基准。

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
