# SPTabBar P0～P4 契约与验收索引

整理日期：2026-11-05；基于 `codex/container-architecture-refactor`、`169f78d` 及本次归档工作区。本文是源码、测试和历史证据的索引，不是新一轮运行报告。阶段中的“通过”仅适用于原记录的源码指纹和环境；当前验证边界见 [验证记录](README.md)。

## 阶段与交付状态

| 原计划 | 实际交付与提交 | 完成判断 | 回退边界 |
| --- | --- | --- | --- |
| P0 固化契约 | `eb2c61a` 包含重构前契约基线和新增回归；本索引补齐集中行为矩阵 | 契约、测试和索引已交付 | P0 基线先于生产拆分运行；没有单独的 P0 可回退提交 |
| P1 内容解析与测量 | `eb2c61a` 提取 Environment／Resolver；后续 `d899241` 扩展快照和缓存 | 已完成 | 内容与选择状态职责分离；后续代码已依赖该分层，不承诺直接撤销早期提交可编译 |
| P2 选择呈现与动画 | `eb2c61a` 提取 PresentationCoordinator | 已完成 | 保留容器切页机制与唯一已提交选择；回退不能丢失后续动画和重入保护 |
| P3 布局事务与失效范围 | `b03a787` 实现 P3A＋P3B；`9db7b3b` 的 P4A 补齐原计划布局提交顺序 | 已完成 | 轻量路径可在保留 P1/P2 分层下重新采用完整刷新；未实际实施并验证回退 |
| P4 按需求扩展 | P4B `d899241`、P4C `d7cb859`、P4D `1b82c29`、P4E `c34461c` | 已选能力完成，兼容性矩阵仍有未覆盖项 | P4B 为获授权的内容代理契约调整；其余可选视觉能力默认保持原有呈现。禁用效果不等于版本回退验收 |

`.default` → `.standard` 的命名调整独立提交于 `27b52d9`，未保留旧名别名。不能把 P0～P4 整体描述为所有公开 API 始终不变。P4A 的工作属于原计划 P3，不能仅凭阶段名称判断完成度。

## 行为契约与测试矩阵

以下路径均为当前正式测试集合中的源码。测试存在不等于本次执行通过；历史结果入口见后文。

| 阶段／契约 | 实现边界 | 可审查测试与验收点 |
| --- | --- | --- |
| P0：点击候选与逻辑提交分离；程序选择不冒充点击 | [SPTabBar](../Sources/StickyPagerKit/TabBar/SPTabBar.swift) 保留已提交选择、代理调用与公开入口；协调器只管理呈现 | [SelectionContractTests](../Tests/StickyPagerKitTests/SPTabBarSelectionContractTests.swift)：`testDidSelectCanRequestNextItemWithoutDuplicateCommit`；既有 [ModelTests](../Tests/StickyPagerKitTests/SPTabBarModelTests.swift) 核对选择与回调 |
| P0：允许选择回调重入，旧请求不得覆盖新请求 | 请求代次和 Item 身份检查 | SelectionContractTests：`testShouldSelectReplacementInvalidatesOriginalRequest`、`testNestedShouldSelectRequestSupersedesOuterRequest` |
| P0：保留公开 override 调用链和同步观察 | 属性入口、容器同步与公开方法动态分发 | SelectionContractTests：`testPropertiesAndContainerSynchronizationPreserveOpenDispatch`；LayoutCommitTests：`testSelectionReentryWithPendingLayoutDoesNotCommitOriginalRequest` |
| P1：测量候选不能改变当前显示状态；临时测量视图不长期持有 | [ContentResolver](../Sources/StickyPagerKit/TabBar/SPTabBarContentResolver.swift) 分离 candidate／applied，显式应用测量 | [AutomaticContentTests](../Tests/StickyPagerKitTests/SPTabBarAutomaticContentTests.swift)：`testCandidateMeasurementsAreIsolatedCachedAndReleaseTemporaryViews`、`testItemSpacingParticipatesInAutomaticMeasurementWithoutCommittingCandidateWidths` |
| P1：保留宽度分配、自动高度、无效测量回退和兼容视图复用 | [ContentEnvironment](../Sources/StickyPagerKit/TabBar/SPTabBarContentEnvironment.swift) 生成配置，Resolver 测量，原内容视图应用配置 | AutomaticContentTests：`testAutomaticAndExplicitSizesCoexistAndInvalidMeasurementFallsBack`、`testAutomaticContentMeasuresMultilineHeightAtAllocatedWidth`；[CustomContentTests](../Tests/StickyPagerKitTests/SPTabBarCustomContentTests.swift) 核对复用及回退 |
| P2：程序动画、分页和连续改选共享呈现状态；旧动画不得终止新动画 | [PresentationCoordinator](../Sources/StickyPagerKit/TabBar/SPTabBarPresentationCoordinator.swift) 管理互斥运动状态、时钟和代次；宿主用同一 Frame 应用指示器与偏移 | [PresentationCoordinatorTests](../Tests/StickyPagerKitTests/SPTabBarPresentationCoordinatorTests.swift)：`testOldCompletionCannotStopAnimationStartedWhileApplyingFrame`、`testPagingTakeoverRejectsLaterAnimationTicksAndResetDropsOrigin` |
| P2：取消、反向、跨多项选择与 RTL 保持一致 | 逻辑索引与物理几何分离；分页接管使用当前呈现起点 | [IndicatorTests](../Tests/StickyPagerKitTests/SPTabBarIndicatorTests.swift)、[SelectionProgressTests](../Tests/StickyPagerKitTests/SPTabBarSelectionProgressTests.swift)：`testPagingTakesOverAnimationAndNonadjacentProgressUsesOnlyEndpoints`；真实触摸见阶段 Demo 结果，不用模型测试代替 |
| P3：按刷新原因减少确定无必要的工作，未知几何依赖继续复核 | [SPTabBarChange](../Sources/StickyPagerKit/TabBar/SPTabBarRefresh.swift) 区分内容、装饰、无障碍、单项呈现和指示器变化 | [RefreshTests](../Tests/StickyPagerKitTests/SPTabBarRefreshTests.swift)：`testStandardRefreshWorkIsLimitedToAffectedPresentation`、`testGeometryChangesStillInvalidateMeasurementAndReflow`、`testCustomIndicatorGeometryStillReactsToLightweightItemChange` |
| P3：保留共享 Item、整栏选中外观、手动偏移与分页进度 | Item 身份通知；选中 Item 的 Appearance 仍属于全栏环境 | RefreshTests：`testSharedItemUpdatesEachHostAndOffscreenContentAppearsCurrent`、`testSelectedItemAppearanceRemainsBarWideAndCopied`、`testRefreshPreservesAnimationPagingAndManualOffsetInBothDirections` |
| P3／P4A：先提交视口及附件，再提交内容几何、运动状态，最后呈现 | `commitLayoutGeometry` 内抑制中间滚动回调呈现；切页入口同步布局，不增加异步提交队列 | [LayoutCommitTests](../Tests/StickyPagerKitTests/SPTabBarLayoutCommitTests.swift)：`testContentAndViewportChangesRenderOnlyCommittedGeometryAndPreserveManualOffset`、`testTransitionEntryFlushesPendingLayoutBeforeTakingOrigin`、`testViewportOnlyResizeAlignsSelectionWithoutRepeatedContentResolution` |
| P4B：单项只读快照、有界复用、外部依赖显式刷新 | [ContentItem](../Sources/StickyPagerKit/TabBar/SPTabBarContentItem.swift)／Context；每项最多两个输入组合；外部数据变化调用 `reloadContent()` | [ContentCacheTests](../Tests/StickyPagerKitTests/SPTabBarContentCacheTests.swift)：`testItemChangesUseOneSnapshotAndExternalDataRequiresReload`、`testSnapshotAppearanceAndAttributesCannotMutateItem`、`testReorderUsesNewIndexAndRemovalDoesNotRetainItem`、`testPerItemCacheIsBoundedAndCandidateDoesNotReplaceAppliedContents` |
| P4C：自定义连续进度需显式开启，不改变逻辑选择，不逐帧请求内容代理或测量 | [SelectionProgress](../Sources/StickyPagerKit/TabBar/SPTabBarSelectionProgress.swift) 提供有界状态值 | SelectionProgressTests：`testPagingProgressPreservesLogicalSelectionAndDoesNotRequestOrMeasure`、`testProgressUpdatesReuseViewAndPreserveHighlightWithoutOptingLegacyContentIn`、`testContentOnlyAnimationAndRepeatedSelectionContinueFromAllCurrentWeights` |
| P4D：淡化、拉伸为通用可选效果，保留端点与 RTL | [VisualStyle](../Sources/StickyPagerKit/TabBar/SPTabBarVisualStyle.swift) | [VisualStyleTests](../Tests/StickyPagerKitTests/SPTabBarVisualStyleTests.swift)：`testStandardAndNormalizedStylesPreserveLayoutAndRemainHittable`、`testFadeUsesContinuousProgressWithoutReconfigurationOrMeasurement`、`testStretchKeepsEndpointsAndMirrorsForwardAndReverseInRTL` |
| P4E：缩放与布局／命中分离，弹簧装饰进度不能泄露为越界业务进度 | 独立视觉层；[AnimationStyle](../Sources/StickyPagerKit/TabBar/SPTabBarAnimationStyle.swift) 分离程序弹簧与有界颜色／内容进度 | [ScaleTests](../Tests/StickyPagerKitTests/SPTabBarScaleTests.swift)、[SpringTests](../Tests/StickyPagerKitTests/SPTabBarSpringTests.swift)：`testSpringRetargetPreservesPositionAndVelocityWhilePublicProgressIsBounded`；SelectionProgressTests：`testSpringScaleDoesNotLeakOvershootIntoCustomConfigurationAndRetargetsWithoutRebuilding` |
| P4E：默认图文颜色可选连续过渡，保留状态、traits、显式颜色与原色图像边界 | 基础内容快照与连续呈现分离，不缓存上一帧完整配置作为下一帧输入 | [ColorTransitionTests](../Tests/StickyPagerKitTests/SPTabBarColorTransitionTests.swift)：`testDefaultRemainsDiscreteAndOptInCrossesMidpointContinuously`、`testFramesReuseImageAndDoNotRequestOrMeasureContent`、`testExplicitTitleAttributesDisabledAndOriginalImage`、`testTintAndDynamicTraitsRefreshEndpointsWithoutLosingProgress` |

P4B 的“局部更新”指 Item 自动失效与逐项缓存复用；当前没有公开的任意指定 Item 外部数据刷新入口。`reloadContent()` 仍用于外部依赖整体刷新。这不影响本轮已选范围完成，也不构成新增 API 的待办承诺。

## 历史验收入口

原始结果位于本地忽略目录，仓库克隆后可能不可用；可分发的结论、失败原因及未覆盖范围在 [Validation/README.md](README.md)。下列条目不是本次重新运行。

| 阶段 | 历史结果 | 必须保留的限制／失败 |
| --- | --- | --- |
| P0～P2 | [P0 契约基线 4/4](Results/20261102-tabbar-p0-contract/summary.json)、[最终 Debug 库 389/389](Results/20261102-tabbar-final-debug/summary.json)、[Demo 修复后 15/15](Results/20261102-tabbar-demo-label-fix-mcp/summary.json) | 首轮 Demo 诊断标签影响 UI 查找，修复 Demo 后聚焦补验；不能把此前 UI 批次计作修复后全矩阵重跑 |
| P3A＋P3B | [完整库 397/397](Results/20261102-tabbar-p3-final-library/summary.json)、[Demo 15/15](Results/20261102-tabbar-p3-demo-mcp/summary.json) | 保留优化前预期失败、首轮屏幕外 Cell 夹具崩溃及 appearance 诊断；工作量减少不等于耗时收益 |
| P4A | [最终完整库 401/401](Results/20261102-tabbar-p4a-library-verified/summary.json)、[Demo 16/16](Results/20261102-tabbar-p4a-demo/summary.json) | 首轮 appearance 警告根因未确认；后续复验通过不能注销首次诊断 |
| P4B | [最终完整库 407/407](Results/20261102-tabbar-p4b-library-verified/summary.json)、[最终 Demo 18/18](Results/20261102-tabbar-p4b-demo-verified/summary.json) | 保留旧代理契约迁移导致的测试失败、Demo 编译失败和动画等待异常；按目标核对源码，不能合并成一次全绿运行 |
| P4C／P4D | 验证记录中的“自定义内容连续选择进度与 Demo 视觉过渡（P4C）”“内置视觉预设与指示器拉伸（P4D）”两节 | 各节保留独立专项、Demo 结果和未执行项；后续 P4E 全库结果是补充，不能覆盖原过程 |
| P4E | [完整 Debug 库 445/445](Results/20261103-tabbar-p4e-final-debug/summary.json)、[最终 Release 性能采样 4/4](Results/20261103-tabbar-performance-release-verified/summary.json)、[iPad UI 补跑 2/2](Results/20261103-tabbar-ipad-ui-recovery/summary.json)；Release 441 项完整库结果见原记录 | 不拼成一次 Release 445 项；保留 Runner 准备失败、模拟器关闭及等待异常；性能用例通过不是性能预算达标 |
| 后续兼容性补充 | P5C5 非性能标签栏及诊断／自然动画 259/259；P5C6 iOS 26.5 冻结 A/B 各 11/11，见原记录 | 非当前全部测试重建结果；真机触摸 Runner 初始化失败，测试体未执行；未安装 iOS 15 运行时 |

## 收尾与未覆盖范围

- **已交付：** 核心职责分层、同步布局与选择契约、明确失效范围、选定可选视觉能力、对应测试源码和阶段证据索引。
- **未执行：** 本轮 UIKit 构建、测试及 UI 运行；实际撤销早期提交后的回退验证。本文没有增加运行验收声明。
- **仍未完整覆盖：** 最低支持系统运行、真机真实触摸、完整 VoiceOver／系统无障碍设置端到端矩阵、完整窗口形态和长期压力。具体历史平台覆盖以原记录为准，不由模拟器结果替代。
- **性能边界：** 不把计数、CPU、分配、显示链回调、静态像素或系统 hitch 混为同一指标；P5 的局部收益不能推广成整个标签栏全面提速。
- **归档边界：** [P5C2～P5C4 实验](Experiments/P5C2-P5C4/README.md) 保留用于解释已采用和未采用方案，不属于 P0～P4 完成的前提，也不加入默认回归集合。
