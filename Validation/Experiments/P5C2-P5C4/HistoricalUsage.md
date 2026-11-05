# P5C2 历史诊断方法与调用说明

本页保存原 README 的诊断说明，归档日期为 2026-11-05。命令按仓库根目录执行，已更新两个归档脚本的路径；设备状态和成功／失败结论属于原阶段，不表示当前环境已验证。工具的用途、不同输入协议及重新运行限制见 [归档说明](README.md)。本次整理未执行以下采集命令。

P5C2 的 `SPTabBarColorAttributionTests` 是独立诊断用例，不替换 P5A/P5C1 基准。专用异步窗口等待真实 `viewDidAppear`／`viewDidDisappear`，避免在 MainActor 任务中嵌套 RunLoop 处理 appearance。工作量路径固定 120 批 × 360 手动进度点，分别记录墙钟和 `getrusage(RUSAGE_SELF)` 的进程用户／系统 CPU 时间；选择复位在批次计时外，CPU 包含宿主其他线程，不能解释成主线程独占成本。自然动画路径不手动推进进度或强制布局，等待显示链实际启动后分别执行 12 次标准／弹簧选择，保存回调时间戳、目标时间戳和中间标题颜色；启动样本单列，回调间隔不等于 GPU FPS 或系统 hitch 指标。

```sh
export SP_RUN_NAME="<新的 P5C2 构建与聚焦运行名>"
SP_SCOPE=library SP_CONFIGURATION=Release Scripts/validate.sh test ENABLE_TESTABILITY=YES \
  -only-testing:StickyPagerKitTests/SPTabBarColorAttributionTests
python3 Validation/Experiments/P5C2-P5C4/Scripts/profile_colors.py "Validation/Results/$SP_RUN_NAME" \
  "Validation/Results/<新的独立采集名>" \
  --device "$SP_SIMULATOR_ID" --developer-dir "$SP_DEVELOPER_DIR" \
  --template 'Time Profiler' --test testWorkloadColorsOff
```

`profile_colors.py` 默认使用本机 iOS Simulator 的独立 UIKit 宿主，要求构建输入与当前源码一致。每次冻结宿主、测试包及依赖产物，通过唯一 token／PID 握手，确认采集器进入 recording 后才开始负载；负载结束后停止采集、核验目标 PID、源码及产物，保存期允许最多 180 秒。逐次串行运行 `testWorkloadColorsOff`／`testWorkloadColorsOn` 的 `Time Profiler`、`Allocations` 对照；采集器模式不并入无采集器耗时数据。原始 trace、signpost、工作量 JSON、执行状态与 XCTest 摘要均保留，不覆盖已有目录。测试通过、采集成功、数据可用于归因是三个不同判断，必须另检查工作负载起止区间、实际导出表及工具警告。分配窗口包含选择复位、宿主和记录活动，累计分配不代表存活量；调用链的 inclusive 采样权重相互重叠，不能相加为独占百分比。

自然动画可选择 `testNativeStandardColorsOff`／`testNativeStandardColorsOn` 和 `Animation Hitches` 模板，但工具是否支持当前平台必须实测。本机 Xcode 27.2／iOS 27.2 Simulator 明确返回 `Hitches is not supported on this platform`，因此该环境不具备系统 hitch 验收结果；不能用 CADisplayLink 附件或通过的 UI 测试补造系统指标。真机采集使用 `--platform device --device <UDID>`，必须提供单独构建且正确开发签名的 `Release-iphoneos` 宿主及 `Hosted.xctestrun`；不能复用模拟器产物。脚本通过 `devicectl` 的 `appDataContainer` 文件服务传输唯一 token 下的握手文件，不访问设备内部目录。签名、描述文件、XCTest 注入路径和依赖需要在组装宿主时核对，本次组装命令与脚本保存在对应构建证据目录；脚本本身不创建签名配置或自动修改工程。当前 iPhone 13／iOS 27.2 的独立宿主与 Xcode 原生空用例均在 XCTest 连接阶段退出 74，因此 `--platform device` 的 XCTest 采集链路仍未通过端到端验证。本轮改用忽略目录中的独立诊断应用，链接同次 Release 库对象，执行相同六项图文与 12 次自然选择检查；通过 `devicectl` 启动并以短时系统录制加 Points of Interest 补采，仅分析目标 PID 与应用 signpost。这是独立真机诊断结果，不是 XCTest 或真机触摸验收。各次有效结果、失败及恢复边界见 [验证记录](../../README.md)。

P5C2 的 `testChannelIsolation` 另行隔离默认图文颜色通道：保留六项标题和模板图标，比较关闭连续颜色、两端固定、仅标题变化、仅图标变化、两者变化，各自测量逐点不主动布局和逐点同步布局两种边界。每个条件预热一次后记录 30 批 × 360 点；无主动布局条件在批次计时外排空布局。非计时遍历另核验配置赋值、标题 transformer 创建和目标按钮 tint 变化次数，计时期间不挂计数器。通过 `SP_P5C2_CHANNEL_REVERSE=1` 完全反转条件顺序；比较时应冻结同一份 Release 产物、串行独立启动并核对实际 Main Thread Checker 加载状态。该诊断不是 P5A/P5C1 基线，也不表示自然动画、纯 setter 耗时或逐帧分配；配置写入数不能替代 UIKit 布局和分配指标。

进一步归因可使用 `testWorkloadTitleOnly`／`testWorkloadIconOnly`：保持原 120 批 × 360 点及同步布局，固定另一通道为红色；`profile_colors.py --test` 支持这两个入口。`testNativeStandardTitleOnly`／`testNativeStandardIconOnly` 和对应 `testNativeSpringTitleOnly`／`testNativeSpringIconOnly` 验证自然显示链：变化通道必须出现中间颜色，固定通道的观察样本保持红色，选中索引与终态颜色正确。单通道自然用例额外读取按钮 tint，附件包含 `channel` 及 `iconBlue`；它们仍是模型颜色观察，不代表图像像素已呈现、真实触摸或系统 hitch 验收。CPU 应区分颜色函数内配置 setter、setter 外的显式 tint 栈和随后布局，分配统计必须注明是否按工作区间过滤。

P5C2 的真机 trace 可以用 `Validation/Experiments/P5C2-P5C4/Scripts/analyze_color_hitches.py <运行目录> --output <新摘要路径>` 独立重读。输入须包含成功的采集状态、源码／产物一致性、完整的 12 次检查，以及 `hitches`、`hitches-updates`、`hitches-frame-lifetimes` 和 `os-signpost` XML。分析按目标 PID 和唯一 Begin／End 区间过滤，再通过 display／swap ID 关联帧；缺表、缺帧或模式不一致会拒绝给出零 hitch 结论，输出不覆盖旧文件。摘要中的更新 duration 是工具报告的应用更新阶段，不能视为颜色函数独占 CPU。

诊断开关对照仅修改冻结 xctestrun 中 Main Thread Checker 的注入项，其他注入和工作量保持不变；`SPTabBarColorAttributionTests` 在计时外记录实际加载状态、thermal state 与低电量模式。实际加载状态与请求不符时，该对照不能用于判断诊断开销。自然动画重复采样按整次启动汇总，不把一次录制中的帧行当作独立重复，也不将历史单组结果并入新实验。采样顺序及失败保留要求见各次验证记录；本阶段描述波动，不新增发布性能门槛。

采集器打印 `Ctrl-C to stop` 或退出码 0 也可能伴随设备断连。`profile_colors.py` 在释放工作负载前检查已报告的断连；trace 分析还要求本协议正常主动停止，且完整 signpost 位于实际录制时段内。XML 后续同类型节点可能省略 schema 定义，解析时继承列定义并逐行去重，不能把整个后续节点当作重复数据跳过。断连、缺失区间或输入变化均保留为无效证据，不追加替换样本以拼出通过结果。
