import UIKit
import SnapKit

final class FlexDockShell: UITabBarController, UITabBarControllerDelegate, UINavigationControllerDelegate {
    private let customDock = FlexDockBar()
    private var dockIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        suppressSystemTabBar()
        setupTabs()
        view.addSubview(customDock)
        customDock.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().offset(-64 * 2)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.equalTo(64)
        }
        customDock.onSelect = { [weak self] index in
            self?.handleDockSelect(index)
        }
        customDock.highlight(index: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        suppressSystemTabBar()
    }

    func selectTab(index: Int) {
        guard FlexLoginGate.isLoggedIn || index == 0 else { return }
        dockIndex = index
        selectedIndex = index
        customDock.highlight(index: index)
        refreshDockVisibility()
    }

    func setDockHidden(_ hidden: Bool, animated: Bool = true) {
        // Dock sits above every tab's nav stack and overlaps product-detail Apply Now.
        // Never leave a transparent-but-tappable dock over pushed pages.
        customDock.isUserInteractionEnabled = !hidden
        let apply = {
            self.customDock.isHidden = hidden
            self.customDock.alpha = hidden ? 0 : 1
        }
        guard animated else {
            apply()
            return
        }
        if hidden {
            UIView.animate(withDuration: 0.2, animations: {
                self.customDock.alpha = 0
            }, completion: { _ in
                if !self.customDock.isUserInteractionEnabled {
                    self.customDock.isHidden = true
                }
            })
        } else {
            customDock.isHidden = false
            UIView.animate(withDuration: 0.2) { self.customDock.alpha = 1 }
        }
    }

    private func suppressSystemTabBar() {
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.isUserInteractionEnabled = false
        if tabBar.superview != nil {
            tabBar.frame.origin.y = view.bounds.maxY
        }
    }

    private func refreshDockVisibility() {
        guard let nav = selectedViewController as? UINavigationController else {
            setDockHidden(false, animated: false)
            return
        }
        updateDockVisibility(for: nav, showing: nav.topViewController ?? nav, animated: false)
    }

    private func updateDockVisibility(for navigationController: UINavigationController,
                                      showing viewController: UIViewController,
                                      animated: Bool) {
        let atRoot = viewController === navigationController.viewControllers.first
        setDockHidden(!atRoot, animated: atRoot && animated)
    }

    private func handleDockSelect(_ index: Int) {
        guard index != dockIndex else { return }
        if !FlexLoginGate.isLoggedIn {
            FlexLoginGate.presentLogin(from: self)
            customDock.highlight(index: dockIndex)
            return
        }
        dockIndex = index
        selectedIndex = index
        customDock.highlight(index: index)
        refreshDockVisibility()
    }

    private func setupTabs() {
        viewControllers = [
            makeNav(MintHubCanvas()),
            makeNav(LedgerOrdersCanvas()),
            makeNav(RupeeEMICanvas()),
            makeNav(CofferProfileCanvas())
        ]
    }

    private func makeNav(_ root: UIViewController) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.setNavigationBarHidden(true, animated: false)
        nav.delegate = self
        return nav
    }

    // MARK: - UITabBarControllerDelegate

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        dockIndex = selectedIndex
        customDock.highlight(index: selectedIndex)
        refreshDockVisibility()
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        guard navigationController === selectedViewController else { return }
        updateDockVisibility(for: navigationController, showing: viewController, animated: animated)
    }
}

private struct DockTabGlyph {
    let idle: String
    let lit: String
    let label: String
}

final class FlexDockBar: UIView {
    var onSelect: ((Int) -> Void)?

    private let stack = UIStackView()
    private let tabs: [DockTabGlyph] = [
        DockTabGlyph(idle: FlexSliceCatalog.dockSproutIdle, lit: FlexSliceCatalog.dockSproutLit, label: "Home"),
        DockTabGlyph(idle: FlexSliceCatalog.dockLedgerMute, lit: FlexSliceCatalog.dockLedgerGlow, label: "Orders"),
        DockTabGlyph(idle: FlexSliceCatalog.dockCalcRest, lit: FlexSliceCatalog.dockCalcBeam, label: "EMI"),
        DockTabGlyph(idle: FlexSliceCatalog.dockVaultDim, lit: FlexSliceCatalog.dockVaultBright, label: "Me")
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FlexPalette.dockBlack
        flexRoundCorners(32)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        addSubview(stack)
        let pad: CGFloat = 8
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: pad, left: pad, bottom: pad, right: pad)) }
        tabs.enumerated().forEach { index, tab in
            let item = FlexDockTabItem(idle: tab.idle, lit: tab.lit, label: tab.label, tag: index)
            item.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(item)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func highlight(index: Int) {
        stack.arrangedSubviews.enumerated().forEach { idx, view in
            (view as? FlexDockTabItem)?.setSelected(idx == index)
        }
    }

    @objc private func tabTapped(_ sender: FlexDockTabItem) {
        onSelect?(sender.tag)
    }
}

/// Tab item — displays slice assets as-is (`*_n` idle, `*_u` selected).
private final class FlexDockTabItem: UIButton {
    private let idleAsset: String
    private let litAsset: String

    init(idle: String, lit: String, label: String, tag: Int) {
        self.idleAsset = idle
        self.litAsset = lit
        super.init(frame: .zero)
        self.tag = tag
        accessibilityLabel = label
        adjustsImageWhenHighlighted = false
        contentVerticalAlignment = .center
        contentHorizontalAlignment = .center
        imageView?.contentMode = .scaleAspectFit
        snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }
        setSelected(false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        get { false }
        set { super.isHighlighted = false }
    }

    func setSelected(_ selected: Bool) {
        let stem = selected ? litAsset : idleAsset
        setImage(FlexSlice.slice(stem)?.withRenderingMode(.alwaysOriginal), for: .normal)
    }
}
