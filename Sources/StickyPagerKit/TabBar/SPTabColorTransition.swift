import UIKit

/// 默认内容的颜色端点快照，与字体、图片和测量缓存分离。
internal struct SPDefaultTabColors {
    let title: SPTabColorTransition
    let icon: SPTabColorTransition
}

/// 在统一 extended sRGB 空间插值；端点精确保留，无法转换时由调用者保留离散配置。
internal struct SPTabColorTransition {
    private let from: UIColor
    private let to: UIColor
    private let components: ([CGFloat], [CGFloat])?
    private let hasEqualEndpoints: Bool

    init(from: UIColor, to: UIColor, traits: UITraitCollection) {
        self.from = from.resolvedColor(with: traits)
        self.to = to.resolvedColor(with: traits)
        hasEqualEndpoints = self.from == self.to
        let space = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        if let a = self.from.cgColor.converted(to: space, intent: .defaultIntent, options: nil)?.components,
           let b = self.to.cgColor.converted(to: space, intent: .defaultIntent, options: nil)?.components,
           a.count == 4, b.count == 4, a.allSatisfy(\.isFinite), b.allSatisfy(\.isFinite) {
            components = (a, b)
        } else {
            components = nil
        }
    }

    func color(at progress: CGFloat) -> UIColor? {
        guard let (a, b) = components else {
            return nil
        }
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        if p == 0 {
            return from
        }
        if p == 1 {
            return to
        }
        // 相等端点直接复用已解析颜色，避免插值生成等价颜色及后续重复配置。
        if hasEqualEndpoints {
            return from
        }
        // 转换时已确认四个分量；直接求值，避免为每个进度点创建临时数组。
        return UIColor(
            red: a[0] + (b[0] - a[0]) * p,
            green: a[1] + (b[1] - a[1]) * p,
            blue: a[2] + (b[2] - a[2]) * p,
            alpha: a[3] + (b[3] - a[3]) * p
        )
    }
}
