/// 业务页面主要滚动视图的指示器显隐策略，不影响框架自身的滚动视图。
public enum SPScrollIndicatorVisibilityPolicy: Equatable, Sendable {
    /// 保留业务配置；绑定、布局、分页及解绑均不改写指示器显隐属性。
    case preserve
    /// 横向分页拖动、减速及切页转场期间临时隐藏两个方向的指示器。
    /// 完成、取消或切回 preserve 时恢复业务最新配置；短／空内容不额外隐藏。
    case hideDuringPaging
}
