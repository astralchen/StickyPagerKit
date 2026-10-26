# StickyPagerKit 验证记录

验证日期：2026-10-15 至 2026-10-26。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

## 2026-10-26：绑定选择提交前的远程整合验证

推送前发现远程 `main` 已新增 `7602c11`、`bd67df4`，将本次绑定选择修改重放至远程最新版本。唯一文本冲突位于本文件，保留双方记录；容器、分页及 Demo 自动合并后重新验证，整合前的结果不作为合并后终态证据。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。库测试使用仓库 UIKit application host 脚本；Demo UI 使用官方 Xcode MCP 的 `StickyPagerDemo` scheme。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [整合后库专项](Results/20261026-binding-selection-integration-focused/summary.json) | **157 通过、0 失败、0 跳过** | 完整容器测试类、`SPPageViewportTests`、`SPPagingScrollViewTests`；四类运行时诊断均为 0。 |
| [整合后首轮 UI](Results/20261026-binding-selection-integration-ui/summary.json) | **5 项用例失败，另有 1 条 runner 错误** | 均在点击标签前失败；结果包另记录 runner code 75，不省略该错误。截图、日志与结果包保留。 |
| [修正夹具后 UI](Results/20261026-binding-selection-integration-ui-fixed/summary.json) | **5 通过、0 失败、0 跳过** | 不绑定列表独立滚动及分页、普通页面拖动、默认 Header／列表联动、快速分页选择、状态栏回顶部；四类运行时诊断均为 0，无运行时警告，`sourceChangedSinceRun=[]`。 |

首轮 UI 失败源于远程新增的工具栏遮挡计算与 iOS 27 AX 几何不兼容：标签区域为 `(0, 220, 440, 44)`，浮动工具栏 AX 宿主却为整窗 `(0, 0, 440, 956)`，使可点击高度被裁为 0。单项日志探针复现同一失败并确认该几何，保存在首轮目录的 `toolbar-probe/`；交付前已移除探针。测试辅助方法不再把覆盖整窗的透明工具栏宿主视作实际遮挡，普通工具栏仍按原规则裁切；真实点击、选中及行为断言保持不变，未改框架绑定实现。

库专项之后仅修改 Demo UI 测试辅助方法；该文件是库摘要中唯一的 `sourceChangedSinceRun` 项，不属于库编译目标。框架及库测试源码与执行时一致，最终 UI 对修改后的源码重新执行。7 个相关 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。

本轮未重跑完整库／Demo 套件，未执行 Release、Swift 6.3、iPad、旧版 iOS 或真机验证。远程历史记录中的 iPad 分屏终态偏移、Header 偶发吸顶及完整库 appearance 告警仍按原状态保留，不因本轮专项通过而认定已解决。

## 2026-10-26：绑定选择与首次生效的复查修复

复查发现并修复两类首次加载重入问题：`viewDidLoad` 中更新的运行时选择被外层初始请求覆盖；挂载回调重排／删除页面后，首次数据源查询仍使用旧索引或已移除控制器。初始请求仅在加载期间没有新选择时应用；各挂载阶段校验记录仍有效，查询索引按稳定标识从当前快照获取。保留三态 API、默认发现算法、nil 恢复自动发现以及既有布局、分页和位置恢复规则。README 补充回调契约。

新增 3 项回归：加载回调中的最新选择保留，挂载回调重排后的当前索引，加载／布局／挂载三个阶段删除页面后不再查询或重新挂载。修复前 3 项均失败，保留对应源码差异和测试证据。保留上一轮所有未提交修改。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 和目标；库测试使用仓库 UIKit application host 脚本，UI 使用官方 MCP。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前基线](Results/20261026-binding-selection-review-baseline/summary.json) | **0 通过、3 失败** | 复现新选择被覆盖、索引仍为 2 而非重排后的 0、已删除页仍收到首次查询。删除用例在修复后扩展为三个生命周期阶段。 |
| [修复后容器回归](Results/20261026-binding-selection-review-focused/summary.json) | **140 通过、0 失败、0 跳过** | 包含全部绑定选择及容器生命周期用例；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [修复后 UI 回归](Results/20261026-binding-selection-review-ui/summary.json) | **5 通过、0 失败、0 跳过** | 不绑定列表、普通页面拖动、默认 Header／列表联动、分页快速选择、状态栏回顶部；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0，无运行时警告。 |

全部 7 个修改／新增 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261026-binding-selection-review-ui/swiftformat-lint.txt)，`git diff --check` 通过。此次执行受影响的完整容器测试类及 5 项 UI 回归；未重跑全部库／Demo 测试套件，也未执行 Release、Swift 6.3 工具链、iPad、iOS 15 或真机验证。上一轮 283 项完整库结果保留为历史证据，不计为本轮执行。没有提交或推送。


## 2026-10-25：三类问题分开定位与状态查询修正

本轮以 `Results/20261025-three-paths-baseline` 保存的入口源码为基准，保留之前的用户修改和所有历史失败。没有恢复空闲期行几何拦截，没有关闭行高估算，没有放宽 0.5／1 pt 位置容差或 5／6 秒状态等待。

已确定的设计问题：Demo 每次 Header 进度更新都读取 `accessibilityValue`，回归模式因此遍历视图并序列化手势；现改为独立保存进度。初步版本尝试仅在文字变化时测量，复查后撤回该优化，保留字号与系统容器变化时的原有测量刷新，避免把本轮扩展成未经覆盖的标签测量变更。等待改用标识与短 label 的元素条件查询，避免 `XCTWaiter` 谓词回调中同步跨进程快照；没有增加预算或事后按“实际已正确”改判超时。探针测到旧查询单次约 0.1～1.4 秒，本轮未再次捕获旧 5 秒超时，因此这些修改消除了已知的冗余读取与等待嵌套，不等于已证明所有环境下都不会超时。

此前未收敛的原因与证据边界：

- 几何相关性不能区分 UIKit 估算补偿与业务定位。延长空闲期保护曾误伤原生定位，已按用户选择撤除；本轮不恢复该做法。
- 受控故障注入只证明预设收尾时序，不能替代真实分屏。全量调用栈探针抓到 `_updateVisibleCellsNow:` 内的 −10.5 pt 回写，但该次发生在受保护的布局内并恢复成功，尚不是历史终态失败的完整因果链。
- 全量堆栈采集会扰动主线程，后续缩小为实际空闲位置变化；中途读取完整列表后，估算 contentSize 会结算，故新增途中不读列表的路径，不能把有额外查询的用例通过当成原流程修复。
- Header 短拖动原先缺少原生释放速度。新增观测明确区分真实触摸、速度、惯性和几何变化，不从“拖动结束”推定速度必为零。

诊断轮次（均为独立记录，不是重跑取绿）：

- `20261025-three-paths-trace-build`：诊断代码使用不可用的 CGRect 字符串函数，编译失败，未执行测试；改为 `String(describing:)`。
- [减速后分屏探针](Results/20261025-three-paths-ipad-trace/summary.json)：1/1，通过用例内预设三轮浮动、并排与全屏恢复；未重现终态偏移。
- [原始长流程探针](Results/20261025-three-paths-original-trace/summary.json)：1/1，包含真实分页与旋转；正文初值 507 pt，不据此注销历史 582→571.5 pt 失败。
- [固定历史位置探针](Results/20261025-three-paths-exact-trace/summary.json)：LTR／RTL 2/2，包含浮动阶段的中间位置查询；尚不能覆盖没有中间查询的路径。
- `20261025-three-paths-light-ready`：新增可选代理观测缺少 `override`，编译失败；随后编译成功。
- [Header 探针错误](Results/20261025-three-paths-header-trace/summary.json)：三个用例均因新观测调用了无实现的父类可选代理方法而退出，另有一条 runner 错误，共 4 条失败。崩溃栈见 `probe-crash.ips`；已移除该 `super` 调用。这是本轮引入并修正的探针错误，不是原 Header 问题的复现。
- `20261025-three-paths-header-observed`：修正后 3/3，原系统容器用例及 LTR／RTL 合并触摸短拖动通过；[原生松手证据](Results/20261025-three-paths-header-observed/vertical-release-evidence.json) 显示三次 50 pt 输入均消耗约 40 pt、释放速度为 0。较长拖动即便有终点停留也记录到非零速度，不能只用触摸 API 参数推定惯性。旧偶发完全吸顶尚未捕获失败调用链，不标记已修复。

- `20261025-three-paths-unobserved-trace`：不中途查询列表的 582 pt LTR／RTL 分屏 2/2，包含切页与全屏恢复，四类诊断为 0；保留独立结果，不用通过覆盖旧的偶发失败。

撤除逐次日志／调用栈探针后的 `20261025-three-paths-terminal-ipad-ui` 再次在原生分屏捕获 **582 → 571.5 pt**，`testSystemSplitUnobservedExactRegressionPosition` 的 1 pt 断言失败。该失败优先于之前带探针通过的结果，说明目前不能将问题标为已修复；随后改用内存事件记录继续定位，不重跑旧用例取绿。

`20261025-three-paths-final-viewport` 的 12 项窗口专项通过，包含新加入的 582／513.5 pt 位置矩阵。`20261025-three-paths-terminal-library` 的完整 320 项 XCTest 断言通过，但运行时门禁捕获 4 条 appearance 不平衡，**整体失败**。告警发生于独立标签栏窗口夹具，原始行号 199、210、250、366 保留；本轮不将断言通过写成全量通过。

`20261025-three-paths-final-demo-cli` 与 `20261025-three-paths-terminal-demo-unit` 各 12 项 XCTest 断言通过，但分别有 2 条 appearance 不平衡，均按失败记录。发现 `DemoIndicatorContentTests` 在窗口显示期间挂载两个普通控制器，未等待真实 appearance 收尾便拆除窗口；改为先完成 containment，再通过实际 `viewDidAppear`／`viewDidDisappear` 回调等待，并新增父子控制器完整且成对的生命周期序列断言。没有手工补 begin/end 或放宽几何断言，修正后结果另记。

`20261025-three-paths-fixture-unit` 修正后 Demo 宿主 12/12，通过新增生命周期配对断言，四类运行时诊断为 0。该结果不覆盖完整库中的另外 4 条告警。原始分屏查询期间采样 `app-busy-sample.txt`：主线程 315 个样本中 313 个处于 RunLoop 事件等待，未观察到持续布局死循环；该采样不能排除未覆盖时段的短时重入。

官方 Xcode MCP 执行 Demo 测试超时 300 秒，后续日志查询未返回；CUA 获取 Xcode 状态也超时 51.4 秒。保留工具错误并改走明确设备与 scheme 的 CLI，未把工具超时算成 XCTest 通过。

终态结果（无临时框架探针）：

| 范围 | 结果与限制 | 证据 |
| --- | --- | --- |
| 窗口几何专项 | 12/12，诊断为 0；实际编译的框架／库测试与当前一致 | [窗口专项](Results/20261025-three-paths-final-viewport/summary.json) |
| 完整库 | 320/320 断言通过，但 4 条 appearance 不平衡，整体失败 | [完整库](Results/20261025-three-paths-terminal-library/summary.json) |
| Demo 宿主 | 12/12，新增生命周期配对断言通过，诊断为 0，全部源码哈希一致 | [Demo 宿主](Results/20261025-three-paths-fixture-unit/summary.json) |
| 系统容器 UI | 5/5，诊断为 0，全部源码哈希一致；包含 50 pt 短拖动、合并事件、旋转和 RTL | [系统容器](Results/20261025-three-paths-system-ui/summary.json) |
| iPad 原生分屏 | 2 通过、1 失败。原始 LTR 长流程及 RTL 固定 582 pt 通过；LTR 固定 582 pt 在分屏后变为 571.5 pt | [分屏失败](Results/20261025-three-paths-terminal-ipad-ui/summary.json) |

分屏与完整库的 `sourceChangedSinceRun` 仅列后续修正的独立 Demo 单元测试夹具，不在这两个运行的编译目标内；窗口专项还列出后续撤回文字测量优化的 Demo `AppDelegate.swift`，同样不在库目标内。各轮原始清单未重写。上述运行没有放宽位置或超时断言。六个相关 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；[源码审计](Results/20261025-three-paths-system-ui/final-source-audit.json)确认框架 Sources 与本轮入口逐字一致，状态等待的断言形式由 `XCTWaiter` 结果改为条件元素存在，原有几何断言保留。

进一步诊断另列，不纳入“修复后通过”：

- `20261025-three-paths-ring-build` 编译内存数组探针，未运行该版本；改为固定内存映射后在 `20261025-three-paths-ring-mmap-build` 编译成功。
- [单次内存取证](Results/20261025-three-paths-ring-position/summary.json) 1/1。不在滚动回调或无障碍 getter 中执行文件写入／堆栈采集；映射记录显示转场结束约 0.9 秒后仍有 −10.5 pt 原生 offset 回写，该次随后被现有交互缩放保护恢复。它没有产生终态失败，不能认定已捕获失败原因。
- [预定四轮采样](Results/20261025-three-paths-ring-four-samples/summary.json) 四次均通过，保留全部结果，不用于覆盖无探针失败。测试重装更换 data container，首轮映射文件未被固定旧路径监控取得；之后只读匹配诊断文件取得第 2–4 轮。前一批次日志单独标记为 `prior-single-sample`，不冒充首轮事件记录；详见同目录 `trace-capture-note.txt`。

交付源码已撤除全部临时框架探针，无额外业务接入或公开 API。状态查询的冗余读取及等待嵌套已修改，Demo 生命周期夹具问题已验证修复；**10.5 pt 原生终态偏移仍未修复，Header 偶发完全吸顶仍未定因，完整库 appearance 告警仍未解决**。这轮没有完成全部问题闭环，也不能声明完整回归通过。下一步缺的是失败当次从 UIKit 延迟结算、容器保护状态到保存位置提交的完整链路，不是继续增加一个空闲期回滚条件。

环境为 Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator；仅本轮相关库、Demo 宿主和列出的 UI 路径得到执行。未执行全部 Demo UI、Release、iOS 15、真机或性能基准。没有提交或推送。



验证日期：2026-10-15 至 2026-10-25。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

## 2026-10-25：原生定位优先、限定尺寸事务保护

按用户确认的行为边界，业务不增加任何更新／定位接入。移除 `SPScrollBinding.TableSettlement` 及空闲期行几何匹配回滚；只保留容器尺寸布局和 completion 同步收尾内的保护、范围钳制、布局重入标记及旧 completion 代际检查。转场收尾后原生 `performBatchUpdates`、`scrollToRow`、`setContentOffset` 继续记录新位置。

- [误拦截红灯](Results/20261025-native-position-red/summary.json)：旧实现对 −10.5／+17 pt 同步几何与业务定位回滚到 546，LTR／RTL 及切页恢复共 8 个断言失败。它是不可区分输入的受控回归，明确证明几何相关性不足以认定 UIKit 补偿。
- 原 `testLateEstimatedRowCompensationDoesNotBecomeSavedBodyPosition` 的“转场完成后未知来源位移应回滚”与新契约冲突。本轮将它改为 `testEstimatedRowCompensationInsideViewportTransactionDoesNotBecomeSavedPosition`，将故障注入放入 completion 触发的真实列表布局中，仍精确检查 546 pt 与切页恢复；另增事务结束后相同几何输入必须保留业务位置的回归。这是按用户授权调整保护范围，不宣称原测试逐字未改，也未放宽 0.5 pt 精度。入口源码保存在 `Results/20261025-native-position-baseline`，旧失败证据全部保留。
- [首轮专项](Results/20261025-native-position-focused/summary.json)：11 通过、1 失败。新增等行数更新夹具修改了不可见第 0 行，UITableView 继续使用旧估算高度，未产生预期 17 pt 重排。改为更新可见第 12 行，检查第 14 行精确增加 17 pt，保留全部容差；真实批量更新完成后再测试定位。没有靠重复运行取通过。
- [修正后专项](Results/20261025-native-position-green/summary.json)：12/12 通过，四类诊断为 0。包括立即／空闲后等行数更新、LTR／RTL、原生行定位、正负 offset 定位、切页恢复、事务内延迟结算、底部钳制和布局重入。后续新增 UI 测试文件，因此此轮摘要的源码差异会列出 UI 测试／辅助脚本。
- `20261025-native-gesture-probe` 未执行 XCTest：在构建已枚举文件后新增了 `NativeTouchPath.swift`，首轮编译找不到类型。保留日志，后续重新生成构建输入。

- [真实手势红灯](Results/20261025-native-gesture-ready/summary.json)：LTR／RTL 拖过半页后禁用实际 pan，收到 `.cancelled`，旧容器仍提交目标页及 `didSelectPageAt`。新增取消分支恢复原页，不改变普通松手的吸附与提交语义。
- 同轮甩动夹具失败：0.65 秒停顿覆盖整段 0.35 页快速输入，记录的 release velocity 为 0、吸附回原页，不能算非零速度验证。仅该新增夹具改为 0.06 秒停顿，使后续触摸自然形成速度；继续要求 release 非零且方向正确、半页以内借速度翻页、每次只提交一次及 1 pt 位移精度。原合并事件回归参数未改。
- 首次启动的预览桥接期间模拟器查询与构建严重停顿，机器 load average 达 451；停止该辅助进程后恢复。保留构建采样，未修改系统设置或重启已有 iPhone。连续折返使用固定设备的无预览桥接，避免额外预览轮询。

- `20261025-native-gesture-green` 与 `20261025-native-gesture-executed` 均为 **0 项执行**，不算通过。编译产物包含新方法，运行时平铺枚举也能找到完整标识；CLI 方法级 `-only-testing`（含／不含括号）未命中，改用 `.xctestrun` 副本的 `OnlyTestIdentifiers` 与 target 级筛选后实际执行。没有删除筛选、跳过失败测试或把工具成功码当成验证结果。

- `20261025-native-gesture-configured` 实际执行 4 项：LTR／RTL 真实取消和 RTL 甩动通过；LTR 甩动的速度、方向、位移、选择回调都通过，最终正文 546 对先前采集的 524 pt 失败。该用例此前在窗口缩放后分别远程读取列表 value、导航栏 frame 和 window frame；触摸开始时原始 position 已为 702（正文 546）。为排除跨帧组合，`contentPosition()` 改为一次应用快照取得这三项，仍用实际导航栏底边和原公式计算，不改容差、不把期望重设为当前值；新增原始坐标日志。首次差值记录保留，不仅凭后来通过宣称已捕获旧次偏移的全部时序。
- `20261025-native-reversal` 为 1 通过、1 失败：RTL 同一手势折返的两个物理方向通过；LTR 桥接冷启动时首个移动延迟约 1.2 秒，后续移动时间戳间隔约 0.00025 秒，pan 为 `.failed`、实际分页为 0，未满足越过半页断言。新增静止触摸的送达检查，确认完整 began→ended 且未选页／改正文后，再开始一次触摸的折返；不删除半页门槛、净位移或同次手势断言。每次折返仍核对 sequence 恰好增加 1。

完整库 320/320、LTR／RTL 甩动与真实取消 4/4，四类运行时诊断均为 0。首次 Demo 宿主 12/12 后仍调整了回归状态读取；最终通过官方 Xcode MCP 对这些 Demo 变更再次执行 12/12。库测试完成后未改动库生产代码或库测试源码；最终审计按各结果的实际编译范围核对，不将全仓哈希变化隐藏。

`20261025-native-reversal-ready` 中 LTR 通过，RTL 第二次折返的长状态 value 查询耗尽 5 秒；结果包另记录 runner 以 code 75 提前退出，因此摘要为 3 条结果（1 通过、2 失败），并非只有一条失败。该次后续诊断仍显示原页、正确净位移及正文 546，不能据此抹掉等待失败。Demo 回归模式增加精简 `accessibilityLabel`（同源状态，完整触摸仍保留在 value），等待改读新快照 label，保留原 5／6 秒预算。`20261025-native-reversal-observed` 两项均实际通过，四类诊断为 0；随后仅把其他旋转与系统容器等待也切换到同样短状态读取。

`20261025-native-final-nested-ui` 为 6 通过、2 失败：五项嵌套横向滚动及 LTR 系统旋转通过；Header 50 pt 短拖动完全吸顶，违反原有部分折叠断言；RTL 方向等待超时，但失败信息中的当前方向已为期望值。失败未删除，后续增加纵向 pan 状态／速度输入观测，并用同样短状态快照核对方向；不改拖动距离、保持时间或位置断言。

[带纵向观测的定向诊断](Results/20261025-native-system-input-trace/summary.json) 两项通过，原始 50 pt 短拖动的 [输入记录](Results/20261025-native-system-input-trace/vertical-input-traces.json) 显示内容位置由 0 到约 40 pt，保持部分展开。它没有重现上一轮完全吸顶，**该偶发失败仍未定因，不算已修复**；方向检查的 5 秒预算也未改变。

`20261025-native-final-ipad` 被沙箱拒绝连接 CoreSimulator，未执行用例；随后通过已授权的本机访问启动完整八项 iPad 回归，环境失败单独保留。

| 本轮验证 | 结果 | 证据 |
| --- | --- | --- |
| 完整 UIKit 库 | 320/320，四类诊断为 0 | [库结果](Results/20261025-native-final-library/summary.json) |
| 最终 Demo 宿主 | 12/12，四类诊断为 0 | [官方 MCP](Results/20261025-native-demo-terminal-unit/mcp-result.json) |
| LTR／RTL 非零速度与真实取消 | 最终 4/4，四类诊断为 0，源码一致 | [松手同刻测量](Results/20261025-native-release-measured/summary.json) |
| LTR／RTL 同次触摸反向 | 2/2，四类诊断为 0 | [HID 折返](Results/20261025-native-reversal-observed/summary.json) |
| 嵌套滚动与系统容器 | 首轮 6/8；定向诊断 2/2，Header 偶发失败未定因 | [首轮失败](Results/20261025-native-final-nested-ui/summary.json)、[定向诊断](Results/20261025-native-system-input-trace/summary.json) |
| 原始 iPad 分屏 | **7/8，通过 7、失败 1**，四类诊断为 0；之后仅修改独立甩动用例 | [原生结果](Results/20261025-native-ipad-executed/summary.json) |

iPad 八项终态 UI 已结束，LTR／RTL 合并触摸、Header 往返、513.5 pt 行边界恢复以及 RTL 完整分屏均通过；LTR 完整分屏失败（[坐标摘录](Results/20261025-native-ipad-executed/ltr-failure-excerpt.txt)、[失败截图](Results/20261025-native-ipad-executed/ltr-attachments/CDC2C4A8-0BA4-4EC8-8FC8-4ABFD7380A31.png)）：同一快照公式下，进入窗口操作前正文为 582 pt（raw 716、safeTop 86），并排窗口后为 571.5 pt（raw 705.5、safeTop 86），真实减少 10.5 pt，原 1 pt 断言保留并报错。可见第 7 行高度仍为 73.5 pt，contentSize 从 5880 到 6384；这些几何变化不足以判定 offset 回写的完整调用链。当前事务保护尚未覆盖这条路径；不恢复会误伤业务定位的空闲期启发式，不重置预期位置，也不以其他窗口用例通过抵消该失败。

最终观测代码上的四项手势复核 `20261025-native-gesture-terminal` 为 2 通过、2 失败（[结果](Results/20261025-native-gesture-terminal/summary.json)）。LTR 取消在手势前的 5 秒状态等待超时，失败信息已是期望的 `page=list`；说明精简 label 尚未根除查询超时，不能将后续通过说成该问题已修复。RTL 取消和甩动均通过。

同轮 LTR 甩动的新增测试误把松手后的减速也算入手指行程：[完整取样](Results/20261025-native-gesture-terminal/paging-traces.json)记录起点 750、获准触点 197.5、末端触点 319，松手回调 offset 628.5，精确满足 `750 - (319 - 197.5)`；`super.sendEvent(.ended)` 返回后的 offset 已是 612.5。原测试取整个事件样本的 min/max，因包含后续 16 pt 减速而得到 137.5 对 121.5 的失败。仅新增甩动测试改为松手回调的 offset 检查同一物理等式，仍保留 1 pt、非零速度及方向、半页以内、最终一页和一次选择回调，另要求触摸正常 ended；既有零速度位移测试及生产补偿算法未改。修改前测试源码与失败结果保留，不将此取样修正混同于解决原生分屏 10.5 pt 偏移。

[源码审计](Results/20261025-native-final-library/final-source-audit.json)确认本轮未改分页补偿算法、标签栏或 Header 布局；完整库及最终 Demo 宿主的实际编译范围与当前一致。旧 UI 断言未删除；库几何精度 0.5 pt、UI 精度 1 pt，等待预算 5／6 秒均保留。8 个相关 Swift 文件通过 SwiftFormat 0.64.0 lint，脚本回归 8/8，`git diff --check` 通过。

环境为 Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator。使用 iPhone 17 Pro 与 iPad Pro 13-inch (M5)；Demo 宿主优先走官方 Xcode MCP，库 scheme 未暴露及指定 iPad／HID 输入的 UI 回归使用命令行产物。未执行全部 Demo UI、Release、iOS 15、真机、VoiceOver 或性能验证。没有提交或推送。

[修正取样后的四项验证](Results/20261025-native-release-measured/summary.json) 实际 4/4 通过、无 skip、四类诊断为 0，全部源码哈希一致；这不代表之前的状态查询超时已根治。原生八项 UI 运行结束后仅修改 `verifyMomentumPaging`，审计确认该函数之外的测试全文相同。HID 折返通过后仅调整了它不调用的旋转与甩动辅助方法，以及独立系统容器测试，未重跑折返。已关闭本次 iPad 和目标桥接，保留原有 iPhone 会话。

## 2026-10-25：空闲期行高结算、布局重入与合并分页事件修复

本轮保留历史 10.5 pt 正文偏移与 RTL 分页位移失败，未放宽原有 0.5 pt 库测试／1 pt UI 位置精度，也未把重复运行偶然通过当成修复依据。

- `20261025-idle-offset-trace` 原始 LTR 分屏同样失败：分页只移动 229.5 pt，未达到 511 pt 视口的一半；该批次剩余 RTL 用例主动取消。这说明失败不限于 RTL。
- `20261025-row-boundary-pan-trace` 的固定 513.5 pt 原生窗口往返通过，但原始 RTL 分页仍失败（239 < 255.5 pt）。完整触摸记录 `sp-pan-45279-5.json` 显示：方向判定通过后，一次含 24 个合并触点的移动使 translation 清零，丢失约 109 pt。相同 frame／contentSize 回写发生于前一次手势，距失败手势约 56 秒，不能据此归因于重复赋值。
- `20261025-native-idle-viewport-red` 的真实 UITableView 空闲期窗口测试通过，覆盖 LTR／RTL 与正文 503、513.5、524、535.5 pt；目录名中的 red 不代表该测试失败。它说明单纯等待估算结算不足以稳定复现历史偏移。
- `20261025-late-compensation-red` 受控模拟转场结束之后，同一可见行坐标、总高度和 offset 同步修正，LTR／RTL 均失败：期望正文 546 pt，实际为约 535.67 或 563 pt，切页恢复也错误。该测试明确是几何故障注入，不冒充捕获了历史 UIKit 主动页回写的完整链路；普通程序化 ±10.5／37 pt 定位另行保留断言。
- `20261025-coalesced-pan-red` 两项新夹具在窗口宽度前置条件失败，尚未进入分页检查。只调整了该新增用例的系统窗口缩放输入（-250/-350 → -500/-600），保留宽度 < 650 的断言。`20261025-coalesced-pan-ready` 达到半页并翻页成功，但诊断仍显示丢失位移，故新增识别后触摸与实际分页位移的 1 pt 等式断言；不是削弱原断言。
- `20261025-coalesced-distance-red` 使用上述严格断言与一次 0.65 秒测试专用主线程停顿，旧分页实现 LTR 实际移动 208.5 pt，而方向获准后触摸移动 249 pt。诊断显示 `gestureRecognizerShouldBegin` 与 `scrollViewWillBeginDragging` 之间的移动在 translation 清零时丢失。
- `20261025-late-compensation-green` 在重复 Package 解析期间主动中止，随后构建中断；未执行 XCTest，不能计为通过。接下来的运行使用新目录，保留全部原始日志。

`20261025-settlement-focused` 的 11 项窗口／分页库测试通过。严格合并事件红灯为 LTR 208.5 vs 249 pt、RTL 209 vs 249.5 pt；`20261025-coalesced-distance-green` 两项通过，正向、反向和取消的实际移动均与识别后的移动一致。

`20261025-settlement-library-final` 完整 317 项中 316 项通过，1 项新增测试失败：插行业务负例用插行前位置计算后续定位，但插行本身结算了先前注入的估算坐标。修正为完成插行布局后记录业务定位起点，仍断言后续精确增加 17 pt，保留 0.5 pt 精度；没有修改生产实现来迎合该负例。该首轮还在未修改的 `SPTabBarCustomContentTests.testStateHighlightActivationAndDisabledSelectionStayCoordinated` 出现 1 条 appearance 不平衡警告，原因尚未定位；不能用后续干净结果宣称警告已经修复。

`20261025-settlement-library-verified` 未进入 XCTest，持续重复 Package 解析。采样见同目录 `package-resolution-sample.txt`，主线程等待 Package 加载并递归同步工作区文件。先发中断信号未退出，再终止本次构建进程，保留日志；随后库构建与 UI 验证改为顺序执行。此目录不能计为测试通过或测试失败。

`20261025-settlement-ipad-final` 为 5 通过、1 失败。原始 RTL 完整分屏、LTR／RTL 合并事件和两方向 513.5 pt 行边界恢复通过；LTR 完整流程在最后一次 Header 35 pt 短拖动后得到 progress=1，违反原有部分折叠断言。截图确认实际完全折叠，不能把这一整轮记为成功。`20261025-header-partial-trace` 的两个最小原生流程通过，仅表明未稳定触发原始间歇问题，不作为修复证据。

随后新增明确的布局重入回归：缓存页布局重入父容器，再产生当前页的中间 offset 回写，最后恢复实际位置。`20261025-layout-reentry-red` 在 LTR／RTL 均失败，实际位置已恢复 45 pt，但共享折叠量变成 158 pt，切页也恢复错误。根因是内层 `viewDidLayoutSubviews` 退出时直接清除外层保护标记。改为恢复进入时标记后，`20261025-layout-reentry-green` 10 项窗口回归通过。受控回归证明该重入缺陷，尚不能仅凭它断言捕获了原始 Header 失败的完整调用链；仍需执行原始用例。

该绿灯阶段发现新增业务插行夹具在批量更新尚未完成时关闭窗口，出现 UITableView 离开层级后布局警告。夹具改为等待批量更新 completion，仍验证数据更新后的业务定位精确增加 17 pt；几何基准的采集与匹配也要求列表仍挂载到窗口。最终回归覆盖这些修改。

`20261025-settlement-nested-ui` 的 8 项真实 UI 回归通过，包含 5 项嵌套横向列表交接与 3 项系统容器、旋转、RTL 检查；该批次在重入保护修复之前构建，作为分页位移修复的中间证据，不计入重入修复后的终态验证。

Package 构建改用验证脚本的临时副本，仅固定仓库 cwd 并将本轮证据输出到 `/private/tmp/sp-validation/<运行名>`，所有源码、Package、目标、断言和编译参数不变，结束后完整归档回 `Validation/Results`。重入红灯在这一方式下完成，没有删除已有结果；脚本副本随结果保存。提取 iPad 结果时首次并行读取同一 xcresult 遇到 database.sqlite3 初始化冲突，错误摘要保留为 `summary-export-race.json`，附件导出结束后顺序提取成功；没有重跑测试。

分页补偿的初版使用 `setTranslation`。[Apple 的该 API 契约](https://developer.apple.com/documentation/uikit/uipangesturerecognizer/settranslation(_:in:))明确说明它会重置速度，因此没有仅凭位移通过就保留该实现。新增起拖速度非零与物理方向断言后，`20261025-pan-velocity-red` 两项实际通过；目录名不代表失败，也没有观察到当前 iOS 26.5 上的速度重置。最终改为在分页接管之后调整一次滚动起点，不修改 pan translation／velocity。`20261025-pan-offset-green` 两项通过，覆盖 LTR／RTL 正反向分页、短拖动取消、精确位移与起拖速度，全部源码哈希一致。

`20261025-settlement-library-terminal` 318/318 通过，但仍使用前述初版分页补偿，仅作中间证据。`20261025-settlement-ipad-terminal` 因清理临时 Header 探针时遗漏一处 Demo 调用而构建失败，未执行测试；随后移除遗漏调用，保留失败结果。终态回归使用已清理探针、采用滚动起点补偿的源码，单独记录，不覆盖这些结果。

| 终态验证 | 结果 | 证据 |
| --- | --- | --- |
| 完整库 | 318/318 通过，四类运行时诊断为 0 | [完整库](Results/20261025-final-library/summary.json)，包括延迟行高、底部钳制、布局重入、缓存恢复及既有标签栏回归。 |
| Demo 宿主 | 12/12 通过，四类运行时诊断为 0 | [官方 MCP](Results/20261025-final-demo-unit/mcp-result.json)，覆盖 Header、大字号、完整／紧凑卡片和指示器。 |
| 嵌套滚动与系统容器 UI | 8/8 通过，四类运行时诊断为 0 | [真实手势](Results/20261025-final-nested-ui/summary.json)，包含 5 项 CompositionalGestureTests 和 3 项 SystemContainerTests，覆盖 LTR／RTL、边界交接、分页往返及旋转恢复。 |
| iPad 分屏 UI | 8/8 通过，四类运行时诊断为 0 | [iPad 终态](Results/20261025-final-ipad/summary.json)，包含原始 LTR／RTL 完整分屏、合并触摸、Header 部分折叠和 513.5 pt 行边界往返各两项。 |

四组均与当前 79 个源码／配置／脚本文件一致。[源码审计](Results/20261025-final-library/final-source-audit.json)确认：本轮既有窗口库测试和 UI 测试没有删除或替换原始行，新增回归保留 0.5 pt／1 pt 精度；标签栏、卡片和布局配置与本轮开始时一致。7 个相关 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。历史 appearance 警告仍按上文保留为未定因问题，不因本轮诊断为 0 而宣称修复。

原始 LTR／RTL 完整分屏分别耗时 685.254／492.231 秒，均完成竖屏→横屏→竖屏、短页往返、正文恢复，以及 Header 展开／部分折叠／再次吸顶；没有重试失败手势或改变半页门槛。已导出并核对 [LTR 部分折叠](Results/20261025-final-ipad/ltr-attachments/B5FA208D-4B2C-45BE-8C56-AC35F14C3B26.png)和 [RTL 横屏正文](Results/20261025-final-ipad/rtl-attachments/4142B4E3-CB93-48AD-8D8D-7012E3F849A8.png)。本轮受控红绿回归证明延迟几何补偿、布局重入及起拖位移丢失缺陷已修复；历史 10.5 pt 原生失败的完整 UIKit 内部调用链仍未捕获，不能以本次原生通过替代这一证据限制。

环境为 Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator，使用 iPhone 17 Pro 与 iPad Pro 13-inch (M5)。Demo 宿主通过官方 Xcode MCP 执行；库 scheme 未由 MCP 暴露，库使用独立 UIKit 宿主脚本；UI 复用已构建且源码哈希一致的最终产物。未执行全部 Demo UI、Release、iOS 15、真机、VoiceOver 或性能验证；未修改系统设置、擦除模拟器、提交或推送。已关闭本次启动的 iPad，保留原有 iPhone 会话。

## 2026-10-25：转场收尾保存位置同步钳制

复查发现，尺寸转场收尾的额外页面布局可能进一步缩短列表可滚动范围。原实现最后一次 `align` 只限制实际 offset，没有同步限制 `positions`；转场保护又会拦截这一阶段的滚动记录，因此窗口再次缩小、合法范围增大时会恢复过期的正文位置。本次只在收尾布局之后、最终对齐之前同步限制该页保存位置，当前页及已加载缓存页使用相同规则。Header 折叠量、选择提交、delegate 与 RTL 索引契约不变。

新增两项真实 UIWindow／UITableView 回归，分别验证当前页和缓存页，每项均执行 LTR／RTL。从距离底部 12 pt 开始，在转场最后恢复 offset 后受控结算 24 行的行高（84 → 73.5 pt），通过真实 UITableView 重排确认 contentSize 缩短，再检查底部、切页、三轮窗口尺寸往返、Header 吸顶位置、横向分页位置和后续正常滚动。该夹具明确模拟延迟结算时序，不声称捕获了历史 UIKit 内部估算回写；既有 automaticDimension 回归仍保留。

[旧实现红灯](Results/20261025-split-clamp-red/summary.json) 2/2 失败：再次缩小窗口后正文为 1222 pt，期望 970 pt，偏差 252 pt，当前页／缓存页与 LTR／RTL 均触发。保存了该轮生产与测试源码。[修复后专项](Results/20261025-split-clamp-green/summary.json) 11/11 通过，四类运行时诊断为 0；红绿两轮新增测试源码逐字一致，唯一源码差异为生产修复，没有扩大 0.5 pt 断言或重写恢复基准。

[完整库首轮](Results/20261025-split-clamp-library/summary.json) 315 项断言通过，但出现 2 条 appearance 不平衡诊断，按验证规则整轮判为失败。警告分别出现在独立标签栏夹具 `testConfiguredButtonHonorsMinimumSizeAndDynamicConstraintChanges` 和 `testStateHighlightActivationAndDisabledSelectionStayCoordinated`，对应测试不包含分页容器；原始日志保留。保持所有源码与诊断规则不变，[两个测试类隔离复验](Results/20261025-split-clamp-appearance-isolated/summary.json) 36/36 通过、诊断为 0；随后[完整库复验](Results/20261025-split-clamp-library-verified/summary.json) 315/315 通过、诊断为 0。首次警告未重现，具体原因仍未确认，不将其描述为已修复。

| 终态验证 | 结果 | 证据 |
| --- | --- | --- |
| iPhone 完整库 | 315/315 通过，四类诊断为 0 | [完整库复验](Results/20261025-split-clamp-library-verified/summary.json) |
| Demo 宿主 | 12/12 通过，四类诊断为 0 | [官方 Xcode MCP 结果](Results/20261025-split-clamp-demo-unit/mcp-result.json)，覆盖 Header、大字号、完整／紧凑卡片与指示器。 |
| iPad 窗口几何 | 7/7 通过，四类诊断为 0 | [iPad 专项](Results/20261025-split-clamp-ipad-geometry/summary.json)，包含两项新增延迟结算回归。 |
| iPad 真实触摸首轮 | 1 通过、3 失败，四类诊断为 0 | [UI 批次](Results/20261025-split-clamp-ipad-ui/summary.json)：LTR 连续缩放通过；原始失败保留；后续复验单独记载。 |
| iPad 真实触摸终轮 | 2 通过、1 失败，四类诊断为 0，源码一致 | [最终原生复验](Results/20261025-split-clamp-final-native/summary.json)：LTR 分屏、RTL 连续缩放通过；RTL 分屏手势失败。 |

UI 首轮的 LTR 分屏在方向等待中读取到 `<无状态值>`，结束状态及截图均为目标竖屏，但尚未执行该阶段正文位置断言；RTL 分屏因系统 Settings 启动超时中止；RTL 连续缩放在第二次系统窗口拖动后宽度变化为 0 pt，未满足原有大于 40 pt 的输入生效断言。没有放宽任何断言，也没有把截图可见当作通过。LTR 连续缩放完整通过（526.051 秒），覆盖浮动窗口、多轮 Header 展开／部分折叠／吸顶、分页返回、恢复全屏及后续滚动保存。已导出截图、UI 层级及录屏到 `Results/20261025-split-clamp-ipad-ui/all-attachments/`。

测试服务在首轮后已关闭 iPad；重新启动本次 iPad 并通过 bootstatus 确认启动完成，再正常启动同一 Settings 陪测应用，未修改系统设置或擦除设备。[UI 原样复验](Results/20261025-split-clamp-ipad-recheck/summary.json)复用首轮同一构建产物，LTR 捕获到真实正文偏移：503.0 / 513.5，仍相差 10.5 pt，容差保持 1 pt。随后主动取消 RTL 用例并进入针对性诊断；不把该次偏移归类为环境失败，也不再据此前通过记录声称完整 UI 回归通过。新底部钳制的红绿证据有效，但原生分屏仍有待定位的回写路径。临时诊断只用于定位，已全部移除，不纳入交付源码。

[带调用栈诊断的原生分屏运行](Results/20261025-split-clamp-native-kvo-trace/summary.json) 1/1 通过，但含临时探针，不能充当最终源码验证。保留了当时三个探针源码及 `sp-size-trace-38672.log`：转场保护期间 `_updateVisibleCellsNow:` 回写 -10.5 pt，保存位置未覆盖且随后恢复；另有转场结束后 `_prefetchCellAtGlobalRow:aboveVisibleRange:` 的 -10.5 pt 回写，本轮随后也恢复，未造成断言失败。因此预取是后续排查线索，尚不能认定它就是此前 503.0 / 513.5 失败的原因。读取无障碍几何前后值一致，未证实查询本身造成偏移。诊断初轮、方向等待失败轮及日志均保留，没有以诊断通过覆盖原生失败。

最终无探针复验中，LTR 原生分屏通过（360.987 秒）；RTL 分屏在横屏第三次正向分页的输入断言失败：683 pt 视口下实际分页位移 304 pt，未超过原有 341.5 pt 半页门槛。触摸记录起止坐标差 478 pt，但 pan translation 为 304 pt，UIKit 最终回到原页；之前的正文／Header 检查通过。未确认此次位移不足的具体原因，不将其直接归为环境失败，也未改动手势或断言。RTL 连续缩放随后完整通过（434.721 秒），覆盖多轮窗口变化、Header 状态、切页返回、恢复全屏和后续滚动保存。该终轮最终为 2 通过、1 失败，四类运行时诊断为 0，源码哈希一致。完整结果见 [最终原生复验](Results/20261025-split-clamp-final-native/summary.json)；已导出全部附件并核对 [RTL 失败截图](Results/20261025-split-clamp-final-native/attachments/67A4C78B-7339-4D85-B171-33F6A0914AAB.png)。本次不能宣称完整原生 UI 回归通过，也未证明之前的 10.5 pt 间歇偏移已消失。

[最终源码审计](Results/20261025-split-clamp-final-native/final-source-audit.json)确认移除探针后的全部 79 个源码／配置／脚本文件与完整库、Demo 宿主和 iPad 几何通过时一致，红绿两轮新增测试源码也逐字一致。两个本轮修改的 Swift 文件通过 SwiftFormat 0.64.0 lint；`git diff --check` 通过。

本轮没有修改 Demo、既有 UI 用例或诊断脚本，UI 位置断言保持 1 pt。库 scheme 未由官方 MCP 暴露，库与指定 iPad 目标的 UI 使用验证脚本，Demo 宿主使用官方 MCP。环境为 Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator；iPhone 17 Pro 与 iPad Pro 13-inch (M5)。未重跑全部 Demo UI、Release、iOS 15、真机、VoiceOver 或性能验证；历史失败不删除。已关闭本次启动的 iPad，保留原有 iPhone 会话；未提交或推送。

## 2026-10-25：iPad 分屏正文位置回写保护

针对上一轮 `535.5 / 546.0` 的 10.5 pt 偏移继续排查。原生 UITableView 现场的估算行高为 84 pt、实际行高为 73.5 pt；该差值提供排查线索，但没有捕获历史失败那次 UIKit 回写的调用栈，不能仅凭差值断言具体内部实现。排查确认一个可重复的保护缺口：尺寸转场 completion 最后恢复 offset 后可能再次安排列表布局，旧实现随即解除 `isTransitioningSize`，后续布局的 offset 回写会覆盖保存的正文位置。

新增受控延迟布局回归（真实 UIWindow、UITableViewController、导航容器，LTR／RTL）：模拟恢复 offset 后下一次列表布局回写 -10.5 pt。旧实现的[红灯证据](Results/20261025-split-deferred-red/summary.json)为 1 项失败；在 3x iPhone 宿主上首次读到 535.6667 / 546，之后多次缩放继续累积。此用例明确属于故障注入，不冒充历史系统分屏失败的原生复现。修复只在尺寸转场 completion 中增加页面布局收尾并再次对齐，待回写消化后才解除保护；不修改估算行高、选择时序或滚动 delegate。

库回归覆盖真实窗口／父视图缩放、regular／compact、安全区域与导航栏变化、中间尺寸、LTR／RTL、缓存页面切回，以及保护结束后的正常滚动和恢复。UI 新增精确 546 pt 起点的 LTR／RTL 双轮全屏→浮动→分屏→恢复、短页往返，以及三轮真实滑动减速后的分屏恢复。原有失败用例及其位置容差保持不变：库测试 0.5 pt、UI 1 pt；没有扩大断言或重写保存基准。

排查过程中的失败均保留：`20261025-split-unit-red` 是新增夹具漏算窗口继承安全区域，后改为使用实际 safeAreaInsets；`20261025-split-exact-trace` 是测试入口误用库内部成员的编译失败，改用 Demo 自有子控制器；`20261025-split-trace`、`20261025-split-trace-ready`、`20261025-split-position-trace`、`20261025-split-exact-trace-build` 和 `20261025-split-no-trace-red` 涉及模拟器 AX 查询／Settings 启动超时，最后一轮主动取消后仅重启本次启动的 iPad。截图可见页面并不等于无障碍断言通过，不把这些运行计为通过。未修改系统设置或擦除模拟器。

修复前的原生排查中，`20261025-split-exact-ready` 的精确起点双轮恢复和 `20261025-split-deceleration-trace` 的三轮减速恢复均通过；四项窗口几何测试在 `20261025-split-navigation-red` 通过。这说明历史偏移具有间歇性，不能以偶然通过代替回写保护的红／绿对照。

[修复后专项](Results/20261025-split-deferred-green/summary.json) 5/5 通过，四类运行时诊断为 0。该批次启动后还清理了 Demo 临时探针、补充正常滚动恢复断言，因此摘要标记了源码变化；最终一致性以随后完整回归为准。

[完整库首轮](Results/20261025-split-final-library/summary.json) 313 项断言通过，但诊断检测到 1 条 appearance 不平衡警告，整轮判为失败；警告出现在独立标签栏的 `testCandidateMeasurementsPreserveSelectionAnimationAndAccessoryConstraints`，该夹具不包含分页容器。未删除警告，也未将断言通过误报为整轮通过。

[完整库复验](Results/20261025-split-library-verified/summary.json) 在源码不变的条件下 313/313 通过，四类运行时诊断均为 0；首次 appearance 警告未重现，原因未进一步确认，不将其归结为本次生产修复。

[Demo 宿主](Results/20261025-split-final-demo-unit/mcp-result.json) 通过官方 Xcode MCP 执行，12/12 通过、四类诊断均为 0，[源码审计](Results/20261025-split-final-demo-unit/source-audit.json) 一致。

[iPad UI 首轮](Results/20261025-split-final-ipad/summary.json) 在分屏前的状态等待失败：XCTWaiter 返回超时，但同次失败信息中的真实状态已经包含 `progress=1.00`。日志显示轮询先查询 exists 再查询 value，两次远程查询耗尽 5 秒预算。停止批次并保留当时测试源码，将状态与方向轮询改为每次获取一个新的 XCUIElementSnapshot；状态条件、5／6 秒等待预算和全部位置精度不变，不缓存旧快照、不补发触摸。生产代码及单元测试没有变化。

[快照轮询复验](Results/20261025-split-ipad-snapshot/summary.json) 发现 XCUIElementSnapshot.value 只返回前 512 个字符，手势诊断较长时状态字段被截掉，故再次中止并保留源码。最终辅助方法每轮重新解析元素并直接读取一次完整 value，移除重复 exists 查询；保留原始诊断字段与全部等待预算。iPad 后台 mediaanalysisd 持续高占用时，两次仅对已核对属于该设备的进程发送 SIGTERM（系统按需自动重启），没有修改服务配置或数据。

[原始 LTR 分屏手势复验](Results/20261025-split-ltr-verified/summary.json) 1/1 通过，耗时 327.552 秒，四类诊断均为 0，源码哈希一致。覆盖竖屏／横屏分屏、短距离取消、各方向三轮短页往返；原用例位置断言仍为 1 pt。剩余窗口专项复用该轮同一已构建产物执行。

[iPad 剩余专项](Results/20261025-split-ipad-remaining/summary.json) 6 通过、1 失败，四类诊断为 0，源码哈希一致。通过项包括减速后三轮恢复、LTR／RTL 精确 546 pt 双轮恢复、RTL 分屏取消／分页、LTR／RTL 连续缩放。唯一失败的带附件缩放在状态查询返回 `<无状态值>` 时中止，尚未进入该阶段的正文位置断言；保留失败证据并隔离复验。

[Gallery 共用辅助方法复验](Results/20261025-split-gallery-verified/summary.json) 在 iPhone 上 1/1 通过，四类诊断为 0、源码哈希一致，覆盖全部指示器预设、自定义卡片及旋转后选择。带附件失败截图可见正确列表和状态标签，但无障碍值读取失败，截图不代替断言；关闭并重新启动本次 iPad，保持源码与断言不变进行独立复验，不再启动分屏陪测应用。

[附件独立首轮](Results/20261025-split-accessories-verified/summary.json) 1 失败：启动后的入口点击没有进入 Demo，5 秒后首个标签不存在；截图及 UI 层级仍为正常入口页，尚未执行窗口缩放。没有补发点击或放宽入口断言，保留证据后在已稳定启动的同一设备按原样复验。

[附件独立复验](Results/20261025-split-accessories-warm/summary.json) 1/1 通过，耗时 521.342 秒，四类诊断均为 0，源码哈希一致；包括连续缩放、分页往返、恢复全屏、Header 三种折叠状态、再次滚动和搜索附件弹窗。原状态条件、等待预算及位置容差均未改变。

本轮终态覆盖如下，不将含失败的整次运行改写为通过，也不重复统计复跑用例：

| 终态验证 | 结果 | 证据 |
| --- | --- | --- |
| 完整库 | 313/313 通过 | [完整库复验](Results/20261025-split-library-verified/summary.json)，含 5 项新增窗口回归及原有取消／重叠转场测试。 |
| Demo 宿主 | 12/12 通过 | [官方 MCP 结果](Results/20261025-split-final-demo-unit/mcp-result.json)，覆盖卡片、Header、大字号与指示器。 |
| 原始 LTR 分屏失败用例 | 1/1 通过 | [独立复验](Results/20261025-split-ltr-verified/summary.json)，保留原正文位置断言。 |
| 其他 iPad 专项 | 6 项通过 | [批次结果](Results/20261025-split-ipad-remaining/summary.json)中 6 项通过；该批次另有 1 项附件状态读取失败，以上述独立复验补齐。 |
| iPad 附件缩放 | 1/1 通过 | [独立复验](Results/20261025-split-accessories-warm/summary.json)。 |
| iPhone Gallery | 1/1 通过 | [旋转及指示器预设](Results/20261025-split-gallery-verified/summary.json)，验证共用状态读取的另一入口。 |

共 9 项不同 UI 专项已有终态源码通过证据，其中 8 项为 iPad 窗口／分屏回归。终态使用的运行四类诊断均为 0；系统旧 AX 窗口警告及此前失败仍保留在原始日志中。

[最终源码审计](Results/20261025-split-accessories-warm/final-source-audit.json)确认库、应用和单元测试自完整库／宿主通过后未再变化，之后只有 UI 的 `expect(_:)`、`rotate(to:)` 两个查询辅助方法变化，[函数范围审计](Results/20261025-split-ltr-verified/final-source-audit.json)确认其余 UI 用例逐字一致。四个终态 UI 批次均与当前全部源码哈希一致；复用产物的批次使用原始 LTR 通过时构建的同一版本。

已核对实际画面：[LTR 竖屏分屏](Results/20261025-split-ltr-verified/attachments/41600667-6D92-4273-BCCA-8BFBAB73C64E.png)、[LTR 横屏分屏](Results/20261025-split-ltr-verified/attachments/6327C6B6-A3F7-4280-BED7-9CE2230C4D06.png)、[RTL 横屏分屏](Results/20261025-split-ipad-remaining/all-attachments/598683BB-7BA2-4811-8DAB-631E6A89B566.png)。本次 5 个相关 Swift 文件的 SwiftFormat 0.64.0 lint 与 `git diff --check` 通过。环境为 Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator；库 scheme 未由官方 MCP 暴露，库和指定设备 UI 使用验证脚本，Demo 宿主使用官方 MCP。未重跑全部 81 项 Demo UI、Release、iOS 15、真机、VoiceOver 或性能验证。仅关闭本次启动的 iPad，保留原有 iPhone 会话；未提交或推送。

## 2026-10-25：回退复查与下划线内容适配

复查确认 `SPTabBar.swift` 与 `SPPageViewController.swift` 的 SHA-256 与选中时序调整前的最终基线一致，保留点击立即预览、手势半程预览及最终提交回调；紧凑卡片留白与 Header 修复未被撤回。复查过程中按用户新增要求调整 Demo 默认样式：完整／高度适配卡片使用边框和标题颜色，默认关闭下划线；紧凑文字按实际文字宽度绘制，排除内部留白。显式选择下划线、胶囊或自定义视图后跨内容模式保留，自动模式可恢复。卡片显式下划线对齐可见边框。内置纯文字既有布局已按选中态标题测量，本轮补充排除 Item 留白的回归断言，没有统一减去固定宽度，也未改变框架公开 API。

新增真实 UIWindow 测试覆盖 LTR／RTL、内容／等宽／固定项宽、最大辅助字号、完整／紧凑卡片与自动样式恢复，并补充两个真实菜单切换 UI 用例。README 同步说明自动与显式规则。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator。Demo 宿主测试使用 Apple 官方 Xcode MCP；库 scheme 未由 MCP 暴露，使用独立 UIKit 宿主脚本。UI 沿用脚本，避开此前已记录的 MCP Runner 附加失败。各批次顺序执行；最终宽度专项在同一 xcodebuild 批次指定两台设备，失败证据保留。

| 阶段 | 结果 | 说明 |
| --- | --- | --- |
| [回退后完整库](Results/20261025-rollback-review-library/summary.json) | 307 通过 | 样式改动前的完整回退复查；四类诊断均为 0。 |
| [回退后 Demo 宿主](Results/20261025-rollback-review-demo-unit/summary.json) | 10 通过 | 样式改动前，包含卡片及 Header 组合；四类诊断均为 0。 |
| [回退 UI 首轮](Results/20261025-rollback-review-ui/summary.json) | 16 通过、1 断言失败、1 取消 | 接到新增样式需求后主动中止，不能视为完整通过。最大字号 RTL 卡片宽 467 pt、视口 402 pt，旧断言错误要求整项进入视口；改为检查超宽项居中，普通项保留原边界断言。 |
| [样式宿主专项](Results/20261025-indicator-content-focused/mcp-result.json) | 3 通过 | 卡片自动／显式切换、紧凑文字宽度、原渐变指示器；后续小调整由最终宿主回归覆盖。 |
| [文字宽度库专项](Results/20261025-indicator-text-library-focused/summary.json) | 23 通过 | 含新增 LTR／RTL 纯文字测量断言；四类诊断均为 0。 |
| [样式 UI 与 RTL 首轮](Results/20261025-indicator-content-ui-focused/summary.json) | 2 通过、1 失败 | 新增 LTR／RTL 样式切换通过；旧最大字号 RTL 用例横屏时向工具栏遮挡区域发送拖动，标签没有移动，随后目标查找失败。修正测试的真实触摸范围，未修改生产 RTL 布局。 |

[RTL 触摸首轮复验](Results/20261025-indicator-rtl-touch-focused/summary.json) 仍为 1 失败：横屏标签选择已通过，后续 Header 折叠继续沿用被工具栏遮挡的中点。将标签点击、横向查找及 Header 折叠起点统一到窗口内、工具栏上方的区域，保留原进度、布局及恢复断言。该轮四类运行时诊断均为 0。

终态已完成：[RTL 最大字号及 Header 四方向专项](Results/20261025-indicator-rtl-viewport-focused/summary.json) 1/1 通过，[完整库](Results/20261025-indicator-final-library/summary.json) 308/308 通过，[全部 Demo 宿主](Results/20261025-indicator-final-demo-unit/summary.json) 12/12 通过。三组运行结束时源码哈希均一致；随后仅调整下述 UI 宽度测试函数，库、应用、Demo 宿主测试源码没有再变。四类运行时诊断均为 0。33 个变更 Swift 文件的 SwiftFormat 0.64.0 lint、验证脚本 8 项自测和 `git diff --check` 通过。

[完整 iPhone UI](Results/20261025-indicator-final-ui/summary.json) 执行全部 78 项：69 通过、1 失败、8 项 iPad 专属跳过；四类诊断均为 0。唯一失败位于旧 `testCustomWidthPolicyAndRequiredOverflowInBothDirections`：402 pt 整栏扣除默认首尾各 16 pt 后，可用宽度为 370 pt，Demo 的 `max(480, availableWidth + 80)` 应为 480 pt；旧测试使用整栏宽度，错误期望 482 pt。同一用例的最小项宽预期随后也作了校正，见下文。生产源码未改动，仅调整该测试函数的宽度计算，其他 69 项已通过的 UI 用例实现不变；保留原始失败和修改前测试源码。

[宽度预期首轮修正](Results/20261025-indicator-width-final/summary.json) 1 失败：扣除留白后，旧测试仍假定最小项宽会把内容强制压成均分宽度，要求 28.46 pt，但编号本身理想宽度为 30 pt。改为断言最小下限、降低下限后实际缩小（宽屏均分时允许保持）、选择交互和超宽内容的精确宽度；没有扩大容差或修改生产布局。后续 iPad 补测进一步确认该用例默认使用 `.content`，最终断言见下文。

[宽度 iPhone 复验](Results/20261025-indicator-width-verified/summary.json) 1/1 通过，覆盖 LTR／RTL，四类诊断为 0；后续又修正 iPad 默认内容策略预期，并在两台设备重新验证，最终结果见下文。

[iPad 首轮补测](Results/20261025-indicator-final-ipad/summary.json)：7 通过、2 失败、0 跳过，四类运行时诊断为 0。7 项通过包括指针输入、LTR／RTL 分屏位置恢复、RTL 分屏取消与分页、三种连续窗口缩放。宽度失败揭示旧测试仍把默认策略当作 balanced：实际默认 `.content` 在宽屏也保留 44 pt 下限，不能要求均分成 76.92 pt。最终将预期明确为默认内容策略的 44 pt、降低下限后的真实收缩，以及扣除首尾留白后的超宽内容精确尺寸；应用没有改动。

首次 LTR 分屏手势用例停在系统“左右”菜单查询，尚未执行分页断言。失败截图显示应用回到全屏，日志伴随系统设置远程无障碍窗口查询失败；同轮后续 LTR／RTL 分屏均能正常建立。保留截图、层级、录屏及原始失败，不把后续其他用例通过直接当作该用例通过。

[最终宽度双设备复验](Results/20261025-indicator-width-content-verified/summary.json) 同一用例在 iPhone／iPad 各通过一次，均包含 LTR／RTL，四类诊断为 0，运行时源码与当前一致。[源码差异审计](Results/20261025-indicator-final-ui/final-source-audit.json) 确认完整库、Demo 宿主、完整 iPhone UI 与 iPad 首轮之后仅该宽度测试函数变化；应用实现、库与 Demo 单元测试、其他 UI 函数全部逐字一致。结合完整 iPhone 运行的其他 69 项，iPhone 适用的 70 项全部已有通过证据，不将先前包含失败的整次运行改写成通过。

[LTR 分屏独立复验](Results/20261025-indicator-split-verified/summary.json) 1 失败、四类诊断为 0，源码哈希一致。本次系统“左右”菜单已成功展开，失败位置变为首次分屏后的正文位置校验：`535.5` 对比保存的 `546.0`，偏差 10.5 pt，容差仍为 1 pt。失败发生在横向取消／分页输入之前。该轮不能计为通过，也不能据此确认窗口尺寸变化完全没有回归；当前证据尚不能区分原生自适应行高结算、滚动状态与容器恢复的具体原因。本轮没有扩大容差、改写保存位置或修改分页实现来消除失败。首次菜单失败与此次位置失败分别保留，后续需要针对这项窗口恢复问题继续定位。

终态统计：308 项库测试、12 项 Demo 宿主测试通过；78 项不同 UI 用例中，77 项已有通过证据，1 项 LTR iPad 分屏位置恢复仍失败。紧凑／完整卡片、Header、LTR／RTL 与指示器样式切换的相关用例均通过，但完整 UI 回归未全绿。33 个变更 Swift 文件的格式 lint、脚本 8 项自测与 `git diff --check` 通过。未验证 Release、iOS 15、真机、VoiceOver 或性能；未提交或推送。

已核对实际画面：[卡片自动模式](Results/20261025-indicator-final-ui/style-ltr/9B3FF8ED-8DF9-49A5-8A54-DB30291ED56A.png)、[卡片显式下划线](Results/20261025-indicator-final-ui/style-ltr/5FFDF0AA-EF0F-459A-BCB3-C9A1DDD64D1E.png)、[紧凑文字](Results/20261025-indicator-final-ui/style-ltr/8856EA41-F421-400E-827C-FB1C6870AC66.png)。以下旧章节只代表各自运行时源码，不替代本轮终态结果。

## 2026-10-25：恢复此前选中状态逻辑

按用户最新要求撤回本轮“拖动保留提交项、松手吸附终点切换”的调整，恢复点击立即预览、分页达到 50% 预览目标项、退回阈值以下恢复起始项的既有逻辑。此前的紧凑卡片、上下留白、Header 与布局 API 修复保留。README 和状态说明恢复对应契约；删除本轮新增的分阶段容器及 UI 用例，原有默认／自定义内容测试恢复半程预览断言。

[恢复审计](Results/20261025-selection-restored/restoration-audit.json) 对照上次最终验证的源码 SHA-256，确认 `SPTabBar.swift`、`SPPageViewController.swift`、Demo 源码及 UI 测试均与调整前完全一致；差异仅为内容状态注释和两份等价恢复的库测试断言。撤回前的两轮聚焦结果分别为 [78 项通过](Results/20261025-selection-phases-focused/summary.json) 和 [79 项通过](Results/20261025-selection-phases-verified/summary.json)，仅记录被撤回方案的历史结果，不作为当前行为的验证依据。

恢复后[聚焦验证](Results/20261025-selection-restored/summary.json)：44 项通过、0 失败、0 跳过，覆盖 LTR／RTL 默认与自定义内容、半程预览及回退、指示器端点、真实点击动画提交，以及取消／重载回调。环境为 Xcode 26.5 / Debug / iPhone 17 Pro / iOS 26.5 Simulator；库 scheme 未由官方 MCP 暴露，沿用独立 UIKit 宿主脚本。终态源码哈希一致，四类运行时诊断均为 0；7 个涉及本轮恢复的 Swift 文件格式检查及 `git diff --check` 通过。本次恢复未重跑完整库、Demo UI、Release、iPad、iOS 15 或真机；未提交或推送。

## 2026-10-25：紧凑卡片留白组合与选中反馈时序

Demo 紧凑卡片改为使用 `max(0, fixedHeight - contentInsets.top - contentInsets.bottom)` 判断完整卡片是否可容纳，并计算标题字号。在固定高度不变时切换留白，由既有内容配置刷新重新读取最新 inset，不增加高度缓存。组合回归覆盖 LTR／RTL、默认／最大辅助字号、32／60 pt、无／对称／非对称留白、隐藏和恢复完整卡片；检查业务文字边界及内容根视图，避免外层 frame 正确而内部仍被裁切。

用户随后指出直接点击或滑动时，指示器先到目标、选中样式随后才出现。此前两者确实使用不同更新时机：指示器跟随分页进度，内容样式只在最终提交时刷新。本轮分开视觉预览和逻辑提交：点击被接受后立即呈现目标项；手势到达 50% 时预览目标项，退回阈值以下恢复起始项；取消或重载恢复已提交项。`selectedIndex`、无障碍选中标记和代理回调仍在最终提交时更新。默认字体和自定义配置均采用预览状态；测量上下文保留逻辑状态，指示器端点独立测量，避免字体预览造成端点跳变。

新增库回归检查立即点击反馈、分页过半／回退／终点、LTR／RTL、默认字重、自定义内容、刷新保持、取消与重载恢复，以及真实点击动画完成后恰好一次回调。原有端点回归保留几何断言，将“终点仍为普通字体”的旧预期改为提前显示选中字体。README 同步说明视觉预览与提交契约。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iOS 26.5 Simulator。Demo 单元测试使用 Apple 官方 Xcode MCP；库 scheme 未由 MCP 暴露，沿用独立 UIKit 宿主脚本。UI 使用脚本保存完整日志与截图，并避开本会话此前已记录的 MCP Runner 附加失败。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [留白问题复现](Results/20261025-card-insets-red/mcp-result.json) | 1 失败（修复前） | 32 pt 加上下留白后，内容高 25 pt，Item 仅 20／18 pt，标题底部越界；四类运行时诊断均为 0。 |
| [选中时序首轮](Results/20261025-selection-timing-focused/summary.json) | 40 通过、4 失败 | 两项旧测试仍要求终点普通字体；显式 `.content` 端点被视觉预览影响，已修复独立测量；新容器夹具手动强设 offset 导致取消。另有 1 次 appearance 诊断，后续专项未复现，保留原始日志。 |
| [选中时序第二轮](Results/20261025-selection-timing-focused-2/summary.json) | 43 通过、1 失败 | 端点和回退均通过，仅上述容器夹具仍失败；四类诊断均为 0。 |
| [取消调用栈](Results/20261025-selection-timing-trace/xcodebuild.log) | 1 失败（定位用途） | 临时调用栈证明夹具强设 offset 时，UIKit 先触发旧动画结束回调并按起始位置取消点击请求；不是正常点击完成路径。临时日志代码已移除。 |
| [真实点击最终验证](Results/20261025-selection-click-final/summary.json) | 1 通过、0 失败、0 跳过 | 改为等待真实动画完成；立即视觉反馈、最终恰好一次回调、重载取消均通过，四类诊断为 0。 |
| [全部 Demo 单元测试](Results/20261025-card-selection-demo-unit/summary.json) | 10 通过、0 失败、0 跳过 | 包含卡片留白完整组合、Header 和指示器回归；库、Demo 应用及宿主测试源码哈希一致，后续仅调整 UI 夹具；四类诊断均为 0。 |
| [UI 首轮](Results/20261025-card-selection-ui/summary.json) | 3 通过、1 失败 | 默认／自定义指示器真实手势及 LTR 留白切换通过；最大辅助字号 RTL 菜单项在屏幕外被系统回收，直接查询“标签栏高度”失败。补充菜单内滚动定位，保留失败截图和层级；应用源码未变化，四类诊断均为 0。 |
| [RTL 最大字号恢复首测](Results/20261025-card-selection-rtl-final/summary.json) | 1 失败 | 固定高度与留白组合通过后，恢复完整卡片的目标定位失败。录屏显示完整卡片已恢复，当前在后续标签；总宽度增加后原 5 次拖动不足。扩大有界定位范围，菜单拖动改用视口比例，未改变应用布局或断言；四类诊断均为 0。 |
| [最终完整库](Results/20261025-card-selection-library/summary.json) | 307 通过、0 失败、0 跳过 | 新增 3 项选中反馈回归及既有布局、分页、缓存、生命周期测试全部通过；库、Demo 应用及宿主测试源码哈希一致，后续仅调整 UI 夹具；四类诊断均为 0。 |
| [UI 夹具稳定性复测](Results/20261025-card-selection-ui-verified/summary.json) | 2 失败 | LTR 录屏确认栏已隐藏，但直接读取不存在按钮的 `isHittable` 触发查询重试并耗尽 6 秒；改为先判断 `exists`。RTL 初始部分露出的目标点击后仍停留网格，改为按实际 frame 将目标中心移入视口再点击；保留原选择和状态断言及超时，应用代码未改动，四类诊断均为 0。 |
| [LTR 完整复测与 RTL 定位](Results/20261025-card-selection-ui-confirmed/summary.json) | 1 通过、1 失败 | LTR 全部组合通过；RTL 目标定位的固定距离快速拖动在两侧反复越过目标。改为按实际距离计算位移，采用既有 `.slow` 与末端停留 0.2 秒，保持有界重试及原断言；四类诊断均为 0。 |
| [RTL 最大字号最终验证](Results/20261025-card-selection-rtl-verified/summary.json) | 1 通过、0 失败、0 跳过 | 32／60 pt、三种留白、隐藏、恢复完整卡片及恢复无留白全部通过；最终 UI 源码哈希一致，四类诊断均为 0。 |

实际画面已核对：[LTR 32 pt 非对称留白](Results/20261025-card-selection-ui/attachments/C7FCF01A-2FC4-4B87-B7B6-CCD4348739D9.png)、[LTR 完整卡片恢复](Results/20261025-card-selection-ui/attachments/EAB3ACB1-1BDB-4B8D-B30F-B2B0C9D62CF9.png)、[RTL 最大字号 32 pt 非对称留白](Results/20261025-card-selection-rtl-verified/attachments/DA25A103-D3CA-46A8-AC7C-615D41018846.png)、[RTL 最大字号完整卡片恢复](Results/20261025-card-selection-rtl-verified/attachments/3CD19597-23CA-4DE6-B0A4-788DFA221369.png)。紧凑标题完整可见，恢复后编号和副标题重新显示；Header 标题和说明完整位于其内容区域。

最终覆盖：307 项库测试、10 项 Demo 宿主测试、4 项不同 UI 专项通过。4 项 UI 分别为首轮的默认／自定义指示器手势、后续的 LTR 完整组合及最终 RTL 最大字号组合，不将包含失败的整次运行记为全通过，也不重复计数。单元测试覆盖 LTR／RTL 与默认／最大辅助字号的完整交叉组合；UI 覆盖默认字号 LTR 和最大字号 RTL。[终态源码审计](Results/20261025-card-selection-rtl-verified/final-source-audit.json) 确认上述库、应用和宿主测试源码未再变化；后续仅修正 `TabBarPositioningUITests.swift` 的定位辅助方法，最终 RTL 用例对应完整终态源码。所有用于终态覆盖的运行四类诊断均为 0。31 个变更 Swift 文件的 SwiftFormat 0.64.0 lint 和 `git diff --check` 通过。未重跑完整 Demo UI、Release、iPad、iOS 15 或真机；未提交或推送。历史失败及其原始证据均保留。

## 2026-10-24：固定栏高卡片修复与 RTL 失败复现

固定栏高不足时，框架现在保留自定义内容的测量高度，在 Item 内从顶部裁切，避免强压业务 required 高度约束；点击和无障碍入口仍限于实际 Item，恢复高度后完整显示。按用户选择，Demo 进一步将放不下的完整卡片切换为单行紧凑卡片，收起编号和副标题并按可用高度适配标题；恢复内容高度策略后还原完整卡片。默认内容与自定义内容切换时同步恢复裁切状态。README 修正遗留 `.automatic` 项宽说明，分别说明最小高度、固定高度及 Demo 紧凑适配。

新增真实窗口回归覆盖 32／60 pt、隐藏与恢复、上下留白、点击与选择、默认／自定义内容切换，以及容器滚动位置与 inset 恢复；Demo 同时覆盖 LTR／RTL、默认／最大辅助字号。验证过程中还发现 Header 安装或替换时短暂宽度为 0，与两端 required 留白冲突；尾端约束改为 999，正常宽度保留原排版，并在 Header 回归中显式布局零宽度状态。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iPhone 17 Pro / iOS 26.5 Simulator。Demo 宿主测试使用官方 Xcode MCP；RTL 隔离产物复现、重复运行和 UI 截图使用命令行。库测试沿用独立 UIKit 宿主脚本，未将库测试加入 Demo scheme。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [卡片问题复现](Results/20261024-review-card-repro/mcp-result.json) | 1 失败 | 固定高度触发卡片尺寸断言失败和约束冲突；原始 MCP 日志中的诊断有重复输出，不按重复行数推定独立问题数。 |
| [裁切修复首测](Results/20261024-review-card-fixed/mcp-result.json) | 断言 9 通过；诊断失败 | 卡片修复通过，但发现 Header 零宽度时的约束冲突；未将此运行记为整体通过。 |
| [原 RTL 正确断言独立构建](Results/20261024-review-rtl-clean/summary.json) | 1 通过 | 使用新的 DerivedData，`checkGallery` 与历史已改正版本逐字一致，没有断言前的诊断输出或截图。 |
| [旧错误断言对照](Results/20261024-review-rtl-legacy-repro/summary.json) | 1 失败（预期复现） | 临时恢复与首次失败 SHA-256 相同的旧测试文件，准确复现 `312 / 342`；随后恢复正确测试源码。 |
| [裁切与 Header 修复验证](Results/20261024-review-demo-final/summary.json) | 11 通过 | 9 项宿主、2 项 UI；四类诊断均为 0。之后按用户要求增加 Demo 紧凑卡片，不作为最终 Demo 源码证据。 |
| [紧凑卡片首测](Results/20261024-review-compact-unit/mcp-result.json) | 9 通过、1 失败 | 新夹具把框架隐藏角标计入业务标签数量；改为检查业务 `UIContentView` 子树。 |
| [紧凑卡片第二次测试](Results/20261024-review-compact-unit-final/mcp-result.json) | 9 通过、1 失败 | RTL／大字号切换保留物理滚动偏移，待查首项在屏幕外；按既有夹具约定显式滚动到逻辑首项再检查。 |
| [Demo 宿主最终验证](Results/20261024-review-compact-unit-verified/final-source-audit.json) | 10 通过、0 失败、0 跳过 | 全部 Demo 宿主测试通过，四类运行时诊断均为 0，源码哈希一致。 |
| [紧凑卡片 UI 与 RTL](Results/20261024-review-compact-ui/summary.json) | 3 通过、0 失败、0 跳过 | LTR／RTL 下真实点击、固定 32／60、隐藏与恢复，以及 RTL 四种布局模式；源码哈希一致，四类诊断均为 0。 |
| [RTL 独立重启重复运行](Results/20261024-review-rtl-repeat/summary.json) | 1 个用例重复 2 次，均通过 | `test-without-building`、每轮重启 Runner，保留断言后的截图；没有断言前诊断。源码哈希一致，四类诊断均为 0。 |
| [受影响库测试](Results/20261024-review-library-focused/summary.json) | 34 通过、0 失败、0 跳过 | 自定义内容、自动内容和容器栏高恢复回归；源码哈希一致，四类诊断均为 0。 |
| [最终完整库](Results/20261024-review-library-final/summary.json) | 304 通过、0 失败、0 跳过 | 包含新增自定义内容裁切回归及扩展的容器恢复回归；源码哈希一致，四类诊断均为 0。 |

RTL 的首次失败已证明是测试比较了物理左边缘：402 pt 视口、两端 16 pt 留白、5 项时，等宽项宽 74，而内容项宽 44，起始项左边缘随宽度从 342 变为 312；RTL 的起始右边缘应保持 386。历史上改成右边缘后仍出现同值失败的那一轮，本轮未复现；历史日志显示测试源码曾参与编译与链接，不能据此断言是旧二进制或缓存。独立构建、去除断言前诊断和后续重启重复运行用于排查当前是否仍可复现，历史原因保留未确认状态。

实际画面已核对：[固定 32 pt 紧凑卡片](Results/20261024-review-compact-ui/attachments/08ADA539-D6B3-4AA2-A884-964EBD824376.png)、[固定 60 pt](Results/20261024-review-compact-ui/attachments/ADA70A1E-ABC8-46B9-AF91-D5385388A000.png)、[恢复完整卡片](Results/20261024-review-compact-ui/attachments/F8F8CF9A-2CD7-475D-B5D6-58EC9F0A86BA.png)。固定高度下标题完整可见，恢复后编号和副标题重新显示。

最终覆盖：304 项完整库、10 项 Demo 宿主、3 项 UI 专项通过；RTL 同一用例另重启重复两次均通过，不计为新增用例。上述最终运行与当前源码一致，四类运行时诊断均为 0。30 个变更 Swift 文件的 SwiftFormat 0.64.0 lint 和 `git diff --check` 通过。未重跑完整 Demo UI 套件、Release、iPad、iOS 15 或真机；未提交或推送。下方历史记录描述各自当时的源码状态，不替代本轮验证。

## 2026-10-24：标签布局 API 与默认尺寸配置重构

本轮将项宽策略、整组对齐、最小／最大项宽、间距及外围留白统一为 `layoutConfiguration`；新增 `defaultContentLayout`，将图文排列从 Appearance 迁出并开放内部留白、图标区域、图文间距与最小高度。容器新增 `.content(minimum:) / .fixed / .hidden` 栏高策略，保留旧高度入口转发；越界索引现在忽略，`nil` 才清空选择。Demo、README 与库／Demo 测试同步迁移，新增真实窗口与菜单回归。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iPhone 17 Pro 与 iPad Pro 13-inch (M5) / iOS 26.5 Simulator。官方 Xcode MCP 首次 Demo 构建通过；MCP 仅暴露 Demo scheme，根目录库使用脚本的独立 UIKit 宿主流程。脚本与 xcresulttool 需要访问模拟器服务及 Xcode TestReport 缓存，通过获准的沙箱外执行完成。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首次聚焦编译](Results/20261024-tab-layout-focused/xcodebuild.log) | 编译失败，未运行测试 | 部分闭包中的旧属性调用未迁移，新测试的 `.nan` 字面量类型歧义；均已修正。 |
| [第二次聚焦](Results/20261024-tab-layout-focused-2/xcodebuild.log) | 32 通过、1 失败 | 旧纯算法用例迁移到新配置后误带默认 44 pt 下限；显式恢复该夹具的 0 下限，保留原断言。新增 7 项回归均通过。 |
| [布局聚焦复测](Results/20261024-tab-layout-focused-final/summary.json) | 33 通过、0 失败、0 跳过 | 布局主体实现通过；后续补充图标栅格上限、Demo 约束及诊断检查，见下方复测。 |
| [完整库](Results/20261024-tab-layout-library/summary.json) | 301 通过、0 失败、0 跳过 | 布局主体实现通过；按新增检查重审后四类诊断均为 0。后续图标栅格上限单独复测，不将此记录标为全部终态源码一致。 |
| [Demo 宿主首轮](Results/20261024-tab-layout-demo-unit/summary.json) | 断言 7 通过；约束诊断失败 | 官方 MCP 执行。原三类诊断为 0；额外检查发现卡片切换在旧窄 frame 下有约束冲突，原始日志保留。 |
| [官方 MCP UI](Results/20261024-tab-layout-demo-ui/summary.json) | 环境阻塞，6 项未执行 | LLDB 无法附加 UI Runner：`Could not attach to pid`。保留原始 xcresult，回退仓库脚本。 |
| [Demo 宿主复测](Results/20261024-tab-layout-demo-unit-final/summary.json) | 7 通过、0 失败、0 跳过 | 卡片约束修复后四类诊断均为 0；之后仅图标栅格边界及相关测试变化，不影响此卡片修复。 |
| [iPad 图标专项首次启动](Results/20261024-tab-layout-raster-ipad/xcodebuild.log) | 中止，未执行测试 | 与 iPhone UI 并行时持续重复 Package 解析；终止本次库构建，保留日志并串行重试。 |
| [命令行 UI 首轮](Results/20261024-tab-layout-ui-final/summary.json) | 5 通过、1 失败 | RTL 菜单用例误用物理左边缘判断逻辑起始对齐；改为核对右边缘。大字号几何断言通过，但用户截图暴露 Header 文字裁切，不能将该断言通过解释为视觉正确。 |
| [Header 宿主回归](Results/20261024-tab-layout-header-unit/summary.json) | 8 通过、0 失败、0 跳过 | 新增 Header View／Controller、RTL、大字号及字号恢复的实际文字尺寸检查；四类诊断为 0。后续补充容器吸顶契约。 |
| [终态边界聚焦](Results/20261024-tab-layout-boundary-final/summary.json) | 9 通过、0 失败、0 跳过 | 图标栅格边界、统一尺寸与 Header 增高后吸顶／正文／缓存页位置；四类诊断为 0。 |
| [终态完整库](Results/20261024-tab-layout-library-final/summary.json) | 303 通过、0 失败、0 跳过 | 包含新增 Header 吸顶契约与图标栅格保护；库源码及库测试终态一致，四类诊断均为 0。之后仅调整 Demo Header 排版及其测试。 |
| [Header 视觉复查](Results/20261024-tab-layout-ui-verified/summary.json) | 主动中止，不记为通过 | 标题已不裁切，但截图显示品牌名末尾单个 `t` 被换行。保留截图和 canceled 结果，停止旧版 UI 验证后拆分品牌名与说明。 |
| [Header 终态回归](Results/20261024-tab-layout-header-final/summary.json) | 10 通过、1 失败 | 8 项 Demo 宿主、大字号 RTL 四个方向流程及默认尺寸切换通过；RTL 菜单仍报告此前的左边缘比较数值，后续增加逐项几何记录并复测。 |
| [RTL 几何复测](Results/20261024-tab-layout-rtl-diagnostic/summary.json) | 1 通过、0 失败、0 跳过 | 四种布局及自定义／默认内容恢复通过；实测等宽 74 pt、首尾各 16 pt，内容居中余量正确。`sourceChangedSinceRun=[]`，四类诊断为 0。前轮失败原因未进一步确认，保留全部证据。 |
| [iPad 系统容器](Results/20261024-tab-layout-ipad-final/summary.json) | 1 通过、0 失败、0 跳过 | 分页往返、系统标签切换、三次旋转与正文位置恢复；`sourceChangedSinceRun=[]`，四类诊断为 0。 |

Demo 卡片内部水平留白现在使用 999 优先级，在内容配置先于新 Cell frame 生效时允许临时压缩；最终尺寸下恢复理想留白。诊断脚本新增约束冲突检查，并新增“断言通过不能掩盖约束冲突”的脚本回归。脚本 8 项测试通过。边界复查补充图标最大 1024 × 1024 像素的栅格化上限，保留逻辑尺寸；新增真实内容视图回归已通过。

用户指出大字号截图中 Header 副标题被截断：Demo 标题缺少尾端约束，220 pt 固定高度也容不下放大文字。最终将品牌名与说明拆为独立标签：品牌名单行适配宽度，说明独立换行；Demo 的 220／300 pt 作为下限，按文字和顶部安全区域增高，恢复字号及旋转时重测。框架显式 Header 高度配置增大时同步保留已吸顶状态和正文位置，新增缓存页回归；UI 大字号用例补查两段文字四边，系统容器测试按实际 Header 高度计算正文位置。

实际画面复查：[默认字号](Results/20261024-tab-layout-header-final/header-default.png) 的 Header 为 220 pt，[最大辅助字号](Results/20261024-tab-layout-header-final/header-large-text.png) 为 351 pt，两段文字完整可见，品牌名不再出现孤立尾字母。iPhone 模拟器已恢复默认字号并打开 Demo。完整库结果之后仅有 Demo 排版与测试变化；Header 终态运行之后仅为 RTL 用例增加几何记录和截图，应用源码未再变化。

终态覆盖：303 项完整库、8 项 Demo 宿主、4 项 UI 专项及 8 项验证脚本测试通过；UI 通过结果分别来自 Header 终态运行、RTL 复测及 iPad 运行，不将含失败的整次运行标为整体通过。四类运行时诊断在终态覆盖中均为 0。SwiftFormat 0.64.0 的 30 个变更 Swift 文件 lint 与 `git diff --check` 通过。未执行完整 Demo UI 套件、Release、iOS 15 运行时或真机验证；未提交或推送。

## 2026-10-24：提交前复查

复查本次频道样式、左右留白、选中字重、下划线宽度／圆角枚举、归档兼容、Demo 调用及所有新增／调整测试，未发现新的阻塞问题。核对现有终态结果与当前文件 SHA-256：294 项完整库测试和 3 项 UI 手势所对应的库、应用与测试源码未变化；唯一后续变化是 Demo 宿主窗口夹具，已单独复测 1 项通过且诊断清零。首轮失败及诊断证据继续保留，不将首轮 Demo 运行记为整体通过。

本轮未修改实现或重复构建测试；19 个待提交 Swift 文件的 SwiftFormat lint 及 `git diff --check` 通过。验证范围沿用下述记录，不扩展为完整 Demo、Release、iPad、iOS 15 或真机均已验证。

## 2026-10-24：统一宽度枚举与模式切换回归

`SPTabBarIndicatorLayout.width` 统一为 `.automatic / .fixed(CGFloat)`，下划线工厂直接赋值该属性，不再按宽度模式切换尺寸上限。自动宽度由 `reference` 决定；显式 `limitsSizeToReference` 对两种模式均生效。`.title` 保留 Item 高度保护，固定宽度仍可超过短标题。模式切换不重置其他布局配置。保留圆角枚举与旧数值归档格式；旧宽度数值、null、缺省字段均可解码。迁移调用点及 README，修正菜单数量、默认排列描述。Demo 渐变改用 `state.cornerRadius`，不再写死半高。

新增 4 项库回归，覆盖短标题模式切换、工厂与属性一致性、配置保留、分页中切换后双向完成／取消、RTL、三种参考区域与显式限宽、旧宽度字段及 Appearance 往返归档。扩展极矮标签用例到固定宽度。新增 1 项 Demo 宿主测试，在真实窗口检查自定义渐变的自动、直角、固定及上限圆角，并检查分页中的实际渐变图层。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iPhone 17 Pro / iOS 26.5 Simulator。官方 MCP 构建通过，并确认 Demo 新用例已被 scheme 收录；库测试使用独立 UIKit 宿主，Demo 测试沿用命令行路径避开本会话已记录的 MCP Runner 附加问题。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮聚焦](Results/20261024-width-enum-focused/summary.json) | **51 通过、2 失败** | 新夹具替换 Item 后漏设选择，另一新断言精确比较约 1e-14 pt 的插值误差；修正初始化和浮点断言，保留失败记录。 |
| [聚焦复测](Results/20261024-width-enum-focused-final/summary.json) | **53 通过、0 失败** | 此时源码一致，之后修复极矮标签高度保护。 |
| [首轮完整库](Results/20261024-width-enum-library/summary.json) | **293 通过、1 失败** | 解除水平限宽同时丢失了自动下划线在 1 pt 高 Item 内的高度保护；修复实现并保留原断言，扩展固定宽度覆盖。 |
| [边界复测](Results/20261024-width-enum-boundary/summary.json) | **67 通过、0 失败、0 跳过** | 指示器、频道样式与自动内容测试均通过，三类运行时诊断均为 0；后续仅 Demo 宿主夹具变化。 |
| [最终完整库](Results/20261024-width-enum-library-final/summary.json) | **294 通过、0 失败、0 跳过** | 库源码与库测试一致，三类运行时诊断均为 0；后续仅 Demo 宿主夹具变化。 |
| [Demo 首轮](Results/20261024-width-enum-demo/summary.json) | **断言 4 通过；诊断失败** | 3 项真实 UI 分页通过；新渐变宿主测试也通过，但窗口释放过早产生 1 次 appearance 不平衡，未将该运行记为整体通过。 |
| [Demo 宿主修复复测](Results/20261024-width-enum-demo-unit-final/summary.json) | **1 通过、0 失败、0 跳过** | 按既有窗口夹具等待 appearance 完成再解绑，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

终态哈希审计：边界复测、完整库及 Demo 首轮的 `sourceChangedSinceRun` 均只包含 `Examples/StickyPagerDemo/StickyPagerDemoTests/DemoIndicatorTests.swift`。库、Demo 应用及 UI 测试源码未再变化，故仅重跑受影响的宿主用例；原始失败诊断保留。3 项 UI 覆盖默认文字等宽、固定 20 pt 的长短标题双向完成／取消，以及自定义指示器分页。

SwiftFormat 0.64.0 与 `git diff --check` 通过。未执行完整 Demo 套件、Release、iPad、iOS 15 或真机验证。未提交或推送。

## 2026-10-24：四种下划线实际演示

运行最新 Demo，对比文字等宽／固定 20 pt 与自动圆角／直角的四种组合。复用长短标题手势步骤，新增两个直角 UI 用例；本轮未改动框架或 Demo 实现。每组均验证短→长、长→短的取消与完成，并检查当前页面及选中 Item。

[本次结果](Results/20261024-underline-four-styles/summary.json)：**4 通过、0 失败、0 跳过**，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。环境为 Xcode 26.5 / Debug / iPhone 17 Pro / iOS 26.5 Simulator。沿用命令行 UI 测试，避开前轮已记录的官方 MCP Runner 附加问题；构建的 SwiftFormat 阶段通过。

录屏与测试同步进行，导出四段标签栏局部原速视频，展示取消恢复和完成落点。逐帧核对长标题终态：文字等宽覆盖标题，固定宽度保持 20 pt；自动圆角为圆头，`.fixed(0)` 为直角。原始录屏保留双向操作。未重复完整库／Demo 套件、Release、iPad、RTL、iOS 15 或真机测试。

## 2026-10-24：下划线宽度预设与圆角枚举

`SPTabBarIndicatorLayout.underline` 与默认频道线条统一，等价于 `.underline(width: .content)`；`.underline(width: .fixed(20))` 居中对齐选中态标题并保持固定宽度。新增 `.title` 参考区域复用通用布局计算，删除默认线条的独立几何分支。预设仍支持高度、对齐、内缩、偏移、层级和自定义扩展；纯图标及自定义内容保持回退规则。`cornerRadius` 改为 `.automatic` / `.fixed(CGFloat)`，固定 0 表示直角；保持负值／非有限值归零及短边一半的上限。Appearance 归档沿用可选数值字段，兼容旧数值及缺省圆角。README 记录源码调用迁移及旧 Item 内缩布局的表达方式。

新增 6 项库回归，覆盖固定宽度双向分页完成／取消、RTL、长短标题、图标角标、屏幕外选择、字体变化、自定义内容、非法宽度、布局定制、Appearance 复制与归档、旧圆角归档；原文字端点测试同时运行默认与显式下划线预设。Demo 增加固定 20 pt 下划线和圆角菜单，新增固定宽度长短标题双向真实手势测试。

环境：Xcode 26.5 / Swift 6.3.2 / Debug / iPhone 17 Pro / iOS 26.5 Simulator。官方 MCP 构建成功；库测试使用独立 UIKit application host，UI 沿用命令行路径避开本会话已记录的 MCP Runner 附加问题。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮聚焦](Results/20261024-underline-api-focused/summary.json) | **47 通过、2 失败** | 新断言对约 1e-14 pt 的浮点误差使用了精确相等，Item Appearance 替换后也未同步布局；已修正测试。保留失败证据。 |
| [聚焦复测](Results/20261024-underline-api-focused-final/summary.json) | **49 通过、0 失败** | 当时源码一致，三类运行时诊断均为 0。 |
| [首轮完整库](Results/20261024-underline-api-library/summary.json) | **279 通过、11 失败** | 三组旧夹具仍假定显式 `.underline` 为 Item 内缩 12 pt；已用通用布局配置保留其原几何和滚动断言。保留失败证据。 |
| [最终完整库](Results/20261024-underline-api-library-final/summary.json) | **290 通过、0 失败、0 跳过** | `sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [真实手势 UI](Results/20261024-underline-api-ui/summary.json) | **3 通过、0 失败、0 跳过** | 默认文字等宽、固定 20 pt 长短标题双向完成／取消，以及自定义指示器分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

SwiftFormat 0.64.0 检查及 `git diff --check` 通过。未执行 Release、完整 Demo 套件、iPad、iOS 15 或真机验证。未提交或推送。

## 2026-10-24：长短标题分页演示

Demo 的“页面 → 长短标题演示”提供“推荐”“编辑精选与深度阅读”“热点”标题，便于观察默认频道下划线宽度变化。新增 UI 用例覆盖短→长、长→短各自的取消和完成：取消拖动 32% 页面宽度并停住后松手，完成拖动 70%；分别断言当前页面及选中 Item。框架实现未改动。

官方 Xcode MCP 构建通过；真实手势沿用命令行测试，避开前轮记录的 MCP Runner 附加问题。[本次结果](Results/20261024-channel-long-short/summary.json)：**1 通过、0 失败、0 跳过**，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。环境为 Xcode 26.5 / Debug / iPhone 17 Pro / iOS 26.5 Simulator。构建的 SwiftFormat 阶段及 `git diff --check` 通过。

原速录屏覆盖双向宽度变化：完成后分别稳定在长、短标题下方；取消恢复原标题宽度和选中状态。录像剪去启动和多余等待，用于视觉演示；不据此代替前轮长英文标题端点几何测试。本轮未重复完整库和 Demo 测试，也未新增 iPad、RTL 或真机验证。

## 2026-10-24：频道下划线分页端点复查与简化

修复默认下划线在分页提交后随 semibold 标题再次伸缩的问题：内置图文使用独立测量副本解析选中态端点，保持可见标题、逻辑选择和回调提交时机不变。标题／纯图标的选中态几何与显式 `.content` 的实际内容区域分开缓存，继续校验 Item frame；自定义内容仍使用其声明的指示器区域。合并字体解析和 Dynamic Type 缩放入口，保留 Item 字体、Appearance 字体和默认字体的优先级；移除默认线条提前返回后的冗余回退分支。README 同步端点测量规则。

新增 3 项库回归：长英文标题在 LTR／RTL 下完成分页后不再产生第二段宽度动画；双向取消恢复原端点、滚动位置及选择；显式字体与 `.content` 布局切换不会混用两类测量缓存。新增默认频道型真实分页完成／取消 UI 测试，与已有自定义指示器测试复用手势步骤。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator。官方 MCP 确认 Demo 工程，库测试使用独立 UIKit application host。UI 沿用命令行路径，避开本会话已记录的官方 MCP LLDB Runner 附加失败。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前回归](Results/20261024-channel-endpoints-red/summary.json) | **9 通过、2 失败** | 完成端点和显式字体用例捕获旧问题，取消用例通过；默认长英文标题提交后从约 203.7 pt 再伸长至 211.7 pt。保留失败证据。 |
| [修复后聚焦](Results/20261024-channel-endpoints-focused/summary.json) | **101 通过、0 失败、0 跳过** | 频道样式、模型、指示器、基本交互及自定义内容；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库](Results/20261024-channel-endpoints-library/summary.json) | **284 通过、0 失败、0 跳过** | `sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [UI 回归](Results/20261024-channel-endpoints-ui/summary.json) | **3 通过、0 失败、0 跳过** | 默认频道型、自定义指示器的真实分页完成与取消，以及 RTL 分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

本轮 3 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-channel-endpoints-focused/swiftformat-lint.txt)，`git diff --check` 通过。未执行完整 Demo 测试套件、Release、iPad、iOS 15 或真机验证。没有提交或推送。

同日实际画面演示（iPhone 17 Pro 模拟器）：复用与当前源码一致的 Demo 构建，以 `test-without-building` 执行默认频道型完成／取消真实手势并同步录屏，[演示运行](Results/20261024-channel-live-recording/summary.json) **1 通过、0 失败**，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。短拖动后下划线回到“网格”；完成左滑后停在“列表”文字下方。录像仅剪去启动与等待，保留原速；未修改业务源码。

## 2026-10-24：频道型默认样式与下划线主题色

默认采用 `.leading` 内容宽度排列和 `.underline` 指示器，保留首尾 16 pt 滚动留白。选中标题使用同字号 semibold，沿用 Dynamic Type；显式 Item 字体属性和 Appearance 字体仍优先。下划线取实际标题的水平区域，在 Item 底部绘制 3 pt 线条；纯图标回退到图标区域，自定义内容使用其 `indicatorContentRect`。显式 `SPTabBarIndicatorLayout.underline` 保留 Item 左右内缩 12 pt 的原有预设。选择居中滚动策略不变。

根据后续确认，未设置 `indicatorColor` 时下划线始终跟随 `SPTabBar.tintColor`，不受选中标题颜色覆盖影响；显式颜色优先，设回 nil 恢复动态跟随。胶囊与自定义指示器的默认颜色规则保持原样。README、公开注释与 Demo 指示器菜单同步更新。

新增 8 项频道样式测试，覆盖 LTR／RTL、首尾留白、自然宽度、字重切换不挤动 Item、图文与角标、纯图标、显式字体和布局覆盖、大字号、标题和视口更新、屏幕外选择、分页插值及自定义内容。原有字体、宽度、胶囊和换行测试显式配置所验证的模式；角标测试改为检查标题相对按钮中心的位置，兼顾自然宽度扩展。颜色回归覆盖继承 tint、实时改色、标题色独立性、覆盖／恢复、深浅色及动画中刷新。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator。官方 MCP 确认打开的 Demo 工程；根库通过仓库 UIKit application host 执行。UI 沿用命令行流程，原因是本会话前轮官方 MCP 曾因 LLDB 无法附加 Runner 而未能执行测试。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮聚焦](Results/20261024-channel-style-focused/summary.json) | **124 通过、2 失败** | 新增 8 项全部通过；失败来自附件测试的旧胶囊假设和准备 Cell 测试的字体断言，后续显式指定对应配置。保留原始失败证据。 |
| [首轮完整库](Results/20261024-channel-style-library/summary.json) | **279 通过、2 失败** | 角标断言假定 Item 不扩宽，自动增高断言依赖 `.automatic`；已修正测试目的与配置。运行中追加主题色规则及测试修正，5 个文件列于 `sourceChangedSinceRun`，不作为最终源码证据。 |
| [最终完整库](Results/20261024-channel-style-library-final/summary.json) | **281 通过、0 失败、0 跳过** | `sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [UI 交互回归](Results/20261024-channel-style-ui/summary.json) | **4 通过、0 失败、0 跳过** | 指示器预设与前景命中（含旋转）、标签居中和首尾定位、横向拖动保持页面、按住按钮拖动及 RTL 分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

已检查 UI 测试导出的[默认下划线截图](Results/20261024-channel-style-ui/Attachments/E80DA873-F029-4B1A-BD29-083F7EB302BE.png)：选中标题加粗，线条与标题等宽，不包含图标和角标。

17 个修改／新增的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-channel-style-library-final/swiftformat-lint.txt)，`git diff --check` 通过。本轮未执行完整 Demo 测试套件、Release、iPad、iOS 15 或真机验证。没有提交或推送。

## 2026-10-24：标签栏默认首尾留白 16 pt

`SPTabBar.contentInsets` 默认改为 leading／trailing 各 16 pt、top／bottom 为 0。留白随内容滚动，视口仍延伸至安全区域／附件边界，固定附件和内置图文 padding 不变；显式 `.zero` 可取消默认留白。公开注释和 README 同步此契约。

新增 2 项窗口几何回归，覆盖四种排列模式、LTR／RTL、左右安全区域、内容滚过首端留白、尾端留白、零值覆盖、单项／空列表和尺寸变化。原有宽度与间距算法夹具显式指定 `.zero`，继续验证无额外留白时的分配规则；Demo UI 首尾定位断言同步为 16 pt。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator。根库使用仓库 UIKit application host 脚本；官方 MCP 的 Demo 构建成功，但 UI Runner 因 LLDB 无法附加而启动失败，随后回退仓库命令行流程执行相同的三项 UI 测试。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [标签栏聚焦](Results/20261024-tab-insets-focused/summary.json) | **142 通过、0 失败、0 跳过** | 运行期间仅修改 Demo UI 对齐断言，该文件列于 `sourceChangedSinceRun`；库实现与库测试未变。 |
| [完整库](Results/20261024-tab-insets-library/summary.json) | **273 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [官方 MCP UI](Results/20261024-tab-insets-ui/summary.json) | **环境阻塞，3 项未执行** | xcresult 记录 1 条 Runner 启动失败：`Could not attach to pid`；保留原始结果及控制台日志。 |
| [命令行 UI](Results/20261024-tab-insets-ui-cli/summary.json) | **3 通过、0 失败、0 跳过** | 标签居中与首尾定位、横向滚动保持页面、按住按钮后的拖动、RTL 分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

8 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-tab-insets-library/swiftformat-lint.txt)，`git diff --check` 通过。本轮未执行完整 Demo 测试套件、Release、iPad、旋转、iOS 15 或真机验证。没有提交或推送。

## 2026-10-24：页面滚动绑定选择的职责收敛

新增 `SPScrollViewBinding` 的 `.automatic`、`.unbound` 和 `.explicit` 三种选择，以及数据源首次绑定前的配置入口和运行时设置入口。保留默认自动发现与 `setScrollView(nil, ...)` 恢复自动发现的契约。运行时选择按页面标识保存，缓存淘汰不丢失，删除标识后清除；显式对象使用弱引用，失效后不回退到其他候选。自动发现算法未调整。

明确不绑定或显式对象失效后，不接管业务列表滚动；保留页面布局、安全区域和分页，Header／标签栏仅驱动 Header，正文不启用普通页面兜底拖动。首次布局中的重新发现等待选择确定；解绑及 inset 同步回调中改变选择时串行应用最新请求，避免恢复旧选择、重复叠加贡献或丢失滚动回调。

新增 12 项库测试覆盖根／子列表首次不绑定、未加载页面运行时配置、nil 恢复自动、显式失效与恢复、缓存释放／重建、稳定标识重排和删除、外部对象拒绝，以及首次布局、数据源和 inset 回调重入。新增 Demo 真实触摸测试检查独立列表滚动、Header／标签栏折叠和横向分页。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 与目标；库测试通过仓库 UIKit application host 脚本运行，UI 使用官方 MCP。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮聚焦](Results/20261024-binding-selection-focused-retry/summary.json) | **131 通过、3 失败** | 两项释放测试未排空 autorelease pool，一项把 UIKit 布局的 offset 通知计为框架定位；保留当时源码差异和结果。首次沙箱运行未进入测试，CoreSimulator 访问失败日志另保留于 `20261024-binding-selection-focused/host-build.log`，随后获准访问服务完成运行。 |
| [第二轮聚焦](Results/20261024-binding-selection-final-focused/summary.json) | **135 通过、1 失败** | 释放时机修正及同步回调测试通过；offset 通知断言仍需区分同值通知和横向布局调整。 |
| [中间完整库](Results/20261024-binding-selection-final-library/summary.json) | **280 通过、1 失败** | 剩余失败来自 UIKit 横向 inset 对 offset.x 的调整；测试最终只检查正文纵向位置变化。此后补充两项回调测试并修复实现，不作为终态验收。 |
| [聚焦边界](Results/20261024-binding-selection-boundaries/summary.json) | **5 通过、0 失败、0 跳过** | 首次不绑定、首次布局重新发现、加载回调覆盖、inset 重复选择和解绑重入均通过。之后仅修正测试闭包弱引用警告，由最终完整库覆盖。 |
| [最终完整库](Results/20261024-binding-selection-verified-library/summary.json) | **283 通过、0 失败、0 跳过** | 包含全部 12 项新增回归，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [最终 UI 回归](Results/20261024-binding-selection-ui/summary.json) | **5 通过、0 失败、0 跳过** | 不绑定列表独立滚动与分页、普通页面拖动、默认 Header／列表联动、分页快速选择、状态栏回顶部均通过；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0，无运行时警告。 |

7 个修改／新增的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-binding-selection-ui/swiftformat-lint.txt)，`git diff --check` 通过。保留既有测试中的 iOS 17 trait API 弃用警告；本次新增闭包捕获警告已修正。未执行完整 Demo 测试套件、Release、Swift 6.3 工具链、iPad、iOS 15 或真机验证。没有提交或推送。


## 2026-10-24：内部滚动宿主退出状态栏回顶部

仅为分页容器和标签栏内部 Collection View 设置 `scrollsToTop = false`，与 Header 宿主已有配置一致。业务列表的 `scrollsToTop`、delegate 及原生回顶部路径保持业务／UIKit 所有权，自动发现和绑定接口未调整。README 同步此边界。

新增 2 项库测试：内部宿主退出回顶部，同时业务 true／false、运行时更新、delegate 在绑定、切页、布局、重新发现及页面移除后保留；独立标签栏在选中、替换 Item 和布局后仍不参与回顶部。新增真实状态栏点击 UI 测试，并检查 Header 和正文回到顶部、选中页不变。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 scheme 与目标；库测试使用仓库 UIKit application host 脚本，UI 通过官方 MCP 执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [聚焦库测试](Results/20261024-scrolls-to-top-focused/summary.json) | **148 通过、0 失败、0 跳过** | 容器、标签栏与分页测试；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [聚焦 UI 测试](Results/20261024-scrolls-to-top-ui/summary.json) | **3 通过、0 失败、0 跳过** | 真实状态栏点击回顶部、Header／列表滚动、分页与快速选择；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0，无运行时警告。 |

UI 测试的 MCP 导出副本缺少 `Info.plist`，首次摘要无法读取测试元数据；该副本保留为 `MCP-Incomplete.xcresult`，初次摘要保留为 `incomplete-export-summary.json`。随后归档 Xcode 同次运行的完整原始结果包为 `Result.xcresult`，重新生成上述摘要并确认 3 项通过；这是结果导出问题，不是测试失败。

5 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-scrolls-to-top-ui/swiftformat-lint.txt)，`git diff --check` 通过。业务 `scrollsToTop` 两种取值及运行时修改由库测试覆盖，真实回顶部 UI 验证使用业务默认开启的列表。本轮未执行完整库／Demo 测试套件、Release、Swift 6.3 工具链、iPad、iOS 15 或真机验证。没有提交或推送。

## 2026-10-24：首次绑定位置与安全区域同步回调复查

重新核对首次取值时机、已有零／非零历史优先级、页面标识生命周期、KVO 嵌套通知与解绑恢复，未发现需再次修改实现的问题。本轮只补充库测试及验证记录，保留上一轮全部未提交修改。

新增 3 项库回归：首个选中页在窗口挂载和 reload 后仍保留初始正文位置（根／子滚动视图、自动／手动 inset、有／无 Header）；删除页面标识后重新添加时采用新的业务初始位置；安全区域多次改变贡献、同值回写及修改其他方向后，页面移除仍恢复最新业务基准。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 与目标；库测试继续使用仓库 UIKit application host 脚本。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [复查聚焦](Results/20261024-initial-position-review-focused/summary.json) | **126 通过、0 失败、0 跳过** | 包含新增 3 项边界测试；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [复查完整库](Results/20261024-initial-position-review-library/summary.json) | **269 通过、0 失败、0 跳过** | 当前源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

本轮未重跑 UI：与上一轮 [6 项 UI 通过结果](Results/20261024-initial-position-safearea-final-ui/summary.json) 的源码 SHA-256 比较，仅库测试文件变化，框架、Demo、UI 测试及构建配置均一致。该 UI 结果保留为上一轮证据，不计为本轮执行。

4 个已修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-initial-position-review-focused/swiftformat-lint.txt)，`git diff --check` 通过。未执行 Release、Swift 6.3 工具链、iPad、iOS 15、真机或完整 Demo 测试套件。没有提交或推送。

## 2026-10-24：首次绑定位置与安全区域同步回调职责收敛

无历史位置时，在首次绑定叠加框架滚动 inset 前读取业务归一化正文位置；已有历史记录（包括 0）继续按页面标识恢复。保留共享 Header 对齐、有效范围钳制、缓存重建及后台页历史保护规则，不调整后台业务定位或其他交互开关，不新增公开 API。

`SPPageSafeArea` 按 KVO 通知层级区分框架写入和业务嵌套写入，外部 setter 完成后再叠加标签栏贡献，框架写入期间的业务基准和贡献变更串行处理。同步回调中解绑时先保存最新业务基准并解除管理，旧更新不能再次恢复贡献；相同值不额外回写。README 同步位置初始化与安全区域回调契约。

新增 8 项库回归，覆盖自动发现与显式绑定、零／正折叠范围、展开／部分折叠／吸顶、自动／手动 inset、根滚动视图／子视图、负位移与短内容、已有零／非零历史及缓存重建；安全区域覆盖业务与框架 setter 回调、两种 KVO 注册顺序、回调中贡献更新、外部赋值中解绑及重复解绑。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 和目标；库测试使用仓库 UIKit application host 脚本。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前基线](Results/20261024-initial-position-safearea-baseline/summary.json) | **1 通过、4 失败** | 已有历史恢复通过；首次正文位置被覆盖、安全区域嵌套写入和解绑丢失基准失败。保留当时实现与测试快照。初版夹具设置折叠量的方式随后改为直接业务 offset 写入并显式断言；零折叠范围下 300 被覆盖为 0 的独立失败不受此调整影响。 |
| [首轮聚焦](Results/20261024-initial-position-safearea-focused/summary.json) | **120 通过、0 失败、0 跳过** | 包含实现修复和首批 5 项新测试；之后补充 3 项边界测试，因此此轮不是最终源码验证。保留测试快照。 |
| [最终聚焦](Results/20261024-initial-position-safearea-final-focused/summary.json) | **123 通过、0 失败、0 跳过** | 包含全部 8 项新增测试；框架和库测试源码一致，后续仅修改 `SystemContainerTests.swift` 的旧指示器断言；三类运行时诊断均为 0。 |
| [完整库](Results/20261024-initial-position-safearea-library/summary.json) | **266 通过、0 失败、0 跳过** | 框架和库测试源码一致；`sourceChangedSinceRun` 仅列出后续修正旧断言的 `SystemContainerTests.swift`，不影响此库测试产物。三类运行时诊断均为 0。 |
| [首次 Demo UI](Results/20261024-initial-position-safearea-ui/summary.json) | **3 用例通过、3 用例失败；另 1 项 runner 错误** | 三个系统容器用例仍断言短列表自动隐藏指示器，与已提交的默认保留业务显隐契约不一致。MCP 报告 3／3；xcresult 另外记录 runner 退出码 75，因此摘要为 3 通过、4 失败。保留源码快照与完整结果，不隐去运行器错误。 |
| [最终 Demo UI](Results/20261024-initial-position-safearea-final-ui/summary.json) | **6 通过、0 失败、0 跳过** | 官方 Xcode MCP 执行；Header 拖动、快速分页、嵌套列表位置恢复及全部 3 项 SystemContainerTests（安全区域、旋转、系统标签切换、RTL）。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0，无 runner 错误。 |

修正系统容器 UI 测试中的旧短列表指示器断言，使其与现有业务默认显隐契约一致，没有调整指示器实现。

本次 4 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-initial-position-safearea-final-ui/swiftformat-lint.txt)，`git diff --check` 通过。没有提交或推送。

**证据边界：** 位置和同步回调语义由真实 UIWindow 下的库测试验证，不承诺初始原始 offset 或屏幕像素不变。未执行 Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。

## 2026-10-24：原生减速、解绑坐标与 inset 基准复查

在上一轮未提交修改上修复三类同步交互遗漏：

- 原生减速去重不再跳过每次分页输入对框架旧拖动／惯性的取消；业务原生减速仍按同一次分页只交接一次。
- 内容与纵向指示器 inset 按 KVO 通知层级区分框架 setter 和业务嵌套 setter。外部赋值的嵌套回调完成前不叠加贡献；框架写入回调中的业务修改记入基准并在当前更新后处理，防止业务值丢失或中间贡献污染外层通知。按方向的数值契约及同方向读改写限制保持不变。
- 业务在框架写入 contentInset 的同步回调中解绑后，旧几何更新立即退出，不再将已还原的正文位移覆盖为含 Header 折叠距离的旧位置。

新增 5 项库回归：重复分页开始时取消框架拖动但不重复停止业务减速；两类 inset 在业务 setter／框架 setter 回调中的嵌套业务赋值；业务 KVO 观察者两种注册顺序下的 inset 赋值；同步回调解绑后停止旧坐标回写；自动 inset 下解绑保留负位移。README 同步上述边界，没有新增公开 API。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 与目标；库测试继续使用仓库 UIKit application host 脚本。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首次复查基线](Results/20261024-inset-handoff-review-baseline/summary.json) | **1 通过、2 失败** | 自动 inset 负位移解绑通过；分页旧拖动仍推进、嵌套 inset 业务基准丢失。保留当时实现与测试源码。首版指示器几何断言还混入初始归一化位移 13 的差异，后续将夹具显式定位到 0；业务基准丢失另由解绑后的 inset 断言确认。 |
| [解绑回调基线](Results/20261024-inset-handoff-review-detach-baseline/summary.json) | **1 失败** | 解绑后正文位置应为 150，却被旧更新写回 350；保留修复前绑定和测试源码。 |
| [观察者顺序基线](Results/20261024-inset-handoff-review-observer-baseline/summary.json) | **1 失败** | 框架自身通知已处理完，但层级标记仍使后续业务 KVO 写入被忽略，bottom 31 丢失为 19；修正为本次通知结束即释放标记。保留当时源码。 |
| [最终聚焦](Results/20261024-inset-handoff-review-final-focused/summary.json) | **115 通过、0 失败、0 跳过** | 包含全部复查修复；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [最终完整库](Results/20261024-inset-handoff-review-final-library/summary.json) | **258 通过、0 失败、0 跳过** | 包含全部复查修复；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [最终 Demo UI](Results/20261024-inset-handoff-review-ui/summary.json) | **6 通过、0 失败、0 跳过** | 官方 Xcode MCP 执行；Header 拖动、快速切页、原生下拉刷新、禁用列表交互、嵌套列表位置恢复及 RTL 边界交接；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

中间 `20261024-inset-handoff-review-focused` 的 113 项通过仅代表前两类修复完成的源码；`20261024-inset-handoff-review-final` 的 114 项与 `20261024-inset-handoff-review-library` 的 257 项通过包含解绑回调修复，但未包含随后发现的观察者顺序修复。保留各阶段结果与对应快照，不作为最终验证。

本次 3 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-inset-handoff-review-ui/swiftformat-lint.txt)，`git diff --check` 通过。没有提交或推送。

**证据边界：** 原生停止请求次数由可控减速状态的库夹具验证；嵌套 inset 与解绑回调由真实 UIWindow 下的子类回调和 KVO 观察者验证。解绑的业务坐标还原不等于系统布局期间像素完全静止。未执行 Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。

## 2026-10-24：原生减速、解绑坐标与 inset 基准职责收敛

仅在 Header／标签栏开始接管纵向拖动、或同一次分页首次开始时，停止 `isDecelerating == true` 的业务列表；移除程序化切页的重复停止入口，候选页建立与变化共用分页交接。静止列表和业务程序化滚动动画不发送额外停止定位；必要的布局和正文位置协调保留，不承诺业务动画跨这些定位继续运行。

解绑使用 `q - clamp(q, 0...C)` 还原业务正文位移，保留负向位移，折叠范围为 0 时同样不会清零；inset／offset 相同时不额外回写。`contentInset` 与 `verticalScrollIndicatorInsets` 按各方向的新旧数值维护业务基准，变化方向使用新基准，未变化方向保留旧基准，避免只修改 bottom／left／right 时重复叠加其他方向贡献。同方向读改写不解释为业务增量，整组赋值中与实际值相同的分量也保留原基准。无新增公开 API，已同步 README。

新增 4 项库回归：静止／减速列表在 Header、程序化切页与横向分页中的停止请求计数；零／正折叠范围、负位移／部分折叠／正文位移、刷新中／未刷新及重复解绑；内容 inset 多方向更新、原值回写、范围变化和解绑；指示器 inset 多方向更新、原值回写和解绑。原同步回调取消测试改为明确处于减速状态，继续验证真实停止请求中的业务取消不会被覆盖。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo scheme 与运行目标；库测试使用仓库 UIKit application host 脚本，UI 通过官方 MCP 执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前基线](Results/20261024-inset-handoff-baseline/summary.json) | **4 失败** | 复现静止定位／重复停止、负位移清零与两类 inset 重复叠加，保留原实现和测试源码快照。首版解绑夹具另有非法横向位置被 UIKit 修正、刷新控件调整基准的干扰；后续给出合法横向范围，并在刷新布局后设置明确基准，不将这些夹具断言作为框架缺陷。 |
| [聚焦回归](Results/20261024-inset-handoff-focused/summary.json) | **110 通过、0 失败、0 跳过** | 容器、绑定与分页，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库回归](Results/20261024-inset-handoff-library/summary.json) | **253 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [Demo UI 回归](Results/20261024-inset-handoff-ui/summary.json) | **6 通过、0 失败、0 跳过** | Header 拖动、快速切页、原生下拉刷新、禁用列表交互、嵌套列表位置恢复及 RTL 边界交接；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

本次 3 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-inset-handoff-ui/swiftformat-lint.txt)，`git diff --check` 通过。没有提交或推送。

**证据边界：** 停止请求的精确次数由可控减速状态的库夹具验证，UI 测试覆盖实际触摸交互；解绑的业务坐标还原不等于系统布局期间像素完全静止。未执行 Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。

## 2026-10-24：滚动职责边界提交前整合验证

提交前同步远端 `main` 的 `d37f09e` 与 `04322f5`，保留标签栏布局数值、宽度分配模式及 Demo 的全部改动。代码与接入文档自动合并；验证记录仅发生新增段落冲突，双方历史证据完整保留。本次滚动容器、绑定及回归测试实现与复查版本一致。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 scheme 与运行目标；库测试通过仓库 UIKit application host 脚本执行，UI 通过官方 MCP 执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [整合后完整库](Results/20261024-scroll-boundary-push-library/summary.json) | **249 通过、0 失败、0 跳过** | 包含远端新增标签栏测试和本次滚动职责回归；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [整合后 Demo UI](Results/20261024-scroll-boundary-push-ui/summary.json) | **5 通过、0 失败、0 跳过** | Header 拖动、普通页面、禁用列表后的 Header／标签栏拖动与切页、标签栏纵向拖动、短／空／长内容指示器；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

本次 5 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-scroll-boundary-push-ui/swiftformat-lint.txt)，`git diff --check` 通过。此前记录保留为各阶段验证，不以旧源码结果代替本次整合验证。未执行 Release、iPad、iOS 15 实际运行、真机和完整 Demo 测试套件。

## 2026-10-24：滚动开关与零折叠范围职责边界复查

复查发现并修复 1 项同步回调遗漏：Header 拖动开始时停止列表原生减速，业务 `UIScrollView` 子类可在 `setContentOffset(_:animated:)` 回调里关闭并立即开启滚动。原实现先取消交互，随后又登记同一次拖动，导致旧手势及惯性继续推进正文。现在先登记交互，再停止原生减速，返回后确认交互仍有效；同步回调中的取消不会被覆盖。未新增公开 API，也未改变业务滚动开关所有权、布局或切页协调。

新增 3 项库回归：上述同步回调取消、后台页和已解绑列表关闭滚动不干扰当前拖动，以及固定高度 Header 的零折叠范围下缓存页更新业务 inset、恢复折叠范围与解绑。原有零范围几何回归扩展至 `.automatic`、`.always`、`.scrollableAxes`、`.never` 四种策略。零折叠范围底部贡献逻辑未发现额外缺陷，保持上一轮实现。同步 README 的回调取消语义。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 确认 Demo 工程、scheme 和运行目标；库测试仍通过仓库脚本配置的 UIKit application host 执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [同步定位回调失败基线](Results/20261024-scroll-boundary-review-callback-baseline/summary.json) | **1 失败** | 实际子类回调已触发，旧拖动及惯性仍推进正文；保存修复前容器和测试源码。 |
| [最终聚焦](Results/20261024-scroll-boundary-review-focused/summary.json) | **106 通过、0 失败、0 跳过** | 容器、绑定及分页回归；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库测试](Results/20261024-scroll-boundary-review-library/summary.json) | **237 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [Demo UI 聚焦](Results/20261024-scroll-boundary-review-ui/summary.json) | **5 通过、0 失败、0 跳过** | 官方 Xcode MCP：禁用列表后的 Header／标签栏拖动及切页、正常列表 Header 拖动、普通页面拖动、标签栏纵向拖动和短／空／长内容指示器；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

首轮 `20261024-scroll-boundary-review-baseline` 中，后台页／解绑与缓存页 inset 两项通过；回调测试使用同值偏移 KVO，但 UIKit 没有发出该通知，属于夹具未触发预期条件，不作为框架缺陷证据。修正为业务滚动视图子类的实际定位回调后，重新建立上述失败基线。保留首轮日志和测试源码快照。

最终 5 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261024-scroll-boundary-review-ui/swiftformat-lint.txt)，`git diff --check` 通过。保留上一轮所有修改，本轮没有提交或推送。

**未覆盖：** Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机和完整 Demo 测试套件。同步定位回调的精确时序由库测试夹具验证，UI 用例覆盖真实触摸下的正常路径和禁用路径。

## 2026-10-23：业务滚动开关与零折叠范围的职责收敛

按确认的选项 1：已绑定业务列表关闭 `isScrollEnabled` 后，Header／标签栏整次纵向联动暂停，不推动 Header 或正文。绑定观察关闭事件并立即取消框架旧拖动和惯性，手势入口、处理过程和惯性采样同时检查开关；同一帧重新开启不会续接旧交互。框架不写入业务开关，保留布局、业务程序化位置及切页恢复的协调；未绑定列表的普通页面保留原有交互。自动发现仍跳过预先禁用的列表，显式绑定可继续提供布局和位置协调。

折叠范围为 0 时，底部补齐贡献归零；保留业务底部 inset、顶部标签栏避让及系统安全区域调整。折叠范围恢复为正数后，短／空内容仍可通过必要的底部补齐完成 Header 折叠。同步 README；本轮不改动动画终止策略、解绑偏移换算及 inset 基准赋值契约。

新增 4 项库回归：禁用后拒绝输入但保留切页／布局／程序化位置协调，关闭并立即开启时旧拖动及惯性不续接，显式绑定预先禁用的列表，以及零折叠范围下短／空／长内容、尺寸变化、自动／手动 inset、移除与恢复 Header 的底部贡献。Demo 新增回归启动参数，在绑定后模拟业务禁用列表；UI 用例通过实际 Header 和标签栏拖动验证，并继续横向切页。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。已通过官方 Xcode MCP 核对工程、scheme 和目标；库测试需要仓库生成 UIKit application host 的 `.xctestrun`，使用脚本执行，UI 测试通过官方 MCP 执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前基线](Results/20261023-scroll-enabled-zero-range-baseline/summary.json) | **3 失败** | 原实现仍驱动禁用列表，并在零范围时补齐底部；保存当时容器、绑定和测试源码。 |
| [中间聚焦](Results/20261023-scroll-enabled-zero-range-focused/summary.json) | **100 通过、2 失败** | 禁用开关测试直接断言自动 inset 调整过程中的原始 offset，出现 44 pt 差异；后续改用 `.never` 固定该组手势测试的坐标基准，自动 inset 的真实接入由 UI 用例覆盖。同时补上关闭事件即时取消和显式绑定用例。 |
| [最终聚焦](Results/20261023-scroll-enabled-zero-range-final/summary.json) | **103 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库测试](Results/20261023-scroll-enabled-zero-range-library/summary.json) | **234 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [Demo UI 聚焦](Results/20261023-scroll-enabled-zero-range-ui/summary.json) | **5 通过、0 失败、0 跳过** | 官方 Xcode MCP：禁用列表后的 Header／标签栏拖动及横向切页、正常列表 Header 拖动、普通页面拖动、标签栏纵向拖动和短／空／长内容指示器；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

最终 5 个修改的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261023-scroll-enabled-zero-range-ui/swiftformat-lint.txt)，`git diff --check` 通过。失败基线和中间结果保留，不替代最终源码验证。本轮没有提交或推送。

**未覆盖：** Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。

## 2026-10-24：布局模式审查修复与 Demo 窄卡片

Demo 卡片在 `.fill` 下依据可用宽度、间距、项数和最小项宽计算等宽结果；不足 `max(160, 标题字体行高 × 6)` 时移除编号、缩小水平留白并居中显示两行以内的标题与副标题。布局选择写入内容配置，测量和实际显示共用；宽度恢复时重新插入编号。副标题的垂直压缩优先级略低于标题，消除初次布局高度竞争的歧义。保留 `.automatic` 默认策略与框架布局实现。

分页与独立标签栏共用 `showCustomContent(on:)`：已为自定义模式时重载，否则通过 `contentStyle` setter 刷新，避免重复测量。“自动布局”改名“自动图文排列”。README 与 `SPTabBarContent.size` 注释补齐各模式的理想宽度、压缩及 required 最小宽度契约，并明确不可压缩宽内容示例不适用于 `.fill`。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator（x86_64）。先尝试官方 Xcode MCP，连接故障后使用仓库验证脚本；UI 回归通过 `test-without-building` 复用同一源码构建产物。

- **MCP 环境阻塞：** [构建日志](Results/20261023-card-adaptation-mcp/build.log) 显示构建成功，但 [测试日志](Results/20261023-card-adaptation-mcp/xcodebuild.log) 记录 LLDB 附加测试宿主失败，[MCP 摘要](Results/20261023-card-adaptation-mcp/mcp-summary.txt) 为 2 项未执行。
- **首轮失败保留：** [首轮单元测试](Results/20261023-card-adaptation-unit/summary.json) 为 2 失败，卡片文字存在垂直布局歧义；测试窗口未等待 appearance 完成还产生 5 条诊断。已保存当时卡片和测试源码。修正压缩优先级与测试窗口生命周期后重跑，保留无歧义断言，并增加大字号实际生效断言。
- **最终单元测试通过：** [卡片组合测试](Results/20261023-card-adaptation-unit-final/summary.json) 为 2 通过、0 失败。真实 UIWindow 中覆盖 13 项卡片的四模式往返切换、LTR／RTL、普通／辅助功能最大字号、24／44／600 pt 最小项宽、间距，以及单项视口 80／320／80 pt 往返；检查内部文字边界、无布局歧义、编号隐藏和恢复、选择与栏高。
- **最终 UI 回归通过：** [UI 结果](Results/20261024-card-adaptation-ui/summary.json) 为 6 通过、0 失败。包含已有独立栏 LTR／RTL 与默认内容分页模式测试、新增卡片 LTR／RTL 四模式真实点击与拖动、恢复默认内容，以及原有多行自定义内容自动栏高测试。已导出 [截图清单](Results/20261024-card-adaptation-ui/attachments/manifest.json)，核对 LTR／RTL 窄卡片与恢复编号后的宽卡片。

两份最终结果均为 `sourceChangedSinceRun=[]`，三类运行时诊断均为 0；日志未发现 Auto Layout 约束冲突或布局歧义。修改／新增的 6 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。本轮未修改框架运行代码，未重跑库测试；未执行完整 Demo 套件、Release、iPad、iOS 15 实际运行或真机验证。保留此前全部修改与历史证据，未提交或推送。

## 2026-10-23：Demo 标签布局模式切换

分页 Demo 的“页面”和独立“标签外观”的“配置”菜单新增共用的“标签布局模式”子菜单，可选择 `.automatic`、`.fill`、`.centered`、`.leading`。使用不缓存的延迟菜单，每次打开按标签栏当前模式设置勾选；动作只修改 `itemPositioning`，保留内容、间距、附件、方向和选择。独立标签栏新增“紧凑编号内容”，便于在手机上比较 `.centered` 与 `.leading` 的留白；“自定义卡片”恢复非紧凑内容。默认仍为 `.automatic`，未修改库实现、工程 target 或 scheme。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator（x86_64）。Demo 构建按既有 Build Phase 运行 SwiftFormat 0.64.0。

- **官方 MCP 环境阻塞：** [首轮结果](Results/20261023-demo-positioning-focused/summary.json) 与 [MCP 返回](Results/20261023-demo-positioning-focused/mcp-result.json) 已保存。构建成功，但 LLDB 无法附加到 UI 测试 Runner；MCP 报告 1 项未执行，xcresult 记录 Runner 启动错误，不能作为测试断言失败或通过。随后回退到仓库 `Scripts/validate.sh`，未更改全局调试权限。
- **独立标签栏通过：** [LTR UI 测试](Results/20261023-demo-positioning-cli/summary.json) 为 1 通过、0 失败、0 跳过。真实点击四种模式，检查项宽、留白、选中状态，并验证紧凑内容切回卡片和默认内容；已导出并核对 `.centered` 与 `.leading` 截图，见该目录 attachments。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。

- **中间轮失败保留：** [RTL／分页尝试](Results/20261023-demo-positioning-remaining/summary.json) 中，RTL 四种模式的几何检查通过，但恢复宽卡片后选中项在视口外，测试直接读取已回收 Cell 的 frame 失败；随后重启的 Runner 等待 AX loaded 超时，分页用例未实际执行。已保留原测试源码，并修正用例先真实拖动到目标再验证恢复后的内容和选择，没有修改库或放宽几何断言。

- **最终 UI 回归通过：** [最终结果](Results/20261023-demo-positioning-final/summary.json) 为 3 通过、0 失败、0 跳过。覆盖独立栏 LTR／RTL 四模式切换、内容恢复与选择保留，以及分页页菜单的实际项宽和当前页面保持。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。

修改或新增的 4 个 Demo Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。未执行完整 Demo 测试集、Release、iPad、iOS 15 实际运行或真机测试；本次只改 Demo，未重跑库测试，前述库功能的历史结果单独保留。

## 2026-10-23：SPTabBar leading 布局模式

在已有 `SPTabBar.ItemPositioning` 末尾新增 `.leading`，默认仍为 `.automatic`，既有枚举 rawValue 保持不变。每项使用内容测量宽度与 `minimumItemWidth` 的较大值，相邻项保持 `itemSpacing`；扣除安全区域、附件和内容留白后从逻辑起始端排列，余量全部留在 trailing。RTL 下从右侧开始，余量留在左侧；超宽时与 `.centered` 一致，选中项仍沿用已有滚动定位规则。

`.leading` 与 `.centered` 共用自然首选宽度测量。实际布局和几何变化判断共用整组对齐偏移，确保切换模式时分页指示器刷新，等价的超宽几何保留手动偏移和选择动画。README 补充模式表、设置示例、RTL 与测量说明；保留上一轮未提交修改及历史验证记录。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator（x86_64），部署目标 iOS 15。官方 Xcode MCP 仍仅报告 Demo 窗口，库测试通过仓库 UIKit application host 脚本执行。

- **聚焦通过：** [布局模式测试](Results/20261023-tab-leading-focused/summary.json) 为 12 通过、0 失败、0 跳过，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。新增 3 项测试覆盖短单项与空列表、超宽时与 `.centered` 等价及滚动动画、自然内容宽度与 Dynamic Type；扩展已有用例覆盖四种模式切换与默认策略恢复、LTR/RTL、安全区域、附件、留白、尺寸变化、默认／自定义／回退内容及分页指示器。

- **完整库回归通过：** [最终库结果](Results/20261023-tab-leading-library/summary.json) 为 242 通过、0 失败、0 跳过，覆盖所有标签栏测试及容器、滚动、缓存和生命周期测试。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。

修改的 3 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。未执行 Demo UI 真实触摸、Release、iPad 模拟器、iOS 15 实际运行或真机测试。

## 2026-10-23：SPTabBar 宽度分配模式

新增框架自己的 `SPTabBar.ItemPositioning` 与 `itemPositioning` 属性，采用 UIKit 风格的 `.automatic`、`.fill`、`.centered` 命名。默认保留原自适应策略；`.fill` 均分剩余宽度并遵守最小项宽；`.centered` 按内容宽度排列，空间充足时整组居中。三种模式共用安全区域、附件、留白、间距与 RTL 处理。模式切换保留选择、分页进度和实际几何不变时的动画；测量快照包含模式和最小项宽，候选测量不修改当前布局。

`.fill` 内置长标题使用尾部省略；自定义多行内容通过普通测量宿主按分配宽度求高度，水平优先级 999 避免与业务 required 最小宽度冲突。`.centered` 的自动内容测量使用自然首选宽度。同步根 README 的接入和测量契约。

环境：Xcode 26.5（17F42）/ Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator（x86_64），部署目标仍为 iOS 15。官方 Xcode MCP 仅报告 Demo 窗口；尝试独立打开 Package 后仍未返回库窗口。库测试使用仓库 `Scripts/validate.sh` 的 UIKit application host 流程，未将库测试加入 Demo target 或 scheme。

- **首轮失败保留：** [新增模式首轮](Results/20261023-tab-positioning-focused/Result.xcresult) 为 6 通过、1 失败；根控制器的 trait override 未传播到标签栏，导致字号测高断言失败。改用现有测试的子控制器 trait 注入方式，新增实际字号断言；原测试源码保存在该运行目录。
- **中间版本通过：** [标签栏回归](Results/20261023-tab-positioning-final/Result.xcresult) 为 134 通过、0 失败。之后补齐等宽长标题截断及系统内容软宽度测量，该记录不作为最终源码的完整回归证据。
- **最终聚焦通过：** [内容与模式测试](Results/20261023-tab-positioning-content/summary.json) 为 23 通过、0 失败、0 跳过，其中新增 9 项覆盖默认策略恢复、三种模式、溢出、RTL、安全区域、附件、留白、尺寸变化、空／单项、默认／自定义／回退内容、Dynamic Type、多行系统内容、候选测量、选择及分页指示器。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。

- **最终完整库回归通过：** [完整库结果](Results/20261023-tab-positioning-library/summary.json) 为 239 通过、0 失败、0 跳过，包含标签栏及容器、滚动、缓存、生命周期测试。`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。

修改的 3 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。未执行 Demo UI 真实触摸测试、Release、iPad 模拟器、iOS 15 实际运行或真机验证。

## 2026-10-23：SPTabBar 布局数值审查与重构

本次仅整理内部布局规则，保留数值、公开 API 和现有布局行为：

- 内置图文的 24 pt 图标槽位、4 pt 图文间距、单侧 16 pt 水平留白，以及单侧 11 pt 垂直留白由 `SPDefaultTabContentMetrics` 统一定义；总留白从单侧值派生，测量、按钮配置与角标空间计算共用。默认内容高度规则集中计算，仍至少 44 pt；自定义内容不额外套用该规则。
- 角标尺寸与内边距在原 `SPTabBadgeMetrics` 内命名，测量与实际定位共用 4 pt 内容重叠量，避免只修改一处导致位置或宽度不一致。
- 内容、附件及指示器共用 1,000,000 pt 几何上限；仍分别保留原有非有限值回退、正负值及尺寸校验规则。默认最小项宽、独立布局的缺省宽度各自命名，未因数值相同而与其他策略耦合。
- 滚动呈现的 0.5 pt 容差和最大 16 pt 渐隐宽度在标签栏内命名；自定义内容测量优先级改为从 `required` 减 1 派生，实际仍为 999。
- 保留已具备明确语义的胶囊／下划线预设、单像素分隔线、居中与插值公式，以及 `0`、`1`、`2` 等常规数学系数；不新增公开配置。接入及行为说明未变化，无需修改根 README。

按用户要求，`.gitignore` 新增 `.DS_Store`、根目录 `build/`、`.xcarchive` 和 `.xcresult`；沿用现有 SwiftPM、Xcode 用户数据、DerivedData 及验证目录规则。未新增其他编辑器或未使用工具的忽略项。验证 11 项本地产物被忽略、8 项共享源码／配置／证据保持可跟踪，所有已跟踪文件均未命中忽略规则，见 [忽略规则检查](Results/20261023-tabbar-layout-metrics/gitignore-check.txt)。

环境：Xcode 26.5 / Swift 6.3.2 / Debug，iPhone 17 Pro / iOS 26.5 Simulator（x86_64）。官方 Xcode MCP 的 `XcodeListWindows` 返回 `Transport closed`，回退到 `SP_SCOPE=library Scripts/validate.sh test`，通过仓库独立 UIKit application host 执行根 Package 测试。

- **通过：** 8 类 `SPTabBar*Tests` 共 **127 项，0 失败、0 跳过**，涵盖 RTL、左右安全区域、Dynamic Type、长标题、尺寸变化、短／空内容、角标、指示器、附件、自定义内容回退与自动测量、滚动位置及选择转场。读取终态 [summary.json](Results/20261023-tabbar-layout-metrics/summary.json)，`sourceChangedSinceRun=[]`；feedback loop、appearance 不平衡及不兼容内容替换诊断均为 0。
- **通过：** 5 个修改的 Swift 文件使用 SwiftFormat 0.64.0 按根配置格式化，[lint](Results/20261023-tabbar-layout-metrics/swiftformat-lint.txt) 与 `git diff --check` 通过。测试沿用现有行为回归，未新增仅复述常量实现的测试。
- **未执行：** 完整库测试、Demo 构建／UI 测试、Release、iPad、iOS 15 实际运行和真机验证。本次不改变容器或手势逻辑，不将聚焦库测试结果扩展为这些范围已通过。

## 2026-10-23：指示器职责边界复查

复查上一轮未提交修改，发现并修复两类回调重入遗漏：

- 显隐回调中切回 `.preserve` 或解绑时，外层旧操作可能继续隐藏另一方向；恢复中重新开启隐藏还可能保存到只恢复了一半的配置。现在按状态版本串行完成显隐更新，完整恢复后才清除业务意图；缓存页逐页读取最新策略，避免使用回调前的过期值。
- 统一屏蔽框架显隐写入期间的所有通知，会漏掉业务在回调中的再次赋值。现在按方向和通知层级识别本次框架 setter 的通知，保留同轴同值、跨轴及恢复期间的业务配置修改。保留原有几何更新期间的滚动回调保护。

新增 4 项库回归，覆盖上述路径与多个缓存页。前三项修复前失败；业务嵌套赋值用例使用动态派发夹具后确认修复前失败。同步 README 的回调赋值语义；策略注释统一为“切页转场”，与现有无动画切页的同步转场语义一致。没有扩大公开 API 或接管默认模式显隐。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 核对工程、scheme 和目标并执行 UI 测试；库测试继续使用仓库 UIKit application host 脚本。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [策略／解绑重入失败基线](Results/20261023-indicator-review-baseline/summary.json) | **3 失败** | 保存修复前容器、绑定和测试源码快照。 |
| [动态派发下的业务赋值失败基线](Results/20261023-indicator-review-dynamic-baseline/summary.json) | **1 失败** | 同轴同值、跨轴及恢复期赋值均丢失；保存对应绑定和测试源码。 |
| [最终聚焦](Results/20261023-indicator-review-final/summary.json) | **99 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库测试](Results/20261023-indicator-review-library/summary.json) | **230 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [Demo UI 聚焦](Results/20261023-indicator-review-ui/summary.json) | **4 通过、0 失败、0 跳过** | 官方 Xcode MCP：默认短／空／长列表显隐、可选分页隐藏与恢复、快速切页、嵌套列表位置恢复；`sourceChangedSinceRun=[]`，完整控制台三类运行时诊断均为 0。 |

中间阶段 `20261023-indicator-review-focused`、`20261023-indicator-review-focused-final` 的 98 项通过只代表当时实现。`20261023-indicator-review-notification-baseline`、`20261023-indicator-review-regressions` 和 `20261023-indicator-review-notification-trace` 保留诊断过程；其新增赋值用例的 Swift 属性重写未使用动态派发，部分嵌套写入绕过 KVO，不作为最终框架行为判据。修正夹具后重新建立上述动态派发失败基线，并执行最终回归。临时通知日志已从源码移除。

最终 6 个修改或新增的 Swift 文件通过 SwiftFormat 0.64.0 [lint](Results/20261023-indicator-review-ui/swiftformat-lint.txt)，`git diff --check` 通过。保留上一轮所有修改；本轮没有提交或推送。

**未覆盖：** Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。UI 验证为真实触摸下的显隐属性变化与恢复，不等同于指示器像素持续显示验证。

## 2026-10-23：业务滚动指示器职责收敛

新增 `SPScrollIndicatorVisibilityPolicy` 与 `SPPageViewController.scrollIndicatorVisibilityPolicy`。默认 `.preserve`，绑定、布局、分页、解绑均不写入业务列表两个方向的显隐属性；移除短／空内容按正文范围自动隐藏。业务显式选择 `.hideDuringPaging` 后，仅在分页期间保存并临时覆盖显隐，结束、取消、解绑、释放或切回 `.preserve` 时恢复最新业务意图，包括隐藏期间同值 `false` 的赋值。保留必要的纵向指示器 inset 避让与现有滚动协调。

同步 README 的默认行为、接入示例和临时隐藏的读取／赋值语义。新增 3 项库测试，更新原有短／空内容、混合页面、分页显隐和 inset 恢复断言；覆盖四种显隐组合的零写入、内容与视口变化、分页中的策略切换、重复赋值、重新绑定、重载及释放。Demo 增加显式策略启动参数与仅在回归模式计数的显隐观测；新增真实分页 UI 用例，并加强短／空／长内容用例的显隐断言。

环境：Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。官方 Xcode MCP 核对 Demo scheme 和运行目标并执行 UI 测试；库测试需要仓库脚本生成 UIKit application host 的 `.xctestrun`，采用脚本执行。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮聚焦](Results/20261023-indicator-policy-focused/summary.json) | **93 通过、2 失败** | 两处旧测试仍断言短／空内容自动隐藏；更新为保留业务配置。保存失败时测试源码快照，结果与最终源码的差异已标记。 |
| [最终聚焦](Results/20261023-indicator-policy-focused-final/summary.json) | **95 通过、0 失败、0 跳过** | 容器与分页回归，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库测试](Results/20261023-indicator-policy-library/summary.json) | **226 通过、0 失败、0 跳过** | 最终源码，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [Demo UI 聚焦](Results/20261023-indicator-policy-ui/summary.json) | **4 通过、0 失败、0 跳过** | 默认策略下短／空／长列表显隐、显式策略真实横向分页隐藏与恢复、快速切页、嵌套列表位置恢复；`sourceChangedSinceRun=[]`，完整控制台日志的三类运行时诊断均为 0。 |

6 个修改或新增的 Swift 文件使用 SwiftFormat 0.64.0 按仓库配置格式化，[lint](Results/20261023-indicator-policy-ui/swiftformat-lint.txt) 通过，`git diff --check` 通过。没有提交或推送。

**证据边界：** UI 用例验证真实触摸下显隐属性的临时写入及最终恢复，不将其解释为 UIKit 实际指示器像素的持续显示。未执行 Release、Swift 6.3、iPad、iOS 15 实际运行、真机和完整 Demo 测试套件。

## 2026-10-23：滚动职责收敛复查

在上一轮未提交修改上复查，发现并修复 1 项边界拖动遗漏：位置钳制后仍以手势开始时的绝对 translation 计算位置，越界距离虽不显示，却会变成反向拖动时必须先抵消的空行程。现在钳制时同步更新拖动基准；Header／标签栏与无滚动视图的普通页采用相同规则，边界反向移动立即生效，仍不模拟越界和回弹。

新增 2 项真实 UIWindow 库回归：上下边界反向移动覆盖长／短／空内容、普通页、LTR／RTL；列表自身负向位移在普通布局更新中保留，分别覆盖未刷新和正在刷新。前者在修复前失败，修复后通过。同步 README 的边界交互说明，未改变公开 API、业务回弹配置、刷新所有权或其他既有策略。

环境沿用 Xcode 27.1 / Swift 6.4 / Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。库测试使用仓库 UIKit application host 脚本；官方 Xcode MCP 已核对 Demo 工程、scheme 和运行目标。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前失败基线](Results/20261023-scroll-review-baseline/summary.json) | **1 失败** | 新增边界反向用例；保存当时的容器和测试源码，失败证据保留。 |
| [修复后聚焦](Results/20261023-scroll-review-focused/summary.json) | **92 通过、0 失败、0 跳过** | 容器及分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [完整库测试](Results/20261023-scroll-review-library/summary.json) | **223 通过、0 失败、0 跳过** | 最终源码回归，`sourceChangedSinceRun=[]`；三类运行时诊断均为 0。 |
| [Demo UI 聚焦](Results/20261023-scroll-review-ui/summary.json) | **5 通过、0 失败、0 跳过** | 官方 MCP：Header、普通页、标签栏纵向拖动、原生刷新及嵌套列表位置恢复；`sourceChangedSinceRun=[]`，完整控制台日志的三类诊断均为 0。 |

本轮主动格式化和 lint 仅覆盖 2 个修改的 Swift 文件，使用 Package 缓存的 SwiftFormat 0.64.0；[lint](Results/20261023-scroll-review-ui/swiftformat-lint.txt) 通过，`git diff --check` 通过。没有提交或推送。

**证据边界：** 上一轮结果保留为对应阶段证据，不替代本轮最终源码验证。未执行 Release、Swift 6.3、iPad、iOS 15 实际运行、真机及完整 Demo 测试套件。

## 2026-10-23：滚动职责边界收敛

本轮从干净工作区开始，仅收敛已讨论的三项职责：

- `SPScrollBinding` 不再保存、强制开启或恢复业务 `alwaysBounceVertical`；业务在绑定期间修改回弹配置，解绑后仍保留新值。
- Header／标签栏拖动及 display link 惯性均限制在合法滚动范围内，移除越界阻尼和弹簧回弹。保留 Header 折叠、折叠后正文滚动，以及范围内惯性；列表原生触摸的减速和回弹由 UIKit 与业务配置管理。
- 框架源码不再读取 `refreshControl`／`isRefreshing`。刷新期间按实际位置协调，不强制展开 Header、不把正文归零、不禁用框架纵向手势；切页和取消沿用普通页面的共享状态规则。Demo 列表页显式设置 `alwaysBounceVertical = true`，由页面持有刷新策略。

同步 README；保留原有指示器显隐、自动发现和 inset 基准契约。本轮没有新增公开 API、修改 Package／工程配置、提交或推送。

新增 3 项库回归，覆盖回弹配置所有权、长／短／空内容在上下边界的拖动与实际 display link 采样、范围内惯性推进及边界停止；更新 2 项刷新回归，覆盖刷新期间滚动／Header 手势／惯性、切页提交和取消，并检查刷新控件及刷新状态仍由业务持有。Demo 原生刷新触摸用例增加 Header 下拉不触发刷新、随后列表下拉正常触发刷新的检查。

环境：Xcode 27.1（27A9275）、Swift 6.4、Debug，iPhone 18 Pro Max / iOS 27.0 Simulator。已通过官方 Xcode MCP 核对 Demo 工程、scheme 和运行目标。库测试需要脚本生成 UIKit application host 的 `.xctestrun`，官方测试接口无法配置该执行路径，故库测试使用仓库脚本。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [容器与分页聚焦](Results/20261023-scroll-ownership-focused/summary.json) | **90 通过、0 失败、0 跳过** | 含全部本轮库回归，`sourceChangedSinceRun=[]`；三类运行时诊断均为 0。 |
| [完整库测试](Results/20261023-scroll-ownership-library/summary.json) | **221 通过、0 失败、0 跳过** | `sourceChangedSinceRun=[]`；三类运行时诊断均为 0。 |
| [官方 MCP UI 测试](Results/20261023-scroll-ownership-demo-ui/summary.json) | **7 通过、0 失败、0 跳过** | Xcode 延迟执行；后续归档原始结果包。`sourceChangedSinceRun=[]`，无可导出的控制台日志，运行时诊断未核验。 |
| [Demo UI 聚焦（脚本）](Results/20261023-scroll-ownership-demo-ui-cli/summary.json) | **7 通过、0 失败、0 跳过** | iPhone 18 Pro / iOS 27.0；与官方执行同一组触摸用例，`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

官方测试请求等待期间未返回结果，回退脚本后发现 Xcode 已延迟启动 Runner；终止工具等待不会取消 Xcode 的执行。最终归档官方结果包，两次测试分别保留证据，详见[执行说明](Results/20261023-scroll-ownership-demo-ui/notes.txt)。

5 个修改的 Swift 文件使用 Package 缓存中的 SwiftFormat 0.64.0 CLI，按根目录配置格式化及 lint；[lint](Results/20261023-scroll-ownership-demo-ui/swiftformat-lint.txt) 为 `0/5 files require formatting`。Demo Build Phase 为 `0/48 files formatted, 2 files skipped`，未引入额外源码差异。`git diff --check` 通过。

**未覆盖：** Release、Swift 6.3 工具链、iPad、iOS 15 实际运行、真机和完整 Demo 测试套件。

## 2026-10-23：提交前复查标签栏刷新边界

在上一轮未提交的 6 个文件上继续审查，发现并补充修复以下遗漏：

- `minimumItemWidth` 固定 Item 尺寸时，标题区域或替换 Appearance 后的指示器端点仍可变化；仅比较 Item 测量无法判断程序动画是否还有效。为选择动画保存原始端点几何，在最终布局核对后按实际变化结束旧动画。
- 分页接管程序动画时保存的呈现起点也需要校验端点几何。内容区域改变后，清除旧接管起点，按相同分页端点和进度重新定位；接管前先处理待完成布局，覆盖属性修改与接管发生在同一轮更新的情况。
- 通用属性刷新保留动画后，“减少动态效果”通知不再经过原有的停止动画路径。按通知类型单独结束程序动画并对齐选中项；透明度通知仍保留几何未变的动画，分页进度不清空。

新增 4 项真实 UIWindow 回归，其中内容区域及分页起点覆盖 LTR／RTL。复查基线 4 项全部失败，修复后指示器、间距、自定义内容及标签布局聚焦共 75 项通过。公开注释和 README 明确：保留动画的前提包括指示器端点几何不变。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [复查失败基线](Results/20261023-tab-review-baseline/summary.json) | 0 通过、4 失败 | 保存对应实现及测试源码；三类运行时诊断均为 0。 |
| [复查聚焦回归](Results/20261023-tab-review-focused/summary.json) | 75 通过、0 失败、0 跳过 | 指示器、间距、自定义内容和标签布局。 |
| [第一阶段完整库测试](Results/20261023-tab-review-library-final/summary.json) | 218 通过、0 失败、0 跳过 | 包括新增 4 项回归；后续继续补充同一轮更新的接管顺序。 |
| [接管顺序聚焦](Results/20261023-tab-review-takeover-focused/summary.json) | 4 通过、0 失败、0 跳过 | 属性更新在接管前／后两种顺序、程序动画中断、屏幕外几何及重新布局。 |
| [最终完整库测试](Results/20261023-tab-review-library-final-r2/summary.json) | **218 通过、0 失败、0 跳过** | 最终源码 `sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |
| [最终 Demo UI 聚焦](Results/20261023-tab-review-demo-ui-final/summary.json) | **4 通过、0 失败、0 跳过** | 指示器预设与前景命中、分页及取消手势、动态内容与禁用项、间距菜单操作与选择／分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

本节是提交前的后续复查；下方上一轮 214 项库测试及 4 项 UI 测试仅对应其当时源码，不能替代后续修复的验证。

本轮使用 Xcode 27.1 / Swift 6.4、Debug、iPhone 18 Pro / iOS 27.0；库测试仍通过独立 UIKitTestHost 运行。沿用同一会话已确认可用的脚本流程完成验证，官方 MCP 的 hosted xctestrun 限制及 UI 请求未启动记录见下节。新增测试通过通知中心验证无障碍通知响应，没有修改系统无障碍设置。未补测 Release、Swift 6.3、iPad、iOS 15、真机或完整 Demo UI 套件。

最终源码共新增 9 项库回归（前一轮 5 项、本轮 4 项），SwiftFormat 0.64.0 格式校验及 `git diff --check` 通过；按用户要求使用中文提交，不推送。

## 2026-10-23：标签间距、指示器几何与属性刷新

从干净工作区开始，审查 `SPTabBar`、`SPTabBarItem`、`SPTabBarAppearance` 及指示器布局的属性更新链路。未更改公开 API、输入归一化规则或选择回调契约；未提交或推送。

- 指示器内容区域原来只按索引缓存。在间距、最小宽度或留白 setter 使 Collection View 布局失效后，另一次同步指示器刷新可能在 `prepare()` 前缓存旧坐标；后续布局继续复用该值。现在缓存同时保存并核对 Item frame，位置或尺寸不匹配时重新计算。
- Item／Appearance 的通用更新原来直接清空分页转场、停止动画并标记重新居中。现在共用内容刷新策略，保留分页端点和进度；几何不变时保留程序动画与手动偏移，实际几何变化时按原内容刷新规则处理。
- `indicatorColor` 改为只刷新渲染，栏级和 Item 级设置均不再中断程序选择动画。指示器几何配置及显式 `reloadIndicator()` 仍遵循其结束程序动画的既有约定。
- 默认内容的 Dynamic Type 等测量环境变化仍在实际几何改变时对齐选中项。README 新增属性、影响范围和刷新入口对照表，包括业务自有内容与附件需要显式失效通知的边界。

新增 5 项真实 UIWindow 回归，覆盖 LTR／RTL、自定义内容区域和实际 UIButton 标题几何、间距／最小宽度／留白／栏尺寸的连续修改、标题／字体／角标／Appearance 更新中的分页进度，以及颜色更新中的动画。旧实现基线运行其中 3 项，全部复现失败。

库测试使用 Xcode 27.1 / Swift 6.4、Debug、iPhone 18 Pro Max / iOS 27.0。通过仓库脚本构建独立 Package 测试包，再用 UIKitTestHost 提供 UIApplication；官方 MCP 的 scheme 测试接口无法配置该脚本生成的 hosted xctestrun，因此不把库测试加入 Demo scheme。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [修复前回归基线](Results/20261023-tab-layout-baseline/summary.json) | 0 通过、3 失败 | 捕获旧坐标复用、分页进度清空、动画和手动偏移跳变；保存对应修复前源码。 |
| [首次聚焦回归](Results/20261023-tab-layout-focused/summary.json) | 51 通过、0 失败 | 指示器、间距、自定义内容；包括全部 5 项新增用例。 |
| [首次完整库测试](Results/20261023-tab-layout-library-final/summary.json) | 213 通过、1 失败 | `testDynamicTypeUpdatesWidthsAndCentering` 暴露字体环境变化后的重新居中回归；保留失败和对应源码。 |
| [环境对齐修正后聚焦](Results/20261023-tab-layout-traits-focused/summary.json) | 47 通过、0 失败 | Dynamic Type 对齐、指示器及自定义内容。 |
| [完整库测试终态](Results/20261023-tab-layout-library-final-r2/summary.json) | **214 通过、0 失败、0 跳过** | `sourceChangedSinceRun=[]`；三类运行时诊断均为 0。 |
| [Demo UI 聚焦终态](Results/20261023-tab-layout-demo-ui-r2/summary.json) | **4 通过、0 失败、0 跳过** | 指示器预设与前景命中、分页与取消手势、动态内容与禁用项、间距菜单操作与选择／分页；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

修改的 4 个 Swift 文件使用 Package 锁定版本对应的 SwiftFormat 0.64.0 CLI 按根目录 `.swiftformat` 格式化及 lint；`git diff --check` 通过。旧轮次保留为各自阶段的证据，不能作为最终源码的通过结论。

Demo UI 优先尝试 Apple 官方 Xcode MCP；请求等待数分钟未返回，当时 Xcode 仍显示既有 Demo 调试会话，没有观察到 UI 测试 Runner，记录为[未执行尝试](Results/20261023-tab-layout-demo-ui-mcp-attempt/notes.txt)。随后改用仓库脚本，在实际读取到的 iPhone 18 Pro / iOS 27.0 模拟器上执行同样 4 项 UI 测试。首次 CLI 启动误填设备 UUID，在测试执行前停止，保留[中止记录](Results/20261023-tab-layout-demo-ui/notes.txt)及日志；正确设备运行使用独立的 `20261023-tab-layout-demo-ui-r2` 目录。

**未覆盖：** 未执行 Release、Swift 6.3、iPad、iOS 15 实际运行或真机验证；未执行完整 Demo UI 套件。

## 2026-10-23：最小接入与控制器生命周期 Demo 单元测试

将 `StickyPagerDemoTests` 的空模板替换为四项 Swift Testing 用例，使用 `@testable import StickyPagerDemo` 测试真实 `MinimalIntegration`：

- 数据源的页数、稳定标识、标签及独立滚动页面。
- 真实 UIWindow 中的容器 containment、四边布局、Header 和初始选择，以及重复加载和重载后的页面复用。
- 通过实际内容页的子控制器观察 appearance 回调，完整断言切页、导航遮盖／返回及窗口拆除的回调顺序。
- 非动画导航退出后，用弱引用验证示例、分页容器、内容页、滚动视图和 Header 均释放。

窗口测试使用宿主 `UIWindowScene`，在主 actor 上串行执行；拆除时先在可见窗口中移除根控制器，再隐藏窗口并恢复原 key window。未修改框架实现、Demo 产品代码或工程配置。

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [首轮 Debug](Results/20261023-demo-unit-lifecycle-r1/summary.json) | 3 通过、1 失败 | 生命周期夹具同步推进 RunLoop 后即断言，`didAppear` 尚未交付；保留原测试源码和失败结果。 |
| [异步夹具复测](Results/20261023-demo-unit-lifecycle-r2/summary.json) | 4 通过、0 失败 | 让出主 actor，并有界等待实际回调数量；完整顺序断言保留。 |
| [修复宏警告后的最终 Debug](Results/20261023-demo-unit-lifecycle-final/summary.json) | **4 通过、0 失败、0 跳过** | Apple 官方 Xcode MCP，Xcode 27.1 / Swift 6.4，iPhone 18 Pro Max / iOS 27.0；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。 |

释放用例先以显式 `UIView` 局部变量承接 `#require(pager.headerView)`，再赋给弱引用，保留 Header 必须存在的断言并消除直接赋给可选弱引用时的宏冗余警告。最终构建日志确认该警告消失；仍有 Xcode 27.1 测试框架最低系统版本高于 iOS 15 target 的既有链接警告。两次 MCP 复测的输入哈希在构建等待期间保存，终态通过摘要核对；旧轮次的源码差异不能当作最终源码已验证。

本轮遇到高系统负载及构建工具重编译，部分替代验证被中止：[Release 尝试](Results/20261023-demo-unit-lifecycle-release/notes.txt)、[命令行 Debug 尝试](Results/20261023-demo-unit-lifecycle-cli-r3/notes.txt)、[隔离副本尝试](Results/20261023-demo-unit-isolated-debug/notes.txt)、[冗余 Debug 尝试](Results/20261023-demo-unit-lifecycle-final-debug/notes.txt)。这些目录保留日志，不作为通过证据；本次启动的遗留 SwiftFormat 编译进程已结束。最终 MCP 工件副本缺少 `Info.plist`，保留为 `MCPPartial.xcresult`；正式 `Result.xcresult` 来自同次运行已完成的 Xcode 原始结果包，摘要确认四项通过。

**未覆盖：** 本轮未完成 Swift 6.3／Release 测试验证，未运行完整库测试、Demo UI 回归、iPad、iOS 15 或真机测试。README 中的 Release 单元测试命令要求 `ENABLE_TESTABILITY=YES`，不能用此前空模板的 Release 构建结果证明这四项新测试已通过。

## 2026-10-23：Demo 单元测试 target 与文档审查

新增 `StickyPagerDemoTests` 应用宿主单元测试 target，并加入共享 scheme 的 Test Action；应用、Demo 单元测试和 UI 测试共三个 target，根目录 Package 库测试保持独立。审查修复了模板配置中的 iOS 27 最低版本、Swift 5 语言模式及 macOS／visionOS 平台声明：Debug / Release 均复用 `Tests.xcconfig`，继承 iOS 15、Swift 6 和 iPhone／iPad 设置，仅支持 iOS 平台；补齐 scheme 中的 `BlueprintName`。文档明确三个 target 与两个测试 target 的区别，以及三类测试的职责。

| 验证 | 结果 | 范围 |
| --- | --- | --- |
| [官方 Xcode MCP Debug 聚焦测试](Results/20261023-demo-tests-mcp-review/summary.json) | 2 通过、0 失败、0 跳过 | Xcode 27.1、iPhone 18 Pro Max / iOS 27.0；`StickyPagerDemoTests/example()` 与 `StickyPagerDemoUITests/testHeaderStartsAtScreenTopAndPageContentMeetsTabBar()`。三类运行时诊断均为 0。 |
| [Release 测试构建](Results/20261023-demo-tests-release-review/summary.json) | `TEST BUILD SUCCEEDED`，退出码 0 | Xcode 26.6 / Swift 6.3.3，iPhone 17 Pro / iOS 26.5 目标；应用及两个测试 target 的 `build-for-testing` 通过，未执行 Release 测试。 |
| 工程与文档静态核对 | 通过 | `plutil -lint`、scheme XML 的 Build / Test Action 引用、文档 target 数量与职责、`git diff --check`。 |

两次构建均通过 Demo 的 SwiftFormat Build Phase，格式化后的源码对应两份摘要的 `sourceChangedSinceRun=[]`。MCP 运行的源码哈希在自动格式化完成后、等待测试执行结果期间记录。Release 验证通过仓库脚本指定另一套 Xcode 和配置，不切换全局 `xcode-select`；其摘要中的测试数量为 0、结果为 `unknown`，因为该次仅构建测试包，成功依据是构建日志和退出码。

Xcode 27.1 的测试链接日志提示 XCTest、Testing、XCUIAutomation 等测试框架的最低系统版本高于 target 的 iOS 15 设置；本轮 iOS 27.0 实际测试通过，不据此宣称 iOS 15 测试运行兼容。Xcode 26.6 Release 构建另有未依赖 AppIntents 而跳过元数据提取的警告。

`StickyPagerDemoTests` 仍只有无行为断言的 Swift Testing 模板用例，本轮仅证明其能够构建、加载并执行。未执行完整库测试、完整 Demo UI 回归、Release 测试运行、iOS 15 实际运行或真机验证；未改动框架实现及现有 UI 测试逻辑。

## 2026-10-22：顶部对齐完整 Demo UI 回归与滚动回写修复

从提交 `7278e2a` 的干净工作区开始，使用 Xcode 27.1 / Swift 6.4、Debug、iOS 26.5 的 iPhone 17 Pro 与 iPad Pro 13-inch (M4)。本轮用户要求完整 Demo UI 回归、发现问题直接修复并保留失败；不提交或推送。Demo 使用 Apple 官方 Xcode MCP，iPad 初轮与独立 Package 宿主库测试使用仓库脚本；库测试仍独立于 Demo scheme。

### 首轮完整结果与诊断

| 运行 | 终态 | 发现 |
| --- | --- | --- |
| [iPhone 完整 UI 首轮](Results/20261022-top-alignment-full-ui-iphone-r1/summary.json) | 40 通过、12 失败、8 跳过，共 60 项 | 5 项标签栏纵向拖动未完成折叠，7 项旋转断言失败；8 项跳过为 iPad 专属窗口、分屏及指针用例。 |
| [iPad 完整 UI 首轮](Results/20261022-top-alignment-full-ui-ipad-r1/summary.json) | 40 通过、20 失败、0 跳过，共 60 项 | 18 项在旋转步骤失败；另 2 项标签横向拖动用例的默认内容在宽屏上仅剩约 14 pt 滚动余量，不足以验证其长距离拖动要求。3 项实际系统窗口连续缩放用例通过。 |
| [Header 拖动诊断](Results/20261022-top-alignment-drag-diagnostic/Result.xcresult) | 0 通过、1 失败 | 临时调用栈定位到 UITableView 布局回写近乎相同的 `contentOffset`，触发绑定回调并中止 Header 拖动；临时日志已移除。 |
| [旋转串行复核](Results/20261022-top-alignment-serial-focus-r1/summary.json) | 2 项用例失败，另有 Runner exit 75 错误 | `.xcresult` 因 Runner 错误共计 3 条失败；官方 MCP 用例计数为 2。排除了仅由两组 UI 测试并行造成失败的解释。 |
| [仅重启模拟器后](Results/20261022-top-alignment-reboot-focus-r1/summary.json) | 0 通过、2 失败 | 第一项在获取活动应用时发生 AX -25218，清理阶段卡住后结束该 Runner，保留 signal term；第二项仍未进入横屏。 |

首轮 iPad 在运行期间开始了后续源码修复，其摘要的 `sourceChangedSinceRun` 列出 3 个修改文件；首轮二进制来自修复前快照，不能当作修复后验收。所有失败目录、日志、截图和 `.xcresult` 均保留，没有通过删除失败记录获得绿色结果。

### 修复与环境恢复

- `SPScrollBinding` 仍对偏移通知刷新指示器，仅在纵向偏移实际变化超过既有定位精度 `0.001 pt` 时通知容器接管滚动。相同值及浮点尾差不再中止当前 Header 拖动，真实外部滚动仍能接管。
- 新增真实 UIWindow 回归 `testNumericalOffsetWritebackDoesNotInterruptHeaderDrag`，验证连续拖动、完全折叠后正文滚动及真实外部偏移接管。旧实现运行该新增用例失败，4 条位置断言均捕获拖动停在约 45 pt 的问题。
- 两项标签横向拖动 UI 用例先通过公开菜单设置最小项宽 120 pt，建立充分滚动余量；保留原移动距离、居中、边界与选中状态断言。
- 手动多次旋转及仅重启模拟器均未恢复应用方向；按用户要求重启 Device Hub 后，同一 Demo 实际进入横屏，导航栏、标签及网格重新布局。保留[横屏截图](Results/20261022-top-alignment-devicehub-restart/landscape.png)与[操作记录](Results/20261022-top-alignment-devicehub-restart/notes.txt)。这是环境恢复证据，不能替代其后的自动测试终态。
- iPad 后续补测暴露了分屏辅助函数遗漏的状态：系统旋转会把窗口恢复全屏，原函数仍直接点击仅在窗口化状态下提供的 `window-controls`。四项分屏用例在同一辅助函数失败，失败前的窄窗口分页与顶部几何断言通过。补充全屏尺寸判断，以真实右下角系统手柄缩小窗口并断言宽度至少缩小 100 pt，然后重新建立分屏；原分页、位置保持、安全区域及不重叠断言不变。该修改仅用于 iPad 分屏测试，不改变产品代码。

| 修复阶段 | 结果 | 说明 |
| --- | --- | --- |
| [新增回归的旧实现基线](Results/20261022-top-alignment-offset-baseline/summary.json) | 0 通过、1 失败 | 原实现无法抵抗相同偏移／浮点尾差回写。 |
| [绑定修复首轮](Results/20261022-top-alignment-offset-focused/summary.json) | 86 通过、1 失败 | 过早过滤通知使短内容指示器在视口缩小后未刷新；保留失败并调整通知顺序。 |
| [绑定修复聚焦终态](Results/20261022-top-alignment-offset-focused-r2/summary.json) | 87 通过、0 失败 | 容器与分页库测试；指示器刷新先于实际滚动变化过滤，`sourceChangedSinceRun=[]`。 |
| [Device Hub 重启后 UI 聚焦](Results/20261022-top-alignment-hub-focus-r1/summary.json) | 4 通过、0 失败、0 跳过 | 网格 LTR／RTL 连续旋转、标签安全区域 LTR、两项横向标签拖动。MCP 简表误报 4 项未执行，实际日志及终态 `.xcresult` 均为 4 项通过。 |
| [iPad 完整库测试](Results/20261022-top-alignment-library-final-ipad/summary.json) | 209 通过、0 失败、0 跳过 | 三类运行时诊断均为 0；框架与库测试源码一致，差异仅为 Demo 工程签名 Team 和后续 iPad 分屏测试辅助函数，见下述核验。 |
| [iPhone 完整 UI 终态](Results/20261022-top-alignment-full-ui-iphone-final-r3/summary.json) | 52 通过、0 失败、8 跳过，共 60 项 | 首轮 12 项失败全部通过；8 项为 iPad 专属。三类运行时诊断均为 0；后续仅修改 iPad 分屏辅助函数，见下述源码范围核验。 |
| [iPad 14 项补测首轮](Results/20261022-top-alignment-ipad-final/summary.json) | 9 通过、5 失败、0 跳过 | 4 项分屏在旋转恢复全屏后找不到系统窗口控制按钮；另 1 项 RTL 系统容器在横屏后的新拖动未产生滚动位移。两项宽屏标签拖动、网格连续旋转、固定 Label、指针观察、三项窗口缩放及系统容器 LTR 均通过。 |
| [分屏修正与 RTL 状态诊断](Results/20261022-top-alignment-ipad-input-diagnostic/summary.json) | 2 通过、0 失败 | 修正后的 LTR 分屏边界通过；RTL 原无位移现象未复现。该轮系统容器未开启触摸轨迹窗口，只记录状态值，不作为输入轨迹证据。 |
| [RTL 实际触摸轨迹诊断](Results/20261022-top-alignment-ipad-input-trace/summary.json) | 1 通过、0 失败 | 临时开启现有 `--paging-trace`；[解码轨迹](Results/20261022-top-alignment-ipad-input-trace/decoded-touch-traces.json)确认两侧横屏均收到约 535 pt 纵向触摸、正文滚动约 519.5 pt，触摸以 ended 结束。临时参数和日志随后全部移除。 |
| [iPad 无临时诊断终态回归](Results/20261022-top-alignment-ipad-recovery-final/summary.json) | 5 通过、0 失败、0 跳过 | 四项分屏修正及原 RTL 系统容器用例均通过；`sourceChangedSinceRun=[]`，三类运行时诊断均为 0。系统容器测试代码已逐字节恢复原文件。 |

运行期间外部曾修改 Demo 工程 Debug／Release 的 `DEVELOPMENT_TEAM`，随后又恢复为空，本轮均未干预。iPad 库测试快照包含该签名配置差异，将恢复后的文件中的两处空 Team 替换为当时值，SHA-256 与运行快照精确一致，见[签名配置核验](Results/20261022-top-alignment-library-final-ipad/current-source-audit.json)。后续只在 `arrangeSideBySide` 增加了 8 行窗口前置操作；[修改前后 diff](Results/20261022-top-alignment-ipad-final/window-setup-fix.patch)及[范围核验](Results/20261022-top-alignment-full-ui-iphone-final-r3/final-scope-audit.json)确认，移除这 8 行后 UI 文件与 iPhone 完整回归快照逐字节相同。该函数仅由四个经过 iPad 条件检查的分屏用例调用。框架、库测试和 Demo 源码未再改变；临时系统容器诊断已恢复至原文件。因而此前的全量结果保留其实际执行范围，不能将历史 `sourceChangedSinceRun=[]` 理解为后来增加测试辅助操作后仍完全无文件差异。

官方 MCP 完整测试曾因活动目标被切到真机 `iPhone Xr.` 而在 UI 测试 target 签名阶段失败，保存[构建日志](Results/20261022-top-alignment-full-ui-iphone-final-r2/xcodebuild.log)，没有将该次计为已执行 UI 测试；后续改用脚本固定模拟器 UUID，不改动用户当前 Xcode 运行目标。

**保留的因果边界：** iPad RTL 系统容器那次旋转后的无位移失败没有被后续诊断复现，原运行缺少实际触摸轨迹，不能把它明确归因于输入未送达或某一框架缺陷，也不能宣称已找到并修复其根因。后续通过记录与原失败分别保存。

**终态覆盖：** iPhone 完整套件为 52 通过、8 项 iPad 专属跳过；iPad 14 项补测中的 9 项先通过，其余 5 项在修正／诊断后以最终源码全部通过。按用例标识去重，60 个 Demo UI 用例均有通过记录，缺失 0，见[覆盖审计](Results/20261022-top-alignment-final-audit/coverage.json)。这是完整 iPhone 套件加 iPad 分组回归，iPad 后续没有再次运行完整 60 项套件。iPhone 首轮 12 项失败均在完整终态运行中通过；iPad 首轮 20 项失败与后续补测的 5 项失败均保留原记录，不据分组结果宣称每个旧 iPad 场景都已经重新执行。

最终 3 个修改 Swift 文件的 SwiftFormat 0.64.0 lint 和 `git diff --check` 通过；仅保留滚动绑定修复、新库回归、UI 测试前置操作及本验证记录，共 4 个文件。没有提交或推送，也没有改动用户当前 Xcode 真机目标。未执行本轮独立 Release、最低 iOS、真机、Duo、VoiceOver 和性能专项；这些范围不由模拟器 Debug 结果推定通过。

## 2026-10-22：原 iPhone 菜单输入因果对照

在原 iPhone 18 Pro Max／iOS 27.0（24A434），UUID `41AF9CED-9BBB-4B60-B563-73AFB035C2D4` 上继续排查。遵照用户要求使用当前工作区，保留本来已有的安全区域与顶部对齐改动。官方 Xcode MCP 负责构建、测试与 LLDB；输入操作使用电脑工具。没有修改 `DemoPager` 的原生菜单、拦截系统滚轮或加入失败重试。

### 对照结果与因果边界

- **工具滚轮已送达，未触发收起：** 菜单内／外、上下及横向对照均未命中 UIKit 收起断点。App 的 [事件日志](Results/menu-causality-20261022/input-probes-app.log)确认收到 `.scroll`。[一次事件参数](Results/menu-causality-20261022/scroll-parameters.json)为垂直增量 128、phase 2、scrollType 1；按本机 SDK，scrollType 1 是 continuous，不能将其写成离散滚轮。该参数只是单次快照，不代表历史故障的完整事件序列。
- **触摸展开后再滚轮的假设实验失败：** [向下](Results/menu-causality-20261022/touch-opener-down/Result.xcresult)与[向上](Results/menu-causality-20261022/touch-opener-up/Result.xcresult)分别 0 通过、1 失败；预期菜单关闭，但菜单始终存在。两次没有修改实验断言，改变的是输入方向。[解码轨迹](Results/menu-causality-20261022/touch-opener-traces.json)显示触摸序号仍为 2、触摸样本仍为 2，滚轮计数从 0 增至 2。两个用例是被否定的实验假设，不是产品回归失败，也没有改成成功或跳过；临时测试已移除。实验没有完整的运行前源码哈希，不宣称 `sourceChangedSinceRun=[]`。
- **人工鼠标滚轮接收未证实：** 用户确认在同一独立窗口使用鼠标滚轮；[操作后画面](Results/menu-causality-20261022/human-scroll-after.png)仍显示菜单，断点未命中。[App 日志](Results/menu-causality-20261022/human-scroll-app.log)及[限定的系统输入日志](Results/menu-causality-20261022/human-scroll-input.log)没有检出对应滚轮事件，因此不能作为已送达的阴性对照，更不能推断用户未操作。
- **菜单外触摸取消路径已确认：** 14:24 的菜单外点击和 14:44 的菜单外拖动均命中 UIKit 收起断点。[点击栈](Results/menu-causality-20261022/outside-click-stack.json)与[拖动栈](Results/menu-causality-20261022/outside-drag-stack.json)经 `_UIPassthroughScrollInteraction` → `_UIContextMenuContainerView` → `_UIContextMenuPresentation` 请求关闭，实参 reason 为 0。[拖动日志](Results/menu-causality-20261022/outside-drag-app.log)记录的是 `.touches`，不是 `.scroll`；[继续执行后的截图](Results/menu-causality-20261022/outside-drag-after.png)确认菜单关闭、仍为网格页。私有符号仅用于调试观察，未进入源码；不能因调用栈名称包含 Scroll 就判定滚轮是历史根因。

**尚未闭环：** 原故障只有滚轮到达与菜单关闭的时序记录，缺少可重放的完整输入参数及当时的关闭调用栈。本轮确认了触摸取消路径，否定了“这些已送达的滚轮足以关闭菜单”的假设，但仍不能证明原 11:01:53 故障由同一种路径触发。没有依据修补产品菜单；本次提交是诊断证据及取消行为回归，不是原偶发故障修复声明。

### 回归与交付边界

新增 `testPagesMenuOutsideDragCancelsWithoutInvokingAction`：单次、按视口比例的菜单外拖动必须实际产生向上位移；要求只有一个新增触摸且无额外滚轮、菜单关闭、标签高度与选中页不变；随后作为独立交互重新打开菜单，验证动作仍能改变标签高度。前置断言失败立即停止，没有菜单丢失时重开补救或放宽原断言。

| 状态 | 范围 | 证据与限制 |
| --- | --- | --- |
| **通过** | 新增拖动取消首轮，1 项 | [结果](Results/menu-causality-final-focus-20261022/summary.json)。此后补充实际位移断言并恢复 scheme 文件原有末尾字节，因此该次不是最终源码验收。 |
| **通过** | 原 iPhone 最终 4 项 UI，0 失败、0 跳过 | 新增拖动取消、四轮无输入保持／动作、点击取消／子菜单、原自动栏高。[摘要](Results/menu-causality-final-regression-20261022/summary.json)、[日志](Results/menu-causality-final-regression-20261022/xcodebuild.log)、[结果包](Results/menu-causality-final-regression-20261022/Result.xcresult)、[调用参数](Results/menu-causality-final-regression-20261022/command.txt)；`sourceChangedSinceRun=[]`，三类运行时诊断计数均为 0。 |
| **通过** | SwiftFormat 0.64.0 单文件 lint、`git diff --check` | 本轮源码只新增一个 UI 用例；移除该函数后，该文件与起始快照逐字节相同，其他既有源码哈希未变。 |
| **失败，保留** | 两次滚轮关闭假设实验 | 上下方向均收到滚轮而菜单未收起，不能包装成产品修复后的通过。 |
| **被环境／工具能力阻塞** | 原历史输入的精确重放 | 原日志没有完整事件参数，iPhone XCTest pointer 输入不受支持，人工鼠标输入送达未证实；电脑工具已送达的序列未复现故障。 |
| **未执行** | 完整套件及跨设备矩阵 | 仅对本次测试与诊断范围作聚焦验证，不以其代替完整验收。 |

终态由 Apple 官方 `RunSomeTests` 执行。聚焦首轮的 MCP 导出 `.xcresult` 缺少 `Info.plist`，已保留不完整导出，并从 Xcode DerivedData 取得**同次、同时间戳**的原始结果包；最终四项回归的 MCP 导出完整。最终结果使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/summarize_validation.py Validation/Results/menu-causality-final-regression-20261022` 校验；并非重跑来替代结果。临时 scheme 修改曾使目标回到物理 iPhone 13，造成一次签名构建失败，保留[日志](Results/menu-causality-20261022/destination-reset-build.log)，重新指定原模拟器后完成实验；该签名失败不属于菜单故障。交付时已恢复原物理 iPhone 13 目标。

临时调试启动参数、人工等待测试和 LLDB 断点均移除；本轮公开 API 与接入行为无变化，README 的公开契约不调整。构建产生的格式化已与起始快照比较，既有布局修改保持原样。未运行完整库／完整 Demo 套件、iPad、Duo、独立 Release、最低 iOS、真机或 VoiceOver 专项；这些结果不由本轮聚焦回归推定通过。原失败和本轮假设失败证据均保留。

## 2026-10-22：内容页根视图与标签栏顶部对齐

本轮将 `viewControllerAt` 返回页面的真实根视图顶部从标签栏底部移至标签栏顶部，保留容器左右／底边、Header 折叠范围和逻辑分页索引。开始时已有菜单诊断修改；执行期间另一端新增 `fb9cc1f` 将其提交，本轮保留该内容，未执行提交或推送。

提交前复核：用户随后授权全部本地提交。重新检查全部 13 个改动文件，10 个 Swift 文件的 SwiftFormat 0.64.0 lint 与 `git diff --check` 通过。本次复核没有重新运行 XCTest。实时重算 SHA-256 后，顶部对齐终态 iPad 库测试、iPhone UI 修正回归及 iPad UI 的快照均仅有 `StickyPagerDemoUITests.swift` 与当前文件不同：差异恰为既有提交 `96cd7b4` 新增的 32 行菜单取消测试，剔除该新增片段后与三份快照逐字节一致，框架、库测试及原 UI 回归代码未变。该菜单提交的四项最终回归快照与当前源码完全一致。下表的 `sourceChangedSinceRun=[]` 为对应运行结束时的记录，不能理解为后来新增菜单测试后仍无文件差异；原有失败证据及生成结果继续保留在忽略目录中。

### 影响分析与实现

- 分页视口起点由 `S + minimumHeaderHeight + T` 改为 `S + minimumHeaderHeight`，子页仍下移剩余折叠距离 `C - c`；根视图与标签栏共同位于实际 Header 底部，标签栏保持最高显示／触摸层级。
- 子页附加安全区域增加实际栏高 `T`，普通控件可继续约束到 Safe Area。滚动绑定按实际重叠量扣除已有自动 inset，仅补足尚未避让的标签栏部分，覆盖 `.automatic`、`.always`、`.scrollableAxes`、`.never`、滚动根视图及固定 Label 下方的独立滚动视图。
- 短／空内容的底部补齐量扣除标签栏避让，实际滚动范围仍足以折叠 Header。自动指示器使用 Safe Area，手动指示器补足标签栏遮挡，保留业务指示器值。
- 框架管理的附加安全区域随隐藏／动态栏高更新，并在删除、缓存淘汰及容器释放时恢复业务值；只改业务其他 inset 边不会累计 top。根视图尺寸不再随栏高改变，因此单独追踪栏高变化以保留底部钳制、缓存位置和转场取消行为。
- API 签名不变；依赖旧根视图起点或直接使用 `topAnchor` 的业务布局需按新 Safe Area 调整。公开协议、README 及 AGENTS 的长期布局约定已同步。

### 基线、修正与终态证据

| 运行 | 结果 | 说明 |
| --- | --- | --- |
| [基线](Results/20261022-top-alignment-baseline/Result.xcresult) | 0 通过、1 失败 | 新增真实窗口测试在旧实现稳定检测到根视图比标签栏顶部低 44 pt。 |
| [聚焦 r1](Results/20261022-top-alignment-focused-r1/Result.xcresult) | 79 通过、3 失败 | 指示器显式 inset 旧假设、测试删除后索引错误，以及放大 bounds 后顶部随中心移动的几何问题；失败证据保留。 |
| [聚焦 r2](Results/20261022-top-alignment-focused-r2/Result.xcresult) | 81 通过、1 失败 | 修正前两项；剩余用例的 bounds 放大使视口移入 Header／标签栏区域，实际 adjustedTop 为 763 pt，不能按未遮挡的完整视口判断短内容。 |
| [聚焦 r3](Results/20261022-top-alignment-focused-r3/Result.xcresult) | 86 通过、0 失败 | 用 frame 放大保持视口顶部不动，保留实际范围与指示器断言；另验证手动指示器、业务 Safe Area 增量修改、动态栏高、移除后位置恢复和分页仲裁。 |
| [iPhone 完整库测试](Results/20261022-top-alignment-library-final/Result.xcresult) | 208 通过、0 失败、0 跳过 | Xcode 27.1／Swift 6.4、iPhone 17 Pro／iOS 26.5；此后仅修正两个 Demo UI 测试文件，框架与库测试源码未变化。 |
| [终态 iPad 完整库测试](Results/20261022-top-alignment-library-ipad-final/Result.xcresult) | 208 通过、0 失败、0 跳过 | iPad Pro 13-inch (M4)／iOS 26.5；独立 UIKit application host，`sourceChangedSinceRun=[]`。 |
| [iPhone UI 首轮](Results/20261022-top-alignment-ui-iphone/Result.xcresult) | 13 通过、4 失败、0 跳过 | 官方 MCP 与原始 xcresult 计数一致；包含系统容器三项、嵌套边界、普通页面、混合布局、刷新、短／空／长内容指示器及附件栏高恢复。 |
| [终态 iPhone UI 修正回归](Results/20261022-top-alignment-ui-iphone-recovery/Result.xcresult) | 4 通过、0 失败、0 跳过 | 重新构建后运行首轮失败的四项：组合布局分页／位置恢复、异步替换、自动栏高、旋转／系统返回；`sourceChangedSinceRun=[]`。 |
| [终态 iPad 系统容器 UI](Results/20261022-top-alignment-ui-ipad-final/Result.xcresult) | 3 通过、0 失败、0 跳过 | 展开／部分折叠／吸顶／最后一行、LTR／RTL、左右横屏与竖屏、系统 Tab 切换、位置恢复及旋转后新触摸；`sourceChangedSinceRun=[]`。 |

库测试使用仓库宿主脚本：官方 MCP 的 Demo scheme 仅含 Demo 与 UI 测试，不支持库测试所需的独立 hosted xctestrun 配置。Demo 测试构建通过官方 Xcode MCP 完成。上述库运行均未发现 observation feedback loop、appearance 不平衡或不兼容内容视图替换诊断；历史聚焦结果与对应源码分别保存，不替代终态完整库结果。修改文件的 SwiftFormat 0.64.0 lint 及 `git diff --check` 通过。

iPhone UI 首轮的四项失败保留：组合布局用例在页面上移后选中了标签栏覆盖区域的卡片中心（触点 y=124.7，标签栏 y=116～160），现从标签栏底部以下选择实际可见触点；异步替换用例的诊断输出读取了不存在的 Toolbar，现按是否存在记录 frame，不改变后续滚动断言；动态栏高与旋转返回用例共用的 `assertPageFrame` 仍要求旧的底部对齐，现改为本次顶部对齐契约。正文起点、Safe Area、完整触摸距离、分页提交和滚动位置断言均保留。修正后的四项均通过，结果单独记录，不将首轮包装为一次全部通过的 UI 运行。首轮通过后的变化仅涉及这两个 UI 测试文件，框架源码未再修改；终态库与 UI 回归均未发现 observation feedback loop、appearance 不平衡或不兼容内容视图替换诊断，当前无未解决的环境阻塞。

iPhone UI 采用官方 Xcode MCP；它运行期间不能切换目标，iPad UI 使用仓库脚本在另一台模拟器执行，每台设备仅有一个输入执行端。未执行完整 59 项 Demo UI 套件、iOS 15 最低版本、真机、iPhone Duo 内外屏、独立 Release 回归、VoiceOver 和性能专项；这些范围不由本轮结果推定通过。

已导出并检查 iPad 的[展开画面](Results/20261022-top-alignment-ui-ipad-final/screenshots/A8F0DE7E-B328-417A-81C4-7AD51FE336FB.png)和[吸顶画面](Results/20261022-top-alignment-ui-ipad-final/screenshots/59F10EBA-20F9-4663-9615-1E74841B4E29.png)：正文位于标签栏下方，未出现重复顶部留白或标签栏遮挡首行；具体几何仍以真实窗口／UI 断言为准。

## 2026-10-22：页面菜单偶发收起排查与输入观测修正

从干净的 `5056653` 开始。本轮没有修改 `DemoPager` 的原生 `UIBarButtonItem.menu`、框架菜单处理或动画策略；修正的是测试输入观测，**不能据此宣布原偶发故障已修复**。

### 原失败的直接证据

后续历史记录所称“未见菜单展开”只反映最终截图。逐帧检查原 [UI 失败录屏](Results/content-reuse-demo-ui-20261022/attachments/4D4269F1-2D8F-4843-B89E-0C9FA7AE4F6E.mp4)发现菜单先正常展开，随后在 XCTest 下一条动作之前收起。[展开帧](MenuDiagnostics/original-open.png)与[收起帧](MenuDiagnostics/original-closed.png)分别提取自约 17 秒、30 秒，保留原录屏和提取脚本；使用 `AVAssetImageGenerator` 零时间容差并记录实际返回帧时间，静态区间不能按请求时间冒充新画面。

本机仍保留原失败的统一日志，按明确的模拟器 UUID 和 `2026-10-22 11:01:35～11:01:55` 时段读取，未凭复测通过推断原因：

- [App 日志](Results/pages-menu-baseline-20261022/original-app-unified.log)：11:01:38.656 开始菜单动画；11:01:53.280～53.346 向应用窗口派发 `UIEvent` type 10；53.384 开始另一段菜单动画。SDK `UIEvent.h` 明确 type 10 为 `.scroll`。
- [系统输入日志](Results/pages-menu-baseline-20261022/original-input-unified.log)：53.047 新增 `eventSource: mouse`、`transport: CoreDevice` 的触控板服务。此记录只标识通道，不足以归因到某个操作者或工具。
- [testmanagerd 日志](Results/pages-menu-baseline-20261022/original-testmanager-unified.log)：53.417 收到 `_UIContextMenuActionsOnlyViewController` 的 `ViewDidDisappear`。原测试此时仍在等待入口点击后的空闲，下一条菜单项点击记录到 54.79 左右才开始；用例中没有该段滚轮操作。

据此排除“入口从未展开”这一解释，确认故障时段存在用例外的 pointer 输入。**输入与收起的先后关系已证实，完整因果机制及输入发起端仍未闭环。** 用户回复不确定当时是否有其他操作；宿主侧对应时段的限定日志查询没有匹配结果，不能用缺少日志推断无人操作。未将共享 `UIAction`、状态标签布局或菜单条目数量猜测成根因，也未替换原生菜单作为规避。

### 对照实验与实际修正

- 原实现新增四轮单击／保持／动作回归，[初轮 1 项通过](Results/pages-menu-baseline-20261022/Result.xcresult)；延长至每轮无输入保持 15 秒后，与原自动高度用例合跑 [2 项通过](Results/pages-menu-held-20261022/Result.xcresult)。前后触摸序号均为 2、4、6、8，命中 `_UIButtonBarButton`，每次按下至抬起约 0.067 秒。这些通过记录仅证明当次未复现。
- iPhone 受控 pointer 实验[失败](Results/pages-menu-pointer-control-20261022/Result.xcresult)：XCTest 明确报告 `Pointer events are not supported for this device`，属于实验能力受限。电脑滚轮对照也未在 App 日志中得到已送达的 `.scroll`，不能算有效复现。
- iPad pointer 实验[失败](Results/pages-menu-ipad-pointer-control-20261022/Result.xcresult)：3 个 `.scroll` 已送达，菜单却仍存在，否定了“任意菜单外滚轮必然收起”的假设。该假设实验未作为产品验收测试保留，没有将失败断言改成成功或跳过来宣称修复。
- 两次 pointer 实验的 MCP 各报告 1 个用例失败，终态 `.xcresult` 各另含 1 条 runner 退出码 75 记录（摘要为 0 通过、2 条失败记录）；两种报告均保留，不能只引用工具的用例数省略运行器异常。
- 上述 iPad 实验还证实原触摸观测会把 hover／scroll 的区域样本混入触摸序列（`sampleCount` 从 2 增至 10，最后 phase 为 6）。`PagingTraceWindow` 现仅记录 `.touches`，独立累计 `pointerScrollEvents` 和 `lastPointerScrollTimestamp`，仍无条件调用 `super.sendEvent`，不吞掉输入。
- 新增菜单单击保持、动作效果、取消再开及嵌套子菜单回归；原自动高度用例增加输入断言，原栏高增长／恢复、页面衔接及选中断言保留。出现额外触摸、滚轮或菜单丢失均失败，不重开、不重试、不放宽原断言。观测仅在 `--paging-trace` 下启用。

首轮严格回归 [4 项通过、1 项失败](Results/pages-menu-final-iphone-20261022/Result.xcresult)：自动高度用例已调用输入断言，但启动条件漏加 `--paging-trace`，因而读取不到轨迹。已修正用例接线，没有放宽输入或布局断言；该失败不归因为 Demo 菜单故障。终态回归结果见下表；历史失败证据保持原样。

针对观测修正另做[反向验证](Results/pages-menu-observation-before-20261022/Result.xcresult)：保持最终用例与滚轮计数，仅把 `let touch` 恢复为旧的 `event.allTouches?.first`。iPad 明确收到 pointer 输入后，`sampleCount` 为 9 而非原来的 2，新回归失败；MCP 报告 1 个失败用例，结果包另含 runner 退出码 75 记录。恢复过滤后逐字节核对 iPhone、iPad 源码哈希相同。该用例独立验证触摸样本不被 pointer 污染，不对 pointer 是否关闭菜单建立未经证实的预期；iPhone 的 XCTest 不支持此输入时显式跳过，不能冒充通过。

### 最终源码验证

| 状态 | 环境与范围 | 证据 |
| --- | --- | --- |
| **通过** | iPhone 18 Pro Max / iOS 27.0（24A434）：6 通过、0 失败、0 跳过；菜单保持、取消再开、自动栏高、分页拖动、外观切换、实际旋转后的返回手势 | [摘要](Results/pages-menu-verified-iphone-20261022/summary.json) · [结果包](Results/pages-menu-verified-iphone-20261022/Result.xcresult) · [日志](Results/pages-menu-verified-iphone-20261022/xcodebuild.log) |
| **通过** | iPad Pro 13-inch (M4) / iOS 26.5（23F77）：4 通过、0 失败、0 跳过；菜单保持、取消再开、自动栏高及 pointer 观测隔离 | [摘要](Results/pages-menu-verified-ipad-20261022/summary.json) · [结果包](Results/pages-menu-verified-ipad-20261022/Result.xcresult) · [日志](Results/pages-menu-verified-ipad-20261022/xcodebuild.log) |
| **通过（仅构建）** | Demo Release，iPad Simulator：退出码 0、`BUILD SUCCEEDED`；未执行 Release UI 测试 | [日志](Results/pages-menu-release-demo-20261022/xcodebuild.log) · [源码核对](Results/pages-menu-release-demo-20261022/summary.json) |

本轮 UI 通过 Apple 官方 Xcode MCP `RunSomeTests` 执行，测试 target 为 `StickyPagerDemoUITests`，准确标识保存在各运行目录的 `mcp-summary.txt`。iPad 首个请求未返回可核验终态，未计入通过；记录见该目录的 `dispatch-note.txt`。后续请求沿用同一源码和断言，终态单独保存。

iPhone 与 iPad 两轮三类运行时诊断均为 0，`sourceChangedSinceRun` 均为空。已检查[自定义模式下菜单保持](Results/pages-menu-verified-iphone-20261022/attachments/F807FB6E-DF64-4C87-935F-DAD1896A4536.png)，菜单正常呈现，选择动作前后的栏高与页面状态由 UI 断言核对。也已检查 [iPad 菜单保持截图](Results/pages-menu-verified-ipad-20261022/attachments/4CF0D787-6506-48C5-BD2E-63454B987327.png)，系统菜单以可滚动区域显示长列表。


官方 MCP `BuildProject` 没有 configuration 参数，Release 补充使用仓库脚本；构建摘要中的测试数为 0，`result: unknown` 不代表 UI 测试通过。构建终态以退出码和 `BUILD SUCCEEDED` 为准，`sourceChangedSinceRun` 为空。

```sh
SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SP_SIMULATOR_ID=9E4895DA-132A-4BAE-800B-7A322E1A2918 \
SP_SCOPE=demo SP_CONFIGURATION=Release \
SP_RUN_NAME=pages-menu-release-demo-20261022 Scripts/validate.sh build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 Scripts/summarize_validation.py Validation/Results/pages-menu-release-demo-20261022
```

本轮只主动格式化两个修改的 Swift 文件，[lint](Results/pages-menu-diagnosis-20261022/swiftformat-lint.txt)为 `0/2 files require formatting`；[官方构建日志](Results/pages-menu-diagnosis-20261022/official-build.log)中的 Demo Build Phase 为 `0/46 files formatted, 2 files skipped`，没有额外源码差异。构建仍有 App Intents 元数据跳过和 Xcode XCTest dylib 最低系统版本相关提示，未为消除这些工具链提示提高 iOS 15 部署目标。已恢复 Xcode 原来的物理 `iPhone 13` 运行目标。

- **失败证据保留：** 原菜单收起、两次 pointer 假设实验、首次严格回归的启动参数遗漏，以及观测修正的反向对照均保留，不用后续通过覆盖。
- **被环境阻塞：** 原 iPhone 环境的受控 pointer 因果复现；XCTest 不支持该设备的 pointer 合成，电脑滚轮未取得 App 送达证据。
- **未闭环：** 原异常输入的发起端、具体输入组合和菜单收起的完整机制。下一步需要在同一 iPhone 环境取得可确认送达的对应输入，再比较菜单生命周期；当前没有依据改动产品菜单。
- **未执行：** 本轮完整库／Demo UI、Duo 内外屏、iPad 旋转／分屏、深色／辅助字号、iOS 15 实际运行、真机、VoiceOver 与性能矩阵。前轮库通过记录不移作本轮运行结果；本轮也未修改库实现。


## 2026-10-22：内容配置替换提示与容器复用修复

本轮从干净的 `232e3a0` 开始，针对 UIKit `ContentConfiguration` 提示排查实际视图重建。Apple 对 [`UICollectionViewCell.contentConfiguration`](https://developer.apple.com/documentation/uikit/uicollectionviewcell/contentconfiguration-1lcqh) 的契约是：兼容配置原位应用，不兼容配置更换整个内容视图；将配置先置 nil 还会创建空内容视图，因此本轮没有采用先清空配置或过滤日志的方式隐藏提示。

### 根因与修复边界

上一轮最终 Debug 日志有 **115 条**不兼容替换提示，[逐项映射](Results/content-reuse-audit-20261022/baseline-warning-map.json)显示它们分布在默认／自定义模式切换、内容回退和混合内容更新中。原实现分别向 Cell 赋值 `SPTabContentConfiguration` 与 `SPCustomTabContentConfiguration`；两个框架内容视图互不兼容，即使标签本身和激活行为未变，也会重建容器、按钮及其 action。

新增身份／创建次数对照在原实现上得到 [1 通过、2 失败](Results/content-reuse-before-20261022/summary.json)，同时记录 **30 条替换提示**。其中同类型刷新通过；模式／回退切换的容器和按钮身份断言失败，确认了不必要的框架视图重建。另一处失败是测试直接要求弱引用立即为 nil，忽略 UIKit getter 返回对象的 autorelease 生命周期；后续改为先断言已移出层级，再用独立 autoreleasepool 验证释放，没有将此失败归因为产品泄漏。

框架现使用同一种枚举配置与内容容器，默认和自定义模式共享激活按钮，模式变化仅更新呈现与无障碍状态。默认图文、角标和大内容预览切到自定义后显式清理；业务内容离开自定义模式时移除并释放，恢复时按当前配置重新创建。兼容业务配置仍原位更新，iOS 16+ 尊重 `supports(_:)`，iOS 15 保留配置类型判断。不兼容业务配置只替换内部视图；这类必要创建与自动测量使用的独立视图不算冗余重建，也不承诺所有 `makeContentView()` 调用都消失。

新增回归检查：模式与非法尺寸回退时的容器／按钮身份及残留状态、兼容刷新／选中／禁用／高亮／tint 更新时的业务视图身份与创建次数、不兼容配置仅替换内部视图、同一配置类型由 `supports(_:)` 拒绝复用，以及 autoreleasepool 结束后释放旧业务视图。既有点击、指示器、自动测量、动画和容器测试继续运行。公开 API、iOS 15 部署边界和 Demo 菜单未改变。

运行时诊断门禁增加 `contentViewReplacementCount` 与行号；该提示和 observation／appearance 诊断分别计数，任一出现都会使验证返回非零。脚本单测增加“XCTest 之外的内容替换诊断也失败”验证。

### 失败与复测记录

| 状态 | 证据及说明 |
| --- | --- |
| **失败，已定位** | 原实现[聚焦对照](Results/content-reuse-before-20261022/Result.xcresult)：1 通过、2 失败；退出码 65，替换提示 30 条。模式身份缺陷与弱引用断言前提分别处理。 |
| **失败，已修复** | [首轮修复聚焦](Results/content-reuse-focused-20261022/summary.json)：16 通过、3 条失败记录；自动内容回退暴露统一容器默认 fitting 返回无约束最大尺寸的问题，另含宿主异常退出及启动失败记录。默认分支现返回布局分配的 bounds，保持手动布局语义。 |
| **被环境阻塞，已另行复测** | [首次重试](Results/content-reuse-focused-retry-20261022/summary.json)：0 通过、1 条启动失败记录；dyld 报告 `libSystem.B.dylib`／系统缓存不可用，尚未进入用例。仅正常重启本轮 iPhone 18 Pro Max，未清空模拟器或删除运行时；保留失败日志。 |

官方 Demo UI 首轮为 [2 通过、1 失败](Results/content-reuse-demo-ui-20261022/summary.json)。失败用例在打开“页面”菜单后找不到“切换自定义标签”，尚未进入自定义内容步骤；[失败截图](Results/content-reuse-demo-ui-20261022/attachments/68F25D09-97FE-4EF5-8522-2F84499A0A9A.png)未见菜单展开，输入记录的 `(387, 84)` 位于按钮 `{{358, 66}, {58, 36}}` 内，不能解释为点击落在按钮外。同一源码、同一用例[原样复测 1 项通过](Results/content-reuse-demo-ui-retry-20261022/summary.json)，未改 UI 测试、关闭动画或放宽断言。该菜单呈现失败未再次复现，根因尚未确定，不能声称由本轮修复解决。

两个原通过项覆盖默认／自定义切换、内容更新、禁用、分页、按住拖动、同尺寸刷新与恢复；重试项覆盖自动栏高增长／恢复及页面衔接。两轮日志三类诊断各 0，`sourceChangedSinceRun` 均为空。已检查[外观页恢复默认](Results/content-reuse-demo-ui-20261022/attachments/F4B28D46-5E0E-4712-B151-336F439959A5.png)、[分页页拖动与恢复](Results/content-reuse-demo-ui-20261022/attachments/60402118-B68F-4A43-94FD-3FEF1FACFB39.png)和[自动高度复测终态](Results/content-reuse-demo-ui-retry-20261022/attachments/5096B1C4-14E0-46E7-AD9E-B0DC3BF42BED.png)；首轮失败及其录屏、层级和输入记录保存在原运行目录。这是 3 个适用用例分别取得通过，不是一次无失败的 UI 套件。

官方 MCP 确认当前工作区只有 Demo scheme。库测试继续使用仓库 application host 脚本；受影响的 Demo 真实触摸回归使用官方 MCP `RunSomeTests`，终态与源码快照单独记录。历史失败与旧版本通过证据均保留。

聚焦复测 [79 项全部通过](Results/content-reuse-ipad-focused-20261022/summary.json)，三类诊断各 0，源码快照一致。脚本[7 项单测](Results/content-reuse-audit-20261022/script-tests.log)通过；[门禁反向验证](Results/content-reuse-audit-20261022/gate-check.json)对原 XCTest 已通过、但存在 115 条替换提示的历史日志返回退出码 1。仅主动格式化 5 个修改的 Swift 文件，[lint](Results/content-reuse-audit-20261022/swiftformat-lint.txt)为 `0/5 files require formatting`；Demo Build Phase 为 `0/46 files formatted, 2 files skipped`，无额外格式化差异。


### 最终源码验收与未覆盖范围

| 状态 | 验证范围 | 证据 |
| --- | --- | --- |
| **通过** | Debug，iPhone 18 Pro Max / iOS 27.0（24A434）：201 通过、0 失败、0 跳过 | [摘要](Results/content-reuse-final-debug-20261022/summary.json) · [结果包](Results/content-reuse-final-debug-20261022/Result.xcresult) · [完整日志](Results/content-reuse-final-debug-20261022/xcodebuild.log) |
| **通过** | Release，iPad Pro 13-inch (M4) / iOS 26.5（23F77）：201 通过、0 失败、0 跳过 | [摘要](Results/content-reuse-final-release-20261022/summary.json) · [结果包](Results/content-reuse-final-release-20261022/Result.xcresult) · [完整日志](Results/content-reuse-final-release-20261022/xcodebuild.log) |
| **通过** | 两套最终库运行的内容替换、observation、appearance 诊断各 0；退出码 0、`TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 均为空 | 各运行目录的 `runtime-diagnostics.json`、`source-hashes.json`、`host-build.log` 和 `Build.xcresult` |
| **通过，含一次原样复测** | 官方 MCP 的 3 个受影响 UI 用例均取得通过；首轮 2 通过／1 失败，原样单项复测 1 通过 | 上述两轮独立结果；构建、真实触摸及终态截图分别记录，不计为全套 UI 回归 |
| **通过** | 7 项脚本单测、115 条历史提示的门禁反向检查、5 个 Swift 文件 lint、Shell 语法、文档链接与 diff 检查 | [审计目录](Results/content-reuse-audit-20261022) |
| **未执行** | 本轮完整 Demo UI、Duo 内外屏与旋转、iPad UI／分屏、深色和辅助字号 UI 矩阵、iOS 15 实际运行、真机、完整 VoiceOver 与性能压力测试 | 库测试覆盖相关几何／状态，不替代上述系统 UI 及性能验收 |

最终使用 Xcode 27.1（27A9275）；库测试仍编译到 iOS 15 部署目标，但不等于已在 iOS 15 运行。旧模拟器启动阻塞已恢复，最终 iPhone 全量通过；菜单偶发不展开的根因未确定，保留首轮失败，不声称本轮解决了系统菜单或 XCTest 动画通知问题。Xcode 原来的物理 iPhone 13 运行目标已恢复；生成产物、日志、结果包和附件留在忽略目录。

```sh
SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SP_SIMULATOR_ID=41AF9CED-9BBB-4B60-B563-73AFB035C2D4 \
SP_SCOPE=library SP_RUN_NAME=content-reuse-final-debug-20261022 \
Scripts/validate.sh test

SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SP_SIMULATOR_ID=9E4895DA-132A-4BAE-800B-7A322E1A2918 \
SP_SCOPE=library SP_CONFIGURATION=Release \
SP_RUN_NAME=content-reuse-final-release-20261022 \
Scripts/validate.sh test ENABLE_TESTABILITY=YES
```

两套各执行相同的 201 项（比本轮起点新增 5 项），不合并为 402 个不同用例。结果包摘要通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/summarize_validation.py <运行目录>` 生成。官方 UI 请求的准确测试标识及终态保存在各自 `mcp-summary.txt`，首次日志中的动画空闲等待提示不作为本次布局循环证据。

## 2026-10-22：UIKit observation 诊断根因与测试宿主修复

本轮从干净的 `1720708` 开始。修复范围是库测试运行环境、真实窗口夹具、验证门禁及文档；`Sources/`、Demo、Package 公开配置及公开 API 未改变。测试宿主只提供 UIKit application／scene 生命周期，不链接 StickyPagerKit，不把库测试加入 Demo target 或 scheme。

### 根因及证据

原完整库 [192 项日志](Results/review-library-full-20261022/xcodebuild.log)包含 214 次 observation feedback loop 诊断；首次报告的自定义内容状态用例[单独运行](Results/observation-baseline-state-20261022/Result.xcresult)通过且没有诊断，不能仅凭首次出现的位置归因于该用例。临时生命周期对照分别创建 240 个原生集合视图和 240 个标签栏，也没有单独复现；这些临时用例不进入最终提交。

通过 Apple 官方 Xcode MCP 调试器附加真实库测试进程，在 `UIObservationTrackingFeedbackLoopDetected` 与 `UIObservationTrackingInvalidated` 断点取得了[调用栈及寄存器记录](Results/observation-debug-stack-20261022/debugger-evidence.json)：

- `UIApplication.sharedApplication == nil`，原 Package 测试运行在无 application host 的 `xctest` 中。
- 当前 iOS 27.0 运行时的检测计数为 41、阈值为 40；首次断点来自新标签栏挂载时的 `SPTabBar.layoutSubviews → collectionView.layoutIfNeeded → UIView._performPropertiesUpdate`，没有业务状态递归回调的调用栈证据。
- 调试器读取的 UIKit 实现将计数清理安排到 application 的 CA transaction 提交后回调；无 application 时，该清理路径不能正常安排。后续新对象复用地址时继续触发诊断。阈值和内部符号仅作本次运行时诊断证据，仓库实现不依赖它们。
- 同一套库实现和原 192 项测试改用真实 application host 后，feedback loop 降为 0。对照中的 2 项失败是无 scene 窗口的导航安全区域前提失效，另行修复夹具，没有修改框架折叠公式。

根因确认范围是本仓库此次无宿主库测试诊断，不推断其他 App 或所有 UIKit feedback loop 都属于同一原因。未关闭 observation、抬高检测阈值或屏蔽系统日志；只在调试器中读取内部实现，没有把私有 API 调用加入源码。

### 修复内容与迁移影响

`Scripts/validate.sh` 为 library 的 `test`／`build-for-testing` 构建独立 `Tests/UIKitTestHost`，仍由根 Package 编译测试包，再通过 `xcodebuild.xctestrun` 文档化的 application host 配置运行。`prepare_hosted_tests.py` 冻结宿主和同次测试包，保留筛选参数、Main Thread Checker 等原环境，不修改原始 xctestrun。直接给 Package scheme 传外部 `TEST_HOST` 的[不支持记录](Results/observation-hosted-comparison-20261022/xcodebuild.log)保留；最终采用 `TestHostPath` 路径。官方 MCP 用于断点诊断；当前工作区的测试工具没有这条自定义 xctestrun 执行入口，因此完整库回归使用脚本。

真实 application host 还暴露了原夹具的窗口生命周期缺口。固定几何窗口现在连接真实 `UIWindowScene`，保留请求尺寸并显式将屏幕安全区域设为零，仅用 `additionalSafeAreaInsets` 注入几何条件；导航集成窗口保留原生安全区域。异步 `setUp` 仅创建窗口，在测试方法挂载时显示；替换旧窗口前先关闭，关闭时在窗口仍可见时移除根控制器，完成回调后再隐藏。新增回归直接断言 scene、固定尺寸、额外安全区域、完整 appearance 回调顺序，以及 64 次自动 observation 更新后的收敛。

两项原测试假设同步纠正：系统 `UITabBar` 在 iOS 26.5 可保留多个内部角标副本，系统内部 UILabel 坐标／数量改为视觉参考记录，框架自己的 RTL、中文／阿拉伯文、尺寸、点击与无障碍断言保留；屏幕外指示器用例显式关闭 UIKit 预取并重建布局，同时断言目标位于视口外且没有 Cell，确保真正覆盖无 Cell 几何路径。

运行时门禁分别记录 observation feedback loop 和 appearance transition 不平衡；任一出现，即使 XCTest 通过也返回非零。摘要增加运行时计数，并将运行后新增输入也纳入 `sourceChangedSinceRun`。

### 失败、对照与复测记录

| 状态 | 证据及解释 |
| --- | --- |
| **失败，已修复** | 首次[有宿主全量对照](Results/observation-hosted-xctestrun-20261022/summary.json)：190 通过、2 失败，feedback loop 为 0；失败来自导航安全区域夹具。 |
| **通过，中间版本** | [导航与 observation 聚焦](Results/observation-hosted-focused-20261022/summary.json)：17 通过；此后继续补充生命周期夹具，不能据此替代最终全量。 |
| **预期失败，反向验证通过** | [旧无宿主路径](Results/observation-unhosted-negative-20261022/summary.json)：当时新增的两项环境测试均明确失败，不能将无 UIApplication 环境误记为正常验收。 |
| **失败，已修复** | [首次 iPad Release](Results/observation-hosted-final-release-20261022/summary.json)：193 通过、1 失败；[首次角标重试](Results/observation-hosted-badge-retry-20261022/summary.json)仍失败；[角标专项](Results/observation-hosted-badge-final-20261022/summary.json)5 项通过。原失败的[图层截图](Results/observation-hosted-final-release-20261022/attachments/CC105C6B-F35F-4DEB-986D-D40717EC8FE4.png)保留，不能作为最终真实 UI 视觉通过证据。 |
| **失败，已修复** | [生命周期首次回归](Results/observation-lifecycle-focused-20261022/Result.xcresult)暴露缺失 `didDisappear`；[销毁顺序调整](Results/observation-lifecycle-order-20261022/runtime-diagnostics.json)和[scene 调整](Results/observation-scene-focused-20261022/runtime-diagnostics.json)仍有 appearance 诊断，未作为最终通过；[挂载时显示复测](Results/observation-window-method-focused-20261022/runtime-diagnostics.json)两类诊断均为 0。 |
| **失败，已修复** | [后续 Release 全量](Results/observation-accepted-release-20261022/Result.xcresult)暴露屏幕外 Cell 可能被预取的错误前提；保留原失败，按无 Cell 路径的明确条件另行复测。 |
| **通过** | [门禁反向检查](Results/observation-gate-audit-20261022/check-output.json)从历史日志识别 214 条 observation 诊断，[退出码](Results/observation-gate-audit-20261022/check-exit-code.txt)为 1；[脚本单测](Results/observation-gate-audit-20261022/script-tests.log)覆盖冻结、筛选／环境保留、异常 target 拒绝及两类诊断判定。 |

中间结果与最终源码可能不同，分别保留快照和终态，不覆盖失败记录。

### 最终验证方式与覆盖边界

| 状态 | 最终源码验收 | 证据 |
| --- | --- | --- |
| **通过** | Debug，iPhone 18 Pro Max / iOS 27.0（24A434）：196 通过、0 失败、0 跳过；observation 与 appearance 诊断各 0 | [摘要](Results/observation-commit-debug-20261022/summary.json) · [结果包](Results/observation-commit-debug-20261022/Result.xcresult) · [完整日志](Results/observation-commit-debug-20261022/xcodebuild.log) |
| **通过** | Release，iPad Pro 13-inch (M4) / iOS 26.5（23F77）：196 通过、0 失败、0 跳过；observation 与 appearance 诊断各 0 | [摘要](Results/observation-commit-release-20261022/summary.json) · [结果包](Results/observation-commit-release-20261022/Result.xcresult) · [完整日志](Results/observation-commit-release-20261022/xcodebuild.log) |
| **通过** | 两套最终命令退出码 0，终态 `TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 均为空；同次 Debug／Release 宿主及库测试构建通过 | 各运行目录的 `source-hashes.json`、`host-build.log`、`Build.xcresult`；不是以构建成功代替测试 |
| **通过** | 脚本单测 6 项；包含结果包摘要不可用时保留真实 test-without-building 终态，且明确标记结果摘要不可用 | [脚本日志](Results/observation-gate-audit-20261022/script-tests.log) |
| **通过** | 13 个修改／新增 Swift 文件的 SwiftFormat 0.64.0 lint、Shell 语法、宿主工程 plist、文档本地链接及 `git diff --check` | [格式日志](Results/observation-gate-audit-20261022/swiftformat-lint.txt)；框架、Demo、`Package.swift`、`.swiftformat` 与本轮起点无差异 |

最终完整套件新增 4 项环境／生命周期／自动 observation 用例；两套各执行同一组 196 项，不合并为 392 个不同用例。迁移期间的失败均在上表独立保留，当前范围没有未修复的失败或环境阻塞。

最终回归使用 Xcode 27.1（27A9275），命令如下；每个运行名对应独立源码快照、构建日志、`Build.xcresult`、`Result.xcresult` 和运行时诊断记录。Release 显式启用 `@testable` 所需配置。

```sh
SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SP_SIMULATOR_ID=41AF9CED-9BBB-4B60-B563-73AFB035C2D4 \
SP_SCOPE=library SP_RUN_NAME=observation-commit-debug-20261022 \
Scripts/validate.sh test

SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SP_SIMULATOR_ID=9E4895DA-132A-4BAE-800B-7A322E1A2918 \
SP_SCOPE=library SP_CONFIGURATION=Release \
SP_RUN_NAME=observation-commit-release-20261022 \
Scripts/validate.sh test ENABLE_TESTABILITY=YES

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 Scripts/summarize_validation.py Validation/Results/observation-commit-debug-20261022
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
python3 Scripts/summarize_validation.py Validation/Results/observation-commit-release-20261022
python3 -m unittest discover -s Scripts/Tests -v
```

本轮**未执行** Demo UI 全套、Duo 内外屏及实际旋转复跑、iOS 15 运行、真机、完整 VoiceOver 和性能压力验证；本轮仅变更库测试及验证设施，不以真实 scene 的固定尺寸夹具代替上述系统 UI 验收。此前 Duo 分段结果及其限制保持原记录。最终两类运行时门禁通过不代表日志没有其他提示；自定义内容切换仍可出现 UIKit content configuration 替换提示，本轮没有改变该实现。

官方 MCP 调试诊断完成后已移除本轮断点、结束调试，并恢复 Xcode 原来的 iPhone 13 运行目标。生成的测试宿主、结果包和完整日志留在忽略目录，不加入源码提交。

## 2026-10-22：全部待提交改动审查与补测

审查覆盖全部已跟踪差异及新增文件：标签栏留白、附件测量与裁切、角标、Demo 配置与启动参数、真实方向／窗口触摸测试、外部旋转脚本、公开说明和截图证据。保留已有工程 Debug／Release 的空签名 Team 配置，不改变 iOS 15 部署目标。未发现需要修改生产实现的新增阻塞缺陷；本轮补上两项此前没有直接断言的边界：候选宽度测量不终止选择动画、零尺寸及超上限附件恢复后保留业务约束。

| 状态 | 审查或验证范围 | 证据与边界 |
| --- | --- | --- |
| **通过** | 附件聚焦 14 项，0 失败、0 跳过 | [摘要](Results/review-accessory-focused-20261022/summary.json) · [结果包](Results/review-accessory-focused-20261022/Result.xcresult)；包含新增的两个真实 UIWindow 用例 |
| **通过** | 完整库 192 项，0 失败、0 跳过 | [摘要](Results/review-library-full-20261022/summary.json) · [结果包](Results/review-library-full-20261022/Result.xcresult)；Xcode 27.1、iPhone 18 Pro Max / iOS 27.0（24A434），`sourceChangedSinceRun` 为空 |
| **通过** | iPad 带附件的系统窗口缩放专项 1 项，0 失败、0 跳过 | 官方 MCP `RunSomeTests`；iPad Pro 13-inch (M4) / iOS 26.5（23F77）；[摘要](Results/review-ipad-accessory-window-20261022/summary.json) · [结果包](Results/review-ipad-accessory-window-20261022/Result.xcresult)，`sourceChangedSinceRun` 为空 |
| **通过** | Duo 双屏历史逐项结果与当前测试清单核对 | [原始 xcresult 核对](Results/review-audit-20261022/xcresult-mapping-check.json)：每屏 56 个唯一标识，49 通过、7 项 iPad 专属跳过；外屏五项补测及两项最终复测覆盖旧证据，没有漏项或误记通过 |
| **通过** | 当前源码与最终 Duo／Release 证据范围核对 | [源码核对](Results/review-audit-20261022/source-evidence-audit.json)：Duo 最后两项复测快照仅与本轮新增库测试不同，库实现、Demo 和 UI 测试未改变；Release 生产输入未变，不将源码核对表述为重新执行构建 |
| **通过** | 格式、脚本语法、文档链接和差异检查 | [SwiftFormat 0.64.0 lint](Results/review-audit-20261022/swiftformat-lint.txt) 为 `0/21 files require formatting`；Python AST 语法检查、README 与验证文档本地链接检查、`git diff --check` 通过 |

官方 MCP 当前工作区只有 Demo scheme，根 Package 的库测试通过仓库 `Scripts/validate.sh` 执行，显式指定 Xcode 27.1 与上述 Pro Max UUID；完整命令在各轮 `xcodebuild.log` 开头。只主动格式化本轮补充的 `SPTabBarAccessoryTests.swift`。库日志仍有历史已有的 UIKit observation tracking feedback loop 诊断（此前 190 项通过日志也存在），没有把 XCTest 通过解读为无运行时诊断。

iPad 专项通过真实窗口拖动检查多次缩放、正文位置保存、分页、Header 展开／部分折叠／吸顶以及恢复全屏后的附件点击。已核对[浮动小窗口](TabBarAccessories/ipad-review-small-window-20261022.png)和[恢复全屏](TabBarAccessories/ipad-review-restored-20261022.png)：两端附件、标签内容边界和页面衔接正常，搜索按钮确实弹出演示提示；全部 17 个附件及终态日志保存在同轮结果目录。官方构建成功，Build Phase 为 `0/43 files formatted, 2 files skipped`，未引入额外格式化差异；日志仍有 XCTest 依赖最低版本与测试 target 的 iOS 15 设置不一致、无 AppIntents 元数据等工具链提示，没有提高部署版本来隐藏提示。测试结束后恢复 Xcode 原来的 iPhone 13 运行目标；此次专项不等同于本轮完整 iPad 分屏、RTL 或全套 UI 回归。

本轮未改动框架和 Demo 生产行为，Duo 的适用 UI 验收继续采用下文已核实的分段证据，不声称本轮重跑双屏或取得一次不中断全量成功。iOS 15 实际运行、真机、完整 VoiceOver 人工流程及性能压力测试仍未执行；默认 MCP／`XCUIDevice` 无法驱动 Duo 实际旋转的环境限制仍保留。审查不修改历史失败、取消和复测记录。

## 当前 Duo 验证结论（2026-10-21 收尾）

| 范围 | 最终结果 | 证据边界 |
| --- | --- | --- |
| 外屏剩余安全区域 5 项 | **5 通过、0 失败** | 实际竖屏、两侧横屏及恢复；[摘要](Results/duo-outer-filtered-hub-five-20261021/summary.json) |
| 内屏全部适用 UI 项 | **49 通过、7 项 iPad 专属跳过** | 源码范围核验后的分段覆盖；[逐项映射](Results/duo-inner-two-failures-fixed-20261021/inner-segmented-coverage.json) |
| 外屏全部适用 UI 项 | **49 通过、7 项 iPad 专属跳过** | 包含本轮 5 项补测及修正后两项复测；[逐项映射](Results/duo-outer-two-failures-fixed-20261021/outer-final-segmented-coverage.json) |
| 本轮发现的两项 UI 测试问题 | **内屏 2/2、外屏 2/2 修复复测通过** | 窗口锚点修正边缘输入；1e-6 pt 容差处理 80 pt 浮点边界，同时加强触摸与页面几何断言 |
| Device Hub 电脑控制 | **本轮恢复并完成回归** | 筛选 Duo、收起侧栏；不宣称工具根因永久修复 |
| 默认 MCP／XCUIDevice 旋转 | **仍未修复** | 实际旋转通过电脑菜单完成，App 方向断言保留 |

以上不是一次不中断的完整套件成功；失败、取消、复测、截图、录屏与源码差异均在下文独立保留。未覆盖的 iPad、最低系统、真机和 VoiceOver 范围见本轮收尾边界。

## 2026-10-21：Duo 实际旋转与设备环境排查

本轮保持已有实际方向断言，没有以设备方向命令成功或窗口呈横向代替界面旋转成功。对现有 Duo（`049C3F56-87CB-4D53-8B0A-7537DDE19222`）使用官方设备会话核查外屏：系统“设置”（PID `18527`）和 Demo（PID `18712`）的设备方向均依次变为 Portrait、Landscape Left、Landscape Right，但两者实际 App 方向一直为 Portrait，窗口一直为 `466 × 678 pt`。见[观察摘要](Results/duo-rotation-diagnosis-20261021/after-boot-observations.json)、[设置左旋层级](Results/duo-rotation-diagnosis-20261021/settingsLeft-hierarchy.txt)和[Demo 右旋层级](Results/duo-rotation-diagnosis-20261021/demoRight-hierarchy.txt)。该现象不只出现在 Demo；尚未确定根因，不能据此断言系统应用与 Demo 的方向策略相同。

电脑操作确认本机同时运行 Xcode 26.6 的 Simulator 与 Xcode 27.1 的 Device Hub。通过活动监视器正常退出旧 Simulator，并正常重启 Device Hub；未清空 Duo、删除运行时或修改运行时匹配。Device Hub 在设备关机时曾恢复可读，点击 Start 后及后续重试仍出现 `-10005: timeoutReached`／60 秒超时。用户看到的两个显示窗口中哪个黑屏，尚未取得足够的窗口证据确认。进程采样显示主线程处于 AppKit 事件等待，不能将超时直接解释为主线程卡死。

`simctl bootstatus` 两次报告 `Status=3, isTerminal=YES, Data Migration Failed`，尽管命令退出码为 0，随后设备列表又显示 Booted；因此退出码和 Booted 状态不足以证明启动环境正常。只读查询数据迁移服务显示 `last exit code = 0`，未得到迁移失败的具体原因。机器上有 `24A94232`、`24A94425` 两个 iOS 27.1 运行时，但 `simctl runtime match list -j` 明确选择与 SDK 相同的 `24A94232`，服务路径也属于该版本；没有证据认定双运行时就是旋转失败原因。见[环境观察](Results/duo-rotation-diagnosis-20261021/environment-observations.json)、[匹配规则](Results/duo-rotation-diagnosis-20261021/runtime-match.json)、[运行时清单](Results/duo-rotation-diagnosis-20261021/runtime-images.json)和[进程采样](Results/duo-rotation-diagnosis-20261021/devicehub-start-sample.txt)。

另一次独占官方设备会话取得有效外屏截图，并依层级位置打开 Control Center，但画面只显示“添加控制”“电源”等内容，没有方向锁控件，未修改任何开关，方向锁状态仍未核实。结束时设备恢复 Portrait，Control Center 仍可见；已释放会话，见[方向锁检查](Results/duo-rotation-diagnosis-20261021/lock-check/observations.json)。

上述初始阶段仅为诊断证据：当时的**失败**为自动方向事件未使实际界面旋转；**被环境阻塞**为 Device Hub 控件操作及方向锁核对；**未执行**为旋转修复后的双屏完整 UI 回归。后续独立窗口控制恢复及外屏运行结果见下文。前述与后续各轮完整、聚焦、库测试结果分别保留，不合并为双屏通过；本轮未修改框架方向策略或放宽测试断言。

用户随后确认：手动点击 Device Hub 底部旋转按钮时，Demo 内容会转向。这是人工观察，表明不能将自动方向事件失败表述为设备完全不能旋转；需要分别验证 Device Hub 按钮与 `XCUIDevice`／MCP 方向事件两条路径。本节前述“实际旋转未生效”限定为已记录的自动方向事件，不代表人工按钮路径失败，也尚不等于双屏方向矩阵已验收。

随后电脑插件通过 `Window` 菜单中的第二个 Duo 项进入可读的独立窗口（`deviceWindow-AppWindow-1`），主控制窗口仍曾超时。独立窗口提供完整的 `Device → Orientation` 菜单及 Closed／Partially Open／Open 控件。需要区分 `Controls → Rotate Left/Right` 的外框显示与 `Device → Orientation` 的方向设置，不能仅看外框判断实际转场。用户手动旋转后的首轮捕获激活了新 PID，只证明横屏启动；后续对同一 PID `27870` 串行对照才确认运行中转场：菜单 Portrait 让实际场景从 Landscape Left、`678 × 466` 变为 Portrait、`466 × 678`，菜单 Landscape Left 又让场景变为 Landscape Right、`678 × 466`；此后 MCP `orientation portrait` 仍未改变实际场景。见[同进程对照](Results/duo-rotation-diagnosis-20261021/cu-menu-comparison/observations.json)。电脑方向控制阻塞已通过独立窗口解除，MCP 方向事件路径仍未修复。

为按用户要求继续实际旋转回归，新增仅供 UI 测试使用的 `UITestOrientation` 和 `Scripts/run_external_rotation.py`。默认仍使用 `XCUIDevice`；显式外部模式通过唯一请求编号等待电脑菜单操作，各用例原有的实际方向、布局和触摸断言保持不变。Demo 回归状态新增 iOS 26+ 场景方向锁定值，不修改任何控制器方向偏好。官方 `BuildProject(buildForTesting: true)` 构建通过；因官方测试调用没有运行器环境参数，本轮外部模式使用该次 `.xctestrun` 副本及 `xcodebuild test-without-building`，未改 scheme。一次调试启动误用了后台工作区当时的 iPhone 18 Pro Max 目标，已停止并重新选择 Duo，该次运行不计入 Duo 证据；后续命令与结果包均使用明确的 Duo UUID。调试器在 dyld 加载阶段未取得有效场景数据，因此未采用其作为方向锁结论。

外屏外部驱动首轮在启动 Demo 时运行器被 SIGKILL 终止，未进入旋转断言：结果包报告 **0 通过、2 失败记录**（目标用例崩溃和运行器启动错误），`sourceChangedSinceRun` 为空，见[首轮摘要](Results/duo-outer-external-rotation-focused-20261021/summary.json)。同一构建复测 **1 通过、0 失败**，见[复测摘要](Results/duo-outer-external-rotation-retry-20261021/summary.json)与[方向操作记录](Results/duo-outer-external-rotation-retry-20261021/rotation-events.jsonl)：实际横屏方向为 `3`、窗口 `678 × 466`，恢复竖屏方向 `1`、窗口 `466 × 678`，两次 `interfaceOrientationLocked=0`；辅助字号、窄栏附件点击及搜索反馈均通过。复测结束后桥接脚本补充过滤上次运行遗留请求，摘要因此列出 `Scripts/run_external_rotation.py` 差异；不将该轮称为脚本最终版本验证，完整回归另起快照。

本轮再次核对 `duo-inner-library-final-20261021/source-hashes.json` 时，当前 `SPTabBar.swift`、`SPTabContentConfiguration.swift`、`TabBarGallery.swift` 已与该轮快照不同，工作区还出现角标相关新测试文件；这些现有修改均保留。下节所述“最终源码一致”仅描述当次检查时点，不能推定当前工作区仍被该次 185 项结果覆盖。本轮另存[诊断源码快照](Results/duo-rotation-diagnosis-20261021/diagnostic-source-hashes.json)，没有将本轮文档检查计作源码回归。

### 外屏实际旋转回归与锁屏中断

使用 `Scripts/run_external_rotation.py`、同次官方 `build-for-testing` 生成的 `.xctestrun` 和明确 Duo UUID 执行完整 56 项 UI 套件，运行目录为 `duo-outer-external-ui-full-20261021`。测试过程中通过电脑插件操作独立 Duo 窗口的 `Device → Orientation`；真实触摸由 XCTest 执行，没有同时通过其他设备会话注入输入。

| 状态 | 本轮结果与证据 |
| --- | --- |
| **通过** | 33 项取得通过终态，包含 5 项嵌套横滑、网格 LTR／RTL 四方向、辅助字号 LTR／RTL、自定义大字号 RTL、普通字号 LTR、安全区域、旋转后返回手势、Header、宽度溢出及页面状态恢复。见[结果摘要](Results/duo-outer-external-ui-full-20261021/summary.json)、[结果包](Results/duo-outer-external-ui-full-20261021/Result.xcresult)和[实际方向记录](Results/duo-outer-external-ui-full-20261021/actual-orientation-coverage.json)。 |
| **失败（环境原因）** | `testSafeAreaTabsRTL` 等待左横屏请求 `E3813B21-0FCD-423F-8738-A6743EFE7431` 120 秒超时。此时电脑插件明确报告 Mac 已锁屏且自动解锁失败，未写入确认；不能归为实际完成旋转后的布局失败。见[电脑锁屏观察](Results/duo-outer-external-ui-full-20261021/computer-lock-observation.json)。 |
| **被环境阻塞** | 已请求用户手动解锁；为避免继续制造无效失败，向该轮 `xcodebuild` 发送 SIGINT。终态为 `TEST EXECUTE INTERRUPTED`、退出码 75；保存[中断记录](Results/duo-outer-external-ui-full-20261021/environment-interruption.json)及[完整日志](Results/duo-outer-external-ui-full-20261021/xcodebuild.log)。 |
| **未执行** | 原计划 56 项中另有 22 项未执行，不能将其中的 iPad 专属用例记成已经跳过。本轮后续系统容器、附件及角标用例未执行；修复后内屏全量、外屏完整成功重跑尚未完成。 |

同轮实际方向分别记录为 `1 / 3 / 4`，窗口对应 `466 × 678 / 678 × 466 / 678 × 466 pt`，恢复竖屏后尺寸恢复。已核对[左横屏独立窗口](TabBarAccessories/duo-outer-rotation-left.png)及[右横屏独立窗口](TabBarAccessories/duo-outer-rotation-right.png)：前者为折叠 Header 的列表，后者为辅助字号 RTL 自定义标签；两图用于证明实际转向及相应布局，不代表全部主题、附件或 VoiceOver 已验收。首次横屏截图与方向请求 id 的对应关系保存在[视觉记录](Results/duo-outer-external-ui-full-20261021/computer-rotation-visuals.jsonl)。XCTest 导出的部分横屏截图有黑边／裁切异常，未将这些异常截图单独作为视觉通过证据。

本轮 `.xcresult` 确认实际设备为 Duo、iOS 27.1（24A94232），`sourceChangedSinceRun` 为空；[构建与源码核验](Results/duo-outer-external-ui-full-20261021/source-coverage-check.json)确认所有 Swift 文件与构建快照一致。复现命令见运行目录的 [command.json](Results/duo-outer-external-ui-full-20261021/command.json)；汇总使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 Scripts/summarize_validation.py Validation/Results/duo-outer-external-ui-full-20261021`。外部旋转路径已在上述通过项中生效；默认 MCP／`XCUIDevice` 方向事件问题仍未修复，双屏完整验收仍未完成。后续必须使用新运行目录，不能补写本轮旧请求的确认或把分段结果称为一次完整通过。

### 解锁续跑与系统容器触摸距离修正

用户确认解锁后，电脑插件重新核实独立 Duo 窗口可读、`hingeSlider=0`（Closed），恢复 Portrait。将原成功构建复制到 `Validation/Products/DuoRotationFrozen-20261021/`，只执行锁屏中断及未执行的 23 项，得到 **15 通过、1 失败、7 跳过**；7 项均为 iPad 分屏／窗口专属用例。见[续跑摘要](Results/duo-outer-external-ui-resume-20261021/summary.json)、[结果包](Results/duo-outer-external-ui-resume-20261021/Result.xcresult)和[日志](Results/duo-outer-external-ui-resume-20261021/xcodebuild.log)。当次终态核验 `sourceChangedSinceRun` 为空；此前锁屏失败的 `testSafeAreaTabsRTL` 本次四方向完整通过。电脑驱动完成 62 个唯一请求，没有锁屏、超时或切错窗口，见[操作记录](Results/duo-outer-external-ui-resume-20261021/computer-rotation-actions.jsonl)。测试期间使用进程范围的 `caffeinate -di` 临时防止闲置休眠，不修改系统持久锁屏设置。

唯一失败为 `SystemContainerTests/testPagingRotationAndSystemTabRestore`：左右横屏实际方向、几何及滚动均通过，恢复 Portrait 后固定 `60 pt` 拖动仅令 `position` 从 `328` 变为 `335.333`，未超过 `338` 的原要求。触摸 x=191 位于列表安全区域，未落入右侧系统按钮；[846.735 秒录屏](Results/duo-outer-external-ui-resume-20261021/system-and-accessories.mp4)的失败前后帧确认列表只发生小幅移动，不能将其误报成未旋转。RTL 同类用例本轮通过。随后仅修改测试：旋转后滚动使用既有辅助函数按当前可见高度的 60% 拖动，保留“位移超过 10 pt”、方向、几何和位置恢复断言，并打印可见高度与实际请求距离；没有调整框架滚动行为。原失败证据保留，修复后单独复测整个 `SystemContainerTests`。

修复后官方 `BuildProject(buildForTesting: true)` **构建通过**，见[构建摘要](Results/duo-viewport-rotation-build-20261021/summary.json)；源码与构建前快照一致。前后冻结产物中 Demo `.app` 所有文件哈希一致，测试源码仅 `SystemContainerTests.swift` 改变，见[首次运行范围核对](Results/duo-outer-external-ui-full-20261021/post-fix-source-check.json)及[续跑范围核对](Results/duo-outer-external-ui-resume-20261021/post-fix-source-check.json)。因此其他用例结果按未变源码范围保留，不能将这些分段结果描述为一次全量成功。

外屏附件 4 项及角标 2 项均通过。已逐帧核对[首端](TabBarAccessories/duo-outer-resume-start.png)、[中间](TabBarAccessories/duo-outer-resume-middle.png)、[尾端](TabBarAccessories/duo-outer-resume-end.png)：附件固定，渐隐仅位于仍有隐藏内容的标签视口边缘；[搜索反馈](TabBarAccessories/duo-outer-resume-search.png)、[浅色频道菜单](TabBarAccessories/duo-outer-resume-channels.png)、[RTL 深色频道菜单](TabBarAccessories/duo-outer-resume-rtl-channels.png)、[选择反馈](TabBarAccessories/duo-outer-resume-selected.png)及[附件撑高](TabBarAccessories/duo-outer-resume-height.png)均取得有效画面。录屏中应用重启空白帧及选择动画中的过渡帧不作最终外观证据；原始录屏保留。

外屏修复后整个 `SystemContainerTests` 聚焦复测 **3 通过、0 失败、0 跳过**，终态为 `TEST EXECUTE SUCCEEDED`、退出码 0，`sourceChangedSinceRun` 为空，冻结产物哈希无变化。见[复测摘要](Results/duo-outer-viewport-rotation-focused-20261021/summary.json)、[结果包](Results/duo-outer-viewport-rotation-focused-20261021/Result.xcresult)。LTR 原失败项与 RTL 同类项均通过左右横屏、恢复 Portrait、位置保存及旋转后真实滚动；电脑驱动 12 次请求均取得确认。

按测试标识去重后，外屏三轮分段证据覆盖 **49 项通过、7 项 iPad 专属跳过**，见[逐项运行对应](Results/duo-outer-viewport-rotation-focused-20261021/outer-segmented-coverage.json)。这是源码范围核验后的分段覆盖，不是一次完整成功运行；原锁屏中断及固定距离触摸失败均保留。内屏完整回归另起运行目录。

### 内屏电脑菜单映射差异

外屏聚焦结束后，电脑操作将铰链滑块真实拖到 `180`，取得有效 Open 内屏画面；方向菜单在短暂界面过渡后恢复可用，没有重启设备。见[姿态 AX 记录](Results/duo-inner-external-preflight-20261021/open-portrait-ax.txt)和[展开窗口](Results/duo-inner-external-preflight-20261021/open-portrait-device-hub.png)。

使用同一冻结产物执行内屏完整套件时，前 7 项通过；`testCollapsedTabBarStaysAtNavigationBarBottom` 首次旋转失败：电脑已操作 Landscape Left，但 App 实际方向为 Portrait（`1`）、窗口 `669 × 951 pt`、`interfaceOrientationLocked=0`，原断言期望 Landscape Right（`3`）。这说明界面确实发生转向，但内屏菜单与实际场景的对应关系尚未核实，不能沿用外屏映射。随后主动中止测试，避免继续产生相同原因的失败；下一项被取消。结果包为 **7 通过、2 失败记录**（其中 1 项为取消）、47 项未执行，退出码 75，`sourceChangedSinceRun` 为空。见[摘要](Results/duo-inner-external-ui-full-20261021/summary.json)、[结果包](Results/duo-inner-external-ui-full-20261021/Result.xcresult)及[日志](Results/duo-inner-external-ui-full-20261021/xcodebuild.log)。实际方向断言未放宽，后续先核对同进程菜单映射，再单独复测。

后续在同一 App PID `58322` 下，电脑菜单串行操作、官方会话仅空输入抓取，确认如下完整映射。见[同进程汇总](Results/duo-inner-menu-mapping-20261021/mapping-observations.json)。官方 `Device orientation` 在这些抓取中始终为 Portrait，不能代替实际 App 方向；会话中途两次失效并重建，未重启 App、未注入 MCP 方向事件，最终已结束会话。

| Open 内屏 Device Hub 菜单 | 实际 App 场景方向 | 窗口 pt |
| --- | --- | --- |
| Landscape Left | Portrait（1） | 669 × 951 |
| Portrait Upside Down | Landscape Right（3） | 951 × 669 |
| Landscape Right | Portrait Upside Down（2） | 669 × 951 |
| Portrait | Landscape Left（4） | 951 × 669 |

因此内屏外部驱动按目标场景方向选择对应菜单，并在操作记录中同时保留原请求、实际菜单和铰链姿态；不修改请求 id、测试方向预期或 App 方向策略。前述失败属于沿用外屏菜单映射导致的目标方向不符，不是 App 完全不能旋转。修正后的聚焦与完整回归另起目录，不覆盖原失败。

映射修正后的聚焦 **2 通过、0 失败、0 跳过**，包含原失败的折叠栏对齐用例和网格 LTR／RTL 的 Portrait → Landscape Right → Landscape Left → Portrait 实际方向矩阵。终态 `TEST EXECUTE SUCCEEDED`、退出码 0，`sourceChangedSinceRun` 为空；见[聚焦摘要](Results/duo-inner-mapped-rotation-focused-20261021/summary.json)和[结果包](Results/duo-inner-mapped-rotation-focused-20261021/Result.xcresult)。14 个电脑方向请求全部完成，动作记录同时保留原请求与实际菜单。两种横向窗口为 `951 × 669 pt`，竖向为 `669 × 951 pt`，方向值分别为 3／4／1；未将宽高相同的两种横向混为一种方向。

### 内屏连续回归的触摸坐标与系统等待

`duo-inner-mapped-ui-full-20261021` 使用校准后的菜单映射启动完整 56 项。前段 **20 项通过**，包含 5 项嵌套横滑、原折叠栏旋转失败项、自动高度、指示器、按住拖动、宽度溢出、网格 LTR／RTL 方向矩阵及 Header／页面几何。`testCustomTabSafeAreaLargeTextRTL` 失败于竖屏 Header 折叠：实际方向为 1、窗口 `669 × 951 pt`，从 SpringBoard 坐标 `(334.5, 294.5)` 拖到 `(334.5, 86)` 后 `progress` 仍为 0。方向已正确，不能将这项归为旋转失败。

随后 XCTest 连续出现 `App animations complete notification not received, will attempt to continue`，每次触摸前等待 SpringBoard 约 60 秒。旁路[内屏画面](Results/duo-inner-mapped-ui-full-20261021/animation-wait-observation.png)正常，无遮挡；电脑只读检查相关菜单未发现 Slow Animations 项，未修改设置。Header 拖动、替换和页面几何用例仍分别通过，最后一项耗时 525.742 秒。在该项通过、下一项尚未触摸的 setup 边界主动中止，准备正常重启本次 Duo 恢复环境；未清空设备、删除运行时或操作其他模拟器。

本段终态为 **20 通过、2 失败记录**（1 项折叠触摸失败，1 项因中止取消）、34 项未执行，退出码 75。见[摘要](Results/duo-inner-mapped-ui-full-20261021/summary.json)及[结果包](Results/duo-inner-mapped-ui-full-20261021/Result.xcresult)。终态 `sourceChangedSinceRun` 列出工程 `project.pbxproj`：运行期间外部修改新增了 Debug／Release 的签名 Team，当前 Xcode 目标也改为 iPhone 13；这些修改保留，不能将本轮描述为整个工作区零差异。运行使用独立冻结的 Duo 产物，不随 Xcode 当前目标切换。

结束后仅修正 `verifySafeAreaTabs` 的触摸坐标：起点锚定当前标签视口，终点锚定当前 App 窗口，并扣除浮动窗口原点；不再借用可能属于另一显示面的 SpringBoard 坐标。折叠／展开距离、进度、方向、安全区域及位置断言不变。该辅助函数覆盖普通／辅助字号 LTR／RTL 及自定义辅助字号 RTL 共 5 项；修复后须单独复测，不将构建成功当作触摸问题已解决。

正常重启后，Device Hub 能显示外屏 Home；切 Open 后其独立窗口持续显示 busy indicator，但 `simctl io --display=3` 已取得有效的 `2007 × 2853` 内屏 Home，见[重启后旁路截图](Results/duo-inner-environment-recovery-20261021/display-3-after-restart.png)。运行时构建号发生变化：此前结果为 `24A94232`，重启后的 SpringBoard 实际路径与结果包均为 `24A94425`，SDK 匹配规则仍选择 `24A94232`。本轮未删除运行时、修改匹配规则或清空设备；见[运行时观察](Results/duo-inner-environment-recovery-20261021/runtime-observation.json)。两种运行时结果必须分别报告。

窗口坐标修正后 Debug `build-for-testing` 成功，见[构建结果](Results/duo-window-touch-build-20261021/build-result.json)。自动格式化阶段为 `0/43 files formatted`；所有 Swift 文件与构建快照一致，见[源码范围核验](Results/duo-window-touch-build-20261021/swift-source-check.json)。构建期间外部又将签名 Team 改为空，故整体 `sourceChangedSinceRun` 列出工程文件，保留该修改。随后冻结新产物，并在 `24A94425` 上聚焦原失败项：竖屏标签拖动已通过折叠和展开断言，但下一次横屏失败——XCTest 收到 Landscape Right 系统通知，App 场景仍为 Portrait、窗口 `669 × 951 pt`。用例终态 **0 通过、1 失败**，不是完整触摸修复通过；`sourceChangedSinceRun` 为空，见[聚焦摘要](Results/duo-inner-window-touch-focused-20261021/summary.json)及[日志](Results/duo-inner-window-touch-focused-20261021/xcodebuild.log)。

该次运行时也发生变化，不能仅根据那一轮的竖屏步骤改善认定坐标修正有效；后文补充了恢复 `24A94232` 后的部分步骤复测，完整往返仍未完成。上述外屏 49 项分段通过对应窗口坐标修正前版本；其中 44 项的相关源码未受最后一次辅助函数修改影响，另 5 项外屏安全区域用例尚待重新验证。逐项边界见[最终源码 UI 覆盖核对](Results/duo-final-release-build-20261021/final-ui-coverage-boundary.json)。当前内屏完整矩阵也未完成，不将此前 `24A94232` 的方向聚焦通过替代 `24A94425` 上尚失败的方向验收。

### 最终构建与指定 Xcode 启动核查

当前源码的 Release Demo 构建 **通过，0 错误、0 警告**；终态 `BUILD SUCCEEDED`、退出码 0，`sourceChangedSinceRun` 为空。见[构建结果](Results/duo-final-release-build-20261021/build-result.json)及[源码摘要](Results/duo-final-release-build-20261021/summary.json)。Build Phase 为 `0/43 files formatted, 2 files skipped`，未产生额外格式化改动。 当前库范围 `Package.swift`、`Sources/`、`Tests/` 共 27 个文件与此前 190 项通过的库测试快照一致，见[库源码范围核验](Results/duo-final-release-build-20261021/library-source-scope-check.json)；此范围核验不覆盖 Demo UI 测试。这是构建验收，不计为 UI 测试执行；该构建启动时的目标设备元数据为 `24A94425`。

随后用显式 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 执行同一 Duo 的正常 `simctl shutdown`／`boot`，两条命令退出码均为 0。新 SpringBoard PID `76449` 的实际路径恢复为 `24A94232`，说明本次两个启动入口产生了不同的实际运行时；没有修改 runtime matching 规则。`bootstatus` 仍报告 `Status=3, isTerminal=YES, Data Migration Failed`（自身退出码 0），因此不能仅凭版本恢复宣称环境健康。见[指定 Xcode 启动观察](Results/duo-inner-environment-recovery-20261021/explicit-xcode-boot-observation.json)。后续通过 Xcode 菜单重新打开 Device Hub 后，AX 能读取 Home，窗口截图仍超时。改用 AX 控件点击 Open，再通过 `simctl io --display=3` 得到并检查了有效的 `2853 × 2007` 内屏 Home，见[恢复后的内屏](Results/duo-inner-environment-recovery-20261021/display-3-after-ax-open.png)；因此可继续一次聚焦验证，但不能仅凭 Home 画面认定 App 旋转已经恢复。

恢复 `24A94232` 后，首次单项复测仍未进入 App 验证：setup 的外部方向确认在约 133 秒才到达，超过原有 120 秒阈值。电脑多步 AX 合并调用触发 60 秒工具超时；后续分步操作虽成功，不能追认过期请求通过。XCTest 在失败处理进入 async teardown 后持续等待，已采样并主动中止该轮，终态 **0 通过、1 失败，退出码 75**，`sourceChangedSinceRun` 为空。见[握手失败摘要](Results/duo-inner-recovered-window-touch-focused-20261021/summary.json)、[动作记录](Results/duo-inner-recovered-window-touch-focused-20261021/computer-rotation-actions.jsonl)及[运行器采样](Results/duo-inner-recovered-window-touch-focused-20261021/runner-after-setup-failure.txt)。该失败属于电脑驱动握手，不能归因于标签布局或将系统方向通知作为实际 App 方向通过。

随后保留同一冻结产物，改用短分步 AX 调用运行 `duo-inner-stepwise-window-touch-focused-20261021`。该轮实际场景 Portrait（1，`669 × 951 pt`）及 Landscape Right（3，`951 × 669 pt`）均通过方向、安全区域和 Header 折叠／展开步骤；[右横屏大字号 RTL 实际画面](TabBarAccessories/duo-inner-custom-large-rtl-right.png)已核对。下一次目标 Landscape Left 的系统通知虽已到达，电脑动作确认仍超过 120 秒，失败于外部握手，未进入该方向的 App 几何断言。分步控制仍无法稳定完成完整矩阵，因此保留部分步骤证据，不将单项或整套判为通过；最后一次窗口坐标修正后的内屏完整回归及 5 项外屏安全区域复测仍受环境阻塞。收尾读取 Device Hub 的单步操作再次 60 秒超时，未确认恢复竖屏，随后中止仅本轮测试。终态结果包为 **0 通过、2 条失败记录**（1 条外部握手失败、1 条运行器取消），退出码 75，`sourceChangedSinceRun` 为空；见[最终聚焦摘要](Results/duo-inner-stepwise-window-touch-focused-20261021/summary.json)、[结果包](Results/duo-inner-stepwise-window-touch-focused-20261021/Result.xcresult)及[动作日志](Results/duo-inner-stepwise-window-touch-focused-20261021/computer-rotation-actions.jsonl)。没有把超时请求补记成功，没有修改握手阈值或实际方向断言。

### Device Hub 侧栏开销与官方控制路径复核

本轮首先复核官方 Xcode MCP。替换失效的设备会话后，空输入抓取、激活及方向事件均能在约 2.6～8.1 秒内返回；同一 Demo PID `87484` 的实际界面却始终为 Landscape Left、`951 × 669 pt`，即使设备方向字段已经变为 Portrait，实际场景也未改变。官方截图持续为 `678 × 466` 黑图，因此没有用其证明内屏视觉通过。见[官方调用摘要](Results/duo-control-repair-20261021/official-summary.json)。结束会话后才改用电脑操作，未并行注入输入。

Device Hub 旧进程 `22338` 的一次采样显示主线程大量时间位于 AppKit／SwiftUI 布局路径，见[采样](Results/duo-control-repair-20261021/device-hub-before-repair.sample.txt)。通过电脑正常退出并重新打开 Device Hub 后，完整设备侧栏读取仍耗时 34.504 秒；在搜索框筛选 `Duo`、选中目标并收起侧栏后，连续读取降为 0.198～2.794 秒，打开方向菜单约 0.757 秒、选择 Portrait 后读取约 0.899 秒。运行测试期间补充的[恢复后采样](Results/duo-control-repair-20261021/device-hub-after-filter.sample.txt)中，主线程 140 个样本有 134 个处于 Mach 事件等待。两次采样与读取耗时共同支持本机响应改善，但未构成严格对照实验，不能据此证明唯一根因或保证长时间运行不再超时。见[控制恢复观察](Results/duo-control-repair-20261021/control-repair-observation.json)及[有效外屏窗口](Results/duo-control-repair-20261021/hub-after-sidebar-hidden.jpeg)。

该次正常退出 Device Hub 同时关闭了 Duo，不能描述为“模拟器进程未受影响”。随后通过官方 `StartSession` 恢复启动；首次 `EndSession` 等待 71.117 秒后超时，单次清理复查返回会话已不存在，确认释放控制权。新 SpringBoard PID `88333` 的实际路径为 `24A94232`；没有清空设备、删除运行时或修改匹配规则。恢复后再检查实际画面和方向，不以 StartSession 成功推定运行环境已完全健康。

外屏剩余 5 项使用 `DuoWindowTouchFrozen-20261021` 产物另起 `duo-outer-filtered-hub-five-20261021`；启动前核对 11 项冻结产物哈希无变化、全部 Swift 文件与 `duo-window-touch-build-20261021` 构建快照一致。实际测试仍使用原有 120 秒外部握手阈值及场景方向断言，电脑驱动只在短暂窗口过渡时追加一次读取，不改动测试预期。运行终态和后续内屏矩阵分别记录，未完成的运行不计为通过。

外屏这次聚焦回归终态为 **5 通过、0 失败、0 跳过**，退出码 0、`TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 为空。结果包确认 Duo / iOS 27.1 / `24A94232`；见[摘要](Results/duo-outer-filtered-hub-five-20261021/summary.json)、[结果包](Results/duo-outer-filtered-hub-five-20261021/Result.xcresult)、[命令](Results/duo-outer-filtered-hub-five-20261021/command.json)及[完整日志](Results/duo-outer-filtered-hub-five-20261021/xcodebuild.log)。通过项为 `testCustomTabSafeAreaLargeTextRTL`、`testSafeAreaTabsLTR`、`testSafeAreaTabsRTL`、`testSafeAreaTabsLargeTextLTR`、`testSafeAreaTabsLargeTextRTL`，均覆盖实际竖屏、两侧横屏、恢复竖屏，以及 Header 折叠／展开和页面安全区域。

本轮 30 个唯一外部请求全部确认，未出现握手超时；最长请求等待约 94 秒发生于操作者接管期间，不等于单次电脑动作耗时。后续通常约 3～6 秒完成菜单动作与状态读取；见[握手汇总](Results/duo-outer-filtered-hub-five-20261021/rotation-handshake-summary.json)、[原始握手](Results/duo-outer-filtered-hub-five-20261021/rotation-events.jsonl)及[电脑动作](Results/duo-outer-filtered-hub-five-20261021/computer-driver.jsonl)。[外屏横向 3](TabBarAccessories/duo-outer-filtered-large-rtl-ui3.jpeg)与[外屏横向 4](TabBarAccessories/duo-outer-filtered-large-rtl-ui4.jpeg)均取得有效画面，已核对辅助字号 RTL 标签、安全区域换边、Header 和标签栏背景连续性；不据此推定所有附件或完整 VoiceOver 已验收。

此前最后一次触摸坐标修正影响的 5 项现已补测通过，与未受该修正影响的 44 项原通过证据及 7 项 iPad 专属跳过合并，最终源码范围的外屏分段覆盖恢复为 **49 通过、7 跳过**。见[逐项对应](Results/duo-outer-filtered-hub-five-20261021/outer-final-segmented-coverage.json)。这是核对源码范围后的分段覆盖，不是一次 56 项全量成功；保留前述初次失败、中断及修复过程。

外屏结束后通过电脑控件切到 Open，取得[有效内屏画面](Results/duo-inner-filtered-hub-full-20261021/open-stable.jpeg)。随后首次内屏全量启动因验证驱动错误而失败：临时 JavaScript 处理函数仍捕获外屏旧运行目录，首个内屏请求未得到处理。没有向过期请求写确认，亦未进入 App 几何或触摸断言；终态为 **0 通过、1 失败、55 项未执行**，主动中止退出码 75，`sourceChangedSinceRun` 为空。见[摘要](Results/duo-inner-filtered-hub-full-20261021/summary.json)、[结果包](Results/duo-inner-filtered-hub-full-20261021/Result.xcresult)及[日志](Results/duo-inner-filtered-hub-full-20261021/xcodebuild.log)。这属于本次验证驱动实现错误，不归因于产品或 Device Hub 超时；修正为显式传入运行目录、姿态和已处理请求编号后，另起完整回归。

修正驱动后的内屏无过滤全量运行 `duo-inner-filtered-hub-full-retry-20261021` 前 13 项通过，包含全部 5 项嵌套手势、自动内容高度、折叠栏旋转对齐、紧凑标签隐藏恢复、自定义指示器及标签交互。随后 `testCustomTabSafeAreaLargeTextRTL` 已完成实际两侧横屏并恢复竖屏，但连续出现 `App animations complete notification not received, will attempt to continue`，每次触摸前后额外等待约 60 秒。电脑控制仍在数秒内响应，没有待确认的旋转请求；不能将其写成 Device Hub 再次超时。

只读[运行器采样](Results/duo-inner-filtered-hub-full-retry-20261021/runner-idle-wait.sample.txt)显示等待链为 `select(_:)` → `XCUIApplicationProcess.waitForQuiescenceIncludingAnimationsIdle`；同次[App 采样](Results/duo-inner-filtered-hub-full-retry-20261021/app-idle-wait.sample.txt)的主线程 183 个样本均处于 Mach 事件等待，没有证据支持布局死循环。标签滚动仍会在等待后继续。为避免该等待阻塞其他项目，在无方向请求的空闲边界中止仅本轮测试，未重启设备、关闭动画或修改断言。

该轮终态为 **13 通过、1 条取消记录、42 项未执行**，退出码 75，`sourceChangedSinceRun` 为空。见[摘要](Results/duo-inner-filtered-hub-full-retry-20261021/summary.json)、[结果包](Results/duo-inner-filtered-hub-full-retry-20261021/Result.xcresult)及[日志](Results/duo-inner-filtered-hub-full-retry-20261021/xcodebuild.log)。[稳定内屏截图](TabBarAccessories/duo-inner-filtered-custom-large-rtl-portrait.png)已核对选中标签和页面布局；截图不代替被取消项的完整通过。后续按[未完成标识清单](Results/duo-inner-filtered-hub-full-retry-20261021/continuation-candidates.json)复测，分段结果与这次未完成的全量运行分别报告。

保持同一设备、运行时与冻结产物，仅换用新测试运行器单独复测上述取消项，`duo-inner-custom-safearea-focus-20261021` 取得 **1 通过、0 失败、0 跳过**，退出码 0，`sourceChangedSinceRun` 为空。该项完成竖屏 → 实际方向 3 → 实际方向 4 → 竖屏，以及每个方向的安全区域、标签选择和 Header 折叠／展开；没有关闭动画或放宽断言。见[聚焦摘要](Results/duo-inner-custom-safearea-focus-20261021/summary.json)、[结果包](Results/duo-inner-custom-safearea-focus-20261021/Result.xcresult)及[日志](Results/duo-inner-custom-safearea-focus-20261021/xcodebuild.log)。已核对稳定 `display 3` 的[横向 3](TabBarAccessories/duo-inner-filtered-custom-large-rtl-ui3.png)和[横向 4](TabBarAccessories/duo-inner-filtered-custom-large-rtl-ui4.png)画面；截图中的标签位于用例主动滚动位置，不将截图自身作为选中项居中的断言。此聚焦恢复不代表 XCTest 通知问题已根治，其余 42 项继续独立运行。

其余 42 项续跑 `duo-inner-remaining42-20261021` 取得终态 **33 通过、2 失败、7 跳过**，退出码 65、`TEST EXECUTE FAILED`，`sourceChangedSinceRun` 为空。见[摘要](Results/duo-inner-remaining42-20261021/summary.json)、[结果包](Results/duo-inner-remaining42-20261021/Result.xcresult)和[日志](Results/duo-inner-remaining42-20261021/xcodebuild.log)。7 项为 iPad 专属分屏／窗口用例，不能计为 Duo 通过。合并前两段按标识去重后，内屏首次完成覆盖为 **47 通过、2 失败、7 跳过**，不是一次完整成功运行。

两项失败分别为 `testRotationAndBackGesture` 在实际旋转成功后完成边缘返回，未出现首页按钮，以及 `testPagerAccessoryMenuAndHeightRecovery` 在首次“切换高附件”后等待标签视口高度 `>= 80` 超时。原始失败附件分别保存在[返回手势附件](Results/duo-inner-remaining42-20261021/back-attachments/manifest.json)和[附件栏高附件](Results/duo-inner-remaining42-20261021/height-attachments/manifest.json)。有效内屏 [279.605 秒录屏](Results/duo-inner-remaining42-20261021/inner-accessory-tests.mp4)覆盖系统容器末段、附件和角标；已观察到高附件菜单关闭后栏高增长，但这一视觉观察不能代替精确 frame 和恢复断言。后续复现与修复另起运行目录，不覆盖本轮失败。

相同冻结产物的原样聚焦 `duo-inner-two-failures-focus-20261021` 为 **0 通过、2 失败**，退出码 65，`sourceChangedSinceRun` 为空，两处均再次出现；见[聚焦摘要](Results/duo-inner-two-failures-focus-20261021/summary.json)、[原样复现录屏](Results/duo-inner-two-failures-focus-20261021/inner-two-failures.mp4)及[附件清单](Results/duo-inner-two-failures-focus-20261021/attachments/manifest.json)。随后仅在对应 UI 测试增加精确 frame 日志，并对返回用例启用 Demo 已有、不会改变事件分发的 `PagingTraceWindow`，原触摸坐标与成功断言暂时不变。

诊断构建先使用官方 `BuildProject(buildForTesting: true)`，但后台 workspace 沿用当前真机目标，因两个 target 没有签名 Team 失败；[官方构建日志](Results/duo-inner-two-failures-diagnostic-build-20261021/official-first-build.log)保留。没有修改用户的签名 Team 或当前 Xcode 目标，改用显式 Duo UUID 的 `Scripts/validate.sh build-for-testing`，终态 **TEST BUILD SUCCEEDED**、退出码 0，源码快照无变化。Build Phase 为 `0/43 files formatted, 2 files skipped`；保留 XCTest 动态库最低版本为 iOS 17 与本测试 target 的 iOS 15 部署目标不一致的 3 条链接警告，以及未依赖 AppIntents 的元数据提示，未提高框架最低系统版本。见[诊断构建日志](Results/duo-inner-two-failures-diagnostic-build-20261021/xcodebuild.log)及[构建核对](Results/duo-inner-two-failures-diagnostic-build-20261021/build-check.json)。

增加日志后的诊断 `duo-inner-two-failures-diagnostic-20261021` 仍为 **0 通过、2 失败**，退出码 65，`sourceChangedSinceRun` 为空；见[摘要](Results/duo-inner-two-failures-diagnostic-20261021/summary.json)与[触摸解码](Results/duo-inner-two-failures-diagnostic-20261021/back-gesture-decoded.json)。精确高度从 `55.99999999999997` 变为 `79.99999999999997`，与 80 的差仅为浮点坐标变换误差。返回手势起点报告为 `(1, 475.5)`，但取消拖动后的 trace 仍为之前纵向滑动的 `sequence=3`，最终返回拖动后仍为中间分页的 `sequence=4`，两次边缘触摸均未进入 Demo 的窗口事件记录；实际方向断言仍通过。

针对高度比较，测试只增加 `0.000001 pt` 浮点容差，同时要求高度大于原值，并在增长、恢复两个阶段检查页面顶部与标签视口底部贴合。返回用例改用实际窗口锚点，保持 1 pt 边缘起点及原返回距离，并新增取消手势确实产生新触摸、起点位于边缘的检查。框架与 Demo 生产实现未修改；后续修复验证另列，不把诊断失败追记为通过。

修正后的内屏聚焦 `duo-inner-two-failures-fixed-20261021` **2 通过、0 失败**，退出码 0、`TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 为空；见[摘要](Results/duo-inner-two-failures-fixed-20261021/summary.json)、[结果包](Results/duo-inner-two-failures-fixed-20261021/Result.xcresult)及[录屏](Results/duo-inner-two-failures-fixed-20261021/inner-fixed.mp4)。窗口锚点下，取消手势 trace 从 `sequence=3` 增至 `4`，实际起终点 `x=1 → 81`，分页偏移不变；完整返回首页、重新进入及后续分页也通过。高度增长仍为同一 `79.99999999999997`，恢复及页面衔接断言均通过，未修改生产布局以迎合测试。

内屏最终按标识去重覆盖 **49 通过、0 待修复失败、7 项 iPad 专属跳过**，见[逐项运行映射](Results/duo-inner-two-failures-fixed-20261021/inner-segmented-coverage.json)。这是分段覆盖，不是单次完整成功运行；原失败、驱动错误和取消仍保留。最终源码核验发现此前几段与当前只差两个 UI 测试文件，函数级差异仅为返回用例、其专属 trace 启动条件及高附件用例；其余函数与框架／Demo 源码一致。见[源码范围核验](Results/duo-inner-two-failures-fixed-20261021/final-source-scope-check.json)。此前摘要中的 `sourceChangedSinceRun=[]` 表示当次封存时点，不表示修改测试后整个旧快照仍相同；只按未变范围保留其他测试结果。

已核对本轮有效录屏提取的[首端](TabBarAccessories/duo-inner-filtered-start.png)、[中间](TabBarAccessories/duo-inner-filtered-middle.png)、[尾端](TabBarAccessories/duo-inner-filtered-end.png)、[RTL 首端](TabBarAccessories/duo-inner-filtered-rtl-start.png)、[RTL 中间](TabBarAccessories/duo-inner-filtered-rtl-middle.png)、[RTL 尾端](TabBarAccessories/duo-inner-filtered-rtl-end.png)和[深色频道菜单](TabBarAccessories/duo-inner-filtered-rtl-channels.png)：两端附件固定、渐隐局限于有隐藏内容的标签边缘，菜单包含“频道 3：通知”。原视频跨方向录制，固定视频轨道变换会把后续竖屏帧横置；这里提取原始编码帧，未修改 UI 像素，原视频保留。见[视觉核对说明](Results/duo-inner-remaining42-20261021/visual-review.json)。

同一修复产物切换 Closed 外屏后，`duo-outer-two-failures-fixed-20261021` **2 通过、0 失败**，退出码 0、`TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 为空；设备确认 Duo / iOS 27.1 / `24A94232`。见[外屏修复复测摘要](Results/duo-outer-two-failures-fixed-20261021/summary.json)、[结果包](Results/duo-outer-two-failures-fixed-20261021/Result.xcresult)和[录屏](Results/duo-outer-two-failures-fixed-20261021/outer-fixed.mp4)。外屏实际窗口 `466 × 678 pt`，返回手势起点 `(1, 339)`；栏高 `56 → 80 → 56`，增长、恢复及页面顶部衔接均通过。外屏最终同样为 **49 通过、7 项 iPad 专属跳过**的分段覆盖，见[最终外屏逐项映射](Results/duo-outer-two-failures-fixed-20261021/outer-final-segmented-coverage.json)。两轮最终聚焦重新核对源码均无差异，见[最终快照核对](Results/duo-outer-two-failures-fixed-20261021/final-source-recheck.json)。

已核对修复后的内屏[返回首页](TabBarAccessories/duo-inner-filtered-back-home.png)、[附件撑高](TabBarAccessories/duo-inner-filtered-height-grown.png)和[栏高恢复](TabBarAccessories/duo-inner-filtered-height-restored.png)，见[最终视觉说明](Results/duo-inner-two-failures-fixed-20261021/final-visual-review.json)。两份修改的 Swift 测试文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。本轮生产源码未修改；最终核对库范围与此前 190 项通过的快照相同，Release 生产范围也与此前成功构建一致，见[生产与库范围核验](Results/duo-outer-two-failures-fixed-20261021/unchanged-production-library-check.json)。该核验不代表本轮重新执行了库测试或 Release 构建。

最终通过电脑恢复 Open 内屏并打开 Demo，已核对[最终内屏画面](Results/duo-outer-two-failures-fixed-20261021/final-inner-display3.png)为正常竖向内容；测试、录屏和官方设备会话均已结束。普通启动后的 AX 未提供 App 子树，因此[最终状态记录](Results/duo-outer-two-failures-fixed-20261021/final-state.json)没有把截图尺寸当作精确 window frame 或 raw 方向值；实际方向的数值验收来自前述 XCTest 终态。

当前边界：**通过**为双屏全部适用 UI 项的分段回归、真实菜单旋转与上述视觉核对；**失败历史**包括原始返回与浮点高度两项、驱动错误及取消，均保留并由新轮次复测覆盖；**未执行**为单次不中断完整套件、iPad 专属窗口矩阵、iOS 15 实机／模拟器运行、真机及完整 VoiceOver 人工验收；**被环境阻塞／未修复**为官方 MCP／默认 `XCUIDevice` 方向事件不能带动实际 App 方向的路径，电脑菜单替代路径已完成验证。Device Hub 侧栏处理在本轮持续有效，但不宣称 Apple 工具根因已彻底修复。未提交或推送。

## 2026-10-21：角标顶部尾端定位与中文尺寸

修复默认角标原先按 Cell 边缘垂直居中、单侧挤压图文的问题。测量和显示共用包含中文回退字体行高的尺寸；默认内容保持居中，长角标按需要对称增加理想宽度。上下图文跟随图标，纯文字及横向图文跟随整体内容；LTR 为右上角，RTL 镜像到左上角。自定义内容继续由业务配置绘制角标。

- **修复前失败证据：** [原始回归](Results/20261021-badge-before/Result.xcresult)共 3 项，2 通过、1 失败；失败项包含标题偏移、角标未位于内容顶部的几何断言。保留原结果，不计入修复后验收。
- **中间验证通过：** [首次聚焦](Results/20261021-badge-focused/summary.json)为 3 通过、0 失败；随后补充系统 RTL 对照并修正镜像规则，因此该轮不代表最终源码。
- **系统参照：** 用户指定 iPhone 18 Pro Max，使用 Xcode 27.1 / iOS 27.0 的真实 `UITabBar`，分别设置 LTR 与 RTL，包含数字、阿拉伯文和中文角标。[系统对照结果](Results/20261021-badge-system-rtl-promax/Result.xcresult)与图层渲染附件确认尾端位置随布局方向镜像。图层截图不完整呈现系统材质与图标，不作为整栏视觉验收。
- **过程环境记录：** Duo 的 `drawHierarchy` 对照附件为黑图；后续一次运行出现测试运行器通信断开，均保留在 `20261021-badge-system-rtl*` 结果目录。最初全量库测试未取得终态结果，切换设备后另跑最终验证，不将其计入通过。Pro Max 运行器在 IDE 握手阶段等待较长后成功完成，未将该等待误判为角标布局死锁。

- **中间全量失败及修复：** [Pro Max 首轮全量](Results/20261021-badge-library-promax-final/summary.json)共 190 项，188 通过、2 失败。新增 RTL 几何断言发现默认内容视图未可靠继承宿主方向，已将布局方向写入内部配置，并同步到内容与按钮的语义方向；另一项为旧测试仍要求角标挤占 trailing 内边距，已更新为对称内边距契约，保留复用、清理及点击断言。失败结果保留，不把旧轮次作为最终通过证据。
- **UI 启动阻塞：** 官方 MCP 两轮均完成构建，但运行器被 SpringBoard 以 `Busy / Application failed preflight checks` 拒绝启动；第二轮为 2 项未运行，见[官方结果](Results/20261021-badge-ui-final/official-result.json)及[日志](Results/20261021-badge-ui-final/console.log)。仅重启本次新启动的 Pro Max，启动状态最终为 `Finished`，保留设备数据及 Duo 状态。

- **最终库回归通过：** iPhone 18 Pro Max / iOS 27.0 / Xcode 27.1 / Debug，共 **190 通过、0 失败、0 跳过**，包含 5 项新增角标与系统参照测试。见[终态摘要](Results/20261021-badge-library-promax-repaired/summary.json)与[结果包](Results/20261021-badge-library-promax-repaired/Result.xcresult)。期间其他工作更新了 Demo UI 测试方向辅助代码，整体 `sourceChangedSinceRun` 非空；另对本次库测试的 `Package.swift`、`Sources/`、`Tests/` 共 27 个文件核验，全部与测试时一致，见[库范围源码核验](Results/20261021-badge-library-promax-repaired/library-source-check.json)。不将这次库结果表述为整个工作区的 UI 验收。
- **视觉与方向证据：** [中文角标图层对照](TabBarBadges/chinese-system-reference.png)上方为 StickyPagerKit、下方为系统角标；[系统 LTR／RTL 对照](TabBarBadges/system-ltr-rtl.png)及[实际坐标](TabBarBadges/system-ltr-rtl-geometry.txt)显示，中间阿拉伯文角标在 LTR 的中心 x 约为 220.33 pt，RTL 约为 169.67 pt，分别位于中间标签中心 195 pt 的两侧。图层截图未完整绘制系统图标与材质，完整 Demo 外观另以 UI 截图为准。

- **官方 UI 设备核对：** 后续官方 MCP 返回 2 通过，但结果包的实际 `deviceId` 为 Duo `049C3F56-87CB-4D53-8B0A-7537DDE19222`，与此前请求切换的 Pro Max 不一致。目录 `20261021-badge-ui-promax-repaired` 的名字不代表实际设备，该轮只能作为 Duo 聚焦结果，不能计为 Pro Max UI 验收。库回归和系统对照由命令行明确指定 Pro Max UUID，不受此问题影响。最终改用 `SP_SCOPE=demo` 与明确 Pro Max UUID `41AF9CED-9BBB-4B60-B563-73AFB035C2D4` 执行角标 UI 测试。

- **最终 Pro Max UI 通过：** 复用官方已构建、运行前源码一致的产物，复制 App、测试 Runner 和 `.xctestrun` 到独立的 `Validation/Products/BadgeProMaxFrozen/` 后，以 `xcodebuild test-without-building` 和明确的 Pro Max UUID `41AF9CED-9BBB-4B60-B563-73AFB035C2D4` 执行，**2 通过、0 失败、0 跳过**。命令行重新构建的中间轮次因再次触发 SwiftFormat 全量 Release 编译而主动中止，未计为运行通过；正式测试复用的是此前成功构建的独立产物副本。见[最终 UI 摘要](Results/20261021-badge-ui-promax-frozen/summary.json)、[结果包](Results/20261021-badge-ui-promax-frozen/Result.xcresult)及[完整执行命令与日志](Results/20261021-badge-ui-promax-frozen/xcodebuild.log)。结果包明确记录设备名 iPhone 18 Pro Max、iOS 27.0 和上述 UUID；`sourceChangedSinceRun` 为空，[构建产物哈希核验](Results/20261021-badge-ui-promax-frozen/product-check.json)也无变化。
- **截图核对通过：** [Pro Max LTR](TabBarBadges/iphone-18-pro-max-ltr.png)中“新／上新”完整居中、定位在右上角；[Pro Max RTL 深色](TabBarBadges/iphone-18-pro-max-rtl-dark.png)中对应角标镜像到左上角，选中状态和真实点击反馈正常。横向滚动视口边缘仍按已有规则渐隐部分可见的标签内容，不将其当作角标测量裁剪。
- **静态检查通过：** 本次涉及的 6 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。未提交或推送，保留其他进行中工作的方向辅助代码与既有修改。
- **未执行：** 本轮未重跑完整 Demo UI suite、Release、iOS 15、iPad、真机及完整 VoiceOver 人工验收。库测试中的大字号、窄视口、几何和 hit-test 验证不替代这些矩阵；系统 RTL 对照使用明确的语义方向和阿拉伯文字符串，没有将它表述为完整阿拉伯语系统本地化验收。

## 2026-10-21：指示器自动圆角统一

`SPTabBarIndicatorLayout.cornerRadius = nil` 改为使用指示器最终 `min(width, height) / 2`，与显式圆角的上限一致；同步 API 注释与 README。新增真实 UIWindow 测试覆盖横向、正方形、纵向和零尺寸，检查胶囊、线条、自定义模式及自定义渲染状态；另检查显式值截断、非法值归零和设回 nil 后恢复自动圆角。

- **通过：** Xcode 27.1 / iPhone Duo / iOS 27.1 / Debug 下，独立 Package 的 `SPTabBarIndicatorTests` 与 `SPTabBarModelTests` 共 **42 通过、0 失败、0 跳过**。已读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。见[摘要](Results/indicator-corner-radius-20261021/summary.json)与[结果包](Results/indicator-corner-radius-20261021/Result.xcresult)。
- **通过：** 修改的 3 个 Swift 文件使用 SwiftFormat 0.64.0 格式化并通过 lint；`git diff --check` 通过。
- **未执行：** 本次未重跑其他库测试、Demo UI、Release、iOS 15、iPad 和真机矩阵；上述结果不替代其他章节尚未通过的 UI 验收。

官方 Xcode MCP 当前打开的工程仅列出 Demo scheme，未提供独立 Package 库测试，因此使用 `Scripts/validate.sh` 执行。CoreSimulator 访问和 `.xcresult` 摘要缓存首次受沙盒限制，经授权执行环境完成，最终测试及摘要均成功。

## 2026-10-21：iPhone Duo 内屏验证

用户在 Device Hub 手动切换到内屏后，Apple 官方 MCP 独占预检确认 App 窗口为 `951 × 669 pt`，区别于外屏的 `466 × 678 pt`。预检时源码与外屏前序运行 `duo-official-ui-full-20261020` 的快照一致；本节按新运行记录内屏结果，不覆盖外屏失败。

预检中设备方向依次为 Portrait、Landscape Left、Landscape Right、Portrait，但 App 始终为 Landscape Left、窗口始终为 `951 × 669 pt`。App PID 全程为 `60843`，没有观察到退出。方向命令已执行，实际旋转仍未通过；结束时恢复设备 Portrait，`DeviceInteractionEndSession` 返回 `Session stopped`。见[预检记录](Results/duo-inner-preflight-20261021/observations.json)。

本次官方截图全部为 `678 × 466` 黑图，hierarchy 的 hitPoint 也疑似按该范围裁切，因此没有依据这些坐标执行触摸，不能用其作为内屏视觉证据。后续 XCTest 使用 `app.screenshot()` 和实际窗口几何另行验证。新会话先通过 `XcodeOpenWorkspace` 打开 Demo，再将后台工程目标从默认 iPhone 18 Pro 切换到 iPhone Duo；内屏测试使用正式加载的官方 MCP，不复用旧进程的临时桥接。

内屏聚焦调用 `RunSomeTests` 完成 6 项：**4 通过、2 失败、0 跳过、0 未运行**，`sourceChangedSinceRun` 为空。通过项为 Header／分页位置恢复、附件固定与频道菜单、RTL 深色附件交互、分页附件高度增长与恢复；两项失败分别为系统容器 RTL 旋转、窄栏辅助字号旋转，均期望实际方向 `3` 而仍为 `4`。后者窗口为 `951 × 669 pt`，没有将横向尺寸本身当作方向请求生效。见[摘要](Results/duo-inner-ui-focused-20261021/summary.json)、[结果包](Results/duo-inner-ui-focused-20261021/Result.xcresult)、[日志](Results/duo-inner-ui-focused-20261021/console.log)。

聚焦 `.xcresult` 导出的 `app.screenshot()` 同样为黑图（`2006 × 2852 px`），不能承担内屏视觉验收；[原始附件清单](Results/duo-inner-ui-focused-20261021/attachments/manifest.json)保留。导出首次因 TestReport 缓存写入权限失败，使用授权执行环境后导出成功。通过电脑插件再次读取完整路径的 Device Hub 仍返回 `-10005: timeoutReached`，因此当前视觉核对被环境阻塞，触摸／状态断言与视觉结论分开记录。

用户提出录屏／画中画替代后，读取 Xcode 27.1 官方 `simctl io` 帮助及显示源枚举，发现 Duo 内屏为 `Screen ID 3`（`LCD-1`／`primary-1`，物理尺寸 `2007 × 2853`），外屏为 `Screen ID 1`（`LCD`／`primary`，`1398 × 2034`）。显式执行 `xcrun simctl io 049C3F56-87CB-4D53-8B0A-7537DDE19222 screenshot --display=3 <输出路径>` 已取得正常的 `2853 × 2007` 横向内屏画面，见[原始截图](Results/duo-inner-preflight-20261021/inner-display-3.png)。这解除了内屏图像采集阻塞；此前官方 MCP／XCTest 黑图仍保留，不能替换成通过证据。显示源枚举仅用于选择捕获源，没有修改屏幕尺寸、折叠姿态或 App 方向。

使用同一显示源执行 `xcrun simctl io 049C3F56-87CB-4D53-8B0A-7537DDE19222 recordVideo --display=3 --codec=h264 <输出路径>`，收到 `Recording started` 后记录、以 SIGINT 正常结束并取得 `Recording completed`。保存的[内屏视频](Results/duo-inner-preflight-20261021/inner-display-3-recording.mp4)时长 `56.37 s`，编码尺寸为 `2006 × 2852`，应用轨道方向后抽帧为 `2852 × 2006`；已查看[第 10 秒帧](Results/duo-inner-preflight-20261021/inner-display-3-recording.10.png)，正常显示横向卡片滚动。AVFoundation 首次在沙盒内因系统解码服务权限失败，使用授权执行环境后正常解码。此次视频对应完整回归中的嵌套横滑场景，仅证明该显示源取证可用，不代表尚未录制的附件矩阵或旋转验收通过。

已另存[内屏录屏代表帧](TabBarAccessories/duo-inner-compositional-recording.png)和[内屏自定义指示器](TabBarAccessories/duo-inner-custom-indicator.png)。后者为完整回归期间以 `--display=3` 旁路采集，画面显示“收藏”选中边框与内容，右侧系统区域独立；没有为截图注入额外触摸。

随后官方 `RunAllTests` 完成全部 54 项：**29 通过、18 失败、7 跳过、0 未运行**，与 `.xcresult` 摘要一致，运行结束时 `sourceChangedSinceRun` 为空。14 项失败为实际方向断言；其余 4 项分别为普通页用 App 旧方向 frame 比较底边（669 与 951）、紧凑编号错误期待固定 44 pt（实际均分 66.69 pt）、宽屏副标题未换行导致高度仍为 76 pt，以及按住标签后以 App 坐标固定拖动未产生位移。7 项跳过为 iPad 专属窗口／分屏用例。见[完整摘要](Results/duo-inner-ui-full-20261021/summary.json)、[结果包](Results/duo-inner-ui-full-20261021/Result.xcresult)和[日志](Results/duo-inner-ui-full-20261021/console.log)。

针对 4 项宽屏问题，普通页底边改用真实 window，按住标签的手势改为标签视口坐标及相对距离；宽度断言遵守 13 项余量均分和最小项宽下限。Demo“不可压缩宽内容”使用 `max(480, availableWidth + 80)`，保证宽屏也演示超视口内容；“切换多行副标题”加入明确换行，保证宽屏演示栏高增长与恢复。仅修改 Demo 和 UI 测试，未修改框架实现；README 同步这两项 Demo 行为。上述完整回归是修复前结果，不可当作修复后全量通过。

4 项宽屏聚焦复测均通过，见[摘要](Results/duo-inner-adaptive-focused-20261021/summary.json)。运行期间另有并行工作修改 `SPTabBar.swift`、`SPTabBarIndicator.swift` 和 `SPTabBarIndicatorTests.swift` 的圆角实现及测试，故该轮 `sourceChangedSinceRun` 明确列出这 3 个文件，不能视为最终源码验证；这些修改被保留，另见本页圆角验证记录。

完整回归末段的[系统容器与附件录屏](Results/duo-inner-ui-full-20261021/system-and-accessories.mp4)长 `440.65 s`，已正常解码并按测试日志抽帧。可核对[滚动](TabBarAccessories/duo-inner-scroll.png)、[尾端](TabBarAccessories/duo-inner-end.png)、[搜索反馈](TabBarAccessories/duo-inner-search.png)、[频道菜单](TabBarAccessories/duo-inner-channels.png)、[RTL 选中状态](TabBarAccessories/duo-inner-rtl-selected.png)及[附件撑高后的页面](TabBarAccessories/duo-inner-height.png)。录屏发现深色导航区域样式不一致、纯图标频道菜单名称为空：后续将 `--dark` 从内容控制器移到整个 window，菜单标题为空时回退到 `accessibilityLabel`，并加入“频道 3：通知”的 UI 断言。以上旧截图保留为修复前证据。

随后对最终源码重新执行 4 项宽屏修复及 3 项附件交互，共 **7 通过、0 失败、0 跳过、0 未运行**；`.xcresult` 与官方 MCP 终态一致，`sourceChangedSinceRun` 为空。该轮包含已保留的圆角变更，以及窗口深色模式、频道名称回退的 Demo 修复，见[最终聚焦摘要](Results/duo-inner-ui-final-focused-20261021/summary.json)、[结果包](Results/duo-inner-ui-final-focused-20261021/Result.xcresult)和[日志](Results/duo-inner-ui-final-focused-20261021/console.log)。这轮未包含旋转用例，不将 7 项通过折算成修复后的完整 54 项结果。

为补齐修复后画面，另以官方 `RunSomeTests` 运行 2 项附件外观用例并全程录制内屏：**2 通过、0 失败**，`sourceChangedSinceRun` 为空，见[摘要](Results/duo-inner-visual-final-20261021/summary.json)和[130.78 秒原始录屏](Results/duo-inner-visual-final-20261021/accessories.mp4)。已核对[首端](TabBarAccessories/duo-inner-final-start.png)、[滚动途中](TabBarAccessories/duo-inner-final-middle.png)、[尾端](TabBarAccessories/duo-inner-final-end.png)，两端附件保持固定、渐隐位于标签视口边缘；[浅色频道菜单](TabBarAccessories/duo-inner-final-channels.png)和[RTL 深色频道菜单](TabBarAccessories/duo-inner-final-rtl-channels.png)均显示“频道 3：通知”，[选择后的深色界面](TabBarAccessories/duo-inner-final-rtl-selected.png)导航标题与内容可辨识。录制期间没有额外注入触摸，操作由同次 XCTest 完成；自动化可点击性与名称检查不替代完整 VoiceOver 人工验收。

最终独立 Package 的 Debug 全量库回归 **185 通过、0 失败、0 跳过**，`.xcresult` 与终态 `TEST SUCCEEDED` 一致，`sourceChangedSinceRun` 为空，见[摘要](Results/duo-inner-library-final-20261021/summary.json)、[结果包](Results/duo-inner-library-final-20261021/Result.xcresult)和[命令日志](Results/duo-inner-library-final-20261021/xcodebuild.log)。执行参数为 `SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SP_SIMULATOR_ID=049C3F56-87CB-4D53-8B0A-7537DDE19222 SP_SCOPE=library SP_RUN_NAME=duo-inner-library-final-20261021 Scripts/validate.sh test`；官方 MCP 当前 Demo scheme 无法承担独立 Package 测试，因此回退到仓库脚本，随后用同一工具链执行 `Scripts/summarize_validation.py`。

验收边界：**失败**仍包括前述 14 项实际旋转断言，不能从内屏的横向形状推定旋转成功；**被环境阻塞**的是电脑插件对 Device Hub 的读取及由此缺失的控件操作验证，内屏图像采集阻塞已解除；**未执行**包括最终修复后双屏完整 UI 重跑、双屏成功旋转矩阵、iPad 窗口矩阵、iOS 15 实际运行及完整 VoiceOver 人工检查。本轮完成了内屏修复前全量、修复后聚焦与当前源码全量库回归，尚未达到双屏全部 UI／UX 验收通过。

最终 Release Demo **构建通过**，终态日志为 `BUILD SUCCEEDED`，`sourceChangedSinceRun` 为空；见[摘要](Results/duo-inner-demo-release-20261021/summary.json)和[日志](Results/duo-inner-demo-release-20261021/xcodebuild.log)。使用上述工具链与 Duo UUID，指定 `SP_SCOPE=demo SP_CONFIGURATION=Release SP_RUN_NAME=duo-inner-demo-release-20261021 Scripts/validate.sh build`。既有 SwiftFormat Build Phase 正常完成，报告 `0/40 files formatted, 2 files skipped`，没有引入额外源码改动；构建保留了未依赖 AppIntents.framework 因而跳过元数据提取的工具提示。该结果包仅构建、测试数为 0，测试摘要的 `unknown` 不作运行通过解释。最终 UI 聚焦、录屏复测、全量库测试及 Release 构建均再次核对与当前源码一致，`git diff --check` 通过；未提交或推送。

## 2026-10-20：iPhone Duo 外屏 UI 输入与方向断言修复

延续下节同一 Xcode 27.1／iOS 27.1／Duo Closed 环境，保留原始失败结果。此次修改集中在 Demo 诊断及 UI 测试，没有修改框架实现或公开 API：

- **Section 可见区域：** 实测 collection 为 `(0, 264, 466, 414)`，而 `UIToolbar` 的无障碍 frame 为整个窗口 `(0, 0, 466, 678)`。旧测试用工具栏 `minY == 0` 排除了全部可见卡片。改为依据真实工具栏状态内容避让，保持 Section 输入、边界交接和偏移恢复断言。
- **异步页触摸：** 原始事件起点 `(233, 571)` 落在覆盖滚动视图的替换按钮区域。新测试从按钮上方的可见滚动区域发起真实拖动，验证 Header 完全折叠，并再次替换滚动视图。
- **外屏右侧系统区域：** 纵向滚动后返回原页的拖动原先从窗口宽度 85% 处开始，进入横向 Safe Area 外侧。Demo 的回归状态值增加窗口 `safeLeft`／`safeRight`，测试据此限制输入位置；仍要求拖过半页、实际触摸轨迹与计划距离一致、分页位移等于一页，并检查返回后位置恢复。
- **实际旋转断言：** 标签外观页复用 `RegressionStatusLabel`；仅 `--window-regression` 下暴露场景实际方向和横向安全区域。附件 UI 测试等待真实方向并在失败信息中输出窗口 frame，截图改用 `app.screenshot()`，裁切附件点击使用窗口坐标及可见交集。

| 阶段 | 结果 | 证据 |
| --- | --- | --- |
| 增加诊断及方向断言后的复现 | 0 通过、3 失败；Section、异步拖动和实际未旋转均复现 | [摘要](Results/duo-closed-diagnostic-20261020/summary.json) |
| 首轮输入修复 | 5 通过、2 失败；剩余为纵向滚动后返回原页、实际未旋转 | [摘要](Results/duo-closed-input-fixed-20261020/summary.json) |
| 横向 Safe Area 输入修复聚焦复测 | 1 通过、0 失败，包含双向切页和原位置恢复 | [摘要](Results/duo-closed-safe-input-20261020/summary.json) · [截图清单](Results/duo-closed-safe-input-20261020/attachments/manifest.json) |
| Release Demo | 构建通过；非 Release 运行验收 | [日志](Results/duo-ui-fixes-release-20261020/xcodebuild.log) |
| 外屏完整 UI 回归 | 26 通过、21 失败、7 跳过；54 项全部取得终态，7 项为 iPad 专属用例 | [摘要](Results/duo-closed-ui-regression-20261020/summary.json) · [结果包](Results/duo-closed-ui-regression-20261020/Result.xcresult) · [截图清单](Results/duo-closed-ui-regression-20261020/all-attachments/manifest.json) |
| Apple 官方 MCP 修复聚焦复测 | 6 通过、2 失败、0 跳过；两项失败均已到实际横屏方向断言，非先前的输入或安全区域断言 | [摘要](Results/duo-official-ui-focused-20261020/summary.json) · [结果包](Results/duo-official-ui-focused-20261020/Result.xcresult) · [截图清单](Results/duo-official-ui-focused-20261020/attachments/manifest.json) |
| Apple 官方 MCP 外屏完整复测 | 33 通过、14 失败、7 跳过、0 未运行；14 项失败全部发生在实际横屏方向断言 | [摘要](Results/duo-official-ui-full-20261020/summary.json) · [结果包](Results/duo-official-ui-full-20261020/Result.xcresult) · [控制台日志](Results/duo-official-ui-full-20261020/console.log) |

诊断首轮由既有 Demo Build Phase 对两处新增长日志语句排版，`sourceChangedSinceRun` 列出 `CompositionalGestureTests.swift` 和 `StickyPagerDemoUITests.swift`，该轮只作复现证据。后续先用 SwiftFormat 0.64.0 格式化修改文件，再启动验证；首轮输入修复、Safe Area 聚焦复测和 Release 构建的摘要均为空变化列表。

方向断言实际捕捉到目标 `UIInterfaceOrientation` 为 `3`、实际为 `1`、窗口仍为 `466 × 678 pt`。构建产物已声明支持左右横屏，未通过修改应用方向契约或移除断言绕过失败；该阶段的旋转验收仍为失败。

完整回归在修改后续测试之前生成摘要，`sourceChangedSinceRun` 为空；这是该阶段的完整失败结果，不能作为后续修复通过的证据。失败分布为：4 项用序号误点顶部按钮而未返回外观入口，5 项错误假设竖屏没有横向 Safe Area，3 项将右侧系统标签按钮误判为底栏，3 项拖动未达到 Header 折叠状态，1 项直接查找尚未滚入菜单的“重排页面”，5 项实际方向断言未满足。系统标签按钮实际 frame 为 `(396, 544, 44, 108)`，内容右边界为 `382`；侧边按钮不应强制内容从其上方结束。混合页面失败事件为 `(233, 595) → (233, 395)`，后续改用浮动状态控件上方的可见列表区域；Header 两项则避开窗口宽度 85% 处的右侧系统区域。

额外只读核查确认本机 `/Applications/Xcode.app/Contents/Developer/usr/bin/mcpbridge` 可连接 Apple 官方 `xcode-tools`（版本 `25320`）；返回的 `DeviceInteractionSynthesize` 定义包含方向操作。工具清单保存在 `Results/duo-environment-20261020/official-mcp-tools.json`。读取清单没有修改 MCP 配置或设备姿态，不能作为旋转或内外屏切换通过的证据。

用户授权配置后，检查发现 `~/.codex/config.toml` 已有启用的 `mcp_servers.xcode`，命令为 `/usr/bin/xcrun`、参数为 `["mcpbridge"]`，故未重复添加或覆盖。全局工具链当前指向 Xcode 27.1。指定前台 Xcode 进程的临时连接中，官方 `XcodeListWindows`、`XcodeListSchemes`、`XcodeListRunDestinations` 和 `GetTestList` 均返回成功，确认当前工程为 `StickyPagerDemo.xcodeproj`、scheme 为 `StickyPagerDemo`、运行目标为 iPhone Duo／iOS 27.1，并识别全部 54 个 UI 测试。本轮官方测试调用使用该前台工程；完整 UI 回归期间未通过 MCP 并发操作设备。

另按持久配置的原始命令、不指定进程重新连接，桥接转向后台 `XcodeService`，首次读取因代理尚未批准工程访问而返回错误。按其指示调用 `XcodeOpenWorkspace` 打开同一 Demo 工程后，`XcodeListWorkspaces` 成功返回后台及前台两个工程标识，保留[首次错误](Results/duo-environment-20261020/official-mcp-configured-connection.json)、[打开结果](Results/duo-environment-20261020/official-mcp-open-workspace.json)及[读取结果](Results/duo-environment-20261020/official-mcp-configured-workspaces.json)。后台工程初始目标为 iPhone 18 Pro，与前台 Duo 不同；不能假设两者共享运行目标。此项证明当前验证客户端的后台连接可用，不代表其他代理身份已预先获批，也不代表 Codex 当前会话已自动加载新增工具。

为支持耗时超过默认 60 秒的构建与完整 UI 测试，在既有 `mcp_servers.xcode` 中补充 `tool_timeout_sec = 3600`；`codex mcp get xcode --json` 已确认启用状态、原连接命令和新超时值。此项是用户授权的本机配置变更，不属于仓库源码，也没有将临时 Xcode PID 写入持久配置。

后台工程随后通过 `XcodeListRunDestinations` 确认 iPhone Duo／iOS 27.1 为有效目标，并调用 `XcodeSwitchRunDestination` 选中该目标，[返回状态](Results/duo-environment-20261020/official-mcp-configured-duo-target.json)确认 scheme 仍为 StickyPagerDemo；没有从后台另行启动测试。

完整回归结束后，以独占设备会话执行 Apple 官方 MCP 方向对照。`orientation landscapeLeft`／`landscapeRight` 的 hierarchy 分别确认设备为 Landscape Left／Landscape Right，但 App UI orientation 始终为 Portrait、窗口始终 `466 × 678 pt`，截图也保持竖向；恢复 portrait 后设备与 App 均为 Portrait，并成功结束会话。因此“设备方向命令通过”和“App 横屏验收失败”分别记录，未修改方向断言来消除失败。证据见 [结构化记录](Results/duo-official-device-20261020/observations.json)、[左横向层级](Results/duo-official-device-20261020/landscapeLeft-reactivate-hierarchy.txt)、[右横向层级](Results/duo-official-device-20261020/landscapeRight-hierarchy.txt)及[右横向截图](Results/duo-official-device-20261020/landscapeRight-screenshot.png)。

该独占会话的 `DeviceInteractionInstallAndRun` 返回 `Launch session has not been found`，随后通过 `activationBundleId` 激活已安装 App 完成设备验证；[原始错误](Results/duo-official-device-20261020/install-run.json)保留。首次采集后的 App PID 消失、重新激活时 PID 改变，原因未确定，不据此判断框架崩溃，也不把 MCP 的 `applicationState=NotRun` 等同于屏幕上没有 App。官方菜单验证在实际父裁切区域 `(132, 24, 250, 520)` 内执行一次上滑，成功显示“重排页面”；内部 CollectionView 报告高度 `678`，不能直接作为菜单可见高度。前后[截图](Results/duo-official-device-20261020/pages-menu-scrolled-screenshot.png)与[层级](Results/duo-official-device-20261020/pages-menu-scrolled-hierarchy.txt)保留。再次读取 Device Hub 仍遇到电脑插件 `-10005: timeoutReached`，官方工具未提供折叠姿态命令，内外屏切换仍未完成。

后续聚焦复测实际调用官方 `RunSomeTests`，8 项均有终态，`sourceChangedSinceRun` 为空；请求参数、原始响应、控制台日志、Xcode 测试摘要与复制的结果包均在同一运行目录。通过项覆盖 Header 拖动、普通页恢复、自定义外观入口、标签间距与分页、重排／删除／清空菜单、系统侧边标签栏下的短内容和第 80 行可见性。已检查系统容器展开和列表末项截图，内容未被侧边按钮遮挡。混合页面已通过原先失败的折叠断言，`testSafeAreaTabsLTR` 已通过竖屏安全区域与滚动检查；两者随后均因窗口仍为 `466 × 678 pt`、未达到横屏方向而失败，整项仍记为失败。Xcode 导航器显示的“54 Tests”是 scheme 总目录，不代表这次聚焦调用运行了 54 项。

随后通过官方 `RunAllTests` 完成全部 54 项，MCP 返回计数与 `xcresulttool get test-results summary` 一致，`sourceChangedSinceRun` 为空。33 项通过覆盖全部 5 项嵌套横向滚动用例、页面操作菜单、异步滚动视图替换、Header 拖动、宽度分配及溢出、默认／自定义标签交互、系统容器末行，以及附件固定、RTL 深色和栏高恢复。14 项失败均在等待实际横屏时发生：10 项记录实际方向仍为 `1`，另 4 项未获取到状态值，但窗口仍为 `466 × 678 pt`；后 4 项不单凭缺失状态值判断方向，结合此前官方设备层级对照保留为旋转验收失败。此前的触摸区域、菜单可见性及侧栏几何断言没有再次失败。7 项跳过均为 iPad 专属分屏／窗口用例。本轮整体仍为失败，不能称为完整验收通过。

完整复测结束后重置电脑插件会话，再读取 `com.apple.dt.Devices` 仍返回 `-10005: timeoutReached`；同一插件读取 `/Applications/Xcode.app` 成功，并显示 54 项、14 项失败。因此当前阻塞具体位于 Device Hub 窗口读取，不能笼统认为全部电脑操作不可用；内外屏控件尚未被成功操作。

随后用电脑插件经 Xcode 的“Open Developer Tool → Device Hub”重新打开，再以完整应用路径读取窗口，仍得到同样超时。官方设备诊断另行检查系统控制中心：成功打开后内容为空，仅有“添加控制”“电源”，没有可确认的方向锁控件，故锁定状态记为**未能确定**，没有修改设置。左右方向再次验证设备方向变化而 App 仍为 Portrait、`466 × 678 pt`；本次 App PID 全程不变，没有观察到意外退出。已恢复 Portrait，`EndSession` 返回 `Session stopped`；见[诊断摘要](Results/duo-official-orientation-diagnostic-20261020/observations.json)和[控制中心截图](Results/duo-official-orientation-diagnostic-20261020/control-center-screenshot.png)。内屏回归仍等待实际切换条件，不以模拟窗口尺寸替代。

完整复测截图已从同次 `.xcresult` 导出：[清单](Results/duo-official-ui-full-20261020/all-attachments/manifest.json)。逐张检查[首端](TabBarAccessories/duo-outer-full-start.png)、[中间](TabBarAccessories/duo-outer-full-middle.png)、[尾端](TabBarAccessories/duo-outer-full-end.png)：两端附件位置固定，中间标签滚动，首端仅末侧存在渐隐，中间两侧渐隐，尾端仅首侧渐隐；右侧系统区域未覆盖附件。以上属于外屏竖向视觉证据，不代表旋转通过。

保留的代表截图：[外屏系统容器展开](TabBarAccessories/duo-outer-system-expanded.png)、[外屏列表末项与侧边按钮](TabBarAccessories/duo-outer-system-last-row.png)、[菜单滚动后显示页面操作](TabBarAccessories/duo-outer-menu-scrolled.png)、[设备横向但 App 仍竖向](TabBarAccessories/duo-outer-device-landscape-app-portrait.png)。最后一张属于失败证据，设备方向需结合对应 hierarchy 读取，不能仅凭截图推断。

源码关联复核：与外屏 183 项库测试运行快照相比，当前差异仅在 Demo 诊断视图及四个 UI 测试文件，`Sources/`、`Tests/` 和 `Package.swift` 未变化；与 `duo-ui-fixes-release-20261020` 的 Release 构建快照相比，仅 `StickyPagerDemoUITests.swift` 和 `SystemContainerTests.swift` 后续变化。因此保留这些阶段结果的适用范围，不把历史摘要的空变化列表解释成当前全仓源码均与当时一致。

## 2026-10-20：iPhone Duo 外屏首轮阶段验证（尚未完成）

环境为 Xcode 27.1（27A9275）／Swift 6.4、iPhone Duo／iOS 27.1（24A94232），设备 UUID 为 `049C3F56-87CB-4D53-8B0A-7537DDE19222`。用户确认 Device Hub 当前为外屏／Closed，确认截图保存在 `Results/duo-environment-20261020/user-confirmed-closed.png`。本节不能作为内外屏与旋转完整验收。

| 范围 | 结果 | 证据 |
| --- | --- | --- |
| 标签、自动内容、指示器、附件聚焦库测试 | 通过：67 项，0 失败、0 跳过 | [摘要](Results/duo-tab-focused-20261020/summary.json) |
| 外屏完整库测试 | 通过：183 项，0 失败、0 跳过 | [摘要](Results/duo-closed-library-full-20261020/summary.json) · [结果](Results/duo-closed-library-full-20261020/Result.xcresult) |
| 外屏附件专项 UI 测试 | XCTest 通过：4 项；旋转证据不足，见下文 | [摘要](Results/duo-closed-ui-focused-20261020/summary.json) · [截图清单](Results/duo-closed-ui-focused-20261020/attachments/manifest.json) |
| 外屏完整 Demo UI 套件尝试 | 未完成：1 项通过、6 项断言失败、1 项取消；其余未执行 | [摘要](Results/duo-closed-ui-full-20261020/summary.json) · [结果](Results/duo-closed-ui-full-20261020/Result.xcresult) |
| Release Demo | 构建通过，终态日志为 `BUILD SUCCEEDED`；未执行 Release 测试 | [日志](Results/duo-release-build-20261020/xcodebuild.log) |
| 内屏、真实内外屏切换及双屏旋转矩阵 | 被环境阻塞，尚未完成 | [环境记录](Results/duo-environment-20261020/) |

上述运行已读取终态结果，核对时 `sourceChangedSinceRun` 均为空。执行使用 `SP_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`、上述 `SP_SIMULATOR_ID` 和表中目录名对应的 `SP_RUN_NAME`，通过 `Scripts/validate.sh` 分别运行 `SP_SCOPE=library` 的 `test`、`SP_SCOPE=demo` 的 `test` 及 `SP_CONFIGURATION=Release` 的 `build`；完整命令保留在各运行的 `xcodebuild.log`。

附件专项截图已导出；首端画面可见固定附件与标签区域渐隐。不过“横屏辅助字号”截图仍呈竖向布局，该用例只发送了方向请求，没有断言实际界面方向，不能据其通过结果宣称旋转通过。需要补充实际方向验证后重测。

完整 UI 尝试中，5 个 `CompositionalGestureTests` 在寻找可见 Section 的 `XCTUnwrap` 处失败；失败截图中仍可看到横向卡片，需继续核对测试的可见区域及工具栏几何计算。`testAsyncDiscoveryAndReplacement` 等待 Header 完全折叠失败，实际进度为 `0.00`，原因尚未确定。随后为按用户指示通过电脑操作屏幕切换，向本轮 xcodebuild 发送 SIGINT 并保存结果；`testCollapsedTabBarStaysAtNavigationBarBottom` 因取消记为失败，因此 xcresult 的 7 个失败包含 6 个断言失败与 1 个取消，不能将取消归为框架缺陷。原始日志、截图、录屏及结果包均保留。

电脑控制能列出正在运行的 Device Hub，但使用 bundle ID、应用名及完整路径 `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` 读取窗口持续返回 `-10005: timeoutReached`；用户恢复前台及连接后仍复现。另一个可连接的 `Simulator` 实际属于 Xcode 26.6，点击其方向菜单后显示黑屏，不能作为当前 Xcode 27.1 Device Hub 的姿态切换证据。尚未验证成功的横竖屏、内外屏操作均不计为通过；没有通过修改屏幕尺寸来代替折叠切换。

## 2026-10-20：内容留白、固定附件及配套 UI／UX

本轮新增 `contentInsets`、`leadingAccessoryView`、`trailingAccessoryView` 和 `invalidateAccessoryLayout()`；默认零留白、无附件。水平留白随标签滚动，附件固定在横向 Safe Area 内，渐隐和指示器限制在剩余标签视口。附件使用 Auto Layout 压缩尺寸测量，空间不足按理想宽度比例裁切；建议栏高综合标签高度、上下留白及附件高度。公开接入、尺寸依据、刷新、所有权、RTL、窄窗口、点击和无障碍边界统一更新在 [README](../README.md#内容留白与固定附件)，内容代理及指示器注释同步更新。

Demo 的“标签外观 → 配置”与分页 Demo 的“页面”菜单新增“留白与附件”，支持对称／非对称留白、单端／双端附件、标题和高度变化、RTL。搜索展示本地反馈，更多频道菜单使用既有选择 API。启动参数、原有自定义内容和栏高／隐藏操作见 README；`--narrow-tabs` 是 240 pt 的独立栏夹具，与真实系统窗口缩放分别验证。

### 问题、修复和保留的失败证据

- 首轮 [环境日志](Results/accessory-focused-20261020-01/xcodebuild.log) 被沙盒下的 CoreSimulator 访问阻止，未取得有效测试结果；使用允许访问模拟器的执行环境后继续，没有把 0 项或 unknown 当作通过。
- [首轮附件测试](Results/accessory-focused-20261020-02/xcodebuild.log) 8 项中 1 项失败：无尺寸依据的 UIView fitting 使用了旧 bounds。加入优先级 1 的零尺寸测量依据，业务约束与固有尺寸优先；没有使用 frame 或 `sizeThatFits(_:)` 回退。[下一轮](Results/accessory-focused-20261020-03/xcodebuild.log) 50 项中 1 项失败来自测试误将自定义内容可用宽度 220 pt 预期为 110 pt，修正为实际宽度分配契约；其余自动内容、指示器与间距测试通过。
- [Demo 首次构建](Results/accessory-demo-build-20261020-01/xcodebuild.log) 因 Swift 6 对配置对象的重叠读写检查失败；先计算新标题再写回 `UIButton.Configuration` 后恢复。
- [RTL 初次布局探针](Results/accessory-rtl-initial-probe-20261020/xcodebuild.log) 复现尚未布局时同时配置留白、附件与选中项导致初始偏移为 0，RTL 逻辑首项在屏幕外。修复几何刷新过程中提前清空对齐请求的问题，保留真实零 frame 起始回归。
- [配置式按钮尺寸探针](Results/accessory-configured-button-probe-20261020/xcodebuild.log) 复现直接调用 UIButton 的 fitting 重写忽略外加最小高度。改为测量期间将附件四边临时连接普通 UIView 承载视图，由承载视图求解压缩尺寸，实际布局解除连接；44 → 80 → 44 pt 的库测试和真实菜单操作均纳入回归。
- [第一轮 UI](Results/accessory-ui-20261020-01/xcodebuild.log) 和 [聚焦复测](Results/accessory-ui-focused-20261020-02/xcodebuild.log) 保留了上述问题及测试夹具问题：分页第二项实际为“列表”；辅助字号与极窄横屏允许零标签视口，附件的理想 frame 可能大于裁切区域，XCTest 默认激活点不可用。夹具改为在附件承载区域与窗口交集内发送真实点击，以搜索弹窗验证命中，再旋转恢复并继续拖动，没有放宽到仅验证按钮存在。
- [首轮 iPad 窗口回归](Results/accessory-ui-ipad-final-20261020/xcodebuild.log) 中新增附件缩放用例失败于旧几何假设：将 Item 顶边等同栏顶边，忽略了 6 pt 上留白。更新公共夹具，分别断言栏顶、Item 上下内缩、页面紧接栏底；横向 Safe Area 由标签视口与两端承载区域的并集验证。保留原有无附件回归约束。
- `accessory-library-final-20261020-01`、`-02`、`-03` 和 `accessory-release-build-20261020-01`、`accessory-release-final-20261020` 是阶段结果；最后的完整回归和摘要见下表。历史失败、旧源码快照及结果包均保留。

### 最终验证

工具链为 Xcode 26.6 / Swift 6.3.3。Debug 库测试使用真实 `UIWindow`，覆盖输入归一化、滚动留白、Safe Area／RTL、附件测量／生命周期／裁切／恢复、候选测量无显示副作用、手动滚动／选择动画／分页进度、默认／自定义／回退内容、指示器、渐隐及容器高度与隐藏恢复。Demo 测试发送真实触摸，不以构建代替交互验收。

| 状态 | 范围 | 证据 |
| --- | --- | --- |
| 通过 | 附件及容器聚焦回归：13 通过、0 失败、0 跳过，iPhone 18 Pro Max / iOS 27.0 | [日志](Results/accessory-focused-20261020-05/xcodebuild.log)、[结果包](Results/accessory-focused-20261020-05/Result.xcresult) |
| 通过 | 最终完整库：183 通过、0 失败、0 跳过，iPhone 18 Pro Max / iOS 27.0；终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空 | [摘要](Results/accessory-library-final-20261020-04/summary.json)、[结果包](Results/accessory-library-final-20261020-04/Result.xcresult) |
| 通过 | Release Demo 构建（包含本地 Package）：终态 `BUILD SUCCEEDED`，`sourceChangedSinceRun` 为空；仅构建，摘要的测试字段为 unknown／0，不表示测试通过 | [日志](Results/accessory-release-final-20261020-02/xcodebuild.log)、[摘要](Results/accessory-release-final-20261020-02/summary.json)、[结果包](Results/accessory-release-final-20261020-02/Result.xcresult) |
| 通过 | iPhone 最终 UI：4 通过、0 失败、0 跳过，iOS 27.0；固定附件、搜索反馈、频道选择、首／中／尾、RTL 深色、辅助字号旋转、窄栏裁切、分页栏高增长与恢复；`sourceChangedSinceRun` 为空 | [摘要](Results/accessory-ui-iphone-final-20261020-02/summary.json)、[结果包](Results/accessory-ui-iphone-final-20261020-02/Result.xcresult) |
| 首轮失败，分项结果保留 | iPad Pro 11-inch (M5) / iOS 26.5：新增 UI 4 项、系统容器 RTL／旋转／恢复 1 项及嵌套横向 Section RTL 边界 1 项通过；窗口附件缩放 1 项失败，共 6 通过、1 失败、0 跳过 | [摘要](Results/accessory-ui-ipad-final-20261020/summary.json)、[结果包](Results/accessory-ui-ipad-final-20261020/Result.xcresult) |
| 通过 | iPad 窗口最终复测：带附件及默认无附件对照共 2 通过、0 失败、0 跳过；真实系统窗口缩放至 375 pt、连续缩放、Header 展开／部分折叠／吸顶、真实分页、恢复全屏及搜索点击；`sourceChangedSinceRun` 为空 | [摘要](Results/accessory-window-recovery-20261020/summary.json)、[结果包](Results/accessory-window-recovery-20261020/Result.xcresult) |
| 通过 | 本轮 13 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；Demo Build Phase 未产生范围外的格式修改 | 按工作区差异逐文件 lint；源码、Demo 菜单、测试预期和 README 已交叉核对 |

13 项聚焦及首轮 iPad 结果的 `sourceChangedSinceRun` 仅包含随后修正的 `StickyPagerDemoUITests.swift`，框架、Demo 及其他测试源码保持一致；聚焦内容已由最终 183 项库回归重新覆盖，窗口夹具用带附件和默认配置分别复测。没有把首轮 iPad 的整体失败改写为成功。最初环境阻塞已解除；本轮实际执行的最终复测没有失败或跳过项，未执行范围见下文。

执行命令如下；这些运行名已使用，复现时应换用新名字。`Scripts/validate.sh` 同时保存工具链、`source-hashes.json`、终态日志和 `.xcresult`。Debug 构建包含在对应 `test` 操作中；库与 Demo 独立执行。

```sh
export SP_DEVELOPER_DIR="/Applications/Xcode-26.6.app/Contents/Developer"

SP_SCOPE=library SP_SIMULATOR_ID=41AF9CED-9BBB-4B60-B563-73AFB035C2D4 SP_RUN_NAME=accessory-library-final-20261020-04 Scripts/validate.sh test
SP_SCOPE=demo SP_CONFIGURATION=Release SP_SIMULATOR_ID=41AF9CED-9BBB-4B60-B563-73AFB035C2D4 SP_RUN_NAME=accessory-release-final-20261020-02 Scripts/validate.sh build

SP_SCOPE=demo SP_SIMULATOR_ID=41AF9CED-9BBB-4B60-B563-73AFB035C2D4 SP_RUN_NAME=accessory-ui-iphone-final-20261020-02 Scripts/validate.sh test \
  -only-testing:StickyPagerDemoUITests/TabBarAccessoryUITests

SP_SCOPE=demo SP_SIMULATOR_ID=F4629C72-82B7-4FE3-BC0D-543A3A01D6C1 SP_RUN_NAME=accessory-ui-ipad-final-20261020 Scripts/validate.sh test \
  -only-testing:StickyPagerDemoUITests/TabBarAccessoryUITests \
  -only-testing:StickyPagerDemoUITests/StickyPagerDemoUITests/testSystemWindowResizeWithAccessories \
  -only-testing:StickyPagerDemoUITests/SystemContainerTests/testRTLPagingRotationAndSystemTabRestore \
  -only-testing:StickyPagerDemoUITests/CompositionalGestureTests/testSectionEdgesRTL

SP_SCOPE=demo SP_SIMULATOR_ID=F4629C72-82B7-4FE3-BC0D-543A3A01D6C1 SP_RUN_NAME=accessory-window-recovery-20261020 Scripts/validate.sh test \
  -only-testing:StickyPagerDemoUITests/StickyPagerDemoUITests/testSystemWindowResizeWithAccessories \
  -only-testing:StickyPagerDemoUITests/StickyPagerDemoUITests/testSystemWindowResizePreservesPinnedListAndPaging

DEVELOPER_DIR="$SP_DEVELOPER_DIR" python3 Scripts/summarize_validation.py Validation/Results/accessory-library-final-20261020-04
# 其余已结束的运行目录使用同一摘要命令；截图用同一 Xcode 的 xcresulttool export attachments 导出。
git diff --check
```

### 截图与验收边界

已从 [最终 iPhone 截图清单](Results/accessory-ui-iphone-final-20261020-02/Attachments/manifest.json) 导出并检查：[浅色首端](TabBarAccessories/iphone-start.png)、[滚动中间](TabBarAccessories/iphone-middle.png)、[尾端](TabBarAccessories/iphone-end.png)、[RTL 深色首端](TabBarAccessories/iphone-rtl-dark.png)、[辅助字号极窄横屏](TabBarAccessories/iphone-narrow-accessibility.png)、[附件撑高分页栏](TabBarAccessories/iphone-pager-height.png)。固定按钮在标签滚动前后位置一致，首尾对应侧渐隐消失，中段两侧渐隐，背景和分隔线连续；RTL 初始选中项可见。极窄横屏截图记录标签视口压缩为零的边界行为，不代表推荐的常规产品布局。

已查看首轮 iPad 中通过的外观用例截图：[LTR 首端](TabBarAccessories/ipad-start.png)、[RTL 深色首端](TabBarAccessories/ipad-rtl-dark.png)，原始出处见 [iPad 截图清单](Results/accessory-ui-ipad-final-20261020/Attachments/manifest.json)。该轮整体仍为失败，截图与其他通过的用例不替代窗口缩放的独立复测。

窗口复测另行导出并检查 [375 pt 浮动窗口](TabBarAccessories/ipad-small-window.png) 和 [恢复全屏](TabBarAccessories/ipad-fullscreen-restored.png)：两端按钮仍可见，标签及渐隐位于中间视口，页面根视图紧接整栏底部。完整的展开、部分折叠、再次吸顶和连续缩放截图见 [窗口复测清单](Results/accessory-window-recovery-20261020/Attachments/manifest.json)。

自动化检查覆盖按钮无障碍名称、可见区域的真实点击及菜单反馈；完整 VoiceOver 遍历顺序和朗读操作尚未人工验收。未执行完整 Demo UI 套件、真机、iOS 15 实际运行、Release 运行时测试、性能测量及所有设备／字号／方向的笛卡尔组合；部署目标保持 iOS 15 不等于已经在 iOS 15 实机验收。

最终完整库日志仍包含历史记录中已出现的 UIKit observation tracking feedback loop 诊断；本轮未专项解决，不将测试通过表述为“没有运行时诊断”。

## 2026-10-20：提交前全量审查与指示器边界修复

- **审查范围：** 全部 20 个改动文件，包括 4 个新增文件。核对指示器模式／布局／颜色及归档职责、默认与自定义内容几何、间距测量与布局、动画与分页更新、Demo、测试、README 和历史验证记录。工程文件的两处配置项顺序调整不改变构建配置。当前源码、Demo、测试和 README 无旧 API、历史归档字段、旧装饰视图标识及旧菜单文案残留。
- **发现并修复：未选中动画端点。** 程序化动画由未选中状态开始时，渲染路径使用当前选中索引替代 nil 来源，错误报告来源与目标相同。改为保留动画传入的 nil 端点，静止状态由调用方明确传入当前选择；公开注释和 README 明确 nil 表示无选中项。新增真实 UIWindow 回归检查 nil → Item 的起点／中间态及 Item → nil。
- **发现并修复：负尺寸自定义矩形。** CGRect 的 width／height 访问会标准化负尺寸，原检查因此接受了非法矩形。改为校验原始 size.width／size.height；新增回归分别验证几何代理和自定义内容区域的负宽／负高均回退到配置或整项。
- **测试覆盖补强：** 原间距安全区域夹具中标签栏未贴到窗口右边缘，右侧 Safe Area 断言可能仅检查零值。调整真实窗口宽度与标签栏一致，明确断言左 20 pt、右 30 pt，并保留 LTR／RTL、默认／自定义／回退内容、间距、居中和边缘渐隐检查。
- **修复前证据保留：** [复现摘要](Results/precommit-indicator-probes-20261020/summary.json) 为 1 通过、2 失败；两个新增缺陷用例分别复现 nil 来源变为 4、负宽矩形错误呈现，增强后的双侧安全区域用例通过。该轮源码快照对应修复前实现。
- **通过：修复后聚焦回归。** [聚焦摘要](Results/precommit-indicator-focused-20261020/summary.json)：指示器、间距、自动内容与模型套件共 59 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。
- **通过：最终源码完整库回归。** [库摘要](Results/precommit-library-final-20261020/summary.json) 和 [结果包](Results/precommit-library-final-20261020/Result.xcresult)：170 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：最终源码 Demo UI 回归。** [UI 摘要](Results/precommit-ui-final-20261020/summary.json) 和 [结果包](Results/precommit-ui-final-20261020/Result.xcresult)：9 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖自动高度、指示器预设／关闭／恢复与前景点击、分页完成／取消、自定义内容切换及按住拖动、RTL 大字号与四次方向布局、双向宽度策略、动态标签与禁用项分页、间距菜单与间隙命中。环境同上述库回归。已查看最终隐藏指示器、自定义渐变指示器、底部线条截图；导出文件见 [截图清单](Results/precommit-ui-final-20261020/attachments/manifest.json)。
- **通过：排版检查。** 全部 17 个改动 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。历史失败和各阶段结果均保留；源码未加入构建产物、测试结果包或临时文件。
- **已知诊断与未覆盖范围：** 库测试日志仍有此前已存在的 UIKit observation feedback loop 诊断，本轮未专项分析；测试通过不表示无运行时诊断。本轮未运行完整 Demo UI 套件、iPad 分屏／窗口缩放、真机、iOS 15 实际运行、Release、VoiceOver 操作或性能测试。

## 2026-10-20：清理指示器测试和接入文档中的历史字段

- **清理范围：** 删除 `testRemovedArchiveFieldsDoNotOverrideIndicatorConfiguration`，不再构造 `selectionStyle`、`selectionColor`、`isIndicatorHidden` 及其历史归档键，也不验证历史字段被忽略的行为。README 删除旧 API 迁移说明，统一描述当前模式、颜色和布局配置。搜索源码、Demo、测试、当前 README 及 Validation 之外的仓库文本，旧 API 名称和旧测试名称均无匹配；本文件中的历史记录与既有结果包保留。
- **当前契约覆盖：** 新增 `testMissingIndicatorArchiveConfigurationUsesCurrentStyleDefaults`，仅移除当前归档中的 `SP.indicatorColor`、`SP.indicatorLayout`，验证解码为 nil、应用 Appearance 保持 `.none`、切回线条／胶囊后使用默认颜色和几何。该用例覆盖字段缺失，与已有 nil 值归档用例不同；现有测试继续覆盖显式颜色与布局复制、归档往返、样式切换、nil 恢复和 none 行为。生产代码与归档职责未改变，`indicatorStyle` 仍由宿主恢复。
- **通过：最终源码聚焦回归。** [摘要](Results/indicator-current-contract-cleanup-20261020/summary.json) 和 [结果包](Results/indicator-current-contract-cleanup-20261020/Result.xcresult)：`SPTabBarIndicatorTests`、`SPTabBarModelTests` 共 38 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：排版与差异检查。** 本轮修改的 1 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；保留已有工作区修改，未提交或推送。
- **未执行：** 本轮仅调整测试及文档，未重跑完整库、Demo 构建或 UI 测试，以及其他设备、系统版本、Release、VoiceOver 和性能验证。此前验证仍对应各自源码快照。

## 2026-10-20：SPTabBar Item 间距

- **API 与布局：** 新增 `SPTabBar.itemSpacing: CGFloat`，默认 0，表示相邻 Item 布局区域之间的固定水平间距；首尾不加间距，不计入内容理想尺寸或 `minimumItemWidth`，与左右 Safe Area 独立。负数和非有限值归零，上限 1,000,000 pt。总间距先从可分配宽度中扣除，溢出时计入滚动内容宽度；自动内容测量和 Collection View 共用同一宽度分配函数。
- **动态更新：** 测量快照记录间距，保证 Item 宽度不变但间距变化时仍识别几何变化；相同归一化值不刷新。沿用内容布局更新策略，保留 Item 身份、选择及回调语义，手动偏移限制到新范围，程序动画落到当前选中项，分页保持进度并重算端点。Demo 的“页面”和“标签外观 → 配置”新增“标签间距”菜单，提供 0、8、16、24 pt。
- **新增回归：** 6 项真实 UIWindow 库测试覆盖默认值与非法输入、空列表／单项、宽度分配和溢出、间隙命中、默认／自定义／回退内容、RTL、Safe Area、居中与渐隐、分页指示器插值、选择身份与回调、手动滚动及范围收缩、无效赋值保持动画、`.none` 动画、自动内容实际分配宽度与大字号高度，以及候选宽度测量不污染当前布局。新增 1 项 Demo UI 用例验证间距菜单、实际 frame 间隔、间隙点击、标签选择及页面滑动。
- **首轮失败保留：** [首轮聚焦摘要](Results/item-spacing-focused-20261020/summary.json) 为 57 通过、1 失败。新增自动内容测试在直接覆盖 trait 后立即测量，出现栏高 143 pt 与显示内容所需 1176 pt 不一致。夹具改用既有的真实子控制器 trait 覆盖方式，完成布局后刷新，并增加测量环境字号断言；未为该失败修改生产代码。首轮摘要保留该测试文件的源码差异。
- **通过：聚焦复测。** [复测摘要](Results/item-spacing-focused-recovery-20261020/summary.json)：58 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。
- **通过：最终源码完整库回归。** [库摘要](Results/item-spacing-library-final-20261020/summary.json) 和 [结果包](Results/item-spacing-library-final-20261020/Result.xcresult)：168 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。日志仍有 UIKit observation feedback loop 诊断，前一轮完整库日志中也存在；本轮未专项分析该诊断，不以测试通过推定无此运行时诊断。
- **通过：最终源码 Demo UI 回归。** [UI 摘要](Results/item-spacing-ui-final-20261020/summary.json) 和 [结果包](Results/item-spacing-ui-final-20261020/Result.xcresult)：2 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。包含新增间距交互，以及既有自定义指示器分页完成／取消用例；环境同上述库回归。
- **通过：排版与差异检查。** 本轮 7 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过。README 已补充 API、布局公式、动态行为及 Demo 入口；保留此前指示器重构和其他已有修改，未提交或推送。
- **未执行：** 完整 Demo UI 套件、iPad 分屏／窗口缩放、真机、iOS 15 实际运行、Release、VoiceOver 操作及性能测量。

## 2026-10-20：指示器动画解耦、起始状态修复与命名统一

- **修复：** 标签栏滚动动画不再要求指示器两端 frame 非空；`.none` 或零尺寸指示器仍按同一进度滚动，连续选择从当前偏移接续。指示器不能插值时直接采用目标几何，不从零 frame 生长。选择提交期间暂缓指示器更新，待外观、几何及动画状态准备完成后发送 `progress = 0` 的起始帧，避免提前向自定义视图发送目标完成态。
- **命名：** 装饰视图标识改为 `sp.tabBar.indicator`，同步库测试定位；Demo 使用“隐藏指示器”“切换指示器样式”，同步 UI 测试文案；README 统一指示器术语。移除名称仅描述颜色、实际执行完整渲染的 `updateIndicatorColor()` 包装，直接调用 `renderIndicator()`。选择行为本身的 `selectedIndex`、`SelectionAnimation` 等名称保持其原有职责。
- **修复前证据：** [审查首轮](Results/indicator-review-probes-20261020/summary.json) 0 通过、3 失败，其中对照用例因 0.01 pt 容差小于设备像素舍入误差而失败；改为设备单像素容差后的 [审查复测](Results/indicator-review-probes-pixel-20261020/summary.json) 1 通过、2 失败，确认线条模式滚动对照正常，none 直接跳到终点及自定义指示器提前收到完成态均可复现。两轮临时测试已撤除，源码差异仅为撤除的探针文件，夹具副本和失败日志保留在各自结果目录。
- **正式回归：** 新增 2 项真实 UIWindow 测试。覆盖 LTR／RTL 下线条、none 和零尺寸自定义指示器的起点／中间偏移／终点、连续选择和非动画恢复；记录自定义视图完整回调序列，检查初次动画与中途改选均从正确索引、当前 frame、零进度开始，非动画选择只发送静止态。
- **通过：聚焦回归。** [聚焦摘要](Results/indicator-animation-focused-20261020/summary.json)：58 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。
- **通过：最终源码完整库回归。** [库摘要](Results/indicator-animation-library-final-20261020/summary.json) 和 [结果包](Results/indicator-animation-library-final-20261020/Result.xcresult)：162 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：最终源码 Demo UI 回归。** [UI 摘要](Results/indicator-animation-ui-final-20261020/summary.json) 和 [结果包](Results/indicator-animation-ui-final-20261020/Result.xcresult)：3 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖指示器预设／关闭／恢复、前景命中、自定义内容与横屏点击、实际分页完成与取消，以及动态标签、禁用项分页和“切换指示器样式”菜单；环境同上述库回归。
- **通过：排版与差异检查。** 本次涉及的 15 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；生产源码和 Demo 无旧 API、历史字段读取、旧装饰视图标识或旧菜单文案残留。未提交或推送。
- **未执行：** 完整 Demo UI 套件、iPad 分屏／窗口缩放、真机、iOS 15 实际运行、Release、VoiceOver 操作及性能测量。

## 2026-10-20：删除指示器历史归档兼容逻辑

- **当前行为：** 删除 `SP.selectionStyle`、`SP.selectionColor` 的读取与迁移分支；生产源码不再引用旧样式、颜色或隐藏字段。Appearance 指示器归档只读写 `SP.indicatorColor`、`SP.indicatorLayout`，缺少新字段时保持 nil，采用当前样式默认值。`indicatorStyle` 仍由运行中的 `SPTabBar` 管理，宿主负责恢复。
- **测试调整：** 移除旧字段迁移成功的测试，将历史字段相关测试合并为“不影响当前配置”的回归：仅含旧字段时不恢复旧配置，同时含新旧字段时只采用新字段，旧隐藏字段不能改变 `indicatorStyle`。保留当前配置的复制、归档往返及非有限值处理测试。
- **通过：最终源码聚焦测试。** [聚焦摘要](Results/indicator-current-archive-focused-20261020/summary.json) 和 [结果包](Results/indicator-current-archive-focused-20261020/Result.xcresult)：`SPTabBarModelTests`、`SPTabBarIndicatorTests` 共 36 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：排版与差异检查。** 本轮修改的 2 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过，README 已同步。保留已有工作区修改，未提交或推送。
- **未执行：** 本轮未重跑完整库、Demo 构建和 UI 测试，以及其他设备、系统版本、Release、VoiceOver 和性能验证。下方兼容行为及结果为历史记录，不代表当前实现。

## 2026-10-20：指示器颜色统一使用 indicatorColor

- **API 收敛：** 删除 `SPTabBarAppearance.selectionColor`，不保留兼容属性；复制、测试调用和新归档统一使用 `indicatorColor`。新归档写入 `SP.indicatorColor`；解码仍可读取历史数据字段 `SP.selectionColor`，不将其暴露为源码 API。显式颜色和 nil 默认颜色语义保持不变。
- **通过：最终源码聚焦测试。** [聚焦摘要](Results/indicator-color-api-focused-20261020/summary.json) 和 [结果包](Results/indicator-color-api-focused-20261020/Result.xcresult)：`SPTabBarModelTests`、`SPTabBarIndicatorTests` 共 38 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖颜色实时刷新、复制／新归档中的显式颜色与 nil、历史颜色字段读取及既有指示器行为。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：排版与差异检查。** 本轮修改的 3 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；README 已同步，未提交或推送。
- **未执行：** 本轮未重跑完整库、Demo 构建和 UI 测试，以及其他设备、系统版本、Release、VoiceOver 和性能验证；此前结果保留为对应源码的历史证据。

## 2026-10-20：指示器显隐统一由 indicatorStyle 控制

- **API 收敛：** 删除 `SPTabBarAppearance.isIndicatorHidden`，不保留兼容入口；同时删除复制、归档读写和渲染中的隐藏覆盖。通过 `SPTabBar.indicatorStyle = .none` 关闭，切回 `.capsule` / `.underline` / `.custom` 恢复。Item 外观只能覆盖布局和颜色等配置，不能改变标签栏的指示器模式。
- **归档行为：** 历史布局和颜色继续迁移；旧隐藏字段及旧样式中的隐藏语义不再决定是否显示，宿主统一恢复 `indicatorStyle`。新增旧隐藏字段回归，确认新归档没有该字段、读取旧字段不会隐藏、默认布局／颜色仍为 nil，修改 Item 外观不会覆盖 `.none`。
- **通过：最终源码聚焦库测试。** [聚焦摘要](Results/indicator-visibility-focused-20261020/summary.json) 和 [结果包](Results/indicator-visibility-focused-20261020/Result.xcresult)：`SPTabBarIndicatorTests`、`SPTabBarModelTests`、`SPTabBarTests` 共 57 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：最终源码 Demo UI 测试。** [UI 摘要](Results/indicator-visibility-ui-20261020/summary.json) 和 [结果包](Results/indicator-visibility-ui-20261020/Result.xcresult)：1 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空；覆盖各模式切换、关闭后点击、恢复胶囊、自定义前景命中，以及自定义内容和横屏点击，环境同上述库测试。
- **通过：排版与差异检查。** 本轮修改的 7 个 Swift 文件通过 SwiftFormat 0.64.0 lint，`git diff --check` 通过；保留已有工作区修改，未提交或推送。
- **未执行：** 本轮未重跑完整库及完整 Demo UI 套件、独立分页 UI 用例、iPad 分屏、真机、iOS 15 实际运行、Release、VoiceOver 和性能测量。下方历史条目中的结果分别对应当时源码，不能替代本轮最终源码验证。

## 2026-10-20：恢复内置指示器样式并明确 none 语义

- **最终 API：** `SPTabBar.IndicatorStyle` 为 `.capsule` / `.underline` / `.custom` / `.none`，默认 `.capsule`，替代下节阶段设计中的 `.default` / `.custom`。胶囊与线条直接解析各自默认布局和颜色；Appearance 的 `indicatorLayout`、`indicatorColor` 默认 nil，显式覆盖在样式切换时保留，设回 nil 恢复当前样式预设。`SelectionStyle` / `selectionStyle` 仍不提供兼容入口。
- **none 行为：** 表示不需要指示器，清空并隐藏指示器 frame，跳过几何解析和渲染，不调用自定义几何代理或视图更新；标签选择、文字状态和分页继续工作。切回其他模式时，按当前选择或分页进度恢复。自定义对象与外观配置保留。
- **新增验证：** 4 项真实 UIWindow 测试覆盖内置样式默认几何与颜色、覆盖配置跨模式保留与 nil 恢复、none 期间的选择／分页及恢复、自定义回调停用，以及未指定配置的复制与安全归档。Demo UI 用例加入隐藏指示器和恢复胶囊操作。
- **阶段通过：** [样式聚焦摘要](Results/indicator-styles-focused-20261020/summary.json) 82 通过、0 失败、0 跳过。随后补充 none 渲染早退及零 frame 断言，该阶段的 `sourceChangedSinceRun` 如实保留两个文件差异。
- **通过：最终源码完整库回归。** [库摘要](Results/indicator-styles-library-final-20261020/summary.json) 和 [结果包](Results/indicator-styles-library-final-20261020/Result.xcresult)：160 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。环境为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：最终源码 Demo UI 回归。** [UI 摘要](Results/indicator-styles-ui-final-20261020/summary.json) 和 [结果包](Results/indicator-styles-ui-final-20261020/Result.xcresult)：2 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空；覆盖预设切换、隐藏后继续点击、恢复胶囊、自定义内容、横屏点击，以及真实分页完成和取消。已查看导出的隐藏、恢复胶囊和底部线条截图，确认选中文字保持、指示器随模式消失或恢复；见 [截图清单](Results/indicator-styles-ui-final-20261020/attachments/manifest.json)。环境同上述库回归。
- **通过：排版与差异检查。** SwiftFormat 0.64.0 对本次涉及的 15 个 Swift 文件 lint 为 `0/15 files require formatting`，`git diff --check` 通过。保留已有工作区修改，未提交或推送。
- **未执行：** 完整 Demo UI 套件、iPad 分屏／窗口缩放、真机、iOS 15 实际运行、Release、VoiceOver 操作及性能测量。

## 2026-10-20：指示器模式、自由布局与自定义视图（阶段设计）

- **API 与职责：** 按接入要求移除 `SelectionStyle` / `selectionStyle`，不保留类型或属性别名。`SPTabBar.IndicatorStyle` 参照 `ContentStyle`，使用 `.default` / `.custom` 两种独立模式。Appearance 持有 `SPTabBarIndicatorLayout` 值配置、颜色与隐藏状态；胶囊和下划线是布局预设。自定义模式启用弱几何代理与强持有的装饰视图，缺失部分分别回退，切回默认模式保留配置并停止调用自定义扩展。
- **几何与生命周期：** 支持标签／实际内容参考区域、逻辑水平对齐、垂直对齐、固定或跟随宽高、正负内缩、偏移、圆角及前后层级。默认图文从独立布局副本解析，屏幕外项也可用；自定义内容可以声明局部区域。所有几何使用滚动内容坐标；指示器不参与测量、不拦截触摸或无障碍，最终裁剪到安全视口。任意 frame 的 x/y/width/height 统一插值；保持分页进度、取消恢复与连续点击接续。复制和安全归档仅包含配置，不包含代理或视图；历史归档可读取。
- **新增验证：** 13 项真实 UIWindow 库测试覆盖预设与测量隔离、默认图文实际区域、屏幕外标签、LTR／RTL、Safe Area 与滚动坐标、自定义区域／回退、Dynamic Type、Item 外观、自由 frame 四分量插值、取消／旋转尺寸更新、模式独立、弱代理与视图释放、颜色刷新保留进度、清空项后渲染索引、复制／新旧归档、非有限值。新增 2 项 Demo UI 测试覆盖六种效果、前景命中、真实分页完成与取消、自定义标签和横屏点击，并保留截图。
- **首次编译失败保留：** [首轮日志](Results/indicator-focused-20261020-a/xcodebuild.log) 记录可选 UIColor 推断导致的编译失败，未执行测试；修正为明确的非可选解析及回退。`.xcresult` 的测试结果为 unknown、0 项，不能视为通过。
- **首轮测试失败保留：** [聚焦结果 b](Results/indicator-focused-20261020-b/summary.json) 45 通过、1 失败。自定义视图释放断言发生在 UIKit 事务提交前；改为移除视图后清空 autoreleasepool、提交事务并跨过 RunLoop，再验证弱引用释放，同时保留视图移出层级断言。
- **阶段恢复通过：** [聚焦结果 c](Results/indicator-focused-20261020-c/summary.json) 75 通过、0 失败；[第一轮 UI](Results/indicator-ui-20261020-a/summary.json) 2 通过、0 失败；导出的六种效果截图已完成视觉检查。其后补充颜色刷新时保留自定义渲染进度、旧归档颜色语义及清空项后的渲染状态检查，阶段摘要如实记录源码差异。
- **阶段完整回归：** [库结果第一轮](Results/indicator-library-final-20261020/summary.json) 156 通过、0 失败、0 跳过。随后补充清空页面时不再向自定义视图发送旧转场索引的保护，该轮保留为阶段结果。[第二轮 UI](Results/indicator-ui-final-20261020/summary.json) 同样 2 通过、0 失败，但不包含最后的清空项状态保护，摘要保留相应源码差异。
- **通过：最终源码完整库回归。** [最终库摘要](Results/indicator-library-final-v2-20261020/summary.json) 和 [结果包](Results/indicator-library-final-v2-20261020/Result.xcresult)：156 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。
- **通过：最终源码 Demo UI 回归。** [最终 UI 摘要](Results/indicator-ui-final-v2-20261020/summary.json) 和 [结果包](Results/indicator-ui-final-v2-20261020/Result.xcresult)：2 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空；[截图清单](Results/indicator-ui-final-v2-20261020/attachments/manifest.json) 包含六种效果、横屏和分页终态。两轮最终验证均为 Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator。
- **通过：排版与差异检查。** SwiftFormat 0.64.0 按仓库配置检查本次涉及的 Swift 文件，0 个文件需要修改；`git diff --check` 通过。Demo 构建按既有配置执行 SwiftFormat Build Phase。未提交或推送。
- **环境说明：** 普通沙箱下 CoreSimulator 连接和 xcresulttool 报告缓存写入被限制；提权后读取、构建和测试均可执行。未修改全局 xcode-select。
- **未执行：** 完整 Demo UI 套件、iPad 真正分屏／窗口缩放、真机、iOS 15 实际运行、Release、VoiceOver 操作及性能测量。本次结果不替代这些验收。

## 2026-10-20：标签宽度策略与内容测量分离

- **公开 API：** 新增 `SPTabBar.minimumItemWidth`，默认 44 pt，作用于默认、自定义及回退项。0 不额外设下限，负数归零，非有限数恢复 44，超过 1,000,000 pt 截到该上限。更新使测量缓存失效；按实际分配宽度和高度判断几何变化，分配结果不变时保留动画和分页进度。原公开接口保持可用，`SPPageLayout` 的最小栏高及 0 隐藏语义不变。
- **分配规则变更：** 内容理想宽度不再被改写为至少 44。布局先应用最小项宽，再满足较宽项、让其余项尽量等宽；总需求超出视口才滚动。320 pt 视口下 `[160, 44]` 分配为 `[160, 160]`，`[161, 44]` 分配为 `[161, 159]`，消除原算法临界跳变。测量与实际布局共用同一分配函数。
- **超宽内容：** 内容视图先提供首选尺寸，独立 Auto Layout 测量宿主以水平优先级 999 尝试视口内的首选宽度，保留业务 required 最小宽度；再按实际 Cell 宽度以水平 required 测高。系统 UIListContentConfiguration 多行测量继续受支持。根视图 required 固定宽度或自身矛盾的约束不受支持；显式尺寸仍不限制到视口。测量容器完成后移除，候选查询保持独立。
- **极窄项：** minimumItemWidth 可以为 0，胶囊和下划线的横向内缩随 Cell 宽度收敛，1 pt 项不会产生越出 Cell 的指示器。命中区域仍是 Cell bounds，不扩到相邻项或页面。
- **Demo、文档和新增测试：** “页面”→“标签宽度”新增紧凑编号、24／44／120 最小项宽、首项 required 最小宽度 480 pt 的示例。更新公开注释和 README。新增 5 项库测试覆盖临界点及真实 LTR／RTL frame、默认／自定义／回退项、输入归一化、配置变化后的滚动范围、几何不变时保留选择动画／分页、required 超宽内容和极窄指示器；新增 1 项 UI 测试遍历两个方向的菜单设置、超宽滚动和点击切页。
- **首轮失败保留：** [首轮聚焦](Results/width-policy-focused-20261020/summary.json) 66 通过、1 失败。仅把视口约束从 required 降到 999 后，系统内容配置在宽／窄候选下均得到 55 pt 高，未满足换行后增高的既有断言。改用普通 Auto Layout 测量宿主求可行首选宽度，保留原断言；首轮摘要如实记录后续源码变化。
- **恢复通过：** [测量恢复聚焦](Results/width-policy-fitting-recovery-20261020/summary.json) 13 通过、0 失败、0 跳过；之后仅修改 UI 测试夹具，阶段摘要记录相应源码差异。系统多行、required 最小宽度、候选缓存／隔离、临时视图释放及 traits 测试通过。
- **阶段库回归通过：** [首轮全部库测试](Results/width-policy-library-20261020/summary.json) 143 通过、0 失败、0 跳过。后续 UI 夹具修正使该阶段摘要包含相应源码差异；最终源码另行完整回归。
- **首轮 UI 失败保留：** [新增宽度 UI 首轮](Results/width-policy-ui-focused-20261020/summary.json) 0 通过、1 失败。LTR 已执行宽度及超宽内容断言，RTL 扩大最小项宽后，原夹具直接查询移出视口的首项而失败。框架按原约定保留并限制物理滚动偏移，没有修改该策略；夹具改用真实拖动找到首项后检查原有 120 pt 断言，并支持完整露出的窄于 44 pt 标签点击，新增 24 pt 下限下的点击往返验证。
- **增量复测失败保留：** [宽度 UI 增量复测](Results/width-policy-ui-recovery-20261020/summary.json) 0 通过、1 失败，终态 `TEST FAILED`，`sourceChangedSinceRun` 为空。虽然构建日志含测试文件编译步骤，执行日志仍缺少当前源码新增的窄标签往返点击和 RTL 首项滚动定位，并报告旧断言行号；不能将源码哈希一致单独作为测试产物一致的证明。保留结果包，随后对 Demo 执行 `clean test`，核对实际交互步骤；具体缓存或安装失配原因未确定。
- **通过：最终全部库测试 143 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5 Simulator；143 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。见 [最终库摘要](Results/width-policy-library-final-20261020/summary.json) 与 [结果包](Results/width-policy-library-final-20261020/Result.xcresult)。最终日志未出现 `Unable to simultaneously satisfy constraints` 或 `NSInternalInconsistencyException`。
- **通过：清理重建后的新增宽度 UI。** iPhone 17 Pro Max / iOS 26.5 Simulator，执行 `clean test` 后 1 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。实际日志包含窄标签点击往返、RTL 扩宽后的真实滚动定位、120 pt 宽度以及 480 pt 超宽内容与后续切页；未放宽宽度或页面几何断言。见 [清理后 UI 摘要](Results/width-policy-ui-clean-recovery-20261020/summary.json) 和 [结果包](Results/width-policy-ui-clean-recovery-20261020/Result.xcresult)。清理重建恢复通过，增量运行步骤失配的根因仍未确定。
- **通过：最终相关 Demo UI 回归 3 项。** 同一台 iPhone 17 Pro Max / iOS 26.5 Simulator，3 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖多行自动栏高增长与恢复、按住拖动与刷新位置保留／分页选择，以及 RTL 最大辅助字号下竖屏、Landscape Left、Landscape Right、返回竖屏的长标题定位、安全区域、页面 frame 和触摸恢复。见 [相关 UI 回归摘要](Results/width-policy-ui-regressions-20261020/summary.json) 和 [结果包](Results/width-policy-ui-regressions-20261020/Result.xcresult)。这 3 项与新增宽度专项 1 项为两次运行，共覆盖 4 项不同用例；两次 UI 和最终 143 项库测试的源码哈希清单完全一致。
- **通过：格式与差异检查。** SwiftFormat 0.64.0 对本轮 7 个 Swift 文件 lint 为 `0/7 files require formatting`；`git diff --check` 通过。
- **未执行／限制：** 未运行全套 Demo UI、iPad／分屏、Release、真机、iOS 15 实际运行、完整 VoiceOver 流程或性能基准。较小项宽不附带扩展命中区域。保留此前工作区修改及本轮失败证据，未提交或推送。

## 2026-10-20：自定义内容高度与容器最小栏高分离

- **行为：** 移除自定义显式尺寸、自动 fitting 结果和整栏汇总中的统一 44 pt 高度下限。自动高度仍向上取整到 pt；有效性检查不变。默认图文、默认回退项及空栏保留原有高度规则。宽度最小 44 pt、等宽／剩余空间分配、横向滚动规则不变。
- **极小高度：** 高度不足 8 pt 时，胶囊指示器收缩为有限的零高度矩形，避免 `CGRect.insetBy` 返回 `CGRect.null`；下划线高度不超过实际栏高。正常高度下几何保持不变。
- **容器契约：** `SPPageLayout.tabBarHeight` 保留默认 44、正值作为最小栏高、0 隐藏。正值下实际高度为配置下限与内容需求的最大值。自定义内容需要 28 pt 时，配置 32 / 60 / 44 得到 32 / 60 / 44；内容需要 80 pt 时均增高到 80。独立标签栏由宿主设置最终高度，测量层不代替宿主设置最小栏高。
- **Demo 与文档：** 新增“切换紧凑标签”和“标签栏最小高度”菜单，可选 32、60、隐藏、44。最终紧凑示例为仅含 UILabel 的 UIContentView，通过内部约束和固有尺寸测量，不手算宽高；配置响应选中、高亮和禁用状态。同步公开 API 中文注释、README 接入示例及默认回退边界。
- **回归覆盖：** 新增 3 项库测试，验证自动／显式 28 pt 内容的实际 Cell 高度、宽度至少 44 pt、等宽分配及横向滚动、混入默认项；真实 UIWindow 容器遍历 LTR／RTL、28／80 pt 内容、44／32／60／0／32／44 下限，检查隐藏恢复、缓存页顶底边和滚动位置。调整原显式 1 pt 内容的测量断言为 1 pt，并验证自动／显式 1 pt 高度下胶囊和下划线指示器的 frame 有限且不超出栏高。新增 1 项 Demo UI 用例检查菜单切换、实际栏高、隐藏后不可点击、恢复、页面 frame 和选择。
- **阶段通过：** [聚焦库测试](Results/compact-height-focused-20261020/summary.json) 62 通过、0 失败；[首轮全部库测试](Results/compact-height-library-20261020/summary.json) 137 通过、0 失败。随后只调整 Demo 紧凑内容配置，阶段结果不代替最终源码回归。
- **首轮 UI 失败保留：** [首轮结果](Results/compact-height-ui-20261020/summary.json) 3 通过、1 失败。紧凑示例使用 UIListContentConfiguration.cell() 时实际测得 53 pt，未满足默认最小栏高下期望 44 pt 的断言；改为 UILabel 约束内容视图，未放宽测试断言。该轮 `sourceChangedSinceRun` 如实包含 `CustomTabContent.swift`，不是最终源码验收。
- **阶段通过：Demo 修正后全部库测试 137 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro / iOS 26.5 Simulator；137 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`；随后增加极小高度指示器保护，阶段摘要保留相关源码差异。见 [阶段库摘要](Results/compact-height-library-final-20261020/summary.json) 与 [结果包](Results/compact-height-library-final-20261020/Result.xcresult)。

- **通过：最终全部库测试 138 项。** 最后加入极小高度指示器保护后，Xcode 26.6 / Swift 6.3.3 / Debug、iPhone 17 Pro / iOS 26.5 Simulator，138 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。见 [最终库摘要](Results/compact-height-tiny-final-20261020/summary.json) 与 [结果包](Results/compact-height-tiny-final-20261020/Result.xcresult)。
- **阶段 UI 恢复通过：** [Demo 修正后四项 UI](Results/compact-height-ui-final-20261020/summary.json) 为 4 通过、0 失败、0 跳过，覆盖紧凑栏高／隐藏恢复、多行增高、真实按压拖动与分页、RTL 最大辅助字号和双向横屏恢复。iPhone 17 Pro Max / iOS 26.5 Simulator；这一轮运行的是最后指示器保护之前的构建，摘要包含 `SPTabBar.swift` 和对应新增测试的源码差异，不计作最终源码的四项 UI 全量通过。
- **通过：最终紧凑 Demo UI 聚焦复测。** 最后指示器保护之后，iPhone 17 Pro Max / iOS 26.5 Simulator 上 1 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖默认 44、32／60／隐藏／32／44 切换、隐藏时不可点击、恢复后的实际栏高／页面 frame／选中状态和真实点击切页。见 [最终 UI 摘要](Results/compact-height-ui-tiny-final-20261020/summary.json) 与 [结果包](Results/compact-height-ui-tiny-final-20261020/Result.xcresult)。最后的指示器保护后未再次执行其余 3 项扩展 UI，不合并宣称最终源码 4/4。
- **通过：格式和静态检查。** 本轮修改的 9 个 Swift 文件经 SwiftFormat 0.64.0 检查，0 个待格式化；`git diff --check` 通过。Demo Build Phase 执行既定格式化流程，没有产生额外排版修改。
- **未执行：** 全量 Demo UI、iPad／分屏、Release、真机、iOS 15 实际运行、VoiceOver 全流程和性能基准。保留上一次任务的失败记录，不从历史结果推定本轮覆盖。所有修改留在工作区，未提交、未推送。

## 2026-10-20：自定义内容自动尺寸测量

- **尺寸 API：** 新增 `SPTabBarContent(configuration:)`，默认 `size == nil`，由内容视图的 `systemLayoutSizeFitting` 自动测量。原 `init(configuration:size:)` 保留并跳过自动测量；`size` 属性改为 `CGSize?`，原来直接读取宽高的业务代码需要处理 nil。没有移除显式尺寸能力，默认图文路径保持不变。
- **测量边界：** 独立隐藏宿主创建已应用选中／禁用配置的业务视图。先用临时最大宽度约束求自然宽度，再使用与 `SPTabBarLayout` 共用的实际宽度分配规则，以水平 `.required`、垂直 `.fittingSizeLevel` 定宽测高。至少 44 × 44 pt；未知视口宽度不加上限，已知视口保留至少 44 pt。无效测量按项回退，回退改变宽度分配时重新测量剩余自动内容的高度。候选测量保持独立缓存，不改变可见 Cell、偏移或转场；临时视图完成后从宿主移除。
- **UIKit 适配：** 测量视图继承 traits、tint 和方向；iOS 17+ 在测量前调用 `updateTraitsIfNeeded()`，保留 iOS 15 可用性边界。外层内容宿主对 Cell 发起的额外 fitting 查询返回已分配尺寸，避免 UIKit 从宿主再次推导高度，保持整栏等高。业务仍需完整约束或有效固有尺寸，不假定普通 UIView 的 fitting 会自动转调 sizeThatFits。
- **Demo 和文档：** 卡片改用 Auto Layout、UILabel 固有尺寸及多行文本，删除 NSString 字体宽高计算和手工子视图 frame。新增“切换多行副标题”，演示自动栏高增长与恢复；原同尺寸刷新入口保留。README 改为无尺寸接入示例，并说明 fitting priority、显式尺寸迁移、测量视图生命周期、异步数据刷新和缓存失效。
- **新增覆盖：** 6 项自动测量库测试涵盖多行文本与实际分配宽度、系统 UIListContentConfiguration、固有尺寸、显式／自动混用、无效回退、候选宽度隔离与缓存、临时视图释放、真实 traits／RTL、刷新中的偏移／选择动画／分页进度；1 项容器测试验证自动高度变化、缓存页位置、页面顶底边及恢复。新增 1 项 Demo UI 用例验证多行更新后的实际栏高和页面 frame。
- **首轮失败保留：** [首轮库聚焦](Results/auto-content-focused-20261020/summary.json) 为 51 通过、6 失败。内部 Auto Layout 使 Collection View 对外层宿主发起额外 fitting，宿主返回不明确尺寸，触发 UIKit `NSInternalInconsistencyException`。同阶段 [首轮 UI](Results/auto-content-ui-20261020/summary.json) 为 0 通过、4 失败，切换自定义内容后应用退出；未把这轮记作通过。修正宿主 fitting 后继续复测。
- **第二轮失败保留：** [恢复聚焦](Results/auto-content-recovery-20261020/summary.json) 为 16 通过、3 失败。测量视图未及时收到 RTL／辅助字号环境，已通过同步 traits 修正。另两处夹具分别补上 RTL 切换后的显式布局，以及临时视图释放检查的 autorelease pool 边界，原几何与数量断言保留。
- **阶段恢复通过：** [环境修正聚焦](Results/auto-content-traits-20261020/summary.json) 6 通过、0 失败；[Demo 恢复](Results/auto-content-ui-recovery-20261020/summary.json) 2 通过、0 失败，覆盖多行栏高与模式切换。随后增加系统配置和固有尺寸回归，阶段摘要如实保留源码差异，不作为最终完整源码验收。
- **通过：最终全部库测试 135 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro Max / iOS 26.5 Simulator；135 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。涵盖自动测量 6 项、自动栏高容器 1 项及既有 128 项回归。见 [最终库摘要](Results/auto-content-library-20261020/summary.json)。
- **最终源码首轮 UI：3 通过、1 失败。** 多行高度增长／恢复、独立图库模式切换、真实拖动与同尺寸刷新均通过；RTL 最大辅助字号在首次横屏等待时超时，设备已请求 Landscape Left，但系统界面方向仍报告 portrait。未发现测量断言或约束冲突日志；具体原因尚未确认，不直接归因于环境。运行终态 `TEST FAILED`，`sourceChangedSinceRun` 为空，见 [UI 摘要](Results/auto-content-ui-final-20261020/summary.json)。保留既有方向及几何断言，以相同源码单独复测旋转。
- **旋转同源码复测及默认模式对照仍失败：** iPhone 17 Pro 上的 [自定义模式单项复测](Results/auto-content-ui-rotation-recovery-20261020/summary.json) 与 [默认标签模式对照](Results/auto-content-default-rotation-control-20261020/summary.json) 均为 0 通过、1 失败，首次 Landscape Left 后场景仍报告 portrait，未放宽 5 秒等待和方向断言。默认模式没有调用业务自动测量，故问题并非仅出现在自定义视图；尚不能据此确定根因。另用 iPhone 17 Pro Max 对同一构建进行独立验证。
- **通过：另一台设备的完整旋转回归。** 使用同一构建、同一源码，在 iPhone 17 Pro Max / iOS 26.5 Simulator 执行 `test-without-building`；RTL 最大辅助字号完成竖屏、Landscape Left、Landscape Right、返回竖屏，以及各方向首尾／长标题、横屏安全区域、页面 frame、Header 折叠与触摸恢复。1 通过、0 失败、0 跳过，终态 `TEST EXECUTE SUCCEEDED`，`sourceChangedSinceRun` 为空，见 [跨设备旋转摘要](Results/auto-content-alternate-rotation-20261020/summary.json)。与上述同源码主 UI 运行的 3 项通过共同覆盖 4 项不同用例，不合并表述为单次 4 项全通过；iPhone 17 Pro 的旋转超时仍保留，根因未确定。
- **通过：格式与差异检查。** SwiftFormat 0.64.0 对本轮 9 个 Swift 文件 lint 为 `0/9 files require formatting`；最终 Demo Build Phase 为 `0/32 files formatted`，`git diff --check` 通过。运行日志仍有既有 UIKit Observation tracking 提示。
- **未执行／限制：** 未运行全套 Demo UI、iPad／分屏、Release、真机、iOS 15 实际运行、完整 VoiceOver 流程或性能基准。iPhone 17 Pro 旋转验收未通过，已用默认模式对照和另一台设备缩小范围；不删除失败证据。保留此前工作区改动，未提交或推送。

## 2026-10-19：自定义内容 API 行为审查修正

- **修正刷新行为：** `reloadContent()` 不再走模型变更时清空转场并居中选中项的路径。自定义内容尺寸不变时保留手动滚动偏移、选择动画和分页进度；尺寸变化时将手动偏移限制在新范围，选择动画落到已选项，分页按原逻辑进度重新计算位置。默认模式下配置代理或刷新内容不改变当前显示，也不调用内容代理。保留现有公开接口名称、参数和返回类型。
- **修正测量副作用：** 将当前显示快照与最近一次候选宽度测量分开缓存。`sizeThatFits(_:)` 不再写入显示配置或 `SPTabBarLayout.itemWidths`；实际布局才应用当前视口的测量结果。候选宽度反复询问不会创建内容视图，真实尺寸变化后仍更新配置和几何。
- **注释与示例：** 补齐新增公开 API 的显示职责、整项点击和无障碍归属、状态保证、理想尺寸与最终 bounds、弱代理释放及测量回调约定。README 同步刷新和测量契约；分页 Demo 新增“刷新自定义内容”，通过业务副标题更新演示 `reloadContent()`。
- **回归测试：** 新增 7 项真实 UIWindow 库测试，覆盖 LTR／RTL 手动偏移、选择动画中间帧、分页中间进度、默认模式代理赋值、候选宽度测量隔离和实际尺寸变更，以及尺寸缩小后的偏移钳制；真实 traits 与 tint 变化也验证相同尺寸下的偏移、动画和分页保留。Demo 既有自定义拖动用例增加真实拖动后刷新，核对标签物理 frame、选择和页面不变，并继续验证后续选择、纵向折叠及模式切换。
- **修正前失败证据：** [修正前摘要](Results/custom-api-regressions-before-20261019/summary.json) 为 12 项中 6 通过、6 失败，共 22 个断言失败；6 项新增用例全部复现问题，既有 6 项通过。运行终态为 `TEST FAILED`，生成摘要时源码哈希一致；后续修正没有覆盖此结果包。
- **阶段通过：标签聚焦 51 项及首轮全部库测试 127 项。** 分别见 [聚焦摘要](Results/custom-api-focused-20261019/summary.json) 和 [首轮库摘要](Results/custom-api-library-20261019/summary.json)。运行均以 `TEST SUCCEEDED` 结束；随后真实 UI 测试发现环境刷新路径仍会重新定位，补充修正与测试后，这两次不作为最终源码验收，摘要保留 `sourceChangedSinceRun`。
- **真实 UI 首轮：2 通过、1 失败。** 自定义标签按住后拖动，再打开菜单并刷新，标签 minX 从 30.67 pt 回到 121 pt，未通过位置保留断言。保留 [首轮 UI 摘要](Results/custom-api-ui-20261019/summary.json) 和 [结果包](Results/custom-api-ui-20261019/Result.xcresult)；终态 `TEST FAILED`，后续修正的三个源码文件如实记录在 `sourceChangedSinceRun`。自定义模式原先对 traits 变化仍调用 `itemDidChange()`；调整为与手动刷新一致的 `reloadContent()`，tint 刷新也使用同一路径。UI 用例新增打开菜单后的中间位置断言，并保留刷新后的 frame 断言，没有放宽误差。
- **通过：环境刷新聚焦 13 项。** iPhone 17 Pro Max / iOS 26.5 Simulator，13 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。见 [环境刷新聚焦摘要](Results/custom-api-environment-focused-20261019/summary.json)。
- **通过：最终全部库测试 128 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro Max / iOS 26.5 Simulator；128 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。包括新增 7 项回归、既有自定义内容、默认标签及容器几何和选择语义。见 [最终库摘要](Results/custom-api-library-final-20261019/summary.json)。
- **通过：最终相关 Demo UI 3 项。** Xcode 26.6 / Debug，iPhone 17 Pro / iOS 26.5 Simulator；3 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖独立图库切换与内容更新，真实按住拖动后打开菜单／刷新时位置保留、禁用与分页、后续纵向折叠和模式切换，以及 RTL 最大辅助字号的竖屏／双向横屏／返回竖屏、首尾与长标题居中、安全区域、页面 frame 和触摸恢复。见 [最终 UI 摘要](Results/custom-api-ui-final-20261019/summary.json) 和 [结果包](Results/custom-api-ui-final-20261019/Result.xcresult)。
- **通过：格式与差异检查。** SwiftFormat 0.64.0 对本轮 6 个 Swift 文件 lint 为 `0/6 files require formatting`，最终 Demo Build Phase 为 `0/31 files formatted`；`git diff --check` 通过。最终库与 UI 使用同一份源码。日志仍包含既有 UIKit Observation tracking 提示。
- **未执行：** 全套 Demo UI、iPad／分屏、Release、真机、iOS 15 实际运行及完整 VoiceOver 流程。保留首轮失败和阶段验证记录，保留此前工作区改动；本轮未提交或推送。

## 2026-10-19：默认与自定义标签内容架构

- **实现：** 新增 `SPTabBar.ContentStyle.default/custom`、弱引用 `contentDelegate`、`reloadContent()`，以及 `SPTabBarContentDelegate`、`SPTabBarContent`、`SPTabBarContentContext`。业务返回 `UIContentConfiguration` 与包含自身内边距的理想尺寸；缺少配置、代理释放后再次布局或无效尺寸按项回退到默认图文。继续使用标准 `UICollectionViewCell` 与持久的 `CellRegistration`，没有新增 Cell 子类。默认 API、Item 身份、Appearance 复制和优先级、选择提交及代理语义保持原路径。
- **状态与交互：** 私有内容宿主统一处理整项 UIButton 点击和无障碍，向业务配置的 `updated(for:)` 传递选中、禁用、真实按压和 traits；业务视图内部不单独命中或暴露无障碍入口。同类型视图复用，不兼容类型替换。配置和尺寸缓存随模型、选择、外观、tint、traits、可用宽度和 RTL 更新，高亮不触发重新测量。容器以当前视图尺寸询问标签高度，动态高度保持页面根视图与标签底边相接。
- **Demo 与文档：** `CustomTabContent.swift` 提供编号、标题、副标题卡片，支持选中／按压／禁用、RTL 和 Dynamic Type；独立“标签外观”与分页“页面”菜单均可切换模式。README 补充接入示例、代理生命周期、尺寸、刷新、复用和整项交互边界。文件同步分组自动纳入新增 Demo，无需改变 target 或工程配置。最终构建的正常字号展示见 [自定义卡片预览](Results/custom-content-ui-verified-20261019/custom-tabs-preview.png)。
- **新增测试：** 6 项真实 `UIWindow` 标签测试，覆盖缺省与无效回退、弱代理释放、尺寸与配置缓存、单次激活和否决、禁用与程序化选择、无障碍、类型替换、Item 身份替换，以及宽度、RTL、tint、字体和水平尺寸类变化；1 项容器测试覆盖两种模式、LTR／RTL、动态高度和缓存页位置恢复；3 项 UI 用例覆盖独立模式切换、自定义标签真实拖动与分页、辅助字号和四方向安全区域。
- **首次编译失败，已修正：** 测试输入 `CGSize(width: .nan, ...)` 产生重载类型歧义，改为显式 `CGFloat.nan`／`CGFloat.infinity`。见 [编译失败摘要](Results/custom-content-focused-20261019/summary.json)。随后 [46 项聚焦测试](Results/custom-content-focused-fix-20261019/summary.json)、[首轮 121 项库测试](Results/custom-content-library-20261019/summary.json) 和 [补充 traits 后的 121 项库测试](Results/custom-content-library-final-20261019/summary.json) 均通过；这些阶段之后仍调整了源码或测试辅助方法，摘要保留 `sourceChangedSinceRun`，不作为最终完整源码验收。
- **首轮 UI：4 通过、2 失败。** 独立图库用例的辅助方法错误查询仅分页 Demo 才有的 `demo.status`，已在读取前检查元素存在性。RTL 辅助字号用例在切换长标题页后读取状态超时；[失败截图](Results/custom-content-ui-20261019/rtl-attachments/A98BC5E4-4C00-47B7-907B-172FE0259467.png) 显示已选中“本周热门精选”并展示列表，没有发现对应的新崩溃报告，但未确定这次查询超时的具体原因。不放宽状态或几何断言，保留 [失败摘要](Results/custom-content-ui-20261019/summary.json) 与结果包。
- **通过：最终全部库测试 121 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro Max / iOS 26.5 Simulator；121 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。见 [最终库摘要](Results/custom-content-library-verified-20261019/summary.json) 和 [结果包](Results/custom-content-library-verified-20261019/Result.xcresult)。
- **通过：两项 UI 恢复测试。** iPhone 17 Pro / iOS 26.5 Simulator，独立图库默认／自定义切换、标题与角标更新和禁用行为通过；RTL 最大辅助字号完成竖屏、双向横屏、返回竖屏，验证首尾与长标题标签居中、安全视口、页面完整 frame、Header 折叠与新触摸恢复。2 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。见 [恢复摘要](Results/custom-content-ui-recovery-20261019/summary.json)。这次恢复包含后续 traits 刷新调整，不能把恢复直接归因于某一个环境因素。
- **通过：最终其余 4 项 UI 回归。** 同一 iPhone 17 Pro，验证自定义标签禁用点击与分页、按住后横向拖动、纵向折叠不误选、模式切换后的页面 frame，以及默认模式的动态内容／禁用分页、按住后拖动和独立图库选择。4 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。与上述恢复运行使用相同源码，合计覆盖 6 项不同 UI 用例；不将两次运行混写为一次运行。见 [最终 UI 摘要](Results/custom-content-ui-verified-20261019/summary.json) 和 [结果包](Results/custom-content-ui-verified-20261019/Result.xcresult)。
- **通过：格式与差异检查。** SwiftFormat 0.64.0 对 10 个修改的 Swift 文件 lint 为 `0/10 files require formatting`，Demo Build Phase 报告 `0/31 files formatted`，`git diff --check` 通过。运行时仍可见既有 UIKit Observation tracking 提示；前一提交的库运行也包含该提示。模式切换需要替换不同类型的内容视图，UIKit 会提示内容视图替换成本；同类型内容的复用由测试断言验证。未将这些日志表述为“零警告”。
- **未执行：** 全套 Demo UI、iPad／分屏、Release、真机、iOS 15 实际运行、VoiceOver 全流程及性能基准；iOS 15 部署目标保持不变。结果目录是忽略的本地产物，历史失败证据保留；本次未提交或推送。

## 2026-10-19：标签 Cell 内容配置与 CellRegistration

- **实现：** 移除自定义 `TabCell`，使用标准 `UICollectionViewCell`、持久的 `UICollectionView.CellRegistration` 与 `dequeueConfiguredReusableCell(using:for:item:)`，不再手动注册或使用字符串复用标识。新增内部 `SPTabContentConfiguration` 和私有 `SPTabContentView`，通过 `contentConfiguration` 应用标题、图标、角标及无障碍信息；按钮和角标只创建一次，action 读取最新配置，回调弱引用宿主和 Item。注册对象在适配器初始化时提前创建，显示前继续同步预取 Cell。公开 API、iOS 15 部署目标、测量、指示器和分页联动代码保持不变；没有公开行为变更，因此未改写接入 README。
- **状态归属：** 选中／禁用外观仍由 `SPTabBar` 解析，真实按压高亮仍由 `UIButton` 管理。`updated(for:)` 保持内容快照，不将 Cell 的选中或高亮状态引入标签栏；不为此增加 Cell 子类或重复的状态更新链路。
- **新增回归：** 在真实 `UIWindow` 中验证反复配置时复用相同内容视图和按钮、保留按压高亮、只发送一次点击回调；同一标准 Cell 复用后清除旧标题／图标／角标／无障碍及大内容信息、恢复角标预留空间并将点击路由到新 Item；验证配置快照独立于后续模型更新，Cell 状态不能覆盖宿主选择。新增 3 项 `SPTabBarModelTests`，既有外观、布局和容器测试保持原断言。
- **阶段通过，不作为最终源码验收：** 内容视图改造后的 [39 项标签聚焦测试](Results/tab-content-focused-20261019/summary.json) 和 [114 项库测试](Results/tab-content-library-20261019/summary.json) 通过；加入 Registration 后的 [114 项库测试](Results/tab-content-registration-library-20261019/summary.json) 也通过。这些运行之后仍修改了 `SPTabBar.swift`，重新生成的摘要如实记录该文件的 `sourceChangedSinceRun`，不将阶段通过替代最终回归。
- **首次 UI 失败：0 通过、12 失败。** Registration 最初作为 lazy 属性在第一次 `cellForItemAt` 中创建，触发 UIKit 的 `NSInternalInconsistencyException`，Demo 进入分页演示时退出，全部选定用例在入口标签存在性检查失败。库测试未暴露该断言，因此仍需真实 Demo 验证。修复仅将首次创建提前到适配器初始化阶段，没有修改或放宽 UI 断言。保留 [失败摘要](Results/tab-content-registration-ui-20261019/summary.json)、[系统断言日志](Results/tab-content-registration-ui-20261019/registration-assertion.log) 和 [崩溃报告](Results/tab-content-registration-ui-20261019/registration-crash.ips)；失败摘要中的源码差异对应后续初始化修复。
- **通过：聚焦恢复 2 项。** iPhone 17 Pro / iOS 26.5 Simulator，动态标题／角标、禁用项分页和按住按钮后的横向拖动均通过；0 失败、0 跳过，`sourceChangedSinceRun` 为空。见 [恢复摘要](Results/tab-content-registration-ui-recovery-20261019/summary.json)。
- **通过：最终全部库测试 114 项。** Xcode 26.6 / Swift 6.3.3 / Debug，iPhone 17 Pro Max / iOS 26.5 Simulator；114 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。该设备与 UI 回归设备分开执行。见 [最终库摘要](Results/tab-content-library-final-20261019/summary.json) 和 [结果包](Results/tab-content-library-final-20261019/Result.xcresult)。
- **通过：最终相关 Demo UI 测试 12 项。** Xcode 26.6 / Debug，iPhone 17 Pro / iOS 26.5 Simulator；12 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，`sourceChangedSinceRun` 为空。覆盖动态标签、禁用项分页、独立标签外观示例、快速切页、选中居中与横向滚动、按住按钮后的拖动、纵向拖动不误选、RTL 分页、普通／辅助字号 × LTR／RTL 的四方向安全区域和吸顶恢复，以及首尾边缘渐隐。见 [最终 UI 摘要](Results/tab-content-ui-final-20261019/summary.json) 和 [结果包](Results/tab-content-ui-final-20261019/Result.xcresult)。
- **通过：格式与差异检查。** SwiftFormat 0.64.0 对 3 个修改的 Swift 文件检查为 `0/3 files require formatting`；Demo 构建阶段报告 `0/27 files formatted`。`SPTabBar` 的 public/open 声明与改造前一致，`git diff --check` 通过。构建日志中仍有 AppIntents 元数据提取跳过提示；早期测试编译还包含既有的同类型转换及归档 API 弃用警告。
- **未执行／环境边界：** 未运行全套 Demo UI、iPad、Release、真机、iOS 15 实际运行或 Xcode 27 兼容性矩阵。最初沙盒内的 CoreSimulator 查询及 xcresulttool TestReport 缓存写入受限，通过工具权限机制重试后恢复，不计为测试失败。历史失败与结果包均保留。

## 2026-10-19：SwiftPM Command Plugin 与构建时自动格式化

- **接入：** `Package.swift` 精确依赖 SwiftFormat 0.64.0，根 `Package.resolved` 锁定 revision `ce60affbe4143ad93ed16b8018117ed4f1db8ce3`。没有将 SwiftFormat 加入库或测试 target 的编译／链接依赖。`Scripts/format.sh` 使用 macOS SDK 和 Release 配置执行官方 Command Plugin，复用现有 `.swiftformat`，显式覆盖框架、Package 清单、测试及独立 Demo；无需全局安装工具。
- **构建阶段：** Demo target 在 Sources 阶段之前新增 `SwiftFormat` Build Phase，每次 Debug / Release 构建执行。仅 Demo target 关闭脚本沙盒以允许写入源码和工具缓存，格式化错误会使阶段失败。单独构建 Package 不会触发 Demo 的阶段；Demo 的阶段也不保证早于 Package 依赖编译，完整依赖图构建前的格式化可手动执行脚本。
- **通过：插件检查。** 首次真实插件 lint 与最终 lint 均检查 26 个 Swift 文件，报告 `0/26 files require formatting`。工具通过 SwiftPM 编译，未借用此前临时下载的 CLI。见 [首次 lint](Results/swiftformat-plugin-20261019/lint.log) 和 [最终 lint](Results/swiftformat-plugin-20261019/final-lint.log)。首次官方仓库下载约 616 秒、工具 Release 编译约 93 秒；后续使用本地缓存。
- **通过：真实构建自动修复。** 在 `SPPageLayout.swift` 和 `SceneDelegate.swift` 的 import 行各加入尾随空格；lint 准确报告这两个文件并以退出码 1 结束，这是预期的反向验证。随后直接执行 Demo `build`，Build Phase 报告 `2/26 files formatted`，终态 `BUILD SUCCEEDED`，全部 26 个 Swift 文件的 SHA-256 恢复到探针前基线。见 [预期 lint 失败](Results/swiftformat-plugin-20261019/probe-lint.log)、[修复核验](Results/swiftformat-plugin-20261019/automatic-repair.json) 和 [构建结果包](Results/swiftformat-buildphase-probe-20261019/Result.xcresult)。该次 `sourceChangedSinceRun` 如实保留两个被修复文件，不把构建前的带空格源码哈希替换为构建后哈希。
- **通过：最终 Debug Demo 与 UI 测试 target 构建。** Xcode 26.6 / Swift 6.3.3，iPhone 17 Pro / iOS 26.5 Simulator，执行 `build-for-testing`；终态 `TEST BUILD SUCCEEDED`，构建结果 0 错误、0 警告。Build Phase 实际执行且报告 `0/26 files formatted`。见 [构建结果](Results/swiftformat-buildphase-verified-debug-20261019/build-results.json) 和 [源码核验摘要](Results/swiftformat-buildphase-verified-debug-20261019/summary.json)。
- **通过：最终 Release Demo 构建。** 同一工具链和目标，终态 `BUILD SUCCEEDED`，构建结果 0 错误、0 警告。Build Phase 实际执行且报告 `0/26 files formatted`。见 [构建结果](Results/swiftformat-buildphase-verified-release-20261019/build-results.json) 和 [源码核验摘要](Results/swiftformat-buildphase-verified-release-20261019/summary.json)。
- **通过：最终 Package 配置下的库构建及 111 项测试。** Debug，111 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`。见 [测试摘要](Results/swiftformat-plugin-verified-library-20261019/summary.json)。两组最终 Demo 构建及这组库测试的 `sourceChangedSinceRun` 均为空；Shell 语法、工程 plist 和 `git diff --check` 均通过。
- **未执行：** 本次未运行 Demo UI 用例、Release 库测试、iPad、真机或 iOS 15 运行矩阵。此前格式化修改保留，未提交或推送。

## 2026-10-19：框架与 Demo 统一格式化

- **范围：** 使用官方 SwiftFormat 0.64.0，为根目录新增带逐项中文注释的 `.swiftformat`。处理 `Sources`、`Tests`、Demo 应用与 UI 测试，并检查 `Package.swift`；共检查 26 个 Swift 文件，25 个发生排版变化，Package 清单保持原样。开始时工作区干净。同步 README 使用命令及 AGENTS 中的配置状态，未修改工程配置、添加构建钩子、提交或推送。
- **规则边界：** 仅启用显式列出的缩进、空白、括号位置与换行规则；4 空格和 120 字符目标行宽属于项目约定。保留 API、访问控制、声明顺序、`self`、表达式、字面量、分号、条件编译结构与注释正文。
- **通过：语法审计。** 使用 Xcode 26.6 自带的 SwiftParser / SwiftSyntax 对格式化前后全部 26 个文件进行解析；均无语法错误，语法树节点结构、token 序列及注释正文完全一致。见 [审计输出](Results/swiftformat-20261019/token-audit.log) 与 [审计脚本](Results/swiftformat-20261019/audit.swift)。该检查不替代运行时测试。
- **通过：格式检查与幂等性。** `--lint --cache ignore` 报告 `0/26 files require formatting`；再次实际格式化报告 `0/26 files formatted`，最终源码哈希一致。`git diff --check` 通过。见 [首次格式化](Results/swiftformat-20261019/format.log)、[lint](Results/swiftformat-20261019/lint.log)、[重复执行](Results/swiftformat-20261019/repeat.log) 和 [源码与配置哈希](Results/swiftformat-20261019/source-hashes.json)。
- **通过：框架构建及全部 111 项库测试。** Xcode 26.6 / Swift 6.3.3 / Swift 6 语言模式 / Debug，iPhone 17 Pro / iOS 26.5 Simulator；111 通过、0 失败、0 跳过，终态 `TEST SUCCEEDED`，结果包为 `Passed`，`sourceChangedSinceRun` 为空。见 [测试摘要](Results/swiftformat-library-20261019/summary.json)、[构建结果](Results/swiftformat-library-20261019/build-results.json) 和 [结果包](Results/swiftformat-library-20261019/Result.xcresult)。构建有 4 条来自未改写的测试代码的警告：3 处同类型条件转换，以及 1 处已弃用的 `unarchiveTopLevelObjectWithData`；本次没有为消除警告引入代码重构。
- **通过：Demo 应用及 UI 测试 target 构建。** 同一工具链和目标设备，执行 `build-for-testing`；终态 `TEST BUILD SUCCEEDED`，构建结果 `succeeded`、0 错误、0 警告，`sourceChangedSinceRun` 为空。见 [构建结果](Results/swiftformat-demo-20261019/build-results.json)、[源码核验摘要](Results/swiftformat-demo-20261019/summary.json) 和 [结果包](Results/swiftformat-demo-20261019/Result.xcresult)。该次未执行 UI 测试，因此测试摘要的 `totalTestCount` 为 0、`result` 为 `unknown`；构建是否成功以构建结果和终态日志为准。
- **未执行：** 本次未运行 Demo UI 用例、Release、iPad、真机、iOS 15 运行或 Xcode 27 兼容性矩阵；此前历史运行结果不计入本次验收。
- **环境记录：** 最初在沙盒内查询模拟器服务和下载发布信息受到访问限制；通过工具权限机制重试后正常完成。该限制未造成上述构建或测试失败。

## 2026-10-19：系统容器演示入口与安全区域验证

- **实现：** 首页新增「系统容器演示」，全屏呈现 `UITabBarController → UINavigationController → DemoPager`。系统标签包含「联动演示」与「布局说明」，均可关闭回首页。复用现有 Header、列表和分页；系统容器场景隐藏原底部工具栏，把状态放到导航栏。未修改库源码、未硬编码系统栏高度、未提交或推送。
- **通过：iPhone 最终新增 UI 用例 3 通过、0 失败、0 跳过。** Xcode 26.6 / Debug，iPhone 17 Pro / iOS 26.5。覆盖真实入口、Header 展开／部分折叠／吸顶、短列表首末项、长列表第 80 项可见、自动 inset 与指示器配置、点击与横向分页、系统标签往返的滚动位置恢复、LTR／RTL 双向横屏与竖屏、旋转后正文位置保持与新触摸恢复，以及关闭后重新进入原演示。终态 `TEST SUCCEEDED`，全部输入哈希一致。见 [最终摘要](Results/system-container-iphone-verified-20261019/summary.json)、[结果包](Results/system-container-iphone-verified-20261019/Result.xcresult)、[首页截图](Results/system-container-iphone-verified-20261019/launcher.png) 和 [末项截图](Results/system-container-iphone-verified-20261019/screenshots/F10B7570-415B-4852-A26B-09CA5F630BE3.png)。
- **通过：原入口两项回归。** `testCollapsedTabBarStaysAtNavigationBarBottom` 与 `testRotationAndBackGesture` 在此前同一最终应用源码的 clean test 中通过。该次整体为 **3 通过、2 失败**，两项失败来自新增测试对 Toolbar 无障碍节点类型的假设；其后仅调整新增测试，未修改应用或库源码。见 [阶段摘要](Results/system-container-iphone-final-20261019/summary.json)。不将该阶段整组结果记为全通过。
- **历史阶段结果：iPad 新增用例 1 通过、2 失败。** iPad Pro 11-inch (M5) (16GB) / iOS 26.5。通过用例覆盖顶部系统标签布局、展开／部分折叠／吸顶、列表首末项与指示器配置。LTR／RTL 用例均已完成横向分页和系统标签往返的滚动位置断言，但在旋转方向检查处失败：设备请求为横屏，实际场景仍报告竖屏，窗口保持 `834 × 1210pt`。没有跳过方向断言或把竖屏执行算作横屏通过。终态 `.xcresult` 已读取，全部输入哈希一致。见 [iPad 摘要](Results/system-container-ipad-final-20261019/summary.json)、[结果包](Results/system-container-ipad-final-20261019/Result.xcresult) 和 [吸顶截图](Results/system-container-ipad-final-20261019/screenshots/56C52C62-61F5-4789-94A0-71C7503FBF0D.png)。
- **对照失败：** 同一 iPad 上运行未修改的原入口 `testRotationAndBackGesture`，**1 失败**，同样未通过方向检查；状态查询返回无值，截图仍为竖屏窗口。该结果说明当前旋转验证问题也出现在原入口，但尚不能据此确定系统环境根因或排除所有新容器问题。见 [对照摘要](Results/system-container-ipad-rotation-baseline-20261019/summary.json)。该阶段 iPad 横屏和后续恢复路径未通过验收；后续恢复验证见下。
- **后续恢复验证：3 通过、0 失败、0 跳过。** 继续排查时该 iPad 已处于关机状态；从此状态启动同一设备，保持应用、库、测试源码和方向断言不变，原入口 `testRotationAndBackGesture` 与系统容器 LTR／RTL 两项旋转用例均通过。系统容器实际窗口从 `834 × 1210pt` 转为 `1210 × 834pt`，双向横屏、返回竖屏、正文位置保持及新触摸滚动全部通过。见 [恢复摘要](Results/system-container-ipad-resume-baseline-20261019/summary.json)。全部输入哈希一致。该证据支持此前存在可通过重新启动恢复的模拟器运行状态异常，未确定更底层原因；没有修改方向锁定设置、抹除设备或放宽断言。

- **最终 iPad 干净重建验收：5 通过、0 失败、0 跳过。** Xcode 26.6 / Debug，iPad Pro 11-inch (M5) (16GB) / iOS 26.5。同一次 `clean test` 覆盖全部 3 项 `SystemContainerTests` 和原入口 `testCollapsedTabBarStaysAtNavigationBarBottom`、`testRotationAndBackGesture`。终态 `TEST SUCCEEDED`，结果包为 `Passed`，38 个源码输入哈希全部一致。见 [最终摘要](Results/system-container-ipad-recovered-final-20261019/summary.json)、[结果包](Results/system-container-ipad-recovered-final-20261019/Result.xcresult)、[横屏整屏截图](Results/system-container-ipad-recovered-final-20261019/landscape-screen.jpg)。本次继续处理只更新验证记录，没有改动应用、库或测试源码。

实际几何观测（pt）：

| 场景 | 组件标签栏展开顶部 | 吸顶顶部＝导航栏底部 | 底部安全区域 | 结果 |
| --- | ---: | ---: | ---: | --- |
| iPhone 竖屏，系统 Tab Bar 在底部 | 220 | 116 | 83 | 通过 |
| iPhone 横屏，系统 Tab Bar 在底部 | — | 78 | 64 | 通过；左右安全区域各 62 |
| iPad 竖屏，系统标签在顶部 | 220 | 140 | 20 | 通过 |
| iPad 双向横屏，系统标签在顶部 | — | 140 | 20 | 通过；正文位置保持，新触摸恢复 |

页面根视图始终紧接组件标签栏底部并延伸至窗口底边；自动底部贡献等于 `adjustedContentInset.bottom - contentInset.bottom`，没有重复叠加系统安全区域。短列表为提供 Header 折叠范围而存在的补齐 inset 与系统安全区域分开记录；短列表隐藏指示器，长列表显示，手动 `verticalScrollIndicatorInsets.bottom` 保持 0，自动调整保持开启。

中间失败与工具边界保留：

- `system-container-first-20261019`：3 失败。末项检测错误地接受屏外元素的零尺寸 frame；另外两项把横屏枚举值写反。修正为真实可见区域检查和 UIKit 枚举后重跑。
- `system-container-iphone-final-20261019`：3 通过、2 失败。截图证实原演示工具栏仍可见，但系统未暴露独立 Toolbar 节点；改用状态控件的真实位置与可交互性断言。`system-container-iphone-accepted-20261019` 随后 3 项通过；再统一 iPad 标签查找后形成上方最终 iPhone 结果。
- `system-container-ipad-accepted-20261019`：3 失败，起因是把顶部系统标签当作独立 TabBar。`system-container-ipad-verified-20261019` 的进一步探查仍错误限定 Button，且清理阶段继续查询缺失节点而卡住；只停止该次测试进程，退出码 73，不计为完整有效测试运行。实时 UI 快照确认 iPad 为 Tab、iPhone 为 Button，最终使用相同 accessibilityIdentifier、不限定控件类型查找。
- 恢复后的 XCTest `app.screenshot()` 横屏附件出现旋转裁切和黑色缺失区域，不能据此评价完整横屏画面。最终测试运行期间，在 LTR 横屏方向断言通过后，用 XcodeBuildMCP 直接截取模拟器整屏并人工复核，画面完整、导航栏与组件标签栏相接，见上方横屏截图及 [截图来源](Results/system-container-ipad-recovered-final-20261019/screen-capture.json)。布局、位置保持和新触摸恢复仍由原始 UI 断言验收。
- MCP 的早期 iPhone UI 快照未返回交互目标，因此自动交互验证以 XCTest 为准。报告读取最初因 xcresult 缓存写权限失败，获准访问后已成功读取上述终态结果。失败日志和对应源文件快照均保留。

**未执行：** 本次未重跑完整库／完整 Demo 套件、Release、真机、iOS 15、SDK 27 运行矩阵、深色与最大辅助字号、iPad 分屏／自由窗口尺寸变化及 VoiceOver 全流程。此前 iPad 旋转失败记录保留；本轮恢复通过不等同于已证明模拟器异常不会再次发生。

## 2026-10-19：横向 Section 边界交接

- **需求纠正：** 此前把“Section 到边界仍不切页”作为预期，与实际需求不符。现在在手势开始时按物理方向与 `adjustedContentInset` 判断：内部仍有空间则内部滚动；到边界后，新一次向外拖动交给容器相邻页。RTL 按物理内容边界处理；容器本身也在首尾时不抢走内部弹性拖动。从内部开始的同一次触摸保持原归属，不做触摸中途切页。
- **最小修复：** `SPPagingScrollView` 使用公开 `UIGestureRecognizerDelegate` 动态失败依赖，让内部横向 pan 等待容器的方向／边界判断。未更换任何内层滚动代理，未识别 UIKit 私有类名，未禁用业务手势，也未增加另一套分页动画。系统返回手势保留原有优先级。
- **修复前复现：** `testSectionStartEdgeHandoff` 在起点向外拖动后仍留在组合布局页，**1 失败、0 通过**；见 [修复前结果](Results/compositional-edge-before/Result.xcresult)。相同用例在最小修复后 **1 通过**，同时验证 `.continuous` 和 `.groupPaging`，见 [起点复查](Results/compositional-edge-probe/Result.xcresult)。
- **回归内容：** 两种模式的起点与终点向外翻页、反向返回、内部位置保留、RTL 两端交接、内部中段／斜向／快速拖动、纵向 Header 联动和普通区域双向分页；另检查旋转后的系统返回、斜向及短列表回弹。库测试补充真实窗口中的左右边界、业务 inset、RTL、内部弹性越界、禁用内部滚动、容器自身边界，以及纵向和无关滚动视图的失败依赖隔离。

- **最终 Demo 回归通过：7 通过、0 失败、0 跳过。** Xcode 27.1 / Debug / iPhone 17 Pro / iOS 26.5。一次运行覆盖 5 个组合布局用例与 2 个既有手势用例；终态为 `TEST EXECUTE SUCCEEDED`，`.xcresult` 为 `Passed`，`sourceChangedSinceRun` 为空，见 [UI 摘要](Results/compositional-edge-accepted-demo/summary.json) 和 [结果包](Results/compositional-edge-accepted-demo/Result.xcresult)。工具调用在 300 秒后超时，继续检查同一个 xcodebuild 进程约 343 秒的完整日志和结果包后确认通过，没有重复启动测试。

- **完整库回归通过：111 通过、0 失败、0 跳过。** 同一 iPhone 17 Pro / iOS 26.5 / Xcode 27.1 / Debug 环境，根 Package 的 `StickyPagerKit` scheme 独立构建并执行，包含新增 2 项边界判定测试。终态 `TEST SUCCEEDED`，结果包 `Passed`，源码哈希全部匹配，见 [库摘要](Results/compositional-edge-accepted-library/summary.json) 和 [结果包](Results/compositional-edge-accepted-library/Result.xcresult)。首次读取结果包受 `TestReport` 缓存写权限限制，获工具执行权限后读取同一结果包成功，未重跑测试。
- **本轮范围：** 上述为完整库套件及 7 项 Demo 定向回归，未执行完整 Demo 套件、Release、iPad、真机或减速期 HID 专项复测；此前减速观测保留为历史证据。新手势从边界向外翻页已验证，不包含同一次触摸跨越内部边界后中途交接。已重新打开无回归标志的组合布局页，方便手动操作。

- **保留的中间失败：** 首轮综合运行 **6 通过、1 失败**，失败来自 RTL 用例把横向 Section 也假定为镜像布局。实际截图与内部偏移表明：`--rtl` 反转容器标签顺序，但此 Demo 的原生 Section 仍从左侧开始。修正测试按实际物理边界拖动，未为通过测试而强制改变 Section 排列；见 [中间结果](Results/compositional-edge-final-demo/Result.xcresult)。因此本轮 RTL 证据覆盖“RTL 容器中嵌入当前 Demo 的 Section”，不宣称验证了额外镜像 transform 的业务滚动视图。

- **提交前审查：** 已审查全部 9 个变更文件，检查手势失败依赖、滚动边界与 inset、系统返回优先级、标签索引、测试 target 归属及回归观测开关，未发现阻止提交的问题。再次核对两次最终运行的 36 个源码输入哈希均一致；本次为已有结果复核，未重复执行测试。`git diff --check` 通过；构建产物及结果包仍保留在 Git 忽略目录。

## 2026-10-19：组合布局页双向分页

- **位置调整：** 当前顺序为“收藏（index 10）→ 组合布局（index 11）→ 更多专题与活动（index 12）”。保留前 11 个标签的既有顺序；组合布局两侧都有可切换的页面。README 和标签栏首尾测试同步更新。
- **真实滑动验收：** 在组合布局的普通纵向内容区域右滑至“收藏”、左滑返回；再左滑至“更多专题与活动”、右滑返回。每次检查触摸完整结束、行程超过 65% 页宽、容器位移超过半页、最终偏移准确落在相邻页、拖动和减速已结束；两次返回均检查纵向位置及吸顶状态。横向 Section 的两端边界也在这个非末页位置重新验证，避免容器末端钳制掩盖向后一页的误切换。
- **位置恢复：** `.continuous` 和 `.groupPaging` 均记录真实内部偏移，分别切到左右相邻标签后返回，检查两种内部偏移和纵向位置保留。

- **本轮通过：4 通过、0 失败、0 跳过。** Xcode 27.1 / Debug / iPhone 17 Pro / iOS 26.5。一次运行覆盖全部 3 个组合布局用例与 `testTabScrollEdgeAppearance`（LTR／RTL）。`.xcresult` 为 `Passed`，`sourceChangedSinceRun` 为空；见 [双向分页摘要](Results/compositional-middle-iphone/summary.json) 和 [结果包](Results/compositional-middle-iphone/Result.xcresult)。本轮未重跑减速期 HID 观测、完整套件或其他设备；初版证据保留在下节，不能代替此次位置调整后的验证。

## 2026-10-19：Compositional Layout 嵌套滚动演示（初版）

- **实现：** 初版 Demo 在末尾追加“组合布局”标签，保留原有标签索引，并增加“页面 → 组合布局 · 嵌套滚动”入口。新页面使用 `UICollectionViewCompositionalLayout`，包含各 8 项的 `.continuous` 与 `.groupPaging` 横向 Section，以及 30 项纵向内容；支持动态字体、系统配色和 directional insets。启动参数 `--open-demo --compositional` 可直达。未修改 `Sources/StickyPagerKit`，也未替换 UIKit 内部正交滚动视图的代理或手势识别器。
- **验证环境：** Xcode 27.1 / Debug / iPhone 17 Pro / iOS 26.5。3 个新增 XCTest 用例读取真实内容偏移、页面 frame、Header 状态和分页触摸轨迹，覆盖横向 Section 起点／中间／末端、斜向及快速连续拖动、边界后的新触摸、横向卡片上的纵向拖动、Header 折叠／吸顶／展开、普通纵向内容区域的往返分页，以及纵横向位置恢复。追加标签后，原标签栏边缘测试改为检查第 13 项。
- **初版定向验收通过（调整位置前）：5 通过、0 失败、0 跳过。** 同一次运行覆盖 3 个新增用例，以及原有 `testPagingAndRapidSelection` 和包含 LTR／RTL 的 `testTabScrollEdgeAppearance`。终态日志为 `TEST EXECUTE SUCCEEDED`，`.xcresult` 为 `Passed`，该次验收时 `sourceChangedSinceRun` 为空。见 [初版摘要](Results/compositional-accepted-iphone/summary.json) 和 [结果包](Results/compositional-accepted-iphone/Result.xcresult)。本结果是 5 项定向测试，不是全库或完整 Demo 套件。
- **减速期直接观测通过：** XCTest 会等待滚动空闲，因此减速中的触摸另用 AXe 低层 HID 输入验证；只接受完整的 touch began / ended、正确首尾坐标、无重叠的时间顺序和原生 `isDecelerating`。有效样本中，两次触摸间隔约 **0.513 秒**，第二次开始时 `sourceDeceleratingAtTouchBegan=true`；内部偏移由 **675 → 497.33 pt**，容器偏移始终 **4824 pt**。后续新触摸 **248 → 72.67 pt**，容器仍不移动。见 [减速观测](Results/compositional-accepted-iphone/deceleration-observation.json)。这是一组实际运行观测，覆盖 `.continuous`；未将时机不稳定的 HID 调度加入默认 XCTest，也不等同于 `.groupPaging` 减速期覆盖。
- **保留的中间失败：** 首次 UI 测试构建因同步 `setUp/tearDown` 与 Swift 主线程隔离不兼容而失败，改为项目已有的 async XCTest 形式；见 `compositional-baseline`。第一轮触摸测试 **2 通过、1 失败**：100 pt 纵向输入后 Header 实际移动 25 pt，未达到测试要求的 30 pt；后续把输入延长为 180 pt，保留原位移断言，再验证完整折叠、分页和恢复。见 [首轮结果](Results/compositional-gestures-1/Result.xcresult)。第二轮 **1 通过、1 失败**：纵向链路通过，减速测试因 XCTest 等待空闲而未命中减速期；见 [时机诊断](Results/compositional-probe-2/Result.xcresult)。高层 HID 的额外等待、并发输入重叠、touch ended 时偏移尚未提交等实验失败均留在 `compositional-probe-2`，不计为通过。
- **可见输入定位修正：** 后续 5 项运行中 **4 通过、1 失败**，失败位于测试辅助方法 `sectionY`：纵向滚动后首个部分可见 Cell 的中心为 124.67 pt，已在 160 pt 的可见内容上缘之上。改为选择中心实际位于内容视口且未被底部工具栏遮挡的 Cell，保留位移与页面状态断言；见 [定位失败结果](Results/compositional-final-iphone/Result.xcresult)。
- **验证边界：** 本轮未执行全库／完整 Demo 套件、iPad 分屏、iOS 15 真正运行、真机、VoiceOver、最大辅助字号与深色模式的完整交互验收。横向位置恢复仅验证页面保留在现有缓存中的往返；不承诺缓存淘汰后的内部 Section 状态保存。未提交或推送。

## 2026-10-19：线条自动颜色与胶囊圆角

- **改动：** `selectionColor` 改为可选值，nil 表示按样式解析；线条跟随选中态文字颜色（Item 文字属性、selected.titleColor、tintColor），胶囊背景保持 `.tertiarySystemFill`。显式颜色独立覆盖，设回 nil 恢复自动解析；复制和安全归档保留 nil。Demo 切换样式恢复自动颜色。线条保持 3 pt 高度、1.5 pt 圆角，选中动画与分页进度期间保持圆角；更新 tint 不重置动画。
- **通过：library 完整 clean test，109 通过、0 失败、0 跳过。** Xcode 26.6 / Debug，iPhone 17 Pro / iOS 26.5。新增真实 UIWindow 测试覆盖颜色优先级、运行时 tint、显式覆盖与恢复、深浅色动态解析、两种样式切换、动画与分页圆角、Item 外观、复制和安全归档。见 [库摘要](Results/tabbar-underline-auto-library-20261019/summary.json)。
- **通过：Demo 定向 clean test，2 通过、0 失败、0 跳过。** iPad Pro 11-inch (M5) (16GB) / iOS 26.5，执行动态图文／禁用项滑动进入和独立标签栏交互。见 [Demo 摘要](Results/tabbar-underline-auto-demo-20261019/summary.json)。已导出并查看 [线条截图](Results/tabbar-underline-auto-demo-20261019/screenshots/8D769D22-478E-4FEE-8A7A-E12548130A94.png)：蓝色短线两端圆角，禁用项文字仍按禁用外观显示，指示器采用选中态颜色。
- **最终证据：** 两组日志均有 `TEST SUCCEEDED`，终态 xcresult 数量为 109 / 2；两组各 33 个输入文件哈希均与最终源码一致。日志中仍有此前版本已存在的 UIKit Observation tracking 提示；本轮无测试失败。
- **未执行：** 本轮未重跑 Demo 完整 32 项或深色 Demo 场景，未执行 Release、iOS 15、真机和 SDK 27。前一轮完整结果仅代表当时源码。本次改动未提交、未推送。

## 2026-10-19：颜色调整后的 Demo 完整回归与指示器复查

- **开始状态：** 从已提交的 `0949c9e` 开始，工作区干净。Xcode 26.6 / Swift 6.3.3 / Debug；Demo 使用 iPad Pro 11-inch (M5) (16GB) / iOS 26.5，以执行完整分屏和窗口缩放覆盖。原外观为 light，深色补测后已恢复并再次读取确认；结束后关闭 Demo 与陪测“设置”。本轮未提交、未推送。
- **修复前通过但视觉验收发现问题：** 原颜色调整版本的浅色完整 Demo 为 **32 通过、0 失败、0 跳过**，深色四项定向为 **4 通过、0 失败、0 跳过**，分别保留于 `Results/tabbar-tint-demo-light-full-20261019` 和 `Results/tabbar-tint-demo-dark-focused-20261019`。导出截图后发现 SF Symbol 光栅化丢失自动模板语义：文字已着色，图标仍为黑色，深色下尤其不清楚；现有 UI 断言没有覆盖像素颜色。另发现分页 Demo 切换下划线时沿用胶囊填充色，线条对比不足，独立 Demo 切回胶囊时也没有恢复填充色。这些通过记录不代表上述视觉问题已通过验收。
- **失败复现与修复：** 新增 `testSymbolImagesKeepTemplateTintAfterResizing`，在修复前 **1 项失败**，普通与选中符号均未保留模板模式；见 [复现日志](Results/tabbar-symbol-regression-before-20261019/xcodebuild.log)。缩放 `.automatic` 的 SF Symbol 时显式保留 `.alwaysTemplate`，业务指定 `.alwaysOriginal` 仍保留原色。两个 Demo 样式入口同步设置下划线 `.label` 和胶囊 `.tertiarySystemFill`。现有公开 `SPTabBarAppearance.SelectionStyle` 保留 `.underline` / `.capsule` / `.none`，README 补充外部切换示例。
- **通过：最终 library 完整 clean test，107 通过、0 失败、0 跳过。** iPhone 17 Pro / iOS 26.5，新增符号模板回归以及原颜色、外观、布局、分页测试全部通过。见 [库摘要](Results/tabbar-symbol-library-final-20261019/summary.json) 和 [结果包](Results/tabbar-symbol-library-final-20261019/Result.xcresult)。
- **通过：最终深色 Demo 定向 clean test，4 通过、0 失败、0 跳过。** 覆盖动态图文／角标／禁用项滑动进入、独立标签栏、快速连续选择、按住标签后的横向拖动接管。见 [深色摘要](Results/tabbar-symbol-demo-dark-final-20261019/summary.json) 和 [结果包](Results/tabbar-symbol-demo-dark-final-20261019/Result.xcresult)。已查看 [深色胶囊与图标](Results/tabbar-symbol-demo-dark-final-20261019/gallery-screenshots/3B5D6C28-43F0-488A-B5B5-F5852D01F835.png) 和 [深色下划线](Results/tabbar-symbol-demo-dark-final-20261019/dynamic-screenshots/A25DD420-3227-4D86-9D07-133D5AD2881A.png)：选中文字与星形图标同为蓝色，未选中及禁用图标正确变暗，下划线清晰可见。
- **通过：最终浅色 Demo 完整 clean test，32 通过、0 失败、0 跳过。** 无筛选执行，四项真实分屏、两项系统窗口缩放、LTR／RTL、普通／最大辅助字号、图文与纯文字、独立标签栏、Header、连续切页、手势接管和边缘渐隐均在同一次运行中通过；没有单项重试或中途重启。见 [完整摘要](Results/tabbar-symbol-demo-light-final-20261019/summary.json) 和 [结果包](Results/tabbar-symbol-demo-light-final-20261019/Result.xcresult)。已查看 [浅色胶囊与图标](Results/tabbar-symbol-demo-light-final-20261019/gallery-screenshots/8A6247D0-3184-4BA3-B230-6265C36CC4E6.png) 和 [浅色下划线](Results/tabbar-symbol-demo-light-final-20261019/dynamic-screenshots/848B8C70-A9D5-4D57-BCF9-4AE477D97EDE.png)，图标颜色与线条可见度均已修复。
- **最终证据：** 上述三组最终运行均有 `TEST SUCCEEDED` 完成日志，终态 `.xcresult` 的实际数量分别为 107 / 4 / 32，33 个输入文件哈希均与最终源码一致。完整库与完整 Demo 合计 **139 项通过**，深色另有 4 次定向执行，不重复计入不同用例数量。中间视觉问题、失败复现及修复前结果全部保留。
- **未执行／工具限制：** 深色执行四项定向而非完整 32 项；本轮未跑 Release、iOS 15、真机和 SDK 27。额外现场菜单切换检查因 MCP UI 快照未返回可点击目标、桌面输入报告 `windowNotFoundAtPosition` 而未完成，不记为通过；胶囊／下划线由上述截图和 UI 场景验证，`.none` 隐藏行为由库测试覆盖。

## 2026-10-19：标签默认文字与选中颜色

- **改动：** 未选中文字与模板图标保持 `.secondaryLabel`，选中颜色从固定 `.label` 改为跟随 `SPTabBar.tintColor`，包括继承父视图 tint 和运行时变更；禁用保持 `.tertiaryLabel`。显式状态颜色与 Item 文字属性继续优先。状态的 `titleColor` / `iconColor` 支持 nil，表示按状态自动解析；复制与安全归档保留 nil。
- **通过：** 使用仓库脚本执行 library 完整 `clean test`，Xcode 26.6 / iPhone 17 Pro / iOS 26.5 / Debug，**106 通过、0 失败、0 跳过**。新增真实 UIWindow 测试检查实际文字颜色、图标配置、深浅色、继承／显式 tint、外观覆盖与恢复、归档后的自动颜色；原有标签与分页测试继续通过。完成日志为 `TEST SUCCEEDED`，终态 `.xcresult` 与源码哈希核对一致。见 [摘要](Results/tabbar-tint-library-final-20261019/summary.json) 和 [结果包](Results/tabbar-tint-library-final-20261019/Result.xcresult)。
- **环境阻塞记录：** 首次沙箱执行无法连接 CoreSimulator，未开始测试；以已批准的沙箱外访问重新执行后完成上述运行，原日志保留于 `Results/tabbar-tint-library-20261019`。
- **未执行：** 本次颜色调整没有重跑 Demo UI、Release、iOS 15 或真机测试；下方此前完整 Demo 结果属于颜色调整前的源码。

## 2026-10-19：标签栏完整回归续验

- **源码核对：** 开始时当前源码与 `tabbar-refactor-library-accepted`、`tabbar-refactor-demo-iphone-recheck` 的全部输入哈希一致。本轮仅修订 Demo UI 测试的分屏陪测应用激活方式和本验证记录，库与 Demo 实现保持不变。
- **测试宿主修订：** 两处分屏入口将系统“设置”的 `launch()` 改为 `activate()`。陪测应用只提供第二个窗口，不要求每次重新创建进程；Apple 文档明确 `activate()` 会启动尚未运行的应用，并复用已经运行的实例，避免 `launch()` 的强制终止再启动步骤。见 [activate() 文档](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/activate%28%29)。仅改激活方式后仍有超时，随后移除每项分屏测试结束时对“设置”的强制终止，恢复 Demo 全屏后保留后台实例供下一项复用。保留 Demo 自身的启动／终止和窗口清理；不增加重试、不扩大超时、不跳过分屏，也不修改触摸、页状态和几何断言。这是减少无关进程生命周期变化的规避措施，不能据此确定此前所有系统启动超时的底层原因。
- **通过：library 完整 clean test。** Xcode 26.6（17F113）/ Swift 6.3.3 / iPhone 17 Pro / iOS 26.5 / Debug，**104 通过、0 失败、0 跳过**。完成陪测生命周期修订后重新执行并核对完成日志和终态 `.xcresult`，`sourceChangedSinceRun` 为空。见 [本轮最终库摘要](Results/tabbar-refactor-library-final-20261019/summary.json) 与 [库结果包](Results/tabbar-refactor-library-final-20261019/Result.xcresult)。本轮前一次库运行 `tabbar-refactor-library-20261019` 也为 104 通过，保留为中间证据。
- **失败：仅修改 activate 的完整 Demo clean test。** 同一 Xcode 26.6 / iPad Pro 11-inch (M5) (16GB) / iOS 26.5 / Debug，**28 通过、4 失败、0 跳过**。两项分屏在激活“设置”时超时；RTL 分屏手势边界和最后的边缘渐隐用例在等待横屏时失败，均未进入该方向的后续断言。已导出并查看截图，两个旋转失败时屏幕仍为竖屏。其他标签、Header、分页、普通／最大字号 LTR／RTL、独立标签栏及两项系统窗口缩放均通过。见 [完整运行摘要](Results/tabbar-refactor-ipad-full-20261019/summary.json) 与 [结果包](Results/tabbar-refactor-ipad-full-20261019/Result.xcresult)。后续生命周期修订仅改变 UI 测试文件，库与 Demo 实现不变。
- **已确认的环境故障：** 本轮 10:21:09 SpringBoard（PID 84663）发生 `EXC_BAD_ACCESS / SIGSEGV`，故障线程首帧为 `XCTAutomationSupport` 的 `XCTAutomationSession initWithAccessibilityFramework:dataSource:` 回调。系统日志随后出现新的 SpringBoard 进程。崩溃不在本库进程中，但现有记录不足以证明四项失败均由同一个底层原因造成。见 [崩溃摘要](Results/tabbar-refactor-ipad-full-20261019/springboard-crash-summary.json)、[原始报告](Results/tabbar-refactor-ipad-full-20261019/SpringBoard-2026-10-19-102113.ips) 及同目录 `settings-system.log`。完成该次运行后仅重启同一测试用 iPad，未抹除设备或改系统设置，再验证陪测应用复用。
- **通过：连续生命周期定向 clean test。** 同一 iPad 上四项真实分屏与其后的旋转／边缘渐隐共 **5 通过、0 失败、0 跳过**，`sourceChangedSinceRun` 为空。全程没有单项重试或中途重启模拟器，原有触摸、旋转、页面目标、位置与几何断言全部保留。日志显示首次启动“设置”，后续三个分屏用例直接激活已有实例，测试之间没有终止该进程；见 [生命周期审计](Results/tabbar-refactor-split-lifecycle-20261019/companion-lifecycle-audit.json)、[定向摘要](Results/tabbar-refactor-split-lifecycle-20261019/summary.json) 与 [结果包](Results/tabbar-refactor-split-lifecycle-20261019/Result.xcresult)。这证明本次连续场景通过，不等同于证明系统自动化崩溃永不再发生。
- **通过：最终 Demo 完整 clean test。** 保持定向复查后的源码和模拟器状态，不再重启设备，使用同一工具链、设备和 Debug 配置无筛选执行完整套件，**32 通过、0 失败、0 跳过**。四项分屏、两项窗口缩放及末尾旋转／边缘渐隐均在这一次完整运行中通过；日志终态为 `TEST SUCCEEDED`，`.xcresult` 实际执行数量为 32，`sourceChangedSinceRun` 为空。见 [最终完整摘要](Results/tabbar-refactor-ipad-final-20261019/summary.json)、[完整结果包](Results/tabbar-refactor-ipad-final-20261019/Result.xcresult) 和 [陪测生命周期审计](Results/tabbar-refactor-ipad-final-20261019/companion-lifecycle-audit.json)。四处分屏入口均直接激活已有“设置”实例，运行中没有单项重试或重启模拟器；全部测试结束后通过 XcodeBuildMCP 关闭陪测应用。
- **最终证据与边界：** 本轮最终完整库与完整 Demo 合计 **136 项通过、0 失败、0 跳过**，两组输入哈希均匹配当前源码；另有 5 项定向通过记录，不重复计入这 136 项。已查看最终 [RTL 横屏分屏截图](Results/tabbar-refactor-ipad-final-20261019/rtl-screenshots/F4E2449D-F135-44B0-B78A-76F20E70D814.png)，列表位于标签栏下方，两窗口互不覆盖。原始 28 通过／4 失败的完整运行及崩溃报告继续保留，不改写为通过。本轮未重跑 iPhone Demo／SDK 27、Release、iOS 15 实际运行、真机、VoiceOver 全流程及长期压力测试；一次完整通过不构成对系统自动化稳定性的长期保证。未提交或推送。

## UIKit 风格标签栏重构

2026-10-16，从 `3f25579` 继续实现。`SPTabBarItem` 继承 `UIBarItem`，`SPTabBarAppearance` 继承 `UIBarAppearance`；图文排列和 normal / selected / disabled 状态配置使用值类型。最低部署目标仍为 iOS 15，未提交或推送。

- **实现范围：** Item 对象身份、可变内容、多标签栏弱订阅、重复对象拒绝、公开选择代理与容器内部协调分离、转场完成后提交选择、取消旧请求；材质背景、胶囊／下划线、图文自适应排列、角标、禁用点击、Dynamic Type、RTL、降低透明度和减少动态效果。Demo 增加独立标签栏与运行时内容／外观修改，README 更新新 API、事件时序和迁移示例。
- **通过：完整库 clean test。** Xcode 26.6 / iPhone 17 Pro / iOS 26.5 / Debug，**104 通过、0 失败、0 跳过**。终态日志为 `TEST SUCCEEDED`，摘要 `sourceChangedSinceRun` 为空。真实 UIWindow 测试覆盖对象身份、多宿主更新与释放、代理次数、取消／重载／替换、禁用项程序化及手势进入、图文与角标几何、外观覆盖与高度变化、布局方向和字体变化；还覆盖 `UIBarItem` 基类引用赋值、Item 归档及 Appearance 复制／安全归档。见 [库摘要](Results/tabbar-refactor-library-accepted/summary.json) 与 [库结果包](Results/tabbar-refactor-library-accepted/Result.xcresult)。
- **失败：首次完成的完整 iPad Demo clean test。** Xcode 26.6 / iPad Pro 11-inch (M5) (16GB) / iOS 26.5 / Debug，**27 通过、5 失败、0 跳过**。通过项包括新 Demo 场景、最大辅助字号 LTR／RTL、按住标签后横向拖动、Header、旋转和系统窗口缩放。失败分别为 LTR 标签页状态等待、相邻转场中两个列表同名导致查询歧义、分屏分页状态等待，以及两个 RTL 场景启动系统“设置”超时。见 [完整 iPad 摘要](Results/tabbar-refactor-demo-ipad-final/summary.json) 与 [结果包](Results/tabbar-refactor-demo-ipad-final/Result.xcresult)。
- **复查依据：** LTR 标签失败截图已经显示目标页 weekly；分屏手势日志中的最终状态为 list，偏移等于页宽且正文位置保持。测试改为每次轮询重新查询状态元素，仍要求原有状态并保留 5 秒等待；列表交互先等待对应页提交，避免转场中的同名列表歧义。仅重新启动该模拟器的“设置”应用确认可启动，没有抹除模拟器或放宽几何、手势和状态断言。完整 iPad 运行后只修改了 Demo UI 测试文件，库与 Demo 实现哈希保持一致，不能将后续定向复查改记成该完整运行全绿。
- **失败：5 项定向 clean 复查为 3 通过、2 失败。** 前三项恢复通过；两个 RTL 场景仍在启动“设置”时超时，尚未进入对应分屏断言。见 [定向复查摘要](Results/tabbar-refactor-demo-ipad-recheck/summary.json)。随后仅重启该测试用 iPad，保持源码与断言不变，两项 RTL clean test 为 **1 通过、1 失败**：RTL 分屏手势边界通过，紧接着的位置恢复场景再次在启动“设置”时超时。见 [重启后 RTL 摘要](Results/tabbar-refactor-demo-ipad-rtl-recovered/summary.json)。这两次 `sourceChangedSinceRun` 均为空；系统应用重复启动问题尚未消除。
- **通过：剩余 RTL 分屏场景独立 clean test。** 再次仅重启同一 iPad 后，位置恢复场景 **1 通过、0 失败、0 跳过**；源码与断言不变，`sourceChangedSinceRun` 为空。覆盖竖屏 → 横屏 → 竖屏、Header 三态、往返切页和新触摸后的几何与正文位置。见 [独立 RTL 摘要](Results/tabbar-refactor-demo-ipad-rtl-position/summary.json) 与 [结果包](Results/tabbar-refactor-demo-ipad-rtl-position/Result.xcresult)。iPad 的 32 个不同用例均有通过记录，分布在完整运行和三次定向复查中；**未获得单次完整套件全绿**，不能据此宣称系统应用启动偶发问题已解决。
- **通过：iPhone 跨工具链定向 clean test。** Xcode 27.1 / Swift 6.4 / iPhone 18 Pro Max / iOS 27.0 / Debug，串行执行 **4 通过、0 失败、0 跳过**，`sourceChangedSinceRun` 为空。覆盖折叠标签栏与导航栏边界及旋转、动态图文与角标、禁用项仍可手势进入、按住标签后横向拖动接管、独立标签栏选择及运行时更新。见 [iPhone 摘要](Results/tabbar-refactor-demo-iphone-recheck/summary.json) 与 [结果包](Results/tabbar-refactor-demo-iphone-recheck/Result.xcresult)。此前主动中断的 iPhone 全套运行中出现方向和分页状态等待超时，本次对应两项均通过，但不等同于最终源码的 iPhone 完整套件执行。SDK 27 构建已消除本次 NSShadow 属性桥接的 Sendable 警告；UI 测试链接器仍提示 SDK 自带 XCTest 库的最低系统版本为 17，该提示不代表本库部署目标已提高。
- **已修复且保留的中间失败：** `UIBarItem` 抽象基类不能依赖默认属性存储，改为子类显式实现继承属性；安全归档补齐 `supportsSecureCoding`；旧测试改为读取 UIButton.Configuration。最大辅助字号下的大内容长按交互与横向拖动发生冲突，移除 Cell 上的大内容查看器，保留自适应字体和触摸范围；该手势在独立 clean test 和后续完整 iPad 运行均通过。见 [大字号定向摘要](Results/tabbar-refactor-large-text-probe/summary.json)。早期 library 运行、主动中断的 iPad／iPhone UI 运行及其失败截图均保留在 `Results/tabbar-refactor-*`，不计为完成验收。
- **未执行：** 本次 Release、iOS 15 实际运行、真机、VoiceOver 全流程和性能压力测试。iOS 15 的证据是部署目标与 API 编译检查；无障碍属性及禁用激活由库测试覆盖，不能替代完整 VoiceOver 操作。不同系统版本不按原生标签栏逐像素一致验收。

## iPad 分屏横向翻页超时：输入诊断与纵向位置保护

2026-10-16，从 `0e2c256` 继续排查。区分测试实际发送的触摸、UIKit 计算的分页终点和框架最终状态；保留原始失败，不用重试或标签点击掩盖翻页失败。

- **旧手势的边界：** 原 `page-follow-ipad-reboot-20261016` 失败结果中的合成事件为 x=306 → 106、y=670、时长 0.2 秒；在 412 pt 宽的分屏里，200 pt 小于半页 206 pt，因此翻页依赖释放速度。带观测的原手势连续 12 次通过，实际分页位移仅 142.5–196.5 pt；另以相同 200 pt 路径低速拖动并停留，4 次均由 UIKit 将目标定为原页，见 [速度依赖对照](Results/split-gesture-release-baseline-20261016/summary.json)。这证明旧测试输入没有保证越过分页阈值；原始单次失败缺少应用侧触摸轨迹，不能追溯断言它必然由某一种输入原因造成。
- **独立发现的框架缺陷：** RTL 短拖取消后，列表正文位置由 530 变成 519.5 pt；同一可见行高度和 contentSize 不变，行坐标相应移动 10.5 pt，见 [行锚点对照](Results/split-gesture-row-anchor-20261016/summary.json)。进一步观测发现：横向拖动已经开始、候选页尚未建立时，UITableView 的自适应布局会发送临时纵向 offset；原实现只用 `transitionTarget` 保护历史，仍将该偏移保存，取消时也没有恢复。两项 LTR/RTL 库回归在旧框架上均失败，见 [修复前库摘要](Results/split-gesture-library-baseline-20261016/summary.json)。该缺陷是纵向历史污染，不等同于证明原始横向超时由框架引起。
- **框架修复：** 从横向拖动开始到分页结束统一使用 `isPaging` 保护保存位置，忽略此阶段的中间纵向回调；取消后按保存位置重新对齐原页，包括尚未建立候选页的路径。成功切页仍按原有流程提交，并保留滚动指示器显隐行为。新的纵向触摸在分页结束后仍能正常更新历史。
- **测试修复与可观测性：** 在 Demo 的实际 UIWindow 内按当前可见宽度发送 70% 行程的单次慢拖，终点停留消除释放速度依赖；屏幕坐标减去窗口原点，适用于左右分屏和浮动窗口。`--paging-trace` 专用窗口被动记录触摸与原生分页状态，不安装识别器或修改事件分发；Demo 代理只读取 UIKit 的目标偏移。断言同时检查触摸正常结束、应用收到超过 65% 页宽的行程、分页越过半页、原生目标正确、最终偏移及停止状态。短拖对照继续要求留在原页，并验证正文历史。
- **输入取消记录：** 中间矩阵曾收到 began 后直接 cancelled，移动样本和分页位移均为 0，属于未形成有效拖动的输入失败，见 [中断矩阵摘要](Results/split-gesture-ui-fixed-20261016/summary.json)。当时使用 SpringBoard 坐标且另一台模拟器也在运行 UI 测试；尚不能单独归因于其中一个因素。该矩阵后来主动中断，记录为 1 通过、2 失败（含 Testing was canceled），不作为全套通过。最终 iPad 与 iPhone UI 串行执行，手势绑定 Demo 窗口，并明确区分输入取消与有效翻页后的断言失败。
- **完整库回归：** iPhone 17 Pro / iOS 26.5 / Xcode 26.6 / Debug，clean test 后 90 通过、0 失败、0 跳过，见 [库摘要](Results/split-gesture-library-fixed-20261016/summary.json)。库实现、库测试、Package 与最终源码一致；此后仅调整了 Demo UI 测试的坐标绑定与输入断言，该文件不属于库 scheme。
- **iPhone 定向回归：** iPhone 18 Pro Max / iOS 27.0 / Xcode 27.1 / Debug，普通横向分页、RTL 分页、同级 UILabel / UIScrollView 三项 clean test 均通过，见 [三项摘要](Results/split-gesture-iphone-fixed-20261016/summary.json)。此后修改了 UI 手势辅助方法的窗口绑定；最终源码再次 clean 构建并补跑 RTL 用例，1 通过、0 失败、0 跳过，且 `sourceChangedSinceRun` 为空，见 [最终 RTL 摘要](Results/split-gesture-iphone-final-20261016/summary.json)。普通分页和同级 Label 用例不使用该辅助方法，本轮未重复执行。
- **iPad 六项矩阵：** clean test 终态为 3 通过、3 失败、0 跳过，见 [矩阵摘要](Results/split-gesture-ipad-final-20261016/summary.json)。LTR 手势边界、LTR/RTL 完整分屏通过；RTL 手势边界在启动系统“设置”时超时，未发送分页触摸；LTR 缩放完成 4 次横向翻页后，新纵向 swipe 未增加正文位移，原附件缺少应用侧接收轨迹，原因未定；RTL 缩放在标签点击后等待短列表超时，导出的 UI Snapshot 显示按钮收到 began 后直接 cancelled，见 [取消轨迹](Results/split-gesture-ipad-final-20261016/rtl-tap-cancellation.json)。共完成 28 次带完整轨迹断言的横向翻页，均成功。随后只增加清理前及新纵向触摸后的只读日志，重启同一 iPad 后补跑未通过的三项；不更改框架、测试动作或断言。
- **iPad 补跑通过：** 重启同一模拟器后，RTL 手势边界、LTR/RTL 窗口缩放三项 clean test 均通过，0 失败、0 跳过，见 [补跑摘要](Results/split-gesture-ipad-recovery-20261016/summary.json)。六项目标用例的通过记录分布在首轮与补跑，不能描述为一次六项全绿。补跑中的新纵向触摸正常结束，LTR 原生归一化位置从 679 增至 871.5 pt，随后通过恢复全屏与位置保存断言；此前 LTR 单次未滚动缺少接收轨迹，仍保留原因未定。补跑开始阶段曾等待 CoreSimulator 启动应用，持续跟踪同一进程后正常完成，没有重复启动测试。
- **横向输入审计：** 首轮 28 次、补跑 20 次，共 48 次使用新辅助方法的翻页均收到正常 ended，触摸行程超过 65% 页宽，实际分页位移超过半页，最终偏移与 UIKit 目标一致且停止拖动/减速，见 [首轮轨迹审计](Results/split-gesture-ipad-final-20261016/gesture-audit.json) 和 [补跑轨迹审计](Results/split-gesture-ipad-recovery-20261016/gesture-audit.json)。另有 LTR/RTL、竖屏/横屏共 4 次短拖对照，均回到原页并保留正文历史。该次数是本轮覆盖，不代表长期压力测试或保证系统永不取消注入事件。
- **源码一致性：** 补跑的 29 个输入哈希全部匹配最终源码。首轮矩阵之后 UI 测试文件只增加了清理前及纵向滑动后的日志；框架、Demo、分页辅助方法、动作和断言均未改变，差异已反映在首轮摘要。完整库运行之后只有 Demo UI 测试文件变化，库 scheme 的输入保持一致。工作区中 `project.pbxproj` 的格式重排经 plist 解析与 HEAD 语义相同，未改变工程配置；保留该变更。
- **截图复核：** 已查看 [LTR 横屏分屏部分折叠](Results/split-gesture-ipad-final-20261016/screenshots/FB76323B-C8B7-4E24-B1FC-BD873D2FAB11.png) 与 [RTL 横屏分屏部分折叠](Results/split-gesture-ipad-final-20261016/screenshots/4A269502-B097-4A72-AAC5-CE12197E10EC.png)，短列表内容位于标签栏下方；动态过程以物理几何断言和触摸轨迹为准。
- **证据与范围：** 其他诊断失败、临时观测实现和一次探针编译失败均保留在 `Validation/Results/split-gesture-*`，不计入最终验收。框架内的临时打印已移除。位置契约仍是归一化正文位置，不扩展为内容重排后固定某一行的屏幕像素。此次没有重跑完整 Demo UI 套件、Release、真机、旧系统传统 Split View 或其他 iPad 型号。

## iPad 页面跟随：系统分屏、窗口缩放与 RTL 补充回归

2026-10-16，在提交 `964009d` 的框架实现上补跑 iPad Pro 11-inch (M5) (16GB) / iOS 26.5 / Debug。本轮仅加强 UI 测试与验证记录，`Sources` 和 Demo 实现未修改。

- **新增几何检查：** 原页面宽度断言扩展为完整边界检查：页面顶部等于当前标签栏底部，底部等于实际 `UIWindow` 底边，左右铺满窗口，误差限均为 1 pt。系统分屏和各窗口尺寸下通过真实触摸验证展开、部分折叠、吸顶，并检查普通页、缓存切页、原列表正文位置和新触摸恢复。新增 RTL 系统窗口缩放用例，横向手势按 RTL 方向执行。
- **窗口缩放通过：** LTR 独立运行 1 项通过、0 失败、0 跳过，见 [缩放摘要](Results/page-follow-ipad-resize-20261016/summary.json)；RTL 缩放与 RTL 横向分页在首轮矩阵中通过，见 [首轮矩阵摘要](Results/page-follow-ipad-matrix-20261016/summary.json)。Xcode 27.1，实际窗口依次为 375 × 630、690 × 866、535 × 750 pt，最后恢复 834 × 1210 pt 全屏。各尺寸均检查 Header 三态与分页后的正文位置。
- **重启后回归：** Xcode 26.6，默认字号 RTL、最大辅助字号 RTL、同级 UILabel / UIScrollView、RTL 系统分屏共 4 项通过；LTR 分屏 1 项因横向滑动后等待 `page=short` 超时失败，见 [重启后摘要](Results/page-follow-ipad-reboot-20261016/summary.json)。同级页面检查 Label 距标签栏 12 pt、列表距 Label 8 pt，以及旋转、切页和新触摸后的几何。
- **失败与环境恢复：** 首轮矩阵为 2 通过、5 失败：4 项等待原生横屏方向超时，1 项启动系统“设置”超时。切换到 Xcode 26.6 后，同级页面仍在方向等待处失败，见 [工具链对照](Results/page-follow-ipad-rotation-check-20261016/summary.json)。模拟器菜单旋转时 SpringBoard 内容也未正常转向；仅重启该 iPad 后，同一源码的方向断言恢复通过。没有更改方向锁定设置、抹除设备、放宽断言或跳过旋转。以上证据支持当时存在模拟器旋转状态异常，未确定更底层原因。
- **LTR 独立重跑通过：** 保持源码和断言不变，单独重跑 LTR 系统分屏，1 项通过、0 失败、0 跳过，见 [LTR 重跑摘要](Results/page-follow-ipad-ltr-retry-20261016/summary.json)。已完成 412 × 1210 → 600 × 834 → 412 × 1210 pt 的真实分屏、往返分页和 Header 三态检查；首次分页超时原样保留，未通过重复压力测试证明偶发性已消除。
- **最终结果口径：** 8 项不同的目标用例均有通过记录，分布在缩放、首轮矩阵、重启后矩阵和 LTR 独立重跑中；不合并描述为单次 8 项全绿。五次运行的 28 个源码输入哈希一致，所有终态摘要的 `sourceChangedSinceRun` 为空。
- **实际几何：** LTR / RTL 分屏在竖屏 412 × 1210、横屏 600 × 834、回到竖屏三个阶段通过；两个应用窗口均缩窄且互不重叠。竖屏展开/部分折叠/吸顶的根视图顶部为 264/246.5/130 pt，分别等于标签栏底部，底边固定为 1210 pt；横屏对应 264/246/130 pt，底边为 834 pt。
- **截图复核：** 已导出并查看 [LTR 横屏分屏部分折叠](Results/page-follow-ipad-ltr-retry-20261016/screenshots/774F497F-1E4A-4BC0-B050-5DC9B86148FB.png)、[RTL 横屏分屏部分折叠](Results/page-follow-ipad-reboot-20261016/rtl-split-screenshots/EBBCAF24-86B1-4AAA-A1AE-1FB03912C5A1.png)、[RTL 窄浮动窗口部分折叠](Results/page-follow-ipad-matrix-20261016/rtl-resize-screenshots/98DD2AB1-A65C-496D-B4CB-C3AD87BD7DD8.png) 和 [LTR 浮动窗口部分折叠](Results/page-follow-ipad-resize-20261016/screenshots/D3545F8C-0491-4106-B11C-2ECDF4CFDD04.png)。结果包、日志、截图与源码快照保存在本地 Git 忽略目录。
- **边界：** 本轮为针对性 UI 回归，未重跑完整 iPad UI 套件、库套件、Release、真机、旧系统传统 Split View 或其他 iPad 型号。几何结论对应上述设备、窗口与 Header 状态；未进行动画逐帧采样。

## 页面根视图跟随标签栏底部

2026-10-16，统一滚动页与普通页的布局：根视图顶部跟随当前标签栏底部，左右铺满容器，底边保持在容器底边。Header 剩余展开距离由根视图位移承担，已折叠距离由滚动视图顶部 inset 承担；更新尺寸与 inset 时保留归一化滚动位置。短内容按当前视口加上剩余折叠距离补齐物理滚动范围，指示器不重复避让 Header。

- **修改前复现：** 在真实 UIWindow 中添加同级 UILabel / UIScrollView，用两种内部布局与 `.automatic` / `.never` 验证物理坐标；旧实现未折叠时根视图及 Label 比标签栏底部高 200 pt，定向用例失败。见 [修改前结果](Results/page-follow-baseline-20261016/Result.xcresult)。
- **中间回归与修复：** 首轮全库回归暴露业务 inset 在 UIKit setter 中间通知期间被重布局覆盖，以及重新发现滚动视图后仍保留旧的完整 Header inset。新增 contentInset prior 通知保护，并在绑定后立即同步布局；保留首轮 [失败结果](Results/page-follow-library1-20261016/Result.xcresult)。
- **最终完整库回归通过：** iPhone 17 Pro / iOS 26.5 / Xcode 26.6 / Debug，88 项通过、0 失败、0 跳过。新增 3 项覆盖同级 Label、滚动视图铺满或位于 Label 下方、展开/部分折叠/吸顶/正文滚动/回弹、横竖尺寸、RTL、非对称安全区域、缓存切页、短内容物理滚动范围和业务 inset 解绑恢复。见 [最终库摘要](Results/page-follow-library-final-20261016/summary.json)。已读取终态 xcresult，sourceChangedSinceRun 为空。
- **最终完整 UI 回归通过：** iPhone 18 Pro Max / iOS 27.0 / Xcode 27.1 / Debug，24 项通过、0 失败、3 项跳过（仅适用于 iPad 的 LTR/RTL 系统分屏和系统窗口缩放）。新增混合页面通过 `--mixed-page` 注入 Demo 列表页，真实触摸用例检查 Label 与标签栏 12 pt 间距、表格与 Label 8 pt 间距、窗口底边、切页、旋转、展开后新触摸再次折叠；原有刷新、短/空列表、异步替换、系统返回、RTL 和最大辅助字号矩阵一并通过。见 [最终 UI 摘要](Results/page-follow-ui-final-20261016/summary.json)。XcodeBuildMCP 等待在 300 秒时超时，持续跟踪同一 xcodebuild 进程，最终取得 TEST EXECUTE SUCCEEDED 并读取完整 xcresult；没有重启运行或将超时计为失败。最终源码与运行前快照一致，sourceChangedSinceRun 为空。 已导出并复核 [混合页面吸顶截图](Results/page-follow-ui-final-20261016/mixed-page-screenshots/EEEC3F96-121C-4B91-A959-3341C274BCAD.png)，固定说明位于标签栏下方，正文已滚动至后续行。
- **边界：** 本次未执行 iPad 实际分屏/窗口缩放、Release、真机、iOS 15 实际运行或性能压力测试。页面高度会在 Header 折叠期间连续变化；内部使用固定 frame 的业务页面仍需响应自身 bounds 变化。

## 网格 Cell 显示区域避让 Safe Area

2026-10-16，用户指出网格内部 Cell 未避开安全区域。此前全宽回归检查了网格根视图的宽度，未断言 Cell 边界；该覆盖缺口已补齐。

- **修复前复现：** iPhone 18 Pro Max / iOS 27.0 横屏安全区域左边缘为 62 pt，原 Cell 左边缘仍是 12 pt，而安全区域内加 12 pt 间距应为 74 pt。新增几何断言在旧实现上失败，见 [基线摘要](Results/grid-safe-area-baseline-20261016/summary.json)。更早的试运行因截图辅助函数只支持列表而失败，不作为布局复现证据。
- **修复：** DemoGrid 使用 `sectionInsetReference = .fromSafeArea`；Cell 宽度按相同边界扣除 section 和列间距后计算，尊重更大的 adjusted content inset。在布局或 Safe Area 变化时更新尺寸，根视图与背景保持全宽。未改动框架 `Sources`、列表实现或分页步长。
- **新增检查：** 第一排三个 Cell 必须处于同一行，左右完整落在安全区域内，并保留原有 12 pt 间距。iPhone／iPad 均覆盖 LTR、RTL 下的竖屏、左横屏、右横屏及回到竖屏；系统分屏用例增加列表→网格→列表，验证 Cell 布局及列表原有吸顶和滚动位置。
- **最终通过记录：** iPhone 网格矩阵重跑 **1 项通过**，见 [摘要](Results/grid-safe-area-iphone-retry-20261016/summary.json)；iPad 首轮网格矩阵与 RTL 系统分屏 **2 项通过**，见 [首轮摘要](Results/grid-safe-area-final-ipad-20261016/summary.json)；同一源码下 LTR 系统分屏重跑 **1 项通过**，见 [重跑摘要](Results/grid-safe-area-ipad-ltr-retry-20261016/summary.json)。三组终态均已读取，28 个源码输入哈希完全一致，`sourceChangedSinceRun` 为空。
- **失败保留：** iPhone 首轮在 RTL 重新启动后等待 `page=grid` 超时，见 [结果](Results/grid-safe-area-final-iphone-20261016/summary.json)；iPad 首轮 LTR 分屏滑动后未进入短列表，发生在新增网格断言之前。两项保持源码不变、串行 clean 重跑后均通过，不将首轮改写为全绿，也不据此宣称偶发交互问题已消除。
- **实际几何与截图：** iPhone 横屏宽 956 pt，安全视口为 x=62、宽 832 pt；Cell 为 x=74／346／618，各宽 264 pt，最后一格右边缘为 882 pt，距安全视口右边缘 12 pt。已复核 [RTL 横屏截图](Results/grid-safe-area-iphone-retry-20261016/screenshots/00440C5E-B931-4BA1-8499-ABD380DDF510.png)。iPad 分屏 412／600 pt 宽时，Cell 分别宽 124／186 pt，左右各 12 pt。
- **边界：** 本轮为 4 项针对性 UI 用例的通过记录，未在网格修改后重跑完整 UI、库测试、Release 或真机。下方完整 UI 记录对应此次网格修复之前的 Demo 源码。

## 全宽页面的完整 UI 回归：旋转、RTL 与 iPad 分屏

2026-10-16，在 `6abda58` 的框架实现上补跑完整 Demo UI 套件。两台模拟器均执行 `clean test`，无用例筛选；本轮只加强 Demo 的测试观测与 UI 测试，`Sources` 未修改。

| 最终运行 | 配置 | 通过 | 失败 | 跳过 | 结果 |
| --- | --- | ---: | ---: | ---: | --- |
| iPhone 18 Pro Max / iOS 27.0 | Xcode 27.1 / Debug | 22 | 0 | 3 | [完整套件摘要](Results/page-width-accepted-iphone-20261016/summary.json) |
| iPad Pro 11-inch (M5) (16GB) / iOS 26.5 | Xcode 26.6 / Debug | 24 | 1 | 0 | [完整套件摘要](Results/page-width-accepted-ipad-20261016/summary.json) |
| 同一 iPad，RTL 分屏独立重跑 | Xcode 26.6 / Debug | 1 | 0 | 0 | [重跑摘要](Results/page-width-accepted-ipad-rtl-retry-20261016/summary.json) |

- **失败与重跑口径：** iPad 完整套件唯一失败为 `testSystemSplitWindowsRTLPreservePositionAndPaging` 启动系统“设置”超时（`Failed to launch com.apple.Preferences`），发生在建立双应用分屏之前。保持源码不变，重新 clean 构建并单独运行该项后通过。完整套件的失败原样保留，不将其改写为一次 25 项全绿；重跑后全部适用用例均有通过记录。iPhone 的 3 项跳过分别为 LTR 分屏、RTL 分屏、系统窗口缩放，仅适用于 iPad。
- **旋转与安全区域：** 默认字号／最大辅助字号 × LTR／RTL 均经过竖屏、左横屏、右横屏、回到竖屏；直接读取 `UIWindowScene` 的原生界面方向作为旋转完成条件。检查网格和列表的左右边界、列表原生左右安全区域、选中项保持、折叠和新触摸恢复。iPhone 竖屏页面宽 440 pt；横屏宽 956 pt，左右安全区域各 62 pt，标签安全视口宽 832 pt，页面不扣减这 124 pt。
- **真实系统分屏：** 启动“设置”作为第二个应用，操作系统窗口菜单建立左右排列，要求两个窗口缩窄且不重叠。LTR 完整套件与 RTL 重跑均验证竖屏 412 × 1210 pt、横屏 600 × 834 pt、再回到竖屏；页面根视图匹配各阶段的实际窗口宽度，左右安全区域为 0。真实往返翻页后仍保持吸顶和原有内容位移，误差限保持 1 pt。旋转若使系统恢复浮动窗口，先核验浮动状态，再重新建立分屏并继续检查，不把重叠窗口当作分屏。
- **连续缩放：** 完整 iPad 套件通过 375 × 630、690 × 866、535 × 750 pt 浮动窗口及恢复全屏的检查，覆盖页面宽度、安全区域、滚动位置、吸顶边界、往返分页和新触摸滚动。
- **测试修订及影响：** 早期完整 iPad 运行出现页面底边 753 pt 与 `app.frame.maxY` 750 pt 不一致；实际窗口为 `(339, 3, 535, 750)`，页面底边正确。现按 `app.windows.firstMatch.frame` 核验窗口边界，屏幕坐标手势以 SpringBoard 为原点，避免重复叠加浮动窗口偏移。保留 [初次完整结果](Results/page-width-full-ipad-20261016/summary.json)。同时发现仅设置设备方向不足以证明界面旋转，最终套件加入原生方向断言。Demo 仅在 `--window-regression` 下暴露方向、滚动位置和左右安全区域；常规启动不改变可见内容或无障碍值。
- **证据与截图：** 已读取上述三份终态 `.xcresult`；28 个实现、测试、工程及脚本输入的 SHA-256 完全一致，且匹配当前源码，`sourceChangedSinceRun` 均为空。iPhone 与重跑取得 `TEST SUCCEEDED`，iPad 完整套件保留 `TEST FAILED`。已人工复核 [iPhone RTL 横屏吸顶](Results/page-width-accepted-iphone-20261016/rtl-screenshots/0E210B0B-0BB2-4F47-8589-8F4CA347173E.png)、[iPad LTR 横屏分屏](Results/page-width-accepted-ipad-20261016/split-screenshots/FA926DEF-0087-47D4-83CC-5A321691524F.png)、[iPad RTL 横屏分屏](Results/page-width-accepted-ipad-rtl-retry-20261016/screenshots/47C85DBC-1509-4560-BDA7-7EA563FDD67D.png) 和 [回到竖屏](Results/page-width-accepted-ipad-rtl-retry-20261016/screenshots/0F9008CA-3B2B-4DB0-A6DE-F000559C95BF.png)。结果包与截图保留在本地 Git 忽略目录。
- **边界：** 本轮没有修改框架，也未重跑库套件、Release、真机、旧系统传统 Split View、其他 iPad 型号、VoiceOver 全流程或性能压力测试。此前 85 项库通过记录对应相同框架实现，但与本轮 UI 数量分别统计。设置启动超时的偶发性尚未通过多轮重复完整套件证明消除。

## 内容页全宽与左右安全区域

2026-10-16，`viewControllerAt` 返回的页面根视图改为铺满实际容器宽度，取消分页视口对左右 Safe Area 的扣减。页面内部控件继续使用自己的安全区域；使用 `.never` 的滚动内容由业务自行避让。分页步长随实际容器宽度更新。

- **原问题复现：** 新增真实 UIWindow 几何用例在旧实现上失败；390 pt 容器、左右 32/16 pt 安全区域时，页面只有 342 pt。见 [旧实现结果](Results/page-width-before-20261016/Result.xcresult)。
- **连带问题与修复：** 只改宽度后，RTL 从窄容器切至宽容器时，缓存页左安全区域仍可能为 0。增加布局等待后仍有两处断言失败。现先对齐分页偏移再布局子页，使子页基于最终视口更新安全区域。保留原有断言，修复后通过。见 [诊断结果](Results/page-width-diagnose-20261016/Result.xcresult)。
- **完整库回归通过：** iPhone 17 Pro / iOS 26.5 / Debug，85 项通过，0 失败、0 跳过。新增用例覆盖 LTR/RTL、390×844 与 844×390 容器、非对称及零左右安全区域、滚动页/普通页及缓存切回；检查页面物理左右边界、安全区域及选择状态。原有测试同时覆盖 Header、底部边界、业务 inset、连续尺寸变化、自适应行高、分页转场和滚动位置。见 [库摘要](Results/page-width-final3-20261016/summary.json)。
- **定向 UI 回归通过：** iPhone 18 Pro Max / iOS 27.0 / Debug，5 项通过，0 失败、0 跳过。覆盖普通页拖动折叠/展开、旋转与侧滑返回、RTL 横向分页、LTR/RTL 竖屏和左右横屏的标签安全区域及触摸交互。见 [UI 摘要](Results/page-width-final-ui-20261016/summary.json)。
- 两组最终结果均读取终态 `.xcresult`，`sourceChangedSinceRun` 为空。旧实现和中间诊断不计入最终通过数量；旧源码启动的中间 UI 运行已中止，最终 UI 使用修正布局顺序后的源码重跑。
- **未执行：** 本轮未运行完整 Demo UI 套件、iPad 系统分屏/窗口缩放、Release、iOS 15 或真机测试；库中的尺寸矩阵不等同于上述系统场景。

## 标签栏滚动边缘过渡

2026-10-16，针对横屏安全区域边界将标题截成半个字的视觉反馈，保留安全视口与触摸范围，在仍有隐藏内容的一侧添加 16 pt 渐隐。渐隐随实际偏移连续变化，到达首尾或内容无需滚动时恢复不透明，RTL 按物理边界处理。

- **定向库回归：20 项通过，0 失败、0 跳过。** iPhone 17 Pro / iOS 26.5，覆盖首尾、临近端点、回弹、RTL、端点标题完整性，以及扩宽后移除遮罩、缩窄后恢复。见 [结果](Results/tab-edge-fade-20261016/library-summary.json)。
- **定向 UI：2 项通过，0 失败、0 跳过。** iPhone 18 Pro Max / iOS 27.0，覆盖默认字号横屏 LTR／RTL 的首端、收藏、末端选择和手动拖动，以及最大辅助字号 RTL 的竖屏、左右横屏、吸顶与恢复。补充小幅拖动截图后，边缘用例单独重跑 1 项通过。见 [首次结果](Results/tab-edge-fade-20261016/ui-summary.json) · [补图重跑](Results/tab-edge-fade-20261016/ui-scrolled-summary.json)。
- **视觉检查：** 已检查默认字号 LTR／RTL 的端点及手动滚动截图，确认端点标题清晰，经过边界的文字和指示器渐隐。见 [LTR 滚动中](Results/tab-edge-fade-20261016/screenshots/tab-edge-ltr-scrolled.png) · [RTL 滚动中](Results/tab-edge-fade-20261016/screenshots/tab-edge-rtl-scrolled.png)。
- **证据边界：** 读取三份终态 `.xcresult`。首次 UI 验证后仅补充边缘用例截图，库源码保持一致；补图重跑后的源码输入哈希与当前版本一致。本轮未重跑完整库、完整 Demo UI、Release、iPad、真机或性能基准。下方 83 项完整库与 12 组合记录对应渐隐修改前的安全区域版本。

## 标签栏安全区域、长标题与 Dynamic Type

2026-10-16，使用 Xcode 27.1 / Debug，完成截图对应 iPhone 18 Pro Max / iOS 27.0 的 UI 验证，并在 iPhone 18 Pro Max / iOS 27.0、iPhone 17 Pro / iOS 26.5 上执行完整库测试。

- **修复：** 标签栏背景使用容器全宽，内部 Collection View、指示器和触摸命中共用左右安全视口；安全区域变化会重新对齐选中项，RTL 不交换物理左右 inset。只有最长标题也能放入均分项时才使用等宽；否则保留标题固有宽度，再分配剩余空间或横向滚动。此策略替代下方历史“自适应标签宽度”记录中的总宽度均分条件。
- **大字体：** `tabBarHeight` 作为最小高度（0 仍隐藏），默认标签栏通过 `sizeThatFits(_:)` 按字体行高预留上下空间和指示器空间；容器同步调整页面起点。独立使用或自定义子类的高度与安全区域约定已同步到主 README。
- **修复前：** 两项新增／修订回归均失败，分别覆盖背景宽度与左右安全区域命中，以及不等长标题的均分挤压。见 [基线结果](Results/safe-area-tabs-20261016/baseline/summary.json)。
- **最终完整库：** iOS 27.0 和 iOS 26.5 各 **83 项通过，0 失败，0 跳过**。真实 UIWindow 断言覆盖非对称 inset 交换、LTR／RTL 首尾按钮命中、背景全宽、字号增大及恢复、文字垂直空间、页面起点和高度 0。见 [iOS 27 摘要](Results/safe-area-tabs-20261016/library-ios27/summary.json) · [iOS 26 摘要](Results/safe-area-tabs-20261016/library-ios26/summary.json)。
- **最终定向 UI：7 项通过，0 失败，0 跳过。** 其中四项矩阵用例覆盖竖屏、左横屏、右横屏 × LTR／RTL × 默认字号／最大辅助字号，共 12 个组合；每个组合验证首尾切页、选中项对齐、旋转后的选择保持、标签栏纵向拖动吸顶及新触摸恢复展开，保存展开和吸顶共 24 张截图。另三项覆盖按钮按住后横向拖动、系统返回和旋转、纵向拖动不误选。见 [最大字号 RTL](Results/safe-area-tabs-20261016/ui-large-rtl/summary.json) · [其余六项](Results/safe-area-tabs-20261016/ui-matrix/summary.json) · [截图](Results/safe-area-tabs-20261016/screenshots)。
- **测试夹具修订：** 首轮 UI 暴露了继承初始横屏方向、对裁切按钮查询 `isHittable` 失败，以及默认列表 swipe 路径无法可靠驱动横屏折叠的问题。现每项从竖屏开始，点击安全视口中真实可见的按钮区域，再断言选择与对齐；折叠／展开使用标签栏上的真实纵向拖动，后续触摸继续消耗正文位移。保留首轮 [失败摘要](Results/safe-area-tabs-20261016/initial-ui/summary.json)，未放宽最终几何和状态断言。
- **证据边界：** 已读取四份最终终态 `.xcresult`，输入文件哈希与当前源文件匹配，`sourceChangedSinceRun` 为空。未执行完整 Demo UI 套件、Release、iPad、真机、VoiceOver 全流程或性能基准。见 [本轮汇总](Results/safe-area-tabs-20261016/summary.json)。

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
