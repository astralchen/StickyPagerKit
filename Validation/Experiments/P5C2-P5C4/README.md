# P5C2～P5C4 实验归档

归档日期：2026-11-05。这里保存颜色成本调查、写入干预和单一颜色来源实验；不是新的生产候选或发布验收集合。不修改框架实现，也不恢复收益不明确或行为不等价的候选。

## 文件与结论

| 文件 | 用途与保留原因 | 默认集合 |
| --- | --- | --- |
| [SPButtonColorInvalidationTests.swift](Fixtures/SPButtonColorInvalidationTests.swift) | P5C3 独立 UIKit 四组写入干预；解释显式 tint、配置应用及后续布局的关系。简单删除任一写入未满足等价条件 | 已移出 Package 测试目录，不参与默认库回归 |
| [SPButtonSingleColorSourceTests.swift](Fixtures/SPButtonSingleColorSourceTests.swift) | P5C4 独立 UIKit 单一颜色来源；记录高亮即时同步与清除 tint 后继承差异，解释 P5C5 的有限适用条件 | 同上 |
| [profile_colors.py](Scripts/profile_colors.py) | P5C2 XCTest 握手后附加 Instruments 的手动采集入口；保留原失败边界，不承诺真机端到端可用 | 不参与正式脚本测试发现，不自动执行采集 |
| [analyze_color_hitches.py](Scripts/analyze_color_hitches.py) | 独立真机诊断应用的历史 trace 离线核验；拒绝缺表、断连、不完整区间等无效证据 | 按需使用，非任意 trace 通用分析器 |
| [脚本测试](Scripts/Tests) | 采集提示／断连检查 2 项，离线分析协议检查 7 项 | 独立发现运行，不混入 `Scripts/Tests` |
| [P5C3 协议](Historical/P5C3/protocol.json)／[分析器](Historical/P5C3/analyze.py) | 原实验协议与跨组分析逻辑的逐字副本 | 历史源码，不直接在归档目录执行 |
| [P5C4 协议](Historical/P5C4/protocol.json)／[分析器](Historical/P5C4/analyze.py) | 分开内部表示、即时／自然／布局后模型和静态像素 | 同上 |

[provenance.json](provenance.json) 保存原路径与归档前后 SHA-256。两个 Swift 夹具和历史协议／分析器逐字保留；采集脚本仅增加查找仓库正式 `Scripts` 模块的路径。原 `Validation/Results` 中的文件没有移动、删除或改写。历史文档中的旧源文件路径是当时的来源，按本表定位归档文件，不重写旧运行记录。

默认 Package 仍由根 `Tests/StickyPagerKitTests` 发现测试，没有修改 `Package.swift`、Demo target 或 scheme。已提交的 `SPTabBarColorAttributionTests`、`SPTabBarColorSequenceTests`、`SPTabBarTintOrderingTests` 及 P5C5 正式回归继续留在原位置。

## 使用与协议边界

在仓库根目录按需运行归档 Python 测试（不构建／启动 iOS 应用）：

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s Validation/Experiments/P5C2-P5C4/Scripts/Tests -v
```

两个采集／分析工具的输入协议不同，**不能把采集脚本输出直接交给 hitch 分析器**：

- `profile_colors.py` 使用 XCTest token／PID 握手，产出 `workload.json`、`signposts.xml` 等，执行状态包含 `artifactsUnchanged`。`captured` 只表示采集流程完成，仍须核对完整工作区间、警告和导出数据。
- `analyze_color_hitches.py` 使用原独立诊断应用的 `ready.json`、`done.json`、`protocol.json`、`execution.json`（含 `appUnchanged`）、`trace-toc.xml`、`xctrace.log` 及 `os-signpost.xml`、`hitches.xml`、`hitches-updates.xml`、`hitches-frame-lifetimes.xml`。只分析目标 PID、完整 Begin／End 和对应显示帧，不用空表猜测零 hitch。

采集脚本复用正式 `Scripts/color_repeatability.py`，依赖当前 Xcode、签名、设备和冻结测试宿主；真机 XCTest 路径没有取得端到端通过证据。框架构建输入仍由正式工具的 `source_hashes()` 判定，归档目录不在该函数的默认扫描范围内；如重新采集，需另外保存本目录和正式工具的实际版本／哈希，不能仅用旧 `provenance.json` 证明新运行输入一致。详细历史条件和已更新路径的命令见 [历史诊断说明](HistoricalUsage.md)。本次归档不执行采集。

## 独立 UIButton 夹具的重放边界

这两个文件只依赖 UIKit／XCTest，不依赖 StickyPagerKit。若需要重放，应建立单独的、带应用宿主的 iOS XCTest 实验目标，只加入需要的夹具，保持主 actor、真实窗口和实际 Main Thread Checker 未加载的原前提；不重新加入本仓库默认库或 Demo target，不放宽颜色／状态／像素断言。归档没有提供已验证的新宿主工程或自动重放命令。

测试通过仅表示各干预方案内部的诊断子类与普通 UIButton 对照符合预期，跨方案等价性必须另外分析。事件次数不是 CPU／分配收益；自然回调不是系统合成器帧；静态 PNG 一致不是动态真实触摸验收。

`Historical/P5C3/analyze.py` 和 `Historical/P5C4/analyze.py` 保留原相对路径及 `analysis.json` 写出行为。若重读原数据，应在新的临时目录分别放置分析器及原 `focused/reports.json`，再运行临时副本；不要直接在归档目录或历史结果目录执行。分析输出与原 `analysis.json` 比较，不能覆盖原文件，也不能用分析器成功退出宣称候选等价。采集附件到 `reports.json` 的完整流程仍需按原证据目录核对，归档不是自包含运行包。

## 历史结果与失败保留

- [P5C3 原始协议及结果目录](../../Results/20261104-tabbar-p5c3-invalidation)：4 项独立诊断及后续 20 项原回归；写入干预未满足无条件等价。
- [P5C4 原始协议及结果目录](../../Results/20261104-tabbar-p5c4-single-source)：4 项独立诊断；高亮即时图标 tint 和主动清除 tint 后的继承存在差异。
- P5C2 的 CPU／分配／自然动画、断连、采集器／Checker 对照和撤回候选仍完整保存在 [验证记录](../../README.md) 对应九节及其链接中。未把失败批次补成通过，也未强制将 trace、xcresult 或应用产物加入 Git。

本地结果目录被 Git 忽略，其他克隆不保证包含原始数据；本目录保留协议、夹具、分析逻辑和来源，验证记录保留结论及未覆盖范围。是否重新进行实验由新的明确问题决定，不因归档而自动增加性能优化任务。
