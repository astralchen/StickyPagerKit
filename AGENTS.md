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
| `Examples/StickyPagerDemo/` | 独立 Demo 工程、`Config/*.xcconfig`、Demo 单元测试和 UI 测试 |
| `Scripts/` | 验证执行与结果摘要脚本 |
| `Validation/README.md` | 历次验证证据、失败记录与未覆盖范围 |

公开行为和接入方式以 `README.md` 为入口；最小 containment 示例见 `Examples/StickyPagerDemo/StickyPagerDemo/MinimalIntegration.swift`，系统容器示例见同目录 `DemoSystemContainer.swift`。

Demo 通过本地 Package 引用根目录库，包含 `StickyPagerDemo`（应用）、`StickyPagerDemoTests`（Demo 单元测试）和 `StickyPagerDemoUITests`（UI 测试）三个 target。共享 scheme `StickyPagerDemo` 使用应用 target 进行构建和运行，其 Test Action 配置了两个测试 target：`StickyPagerDemoTests` 和 `StickyPagerDemoUITests`。根目录的 `StickyPagerKitTests` 由 `Package.swift` 独立管理，不要将库测试源码加入 Demo 的任何 target，也不要将 `StickyPagerKitTests` 加入 Demo scheme。工程采用 `PBXFileSystemSynchronizedRootGroup`，已关联目录中的新文件通常自动参与所属 target，具体以目录关联和成员排除配置为准，无需逐文件添加引用；新增 target 或调整目录与 target 的关联时仍需更新工程配置。

`StickyPagerDemoTests` 是以 `StickyPagerDemo` 应用为宿主的单元测试 target，用于测试 Demo 自身的逻辑、视图控制器和接入行为；需要访问 Demo 内部类型时使用 `@testable import StickyPagerDemo`，涉及 UIKit 的测试保持主 actor 隔离。框架回归测试放在根目录 `StickyPagerKitTests`；真实点击、拖动和分页手势由 `StickyPagerDemoUITests` 验证。

## 修改方式与代码约定

- 开始修改前检查 `git status --short`、相关 diff 和适用的目录规则，保留用户已有修改；不擅自提交或推送。
- 遇到不熟悉的功能时，先调研 GitHub 上维护活跃、许可证明确的同类开源项目，比较实现思路、依赖和已知问题，优先借鉴成熟设计；引用代码前确认来源可靠、许可证与本项目兼容。
- 遵循邻近源码：`SP` 类型前缀、类型使用 UpperCamelCase、成员使用 lowerCamelCase、四空格缩进，公开说明使用中文 `///`。
- 保留公开扩展点的 `open` / `public` 语义；实现细节使用 `internal` / `private`，不要仅为测试扩大公开 API。库测试使用 `@testable import StickyPagerKit`。
- 保持主 actor 隔离、弱数据源与弱代理关系。新增系统 API 应保留 iOS 15 的可用性边界和旧系统路径，不为消除编译错误直接提高部署目标。
- 输入处理保持现有契约：布局数值归一化、越界选择忽略、重复页面标识拒绝整次快照并保留旧状态，不改成崩溃或部分更新。
- 公开行为或接入方式变更时同步 `README.md`；运行结果记录在 `Validation/README.md`，本指南只保留长期约定。
- Swift 文件统一使用根目录 `.swiftformat` 和 Package 锁定的 SwiftFormat 0.64.0，按 `README.md` 的命令格式化相关文件。`Scripts/format.sh` 覆盖框架、测试与 Demo，支持 `--lint`；Demo 的 Build Phase 在编译前自动执行，失败会中止构建，单独构建 Package 不会触发。除该构建流程或用户要求外，不顺手全仓格式化。

## 需要保持的行为边界

- **布局与安全区域：** Header 总高度包含顶部安全区域，折叠范围为 `max(0, headerHeight - safeTop - minimumHeaderHeight)`。页面根视图顶部与当前标签栏顶部对齐，宽度和底边延伸至容器边界；标签栏在页面上方，框架通过子控制器附加安全区域及必要的滚动 inset 避让其遮挡。内部控件及滚动内容分别通过 Safe Area 和 `adjustedContentInset` 避让系统栏，不重复扣除系统栏高度；详见 `README.md` 的“滚动坐标与布局”。
- **滚动所有权：** `SPScrollBinding` 保留业务 delegate，只管理框架贡献的 inset，并在解绑时恢复业务设置。每页只协调一个主要纵向滚动视图；复杂页面允许显式绑定，异步替换后重新发现。普通页面不额外包装滚动容器。
- **分页与生命周期：** 页面以稳定标识复用和保存位置；转场取消、重载、缓存淘汰和尺寸变化不能让旧页回调覆盖当前状态。保持 containment、appearance 转发及选中提交时机。RTL 改变视觉排列，不改变逻辑索引。
- **嵌套横向滚动：** 内部 Section 在可滚动方向优先处理手势，到边界后下一次向外拖动可交给外层分页；归属在手势开始时判定，不在拖动中途抢占，并兼顾 RTL 和系统返回手势。
- **标签模型和外观：** `SPTabBarItem` 按对象身份区分；Appearance 赋值时复制，通过宿主 getter 修改时实时刷新。保持显式颜色与自动 `tintColor` 的优先级，以及点击、程序化选择、分页手势的不同回调语义。布局变化需兼顾 Dynamic Type、左右安全区域和 RTL。

## 本机 Xcode 外部代理授权

- 当前 Mac、当前 macOS 用户下的所有本机外部代理已获持续访问 Xcode 工具的授权，包含跨重启的自动允许；同一范围内使用或维护连接时不重复请求确认。
- 维护连接时保留现有工作状态，避免中断构建、调试或未保存的编辑。兼容性问题按当前 Xcode 版本处理。
- 此授权不延伸至其他机器、用户或具体任务之外的操作。

## 构建与测试命令

- 优先使用 Apple 官方 Xcode MCP（通过 `xcrun mcpbridge` 桥接）执行构建与测试，以当前会话可用的接口为准。服务注册名称可自定义，`XcodeBuildMCP` 是独立的第三方工具。
- 执行前确认目标工程或 Package、scheme 和运行环境；官方 MCP 不可用或无法完成所需操作时，可回退到下述脚本与 `xcodebuild` 流程，并简要说明原因。
- 按用户要求的任务范围使用工具；仅要求只读检查时，不执行构建、运行或测试。

以下命令在仓库根目录执行，需要兼容的完整 Xcode、iOS Simulator 和 `python3`。库依赖 UIKit，不能直接以 macOS 为目标运行 `swift test`；真机运行另需签名 Team。

`Scripts/validate.sh` 内置本机 Xcode 路径和模拟器 UUID，使用前通过以下变量指定实际环境，无需修改全局 `xcode-select`：

```sh
export SP_DEVELOPER_DIR="<实际 Xcode.app 路径>/Contents/Developer"
DEVELOPER_DIR="$SP_DEVELOPER_DIR" xcrun simctl list devices available
export SP_SIMULATOR_ID="<实际模拟器 UUID>"

# Demo 构建；脚本默认 SP_SCOPE=demo、SP_CONFIGURATION=Debug
SP_SCOPE=demo Scripts/validate.sh build

# 库测试与 Demo 测试（单元测试和 UI 测试）
SP_SCOPE=library Scripts/validate.sh test
SP_SCOPE=demo Scripts/validate.sh test

# Release 库测试需要允许 @testable 导入
SP_SCOPE=library SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES

# 聚焦验证示例；额外参数直接传给 xcodebuild
SP_SCOPE=library Scripts/validate.sh test -only-testing:StickyPagerKitTests/SPPagingScrollViewTests
SP_SCOPE=demo Scripts/validate.sh test -only-testing:StickyPagerDemoUITests/CompositionalGestureTests
```

结果保存到 `Validation/Results/<运行名>/`，构建产物保存到 `Validation/Products/`。运行名默认按时间生成；设置 `SP_RUN_NAME` 时使用新名称。测试结束后用同一 Xcode 生成摘要并检查 diff：

```sh
DEVELOPER_DIR="$SP_DEVELOPER_DIR" python3 Scripts/summarize_validation.py "Validation/Results/<运行名>"
git diff --check
```

## 验证原则

先运行受影响的聚焦测试，再按改动扩大范围。MCP 与命令行遵循相同要求，库测试与 Demo UI 测试不能互相替代。

| 改动 | 验证范围 |
| --- | --- |
| 容器、几何、绑定、发现、缓存或生命周期 | 相关 `StickyPagerKitTests`；影响交互时补 Demo UI 测试 |
| 标签模型、外观或布局 | 对应 `SPTabBar*Tests`；影响容器或交互时补相关库测试或 Demo UI 测试 |
| 分页或嵌套滚动仲裁 | `SPPagingScrollViewTests`、容器分页测试及 `CompositionalGestureTests` 的真实触摸 |
| Demo 系统容器、安全区域或系统栏 | `SystemContainerTests`，按影响覆盖 iPhone／iPad、旋转和 RTL |
| Package、工程或构建配置 | 受影响的库／Demo 构建和测试；按变更补 Release 与工具链兼容性验证 |
| 仅文档 | 核对路径、命令和描述，检查 diff；无需构建或测试 |

- UIKit 几何测试使用真实 `UIWindow`，检查 frame、inset、offset 和恢复行为；手势使用 Demo UI 测试，拖动距离按视口计算。
- 布局改动兼顾 RTL、安全区域、尺寸变化、缓存页及短／空内容；标签同时考虑长标题和 Dynamic Type。
- 依据当前源码对应的终态结果报告“通过 / 失败 / 未执行 / 被环境阻塞”，说明未覆盖范围；构建成功不代表运行时通过。脚本摘要中的 `sourceChangedSinceRun` 用于核对源码一致性。

## 文件与证据边界

- `.build/`、`.swiftpm/`、`DerivedData/`、`Validation/Products/`、`Validation/Results/` 和 `xcuserdata/` 属于忽略的本地生成内容，不作为源码编辑或强制加入 Git。
- `Validation/README.md`、`Validation/final-evidence.json` 及已跟踪截图是历史证据，不能从旧结果推定当前源码已验证，也不要为了得到干净结果删除失败证据。
