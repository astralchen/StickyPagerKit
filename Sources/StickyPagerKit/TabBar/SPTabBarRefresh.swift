/// 内容刷新原因；几何相关变化默认走完整解析，不根据自定义代理的实现猜测依赖。
internal enum SPTabBarChange {
    case content
    case decoration
    case accessibility
    case itemPresentation
    case indicatorAppearance
    case indicatorGeometry
}

/// 累计工作量快照，供内部诊断比较操作前后的增量；不代表耗时或布局遍数。
internal struct SPTabBarRefreshStatistics: Equatable {
    let measurementPasses: UInt
    let contentRequests: UInt
    let cellConfigurations: UInt
}
