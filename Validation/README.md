# StickyPagerKit 验证记录

验证日期：2026-10-15 至 2026-10-20。范围为首版框架、Demo 和本仓库测试。各次结果与运行时源码 SHA-256 绑定；工程迁移前后的结果分别记录。

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
