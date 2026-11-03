/// 默认颜色呈现的内部工作量快照；赋值次数不等于 UIKit 布局次数或堆分配次数。
internal struct SPTabColorStatistics: Equatable, Codable {
    var baseConfigurationAssignments: UInt = 0
    var colorUpdateAttempts: UInt = 0
    var colorPasses: UInt = 0
    var titleColorEvaluations: UInt = 0
    var iconColorEvaluations: UInt = 0
    var titleTransformerCreations: UInt = 0
    var colorConfigurationAssignments: UInt = 0
    var contentLayoutPasses: UInt = 0
}

/// 按需附加到内容视图；默认不创建、不累计，不持有视图或回调。
@MainActor
internal final class SPTabColorDiagnostics {
    var statistics = SPTabColorStatistics()
}

@MainActor
internal protocol SPTabColorDiagnosing: AnyObject {
    var colorDiagnostics: SPTabColorDiagnostics? { get set }
}
