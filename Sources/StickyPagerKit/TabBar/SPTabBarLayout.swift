import UIKit

/// 内容超出一屏时使用各项固有宽度，否则均分可用宽度。几何信息不依赖 Cell 是否已显示。
@MainActor
final class SPTabBarLayout: UICollectionViewLayout {
    var itemWidths: [CGFloat] = [] {
        didSet { if oldValue != itemWidths { invalidateLayout() } }
    }
    var isRightToLeft = false {
        didSet { if oldValue != isRightToLeft { invalidateLayout() } }
    }
    private var itemCount = 0
    // 按从左到右的视觉顺序缓存，RTL 仅改变逻辑索引映射。
    private var frames: [CGRect] = []
    private var contentSize: CGSize = .zero

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        itemCount = collectionView.numberOfItems(inSection: 0)
        let size = collectionView.bounds.size
        let widths = (0..<itemCount).map { index -> CGFloat in
            let width = itemWidths.indices.contains(index) ? itemWidths[index] : 32
            return width.isFinite ? max(0, width) : 32
        }
        let totalWidth = widths.reduce(0, +)
        let fillsWidth = totalWidth <= size.width
        let equalWidth = itemCount > 0 ? size.width / CGFloat(itemCount) : 0
        var x: CGFloat = 0
        frames = (0..<itemCount).map { visualIndex in
            let index = isRightToLeft ? itemCount - 1 - visualIndex : visualIndex
            let width = fillsWidth ? equalWidth : widths[index]
            defer { x += width }
            return CGRect(x: x, y: 0, width: width, height: size.height)
        }
        contentSize = CGSize(width: max(size.width, x), height: size.height)
    }

    override var collectionViewContentSize: CGSize { contentSize }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, (0..<itemCount).contains(indexPath.item) else { return nil }
        let visualIndex = isRightToLeft ? itemCount - 1 - indexPath.item : indexPath.item
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frames[visualIndex]
        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !frames.isEmpty, rect.intersects(CGRect(origin: .zero, size: contentSize)) else { return [] }
        // 宽度不同，使用边界二分定位首项，避免滚动时扫描所有标签。
        var lower = 0, upper = frames.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if frames[middle].maxX <= rect.minX { lower = middle + 1 }
            else { upper = middle }
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
