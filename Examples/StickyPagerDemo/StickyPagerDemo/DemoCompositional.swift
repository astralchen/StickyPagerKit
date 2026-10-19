import UIKit

/// 纵向列表中嵌入 UIKit 原生正交滚动 Section，不接管内部滚动视图或手势代理。
@MainActor
final class DemoCompositional: UICollectionViewController {
    private static let titles = ["连续横滑 · continuous", "整组分页 · groupPaging", "纵向内容 · 容器分页"]
    private static let counts = [8, 8, 30]

    init() {
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] index, environment in
            let horizontal = index < 2
            let scale = UIFontMetrics.default.scaledValue(for: 1, compatibleWith: environment.traitCollection)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
                widthDimension: horizontal ? .fractionalWidth(0.72) : .fractionalWidth(1),
                heightDimension: .absolute((horizontal ? 128 : 88) * scale)), subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
            section.orthogonalScrollingBehavior = index == 0 ? .continuous : index == 1 ? .groupPaging : .none
            section.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)),
                elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)]
            if horizontal {
                // 仅记录公开布局回调中的真实偏移，供 UI 回归读取。
                section.visibleItemsInvalidationHandler = { [weak self] _, offset, _ in
                    (self?.collectionView as? CompositionalCollectionView)?.sectionOffsets[index] = offset.x
                }
            }
            return section
        }
        collectionView = CompositionalCollectionView(frame: .zero, collectionViewLayout: layout)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.accessibilityIdentifier = "demo.compositional"
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "card")
        collectionView.register(CompositionalSectionHeader.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "header")
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int { Self.counts.count }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Self.counts[section]
    }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "card", for: indexPath)
        var content = UIListContentConfiguration.cell()
        content.text = "\(indexPath.section < 2 ? "横向卡片" : "纵向内容") \(indexPath.item + 1)"
        content.secondaryText = indexPath.section == 0 ? "连续滚动 · 左右拖动"
            : indexPath.section == 1 ? "整组吸附 · 左右翻组" : "上下联动 Header · 左右切换标签"
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        cell.contentConfiguration = content
        var background = UIBackgroundConfiguration.listGroupedCell()
        background.backgroundColor = [UIColor.systemTeal, .systemIndigo, .secondarySystemBackground][indexPath.section]
            .withAlphaComponent(indexPath.section < 2 ? 0.16 : 1)
        background.cornerRadius = 16
        cell.backgroundConfiguration = background
        cell.accessibilityIdentifier = "demo.compositional.\(indexPath.section).\(indexPath.item)"
        return cell
    }
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        (header as? CompositionalSectionHeader)?.label.text = Self.titles[indexPath.section]
        return header
    }
}

@MainActor
private final class CompositionalSectionHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

@MainActor
private final class CompositionalCollectionView: UICollectionView {
    var sectionOffsets: [Int: CGFloat] = [:]
    override var accessibilityValue: String? {
        get {
            guard ProcessInfo.processInfo.arguments.contains("--window-regression") else { return super.accessibilityValue }
            var values: [String: Double] = [
                "position": contentOffset.y + adjustedContentInset.top,
                "continuous": sectionOffsets[0] ?? 0,
                "groupPaging": sectionOffsets[1] ?? 0
            ]
            for (section, key) in [(0, "continuous"), (1, "groupPaging")] {
                guard let cell = visibleCells.first(where: { indexPath(for: $0)?.section == section }) else { continue }
                var ancestor = cell.superview
                while let current = ancestor, current !== self {
                    if let scroll = current as? UIScrollView {
                        values[key + "RemainingRight"] = max(0, scroll.contentSize.width - scroll.bounds.width
                            + scroll.adjustedContentInset.right - scroll.contentOffset.x)
                        values[key + "RemainingLeft"] = max(0, scroll.contentOffset.x + scroll.adjustedContentInset.left)
                        break
                    }
                    ancestor = current.superview
                }
            }
            guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set { super.accessibilityValue = newValue }
    }
}
