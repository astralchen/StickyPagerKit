# StickyPagerKit 验证记录

验证日期：2026-10-15 至 2026-10-19。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

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
