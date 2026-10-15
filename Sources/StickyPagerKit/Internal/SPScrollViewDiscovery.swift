import UIKit

@MainActor
internal enum SPScrollViewDiscovery {
    static func find(in root: UIView) -> UIScrollView? {
        var candidates: [(view: UIScrollView, rank: Int, area: CGFloat, order: Int)] = []
        var order = 0
        func visit(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0.01, view.isUserInteractionEnabled else { return }
            defer { order += 1 }
            if let scroll = view as? UIScrollView {
                guard scroll.isScrollEnabled else { return }
                let vertical = scroll.alwaysBounceVertical || scroll.contentSize.height > scroll.bounds.height
                let horizontal = scroll.alwaysBounceHorizontal || scroll.contentSize.width > scroll.bounds.width + 1
                if vertical || !horizontal {
                    let list = scroll is UITableView || scroll is UICollectionView
                    let rect = scroll.convert(scroll.bounds, to: root).intersection(root.bounds)
                    let area = rect.isNull ? 0 : rect.width * rect.height
                    candidates.append((scroll, vertical ? 2 : (list ? 1 : 0), area, order))
                }
            }
            view.subviews.forEach(visit)
        }
        visit(root)
        return candidates.sorted {
            if $0.rank != $1.rank { return $0.rank > $1.rank }
            if $0.area != $1.area { return $0.area > $1.area }
            return $0.order < $1.order
        }.first?.view
    }
}
