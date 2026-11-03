import UIKit

/// 程序化标签选择的运动方式，与内容、颜色和指示器布局独立。
public enum SPTabBarAnimationStyle: Sendable {
    /// 保持原有 0.25 秒平滑插值，默认值。
    case standard
    /// 指示器中心与内容缩放使用阻尼回弹，最多运行 0.5 秒。
    /// 颜色、透明度、内容状态进度和标签栏偏移仍在 0.25 秒内有界完成。
    /// 内容缩放需另设 visualStyle.unselectedScale；其呈现权重限制在 -0.15...1.15，
    /// 允许轻微超出静止尺寸，布局和点击区域不变，仍受标签视口裁切。
    /// 手指分页直接跟随进度，不新增松手回弹；减少动态效果时程序选择直接完成。
    case spring
}

/// 可确定求值的阻尼振子；速度单位为每秒，接管时保留位置与速度。
internal struct SPTabSpringValue {
    var position: CGFloat
    var velocity: CGFloat = 0

    func value(toward target: CGFloat, time: CGFloat, limits: ClosedRange<CGFloat>? = nil) -> Self {
        if time <= 0 {
            return self
        }
        if time >= 0.5 {
            return Self(position: target)
        }
        let decay: CGFloat = 13
        let frequency: CGFloat = sqrt(400 - decay * decay)
        let displacement = position - target
        let coefficient = (velocity + decay * displacement) / frequency
        let e = exp(-decay * time), c = cos(frequency * time), s = sin(frequency * time)
        let wave = displacement * c + coefficient * s
        var position = target + e * wave
        var velocity = e * (-decay * wave - displacement * frequency * s + coefficient * frequency * c)
        // 最后 0.1 秒平滑收敛，终点位置与速度都归零，避免强制完成时截断残余运动。
        if time >= 0.4 {
            let u = min(1, (time - 0.4) / 0.1)
            let blend = 1 - u * u * (3 - 2 * u)
            let derivative = (-6 * u + 6 * u * u) / 0.1
            velocity = velocity * blend + (position - target) * derivative
            position = target + (position - target) * blend
        }
        if let limits, !limits.contains(position) {
            return Self(position: min(limits.upperBound, max(limits.lowerBound, position)))
        }
        return Self(position: position, velocity: velocity)
    }
}
