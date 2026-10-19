# StickyPagerKit 工作指南

本文件适用于整个仓库。若子目录另有 `AGENTS.md`，同时遵守其适用范围内的规则。说明、注释和工作报告使用简体中文，API 名称、标识符、命令和路径保留原文。

## 项目与入口

StickyPagerKit 是通过 Swift Package Manager 分发的 UIKit 粘性 Header 与横向分页容器，支持 iOS 15+，不依赖第三方运行时库。`Package.swift` 声明 Swift tools 6.3、Swift 6 语言模式；涉及 UIKit 的主要类型使用 `@MainActor`。

| 路径 | 职责 |
| --- | --- |
| `Sources/StickyPagerKit/Container/SPPageViewController.swift` | 容器入口、页面缓存、布局、切页及控制器生命周期 |
| `Sources/StickyPagerKit/Interfaces/` | 数据源与代理协议 |
| `Sources/StickyPagerKit/Layout/` | Header 与标签栏高度配置、状态 |
| `Sources/StickyPagerKit/TabBar/` | 标签对象、外观、测量、布局和交互 |
| `Sources/StickyPagerKit/Internal/` | 滚动几何、绑定、发现与分页手势仲裁 |
| `Tests/StickyPagerKitTests/` | 根目录 Package 管理的 XCTest 库测试 |
| `Examples/StickyPagerDemo/` | 独立 Demo 工程、`Config/*.xcconfig` 和 UI 测试 |
| `Scripts/` | 验证执行与结果摘要脚本 |
| `Validation/README.md` | 历次验证证据、失败记录与未覆盖范围 |

公开行为和接入方式以 `README.md` 为入口；最小 containment 示例见 `Examples/StickyPagerDemo/StickyPagerDemo/MinimalIntegration.swift`，系统容器示例见同目录 `DemoSystemContainer.swift`。

Demo 工程只包含 `StickyPagerDemo` 和 `StickyPagerDemoUITests` 两个 target，通过本地 Package 引用根目录库。不要把 `StickyPagerKitTests` 加入 Demo target 或测试 scheme。工程采用 `PBXFileSystemSynchronizedRootGroup`，对应源码目录中的新文件自动参与所属 target；通常无需逐文件修改 `project.pbxproj` 或重新生成工程。

## 修改方式与代码约定

- 开始修改前检查 `git status --short`、相关 diff 和适用的目录规则，保留用户已有修改；不擅自提交或推送。
- 遵循邻近源码的组织和排版。现有惯例为 `SP` 类型前缀、类型使用 UpperCamelCase、成员使用 lowerCamelCase、四空格缩进、公开说明使用中文 `///`。这些是源码惯例，不是自动格式化配置。
- 保留公开扩展点的 `open` / `public` 语义；实现细节使用 `internal` / `private`，不要仅为测试扩大公开 API。库测试使用 `@testable import StickyPagerKit`。
- 保持主 actor 隔离、弱数据源与弱代理关系。新增系统 API 应保留 iOS 15 的可用性边界和旧系统路径，不为消除编译错误直接提高部署目标。
- 输入处理遵循现有接口契约：布局数值归一化、越界选择忽略、重复页面标识拒绝整次快照并保留旧状态。不要随意改成崩溃或部分更新；相关逻辑见 `SPPageLayout`、`SPScrollGeometry` 和容器实现。
- 公开行为或接入方式变更时同步 `README.md`；验证事实写入 `Validation/README.md`，不把临时进度、测试数量或某次成功结果固化到本指南。
- 仓库目前没有 CI 工作流、SwiftFormat 或 SwiftLint 配置，也没有统一格式化／静态检查脚本。不要把未配置的工具当作必需步骤，或顺手全仓格式化。

## 需要保持的行为边界

- **布局与安全区域：** Header 总高度包含顶部安全区域，折叠范围为 `max(0, headerHeight - safeTop - minimumHeaderHeight)`。页面根视图顶部跟随当前标签栏底部，宽度和底边延伸至容器边界。内部控件及滚动内容分别通过 Safe Area 和 `adjustedContentInset` 避让系统栏，不重复扣除系统栏高度。修改时联查页面 frame、内部内容、inset、offset 和短内容滚动范围；详见 `README.md` 的“滚动坐标与布局”。
- **滚动所有权：** `SPScrollBinding` 保留业务 delegate，只管理框架贡献的 inset，并在解绑时恢复业务设置。每页只协调一个主要纵向滚动视图；复杂页面允许显式绑定，异步替换后重新发现。普通页面不额外包装滚动容器。
- **分页与生命周期：** 页面以稳定标识复用和保存位置；转场取消、重载、缓存淘汰和尺寸变化不能让旧页回调覆盖当前状态。保持 containment、appearance 转发及选中提交时机。RTL 改变视觉排列，不改变逻辑索引。
- **嵌套横向滚动：** 内部 Section 在可滚动方向优先处理手势，到边界后下一次向外拖动可交给外层分页；归属在手势开始时判定，不在拖动中途抢占。检查外层首尾、RTL、斜向拖动和系统返回手势，参见 `SPPagingScrollView.swift` 与 `CompositionalGestureTests.swift`。
- **标签模型和外观：** `SPTabBarItem` 按对象身份区分；Appearance 赋值时复制，通过宿主 getter 修改时实时刷新。保持显式颜色与自动 `tintColor` 的优先级，以及点击、程序化选择、分页手势的不同回调语义。布局变化需兼顾 Dynamic Type、左右安全区域和 RTL。

## 构建与测试命令

以下命令在仓库根目录执行。需要完整 Xcode、支持 Package 声明及源码 API 的 Swift 编译器／iOS SDK、可用的 iOS Simulator 和 `python3`。库依赖 UIKit，不能直接以 macOS 为目标运行 `swift test`。

`Scripts/validate.sh` 默认使用 `/Applications/Xcode-26.6.app/Contents/Developer` 和一个固定模拟器 UUID。执行前确认本机环境，通过以下变量覆盖；尖括号内容须替换为实际值。脚本在进程内设置 `DEVELOPER_DIR`，不需要修改全局 `xcode-select`。

```sh
export SP_DEVELOPER_DIR="<实际 Xcode.app 路径>/Contents/Developer"
DEVELOPER_DIR="$SP_DEVELOPER_DIR" xcrun simctl list devices available
export SP_SIMULATOR_ID="<实际模拟器 UUID>"

# Demo 构建；脚本默认 SP_SCOPE=demo、SP_CONFIGURATION=Debug
SP_SCOPE=demo Scripts/validate.sh build

# 两套测试独立执行，不能互相替代
SP_SCOPE=library Scripts/validate.sh test
SP_SCOPE=demo Scripts/validate.sh test

# Release 库测试需要允许 @testable 导入
SP_SCOPE=library SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES

# 聚焦验证示例；额外参数直接传给 xcodebuild
SP_SCOPE=library Scripts/validate.sh test -only-testing:StickyPagerKitTests/SPPagingScrollViewTests
SP_SCOPE=demo Scripts/validate.sh test -only-testing:StickyPagerDemoUITests/CompositionalGestureTests
```

`SP_RUN_NAME` 可指定运行目录名，默认按时间生成。每次使用新的名字，避免已有 `.xcresult` 冲突。脚本保存工具链、`source-hashes.json`、`xcodebuild.log` 和 `Result.xcresult` 到 `Validation/Results/<运行名>/`，构建产物写入 `Validation/Products/`。测试结束后，使用同一 Xcode 生成摘要：

```sh
DEVELOPER_DIR="$SP_DEVELOPER_DIR" python3 Scripts/summarize_validation.py "Validation/Results/<运行名>"
git diff --check
```

这些命令来自当前脚本与项目配置；列出命令不表示已在当前环境执行通过。真机运行另需配置签名 Team。

## 按改动选择验证

| 改动 | 验证范围 |
| --- | --- |
| 容器、几何、绑定、发现、缓存或生命周期 | 相关 `StickyPagerKitTests`；影响交互时补 Demo UI 测试 |
| 标签模型、外观或布局 | `SPTabBarModelTests`、`SPTabBarTests`；影响容器高度或选择时补容器测试；可见交互用 Demo 验证 |
| 分页或嵌套滚动仲裁 | `SPPagingScrollViewTests`、容器分页测试及 `CompositionalGestureTests` 的真实触摸 |
| Demo 系统容器、安全区域或系统栏 | `SystemContainerTests`，按影响覆盖 iPhone／iPad、旋转和 RTL |
| Package、工程或构建配置 | 受影响的库／Demo 构建和测试；按变更补 Release 与工具链兼容性验证 |
| 仅文档 | 核对路径、命令及描述与源码一致，并检查 diff；无需仅为文档运行完整构建或测试 |

先运行受影响的聚焦测试，再按改动影响扩大验证。UIKit 几何测试沿用真实 `UIWindow` 夹具，断言物理 frame、inset、offset 和恢复行为；真实手势、减速、系统返回、分屏及窗口缩放由 Demo UI 测试验证。拖动距离依据实际视口计算，避免固定像素在窄窗口失效。涉及自适应布局时检查 RTL、旋转、缓存页面、短／空内容及内部 Safe Area；标签改动同时检查长标题和辅助字号。

报告明确区分“通过 / 失败 / 未执行 / 被环境阻塞”。读取同次运行的终态日志和 `.xcresult`，检查摘要中的 `sourceChangedSinceRun`；摘要缺失、工具超时或进程仍在运行均不能据此宣称测试通过。保留首次失败、聚焦复测和最终回归的区别；构建成功不等于运行时验收，iOS 15 部署目标也不等于 iOS 15 实际运行通过。

## 文件与证据边界

- `.build/`、`.swiftpm/`、`DerivedData/`、`Validation/Products/`、`Validation/Results/` 和 `xcuserdata/` 属于忽略的本地生成内容，不作为源码编辑或强制加入 Git。
- `Validation/README.md`、`Validation/final-evidence.json` 及已跟踪截图是历史证据，不能从旧结果推定当前源码已验证，也不要为了得到干净结果删除失败证据。
- 当前 Package 没有第三方依赖或需要维护的生成源码目录；`.gitignore` 中的 CocoaPods、Carthage 和 fastlane 模板条目不代表项目使用了这些工具。
