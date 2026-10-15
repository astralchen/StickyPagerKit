import UIKit

/// 等宽横向布局。直接提供所有逻辑索引的几何信息，不依赖 Cell 是否已显示。
@MainActor
final class SPTabBarLayout: UICollectionViewLayout {
    var minimumItemWidth: CGFloat = 72 {
        didSet { if oldValue != minimumItemWidth { invalidateLayout() } }
    }
    var isRightToLeft = false {
        didSet { if oldValue != isRightToLeft { invalidateLayout() } }
    }
    private var itemCount = 0
    private var itemWidth: CGFloat = 0
    private var contentSize: CGSize = .zero

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        itemCount = collectionView.numberOfItems(inSection: 0)
        let size = collectionView.bounds.size
        itemWidth = itemCount > 0 ? max(minimumItemWidth, size.width / CGFloat(itemCount)) : 0
        contentSize = CGSize(width: max(size.width, itemWidth * CGFloat(itemCount)), height: size.height)
    }

    override var collectionViewContentSize: CGSize { contentSize }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, (0..<itemCount).contains(indexPath.item) else { return nil }
        let visualIndex = isRightToLeft ? itemCount - 1 - indexPath.item : indexPath.item
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: CGFloat(visualIndex) * itemWidth, y: 0,
                                  width: itemWidth, height: contentSize.height)
        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard itemWidth > 0, itemCount > 0, rect.intersects(CGRect(origin: .zero, size: contentSize)) else { return [] }
        let first = max(0, Int(floor(rect.minX / itemWidth)))
        let last = min(itemCount - 1, Int(floor(rect.maxX / itemWidth)))
        guard first <= last else { return [] }
        return (first...last).compactMap { visualIndex in
            let index = isRightToLeft ? itemCount - 1 - visualIndex : visualIndex
            return layoutAttributesForItem(at: IndexPath(item: index, section: 0))
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size != newBounds.size
    }
}
