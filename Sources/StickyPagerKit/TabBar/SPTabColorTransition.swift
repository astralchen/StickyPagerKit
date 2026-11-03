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

    init(from: UIColor, to: UIColor, traits: UITraitCollection) {
        self.from = from.resolvedColor(with: traits)
        self.to = to.resolvedColor(with: traits)
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
        let values = zip(a, b).map { $0 + ($1 - $0) * p }
        return UIColor(red: values[0], green: values[1], blue: values[2], alpha: values[3])
    }
}
