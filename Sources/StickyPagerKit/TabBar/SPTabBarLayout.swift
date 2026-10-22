import UIKit

/// 优先满足每项宽度需求，其余项尽量等宽；总需求超出视口时横向滚动。
@MainActor
final class SPTabBarLayout: UICollectionViewLayout {
    var itemWidths: [CGFloat] = [] {
        didSet {
            if oldValue != itemWidths {
                invalidateLayout()
            }
        }
    }

    var itemSpacing: CGFloat = 0 {
        didSet {
            if oldValue != itemSpacing {
                invalidateLayout()
            }
        }
    }

    var contentInsets: NSDirectionalEdgeInsets = .zero {
        didSet {
            if oldValue != contentInsets {
                invalidateLayout()
            }
        }
    }

    var isRightToLeft = false {
        didSet {
            if oldValue != isRightToLeft {
                invalidateLayout()
            }
        }
    }

    private var itemCount = 0
    // 按从左到右的视觉顺序缓存，RTL 仅改变逻辑索引映射。
    private var frames: [CGRect] = []
    private var contentSize: CGSize = .zero

    override func prepare() {
        super.prepare()
        guard let collectionView else {
            return
        }
        itemCount = collectionView.numberOfItems(inSection: 0)
        let size = collectionView.bounds.size
        let widths = (0 ..< itemCount).map { index -> CGFloat in
            let width = itemWidths.indices.contains(index) ? itemWidths[index] : 32
            return width.isFinite ? max(0, width) : 32
        }
        let resolved = Self.resolvedWidths(
            widths,
            viewportWidth: max(0, size.width - contentInsets.leading - contentInsets.trailing),
            itemSpacing: itemSpacing
        )
        let left = isRightToLeft ? contentInsets.trailing : contentInsets.leading
        let right = isRightToLeft ? contentInsets.leading : contentInsets.trailing
        let top = min(size.height, contentInsets.top)
        let height = max(0, size.height - top - contentInsets.bottom)
        var x: CGFloat = itemCount == 0 ? 0 : left
        frames = (0 ..< itemCount).map { visualIndex in
            let index = isRightToLeft ? itemCount - 1 - visualIndex : visualIndex
            let width = resolved[index]
            defer { x += width + (visualIndex < itemCount - 1 ? itemSpacing : 0) }
            return CGRect(x: x, y: top, width: width, height: height)
        }
        contentSize = CGSize(width: max(size.width, itemCount == 0 ? 0 : x + right), height: size.height)
    }

    /// 测量和实际布局共用宽度分配规则，保证多行内容按最终宽度计算高度。
    static func resolvedWidths(
        _ widths: [CGFloat],
        viewportWidth: CGFloat,
        itemSpacing: CGFloat = 0
    ) -> [CGFloat] {
        guard !widths.isEmpty else {
            return []
        }
        let availableWidth = max(0, viewportWidth - CGFloat(widths.count - 1) * itemSpacing)
        guard widths.reduce(0, +) < availableWidth else {
            return widths
        }
        // 先为较宽项保留需求，再把剩余宽度均分给较窄项；临界点不会切换到另一套分配公式。
        var remaining = availableWidth
        var level: CGFloat = 0
        for (index, width) in widths.sorted(by: >).enumerated() {
            let equal = remaining / CGFloat(widths.count - index)
            if width <= equal {
                level = equal
                break
            }
            remaining -= width
        }
        return widths.map { max($0, level) }
    }

    override var collectionViewContentSize: CGSize {
        contentSize
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, (0 ..< itemCount).contains(indexPath.item) else {
            return nil
        }
        let visualIndex = isRightToLeft ? itemCount - 1 - indexPath.item : indexPath.item
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frames[visualIndex]
        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !frames.isEmpty, rect.intersects(CGRect(origin: .zero, size: contentSize)) else {
            return []
        }
        // 宽度不同，使用边界二分定位首项，避免滚动时扫描所有标签。
        var lower = 0, upper = frames.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if frames[middle].maxX <= rect.minX {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        var result: [UICollectionViewLayoutAttributes] = []
        var visualIndex = lower
        while visualIndex < frames.count, frames[visualIndex].minX < rect.maxX {
            let index = isRightToLeft ? itemCount - 1 - visualIndex : visualIndex
            if let attributes = layoutAttributesForItem(at: IndexPath(item: index, section: 0)) {
                result.append(attributes)
            }
            visualIndex += 1
        }
        return result
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size != newBounds.size
    }
}
