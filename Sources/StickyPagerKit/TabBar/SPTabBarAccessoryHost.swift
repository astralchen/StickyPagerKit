import UIKit

/// 固定附件的裁切区域；业务约束只决定理想尺寸，不承担视口压缩。
@MainActor
final class SPTabBarAccessoryHost: UIView {
    private(set) var accessory: UIView?
    private var measurementConstraints: [NSLayoutConstraint] = []
    private var originalTranslatesAutoresizingMask = true
    var alignsRight = false
    var idealSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(frame:)")
    }

    isolated deinit {
        NSLayoutConstraint.deactivate(measurementConstraints)
        accessory?.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMask
    }

    func replace(with view: UIView?) {
        NSLayoutConstraint.deactivate(measurementConstraints)
        measurementConstraints = []
        accessory?.removeFromSuperview()
        accessory?.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMask
        accessory = view
        if let view {
            originalTranslatesAutoresizingMask = view.translatesAutoresizingMaskIntoConstraints
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            // 无任何尺寸依据的 UIView 的 fitting 可能返回旧 bounds；极低优先级零尺寸
            // 建立独立测量依据，固有尺寸和业务约束均优先，不依赖上次布局的 frame。
            measurementConstraints = [
                view.widthAnchor.constraint(equalToConstant: 0),
                view.heightAnchor.constraint(equalToConstant: 0)
            ]
            measurementConstraints.forEach { $0.priority = UILayoutPriority(1) }
            NSLayoutConstraint.activate(measurementConstraints)
        }
    }

    func measuredSize() -> CGSize {
        guard let accessory, !accessory.isHidden else {
            return .zero
        }
        if #available(iOS 17, *) {
            accessory.updateTraitsIfNeeded()
        }
        // UIButton.Configuration 等系统视图可能重写 fitting 并忽略外加尺寸约束。
        // 使用普通 UIView 宿主参与 Auto Layout 求解；仅测量时连接四边，实际布局仍可裁切。
        let edges = [
            accessory.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessory.trailingAnchor.constraint(equalTo: trailingAnchor),
            accessory.topAnchor.constraint(equalTo: topAnchor),
            accessory.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        NSLayoutConstraint.activate(edges)
        defer { NSLayoutConstraint.deactivate(edges) }
        let size = super.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              size.width <= 1_000_000, size.height <= 1_000_000 else {
            return .zero
        }
        return size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        accessory?.frame = CGRect(
            x: alignsRight ? bounds.width - idealSize.width : 0,
            y: (bounds.height - idealSize.height) / 2,
            width: idealSize.width,
            height: idealSize.height
        )
    }
}
