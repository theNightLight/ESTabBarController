//
//  ESTabBar.swift
//
//  Created by Vincent Li on 2017/2/8.
//  Copyright (c) 2013-2020 ESTabBarController (https://github.com/eggswift/ESTabBarController)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit


/// 对原生的UITabBarItemPositioning进行扩展，通过UITabBarItemPositioning设置时，系统会自动添加insets，这使得添加背景样式的需求变得不可能实现。ESTabBarItemPositioning完全支持原有的item Position 类型，除此之外还支持完全fill模式。
///
/// - automatic: UITabBarItemPositioning.automatic
/// - fill: UITabBarItemPositioning.fill
/// - centered: UITabBarItemPositioning.centered
/// - fillExcludeSeparator: 完全fill模式，布局不覆盖tabBar顶部分割线
/// - fillIncludeSeparator: 完全fill模式，布局覆盖tabBar顶部分割线
public enum ESTabBarItemPositioning : Int {
    
    case automatic
    
    case fill
    
    case centered
    
    case fillExcludeSeparator
    
    case fillIncludeSeparator
}

/// ESTabBar 布局设计风格。
///
/// 控制 TabBar 在不同 iOS 版本下走哪条布局路径。与 `usesSystemGlassEffect` 配合使用：
///
/// ```
/// designType          │ iOS 版本   │ 实际布局
/// ────────────────────┼────────────┼──────────────────────────────────────
/// .automatic          │ < iOS 26   │ updateLayoutLegacy（传统布局）
/// .automatic          │ iOS 26+    │ 见 usesSystemGlassEffect
/// .old                │ 任意版本   │ updateLayoutLegacy（强制旧版）
/// ```
///
/// - `automatic`：自动适配。iOS 26 及以上根据 `usesSystemGlassEffect` 选择
///   系统玻璃嵌入或叠加式 Liquid Glass；更低版本走传统布局。
/// - `old`：始终使用旧版布局。在 iOS 26+ 上会额外隐藏 `_UITabBarPlatterView`
///   （玻璃胶囊承接层），并在 TabBar 全宽均分自定义 item，避免出现 iOS 26 独有 UI。
public enum ESTabBarDesignType: Int {
    
    /// 自动适配系统版本（默认）。
    case automatic
    
    /// 强制旧版布局，禁用 iOS 26 Liquid Glass 视觉与布局。
    case old
}



/// 对UITabBarDelegate进行扩展，以支持UITabBarControllerDelegate的相关方法桥接
internal protocol ESTabBarDelegate: NSObjectProtocol {

    /// 当前item是否支持选中
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Bool
    func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool
    
    /// 当前item是否需要被劫持
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Bool
    func tabBar(_ tabBar: UITabBar, shouldHijack item: UITabBarItem) -> Bool
    
    /// 当前item的点击被劫持
    ///
    /// - Parameters:
    ///   - tabBar: tabBar
    ///   - item: 当前item
    /// - Returns: Void
    func tabBar(_ tabBar: UITabBar, didHijack item: UITabBarItem)
}



/// ESTabBar是高度自定义的UITabBar子类，通过添加UIControl的方式实现自定义tabBarItem的效果。目前支持tabBar的大部分属性的设置，例如delegate,items,selectedImge,itemPositioning,itemWidth,itemSpacing等，以后会更加细致的优化tabBar原有属性的设置效果。
open class ESTabBar: UITabBar {

    internal weak var customDelegate: ESTabBarDelegate?
    
    /// set value > 0 to change tabbar height
    /// 设置 > 0 的值了来修改TabBar的高度
    public var tabBarHeight: CGFloat?{
        didSet{
            guard tabBarHeight ?? 0 > 0 else{
                return
            }
            setNeedsLayout()
        }
    }
    
    /// tabBar中items布局偏移量
    public var itemEdgeInsets = UIEdgeInsets.zero
    /// 是否设置为自定义布局方式，默认为空。如果为空，则通过itemPositioning属性来设置。如果不为空则忽略itemPositioning,所以当tabBar的itemCustomPositioning属性不为空时，如果想改变布局规则，请设置此属性而非itemPositioning。
    public var itemCustomPositioning: ESTabBarItemPositioning? {
        didSet {
            if let itemCustomPositioning = itemCustomPositioning {
                switch itemCustomPositioning {
                case .fill:
                    itemPositioning = .fill
                case .automatic:
                    itemPositioning = .automatic
                case .centered:
                    itemPositioning = .centered
                default:
                    break
                }
            }
            self.reload()
        }
    }
    /// tabBar自定义item的容器view
    internal var containers = [ESTabBarItemContainer]()
    /// 缓存当前tabBarController用来判断是否存在"More"Tab
    internal weak var tabBarController: UITabBarController?
    /// 自定义'More'按钮样式，继承自ESTabBarItemContentView
    open var moreContentView: ESTabBarItemContentView? = ESTabBarItemMoreContentView.init() {
        didSet { self.reload() }
    }
    
    /// TabBar 布局设计风格，默认 `.automatic`。
    ///
    /// 修改后会触发 `reload()` 重建 container 与玻璃层展示视图。
    ///
    /// **`.automatic`（默认）**
    /// - iOS 25 及以下：`updateLayoutLegacy`，container 对齐系统 `UITabBarButton`。
    /// - iOS 26 及以上：由 `usesSystemGlassEffect` 决定：
    ///   - `true`  → 嵌入 `_UITabBarPlatterView` 双层结构，保留系统玻璃合成；
    ///   - `false` → 隐藏系统按钮，在 platter 区域叠加 container。
    ///
    /// **`.old`**
    /// - 所有 iOS 版本均走 `updateLayoutLegacy`。
    /// - iOS 26+ 额外隐藏 `_UITabBarPlatterView`，item 在 TabBar 全宽均分平铺，
    ///   视觉与交互接近 iOS 18 及以前的传统 TabBar。
    open var designType: ESTabBarDesignType = .automatic {
        didSet {
            if oldValue != designType {
                reload()
            }
        }
    }
    
    /// 是否使用系统 Liquid Glass 双层嵌入，默认 `true`。
    ///
    /// **生效条件**：`designType == .automatic` 且 iOS 26 及以上。
    /// 当 `designType == .old` 时，此属性被忽略。
    ///
    /// iOS 26 TabBar 内部采用双层合成结构（均为 `_UITabBarPlatterView` 的子视图）：
    /// ```
    /// _UITabBarPlatterView
    ///   ├── SelectedContentView  ← 高亮层，选中 tab 放大显示
    ///   │     └── _UITabButton × N
    ///   └── ContentView          ← 显示层，未选中 tab 正常尺寸
    ///         └── _UITabButton × N
    /// ```
    ///
    /// - `true`：不隐藏系统 tabBarButton；将自定义 item 的展示视图分别嵌入
    ///   两层内的 `_UITabButton`，替换系统 icon/label，保留 destOut 玻璃合成管线。
    ///   选中态 UI 只写入 SelectedContentView，未选中态 UI 只写入 ContentView。
    ///   点击由系统 tabBarButton 处理，container 隐藏仅保留无障碍等用途。
    ///
    /// - `false`：隐藏系统 tabBarButton 及选中装饰，在 TabBar 上叠加
    ///   `ESTabBarItemContainer`，按 platter 区域均分布局（`updateLayoutForLiquidGlass`）。
    open var usesSystemGlassEffect: Bool = true {
        didSet {
            if oldValue != usesSystemGlassEffect {
                reload()
            }
        }
    }
    
    /// iOS 26 系统玻璃模式下，每个自定义 item 对应的一对双层展示视图。
    ///
    /// - `selectedDisplay`：嵌入 SelectedContentView 内 tabButton，强制展示选中态 UI。
    /// - `normalDisplay`：嵌入 ContentView 内 tabButton，强制展示未选中态 UI。
    /// - `sourceContentView`：弱引用主 contentView，选中切换时从此同步视觉属性。
    ///
    /// 注意：主 `contentView` 仍在 ESTabBarItem 上维护选中状态与动画，
    /// 双层视图仅作为系统合成管线的「镜像展示层」，不参与触摸。
    internal struct GlassLayerDisplayPair {
        let selectedDisplay: ESTabBarItemContentView
        let normalDisplay: ESTabBarItemContentView
        weak var sourceContentView: ESTabBarItemContentView?
    }
    
    /// 当前所有 item 的双层展示视图缓存，与 `reload()` 生命周期一致。
    internal var glassLayerDisplayPairs = [GlassLayerDisplayPair]()
    /// 标记嵌入系统 tabBarButton 内的自定义展示视图，便于移除时与系统子视图区分。
    private static let glassCustomContentTag = 9_001
    
    open override var items: [UITabBarItem]? {
        didSet {
            self.reload()
        }
    }
    
    open var isEditing: Bool = false {
        didSet {
            if oldValue != isEditing {
                self.updateLayout()
            }
        }
    }
    
    open override func setItems(_ items: [UITabBarItem]?, animated: Bool) {
        super.setItems(items, animated: animated)
        self.reload()
    }
    
    open override func beginCustomizingItems(_ items: [UITabBarItem]) {
        ESTabBarController.printError("beginCustomizingItems(_:) is unsupported in ESTabBar.")
        super.beginCustomizingItems(items)
    }
    
    open override func endCustomizing(animated: Bool) -> Bool {
        ESTabBarController.printError("endCustomizing(_:) is unsupported in ESTabBar.")
        return super.endCustomizing(animated: animated)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.updateLayout()
    }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let defaultSize = super.sizeThatFits(size)
        if let tabBarHeight, tabBarHeight > 0{
            return CGSize(width: defaultSize.width, height: tabBarHeight)
        }
        return defaultSize
    }
    
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var b = super.point(inside: point, with: event)
        if !b {
            for container in containers {
                if container.point(inside: CGPoint.init(x: point.x - container.frame.origin.x, y: point.y - container.frame.origin.y), with: event) {
                    b = true
                }
            }
        }
        return b
    }

}

internal extension ESTabBar /* Layout */ {
    
    // MARK: - 布局路由
    //
    // `layoutSubviews` → `updateLayout()` 按以下优先级分流：
    //
    //   designType == .old
    //     └─→ updateLayoutLegacy（全版本传统布局；iOS 26+ 隐藏 platter 后全宽均分）
    //
    //   designType == .automatic
    //     ├─ iOS < 26  → updateLayoutLegacy
    //     └─ iOS 26+   → legacyRestoreIOS26PlatterViews()
    //                    ├─ usesSystemGlassEffect == true  → updateLayoutForSystemGlassEffect
    //                    └─ usesSystemGlassEffect == false → updateLayoutForLiquidGlass
    
    /// 是否应走 iOS 26+ 新设计布局路径。
    /// 需同时满足 `designType == .automatic` 且系统版本 >= iOS 26。
    var usesModernDesignLayout: Bool {
        guard designType == .automatic else { return false }
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// 是否启用系统玻璃双层嵌入（`usesModernDesignLayout && usesSystemGlassEffect`）。
    /// 为 `true` 时 container 隐藏，自定义 UI 写入 platter 双层结构。
    var isSystemGlassEffectActive: Bool {
        return usesModernDesignLayout && usesSystemGlassEffect
    }
    
    /// 在系统玻璃模式下，将主 contentView 的视觉状态同步到双层展示视图。
    /// 供 `syncSelectionState()`、`performGlassHijackFeedback()` 等调用。
    func syncGlassLayerDisplaysIfNeeded() {
        guard isSystemGlassEffectActive, let tabBarItems = items else { return }
        if #available(iOS 26.0, *) {
            syncGlassLayerDisplays(tabBarItems: tabBarItems)
        }
    }
    
    /// 布局总入口，在每次 `layoutSubviews` 时调用。
    ///
    /// 根据 `designType`、系统版本、`usesSystemGlassEffect` 选择具体布局实现。
    /// 切换 `.automatic` 时会先 `legacyRestoreIOS26PlatterViews()` 恢复 platter，
    /// 避免从 `.old` 切回后玻璃层仍被隐藏。
    func updateLayout() {
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        
        if designType == .old {
            updateLayoutLegacy(tabBarItems: tabBarItems)
            return
        }
        
        if #available(iOS 26.0, *) {
            legacyRestoreIOS26PlatterViews()
            if usesSystemGlassEffect {
                updateLayoutForSystemGlassEffect(tabBarItems: tabBarItems)
            } else {
                updateLayoutForLiquidGlass(tabBarItems: tabBarItems)
            }
        } else {
            updateLayoutLegacy(tabBarItems: tabBarItems)
        }
    }
    
    /// iOS 26 + `designType == .old` 时为 `true`，触发旧版全宽平铺并隐藏玻璃 UI。
    var isLegacyOldDesignOnIOS26: Bool {
        guard designType == .old else { return false }
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// 是否为 iOS 26 Liquid Glass 附带的连续选中手势 `_UIContinuousSelectionGestureRecognizer`。
    func isContinuousSelectionGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return String(describing: type(of: gestureRecognizer))
            .hasSuffix("_UIContinuousSelectionGestureRecognizer")
    }
    
    /// `.old` 模式下移除连续选中手势，避免与自定义 container 触摸冲突。
    func removeInstalledContinuousSelectionGestures() {
        guard #available(iOS 26.0, *), isLegacyOldDesignOnIOS26, !isCustomizing else { return }
        removeContinuousSelectionGestures(in: self)
    }
    
    private func removeContinuousSelectionGestures(in view: UIView) {
        if let gestures = view.gestureRecognizers {
            for gesture in gestures where isContinuousSelectionGestureRecognizer(gesture) {
                view.removeGestureRecognizer(gesture)
            }
        }
        view.subviews.forEach { removeContinuousSelectionGestures(in: $0) }
    }
    
    /// 传统布局（iOS 18 及以前的行为，也是 `designType == .old` 的唯一布局）。
    ///
    /// **iOS 25 及以下（或 .old 在低版本）**
    /// 1. 查找系统 `UITabBarButton`，将其 frame（转换到 TabBar 坐标系）赋给 container。
    /// 2. 对 ESTabBarItem / 自定义 More：隐藏对应系统按钮，避免与自定义视图重叠。
    ///
    /// **iOS 26 + 且 designType == .old（useOldFlatLayoutOnIOS26）**
    /// 1. 隐藏 `_UITabBarPlatterView`（玻璃胶囊承接层），消除 iOS 26 独有 UI。
    /// 2. 不再逐个隐藏 platter 内按钮（整层 platter 已不可见）。
    /// 3. 在 TabBar 全宽范围内均分 container（`applyLegacyEqualContainerFrames`）。
    /// 4. 将 container 置于最上层，保证触摸与无障碍正常。
    ///
    /// **注意**：iOS 26 上 platter 内的 tabButton frame 是相对于 platter 的局部坐标，
    /// 不能直接赋给 TabBar 的直接子视图 container，否则 item 会挤在左上角。
    func updateLayoutLegacy(tabBarItems: [UITabBarItem]) {
        /// iOS 26 旧版模式且非编辑态：隐藏 platter + 全宽均分。
        let useOldFlatLayoutOnIOS26 = isLegacyOldDesignOnIOS26 && !isCustomizing
        
        // Step 1: 处理 iOS 26 玻璃承接层显隐。
        if useOldFlatLayoutOnIOS26 {
            legacyHideIOS26PlatterViews()
        } else if #available(iOS 26.0, *) {
            // 非 .old 路径进入 legacy 时（如 iOS < 26），确保 platter 未被误隐藏。
            legacyRestoreIOS26PlatterViews()
        }
        
        let tabBarButtonInfos = legacySystemTabBarButtonInfos()
        
        if isCustomizing {
            // 编辑模式：恢复系统 UI，隐藏自定义 container。
            if isLegacyOldDesignOnIOS26 {
                legacyRestoreIOS26PlatterViews()
            }
            // 编辑模式：显示系统按钮，隐藏自定义 container。
            for (idx, _) in tabBarItems.enumerated() {
                guard idx < tabBarButtonInfos.count else { continue }
                tabBarButtonInfos[idx].view.isHidden = false
                tabBarButtonInfos[idx].view.alpha = 1.0
                moreContentView?.isHidden = true
            }
            for (_, container) in containers.enumerated(){
                container.isHidden = true
            }
        } else {
            if !useOldFlatLayoutOnIOS26 {
                // 常规 legacy：逐个隐藏有自定义内容的系统按钮。
                for (idx, item) in tabBarItems.enumerated() {
                    guard idx < tabBarButtonInfos.count else { continue }
                    if let _ = item as? ESTabBarItem {
                        tabBarButtonInfos[idx].view.isHidden = true
                    } else {
                        tabBarButtonInfos[idx].view.isHidden = false
                    }
                    if isMoreItem(idx), let _ = moreContentView {
                        tabBarButtonInfos[idx].view.isHidden = true
                    }
                }
            }
            for (_, container) in containers.enumerated(){
                container.isHidden = false
            }
        }
        
        var layoutBaseSystem = true
        if let itemCustomPositioning = itemCustomPositioning {
            switch itemCustomPositioning {
            case .fill, .automatic, .centered:
                break
            case .fillIncludeSeparator, .fillExcludeSeparator:
                layoutBaseSystem = false
            }
        }
        
        if layoutBaseSystem {
            if useOldFlatLayoutOnIOS26 {
                // iOS 26 .old：platter 已隐藏，按 TabBar 全宽均分（不依赖系统按钮 frame）。
                applyLegacyEqualContainerFrames()
            } else {
                // 常规 legacy：container 与系统按钮对齐（frame 已转换到 TabBar 坐标系）。
                for (idx, container) in containers.enumerated(){
                    if idx < tabBarButtonInfos.count {
                        let frame = tabBarButtonInfos[idx].frameInTabBar
                        if !frame.isEmpty {
                            container.frame = frame
                        }
                    }
                }
            }
        } else {
            // 完全 fill 模式：忽略系统按钮位置，按 itemEdgeInsets 手动均分。
            var x: CGFloat = itemEdgeInsets.left
            var y: CGFloat = itemEdgeInsets.top
            switch itemCustomPositioning! {
            case .fillExcludeSeparator:
                if y <= 0.0 {
                    y += 1.0
                }
            default:
                break
            }
            let width = bounds.size.width - itemEdgeInsets.left - itemEdgeInsets.right
            let height = bounds.size.height - y - itemEdgeInsets.bottom
            let eachWidth = itemWidth == 0.0 ? width / CGFloat(containers.count) : itemWidth
            let eachSpacing = itemSpacing == 0.0 ? 0.0 : itemSpacing
            
            for container in containers {
                container.frame = CGRect.init(x: x, y: y, width: eachWidth, height: height)
                x += eachWidth
                x += eachSpacing
            }
        }
        
        if useOldFlatLayoutOnIOS26 {
            // platter 隐藏后 container 可能被其他 subview 遮挡，提到最前。
            containers.forEach { bringSubviewToFront($0) }
        }
    }
    
    /// 系统 Tab 按钮引用及其在 TabBar 坐标系下的 frame。
    /// `frameInTabBar` 由 `convert(_:to: self)` 得到，避免 platter 内局部坐标导致错位。
    struct LegacyTabBarButtonInfo {
        let view: UIView
        let frameInTabBar: CGRect
    }
    
    /// 在 TabBar 可用宽度内均分所有 container 的 frame。
    ///
    /// 专用于 iOS 26 + `designType == .old`：隐藏浮动胶囊 platter 后，
    /// item 需要铺满整条 TabBar（类似 iOS 18 全宽 TabBar），而非缩在胶囊区域内。
    ///
    /// 布局公式（第 i 个 item）：
    ///   eachWidth = (bounds.width - insets) / count  （itemWidth == 0 时）
    ///   x = itemEdgeInsets.left + i × (eachWidth + itemSpacing)
    ///   y = itemEdgeInsets.top
    ///   height = bounds.height - y - itemEdgeInsets.bottom - safeAreaInsets.bottom
    func applyLegacyEqualContainerFrames() {
        guard !containers.isEmpty else { return }
        
        let count = containers.count
        var y = itemEdgeInsets.top
        if y <= 0.0 {
            y = 0.0
        }
        let layoutWidth = bounds.width - itemEdgeInsets.left - itemEdgeInsets.right
        let layoutHeight = bounds.height - y - itemEdgeInsets.bottom - safeAreaInsets.bottom
        let eachWidth = itemWidth == 0.0 ? layoutWidth / CGFloat(count) : itemWidth
        let eachSpacing = itemSpacing == 0.0 ? 0.0 : itemSpacing
        var x = itemEdgeInsets.left
        
        for container in containers {
            container.frame = CGRect(x: x, y: y, width: eachWidth, height: layoutHeight)
            x += eachWidth + eachSpacing
        }
    }
    
    /// 隐藏 iOS 26 Liquid Glass 承接层 `_UITabBarPlatterView`。
    ///
    /// platter 是 iOS 26 TabBar 的玻璃胶囊容器，内部包含 SelectedContentView / ContentView
    /// 及系统 tab 按钮。`.old` 模式下必须隐藏此层，否则即使自定义 item 布局正确，
    /// 仍会看到浮动玻璃胶囊背景。
    func legacyHideIOS26PlatterViews() {
        if #available(iOS 26.0, *) {
            legacyFindPlatterViews().forEach { legacySetPlatterView($0, hidden: true) }
        }
    }
    
    /// 恢复 `_UITabBarPlatterView` 的可见性与交互。
    /// 在 `designType` 从 `.old` 切回 `.automatic`，或进入编辑模式时调用。
    func legacyRestoreIOS26PlatterViews() {
        if #available(iOS 26.0, *) {
            legacyFindPlatterViews().forEach { legacySetPlatterView($0, hidden: false) }
        }
    }
    
    /// 设置 platter 视图显隐（同时控制 alpha 与 isUserInteractionEnabled）。
    private func legacySetPlatterView(_ view: UIView, hidden: Bool) {
        view.isHidden = hidden
        view.alpha = hidden ? 0.0 : 1.0
        view.isUserInteractionEnabled = !hidden
    }
    
    /// 递归查找 `_UITabBarPlatterView`（兼容 `UIKit._UITabBarPlatterView` 模块前缀）。
    private func legacyFindPlatterViews() -> [UIView] {
        return legacyFindViews(in: self) { legacyMatchesSystemClassName($0, target: "_UITabBarPlatterView") }
    }
    
    /// 深度优先递归收集满足条件的子视图。
    private func legacyFindViews(in view: UIView, where predicate: (UIView) -> Bool) -> [UIView] {
        var results: [UIView] = []
        for subview in view.subviews {
            if predicate(subview) {
                results.append(subview)
            }
            results.append(contentsOf: legacyFindViews(in: subview, where: predicate))
        }
        return results
    }
    
    /// 匹配 UIKit 私有类名（`NSStringFromClass` 与 `String(describing:)` 双通道比对）。
    private func legacyMatchesSystemClassName(_ view: UIView, target: String) -> Bool {
        let objcClassName = NSStringFromClass(type(of: view))
        let swiftTypeName = String(describing: type(of: view))
        for name in [objcClassName, swiftTypeName] {
            if name == target || name.hasSuffix(".\(target)") {
                return true
            }
        }
        return false
    }
    
    /// 收集系统 Tab 按钮，附带转换到 TabBar 坐标系的 frame，按 x 从左到右排序。
    func legacySystemTabBarButtonInfos() -> [LegacyTabBarButtonInfo] {
        return legacySystemTabBarButtons()
            .map { view in
                LegacyTabBarButtonInfo(
                    view: view,
                    frameInTabBar: view.convert(view.bounds, to: self)
                )
            }
            .sorted { $0.frameInTabBar.origin.x < $1.frameInTabBar.origin.x }
    }
    
    /// 查找系统 Tab 按钮 view 列表，按 x 坐标从左到右排序。
    ///
    /// 查找策略：
    /// 1. 优先在 ESTabBar 直接子视图中找 `UITabBarButton`（iOS 18 及以前）。
    /// 2. 找不到则递归子树，按类名包含 `TabBarButton` 兜底（iOS 26 platter 内部）。
    func legacySystemTabBarButtons() -> [UIView] {
        if let cls = NSClassFromString("UITabBarButton") {
            let buttons = subviews
                .filter { $0.isKind(of: cls) && !($0 is ESTabBarItemContainer) }
                .sorted { $0.frame.origin.x < $1.frame.origin.x }
            if !buttons.isEmpty {
                return buttons
            }
        }
        
        // iOS 26：按钮嵌套在 _UITabBarPlatterView → ContentView 内，需递归搜索。
        return legacyFindTabBarButtons(in: self)
            .sorted { $0.frame.origin.x < $1.frame.origin.x }
    }
    
    func legacyFindTabBarButtons(in view: UIView) -> [UIView] {
        var results: [UIView] = []
        for subview in view.subviews {
            guard !(subview is ESTabBarItemContainer) else { continue }
            let className = NSStringFromClass(type(of: subview))
            if className.contains("UITabBarButton") {
                results.append(subview)
            }
            results.append(contentsOf: legacyFindTabBarButtons(in: subview))
        }
        return results
    }
}

@available(iOS 26.0, *)
private extension ESTabBar /* Liquid Glass Layout */ {
    
    // MARK: - iOS 26 Liquid Glass 叠加布局说明
    //
    // 适用：`designType == .automatic` && `usesSystemGlassEffect == false` && iOS 26+
    //
    // iOS 26 TabBar 视图层级：
    //   ESTabBar
    //     ├── _UITabBarPlatterView（玻璃胶囊，保持可见）
    //     │     ├── SelectedContentView → _UITabButton × N
    //     │     └── ContentView         → _UITabButton × N
    //     └── ESTabBarItemContainer × N（本模式叠加在 platter 上方）
    //
    // 本模式策略：隐藏系统 tab 按钮与选中装饰，在 platter 区域上叠加自定义 container。
    // 布局基准：以 `_UITabBarPlatterView` 的 frame 均分 slot；找不到 platter 时走回退布局。
    //
    // 整体流程（updateLayoutForLiquidGlass）：
    //   1. 收集系统按钮 frame（隐藏前缓存位置）
    //   2. 对 ESTabBarItem / 自定义 More：隐藏对应系统按钮
    //   3. 有 platter → 按 platter 均分 container；无 platter → 回退布局
    //   4. 隐藏选中胶囊等系统装饰（避免与自定义选中态重叠）
    //   5. container 置顶，同步 contentView 选中状态
    
    /// 系统 Tab 按钮的 view 及其在 ESTabBar 坐标系下的 frame。
    struct SystemTabBarButtonInfo {
        let view: UIView
        let frameInTabBar: CGRect
    }
    
    /// iOS 26 Liquid Glass 布局主流程。
    /// 找不到 `_UITabBarPlatterView` 时，走 iOS 26 专用回退布局（不走 updateLayoutLegacy）。
    func updateLayoutForLiquidGlass(tabBarItems: [UITabBarItem]) {
        // 先收集系统按钮 frame，后续隐藏按钮前需要用到位置信息。
        let buttonInfos = systemTabBarButtonInfos()
        
        if isCustomizing {
            // 编辑模式：恢复系统按钮，隐藏自定义 container。
            buttonInfos.forEach {
                $0.view.isHidden = false
                $0.view.alpha = 1.0
                $0.view.isUserInteractionEnabled = true
            }
            moreContentView?.isHidden = true
            containers.forEach { $0.isHidden = true }
            return
        }
        
        for (idx, item) in tabBarItems.enumerated() {
            // ESTabBarItem 或自定义 More：隐藏系统按钮，只显示自定义 contentView。
            // 普通 UITabBarItem（mixture 模式）：保留系统按钮。
            let shouldHideSystemButton = item is ESTabBarItem || (isMoreItem(idx) && moreContentView != nil)
            
            guard idx < buttonInfos.count else { continue }
            
            let button = buttonInfos[idx].view
            if shouldHideSystemButton {
                hideViewTree(button)
            } else {
                button.isHidden = false
                button.alpha = 1.0
                button.isUserInteractionEnabled = true
            }
        }
        
        containers.forEach { $0.isHidden = false }
        // 有 platter：按 _UITabBarPlatterView 宽高均分；无 platter：iOS 26 回退布局。
        if platterFrameInTabBar() != nil {
            layoutContainersInPlatter()
        } else {
            layoutContainersFallback(buttonInfos: buttonInfos)
        }
        // 隐藏系统选中胶囊等装饰，防止与自定义 item 内容重复。
        hideSystemSelectionDecorations()
        // 确保自定义 container 在最上层，能响应点击。
        containers.forEach { bringSubviewToFront($0) }
        // 同步 ESTabBarItem contentView 的选中/未选中视觉状态。
        syncSelectionState()
    }
    
    /// 查找系统 Tab 按钮。iOS 26 按钮可能在 platter 内部，需递归搜索。
    /// 搜索优先级：UITabBarButton → platter 内按钮 → 顶层 UIControl。
    private func systemTabBarButtonInfos() -> [SystemTabBarButtonInfo] {
        let itemCount = items?.count ?? 0
        
        // 1. 在 ESTabBar 子树中找 UITabBarButton（类名字符串匹配，兼容私有类）
        let tabBarButtons = findSubviews(in: self, where: isSystemTabBarButtonView)
        if !tabBarButtons.isEmpty {
            return makeButtonInfos(from: tabBarButtons)
        }
        
        // 2. 在 _UITabBarPlatterView 内部找按钮
        let platterButtons = systemButtonsInsidePlatter()
        if !platterButtons.isEmpty {
            return makeButtonInfos(from: platterButtons)
        }
        
        // 3. 兜底：找顶层 UIControl
        let directControls = subviews.filter { subview in
            subview is UIControl && !(subview is ESTabBarItemContainer)
        }
        if directControls.count >= itemCount || !directControls.isEmpty {
            return makeButtonInfos(from: directControls)
        }
        
        return []
    }
    
    /// 将 view 列表转为 SystemTabBarButtonInfo，并按 x 坐标从左到右排序。
    private func makeButtonInfos(from views: [UIView]) -> [SystemTabBarButtonInfo] {
        return views
            .map { view in
                SystemTabBarButtonInfo(
                    view: view,
                    frameInTabBar: view.convert(view.bounds, to: self)
                )
            }
            .sorted { $0.frameInTabBar.origin.x < $1.frameInTabBar.origin.x }
    }
    
    /// 是否为 iOS 26 玻璃背景容器 `_UITabBarPlatterView`。
    /// NSClassFromString 对 UIKit 私有类通常返回 nil，因此用类名精确匹配。
    /// po 中显示为 `UIKit._UITabBarPlatterView`，NSStringFromClass 可能为 `_UITabBarPlatterView`。
    private func isPlatterView(_ view: UIView) -> Bool {
        return matchesSystemClassName(view, target: "_UITabBarPlatterView")
    }
    
    /// 是否为系统 Tab 按钮（`_UITabBarButton` / `UITabBarButton` / `_UITabButton`）。
    private func isSystemTabBarButtonView(_ view: UIView) -> Bool {
        guard !(view is ESTabBarItemContainer) else { return false }
        return matchesSystemClassName(view, target: "_UITabBarButton")
            || matchesSystemClassName(view, target: "UITabBarButton")
            || matchesSystemClassName(view, target: "_UITabButton")
            || matchesSystemClassName(view, target: "UITabButton")
    }
    
    /// 是否为 iOS 26 玻璃模式下的选中层高亮容器 `SelectedContentView`。
    private func isSelectedContentLayerView(_ view: UIView) -> Bool {
        return matchesSystemClassName(view, target: "SelectedContentView")
    }
    
    /// 是否为 iOS 26 玻璃模式下的显示层容器 `ContentView`（排除 SelectedContentView）。
    private func isNormalContentLayerView(_ view: UIView) -> Bool {
        return matchesSystemClassName(view, target: "ContentView")
            && !isSelectedContentLayerView(view)
    }
    
    /// 匹配 UIKit 私有类的真实类名（兼容模块前缀，如 `UIKit._UITabBarPlatterView`）。
    private func matchesSystemClassName(_ view: UIView , target: String) -> Bool {
        let objcClassName = NSStringFromClass(type(of: view))
        let swiftTypeName = String(describing: type(of: view))
        
        for name in [objcClassName, swiftTypeName] {
            if name == target || name.hasSuffix(".\(target)") {
                return true
            }
        }
        return false
    }
    
    /// 获取 TabBar 中的 `_UITabBarPlatterView`（通常是 ESTabBar 的直接子视图）。
    private func platterViewInTabBar() -> UIView? {
        if let platter = subviews.first(where: { isPlatterView($0) }) {
            return platter
        }
        return findSubviews(in: self, where: isPlatterView).first
    }
    
    /// 递归查找满足条件的子视图。
    private func findSubviews(in view: UIView, where predicate: (UIView) -> Bool) -> [UIView] {
        var results: [UIView] = []
        for subview in view.subviews {
            if predicate(subview) {
                results.append(subview)
            }
            results.append(contentsOf: findSubviews(in: subview, where: predicate))
        }
        return results
    }
    
    /// 在 _UITabBarPlatterView 内部查找 UITabBarButton。
    private func systemButtonsInsidePlatter() -> [UIView] {
        guard let platter = platterViewInTabBar() else { return [] }
        
        let buttons = findSubviews(in: platter, where: isSystemTabBarButtonView)
        if !buttons.isEmpty {
            return buttons
        }
        
        let controls = platter.subviews.filter { subview in
            subview is UIControl && !(subview is ESTabBarItemContainer)
        }
        return controls
    }
    
    /// 获取 _UITabBarPlatterView 在 ESTabBar 坐标系下的 frame。
    /// 这是 iOS 26 item 布局的基准区域。
    private func platterFrameInTabBar() -> CGRect? {
        guard let platter = platterViewInTabBar() else { return nil }
        let frame = platter.convert(platter.bounds, to: self)
        return frame.isEmpty ? nil : frame
    }
    
    /// 将每个 ESTabBarItemContainer 的 frame 设为 platter 均分后的 slot。
    private func layoutContainersInPlatter() {
        guard !containers.isEmpty,
              let slotFrames = itemSlotFramesInPlatter(count: containers.count) else {
            return
        }
        
        applySlotFrames(slotFrames)
    }
    
    /// iOS 26 找不到 _UITabBarPlatterView 时的回退布局。
    /// 优先对齐系统 Tab 按钮 frame，否则在 TabBar 可用区域内均分。
    private func layoutContainersFallback(buttonInfos: [SystemTabBarButtonInfo]) {
        guard !containers.isEmpty else { return }
        
        // 1. 优先使用系统 Tab 按钮的实际 frame
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map { $0.frameInTabBar }
            if frames.allSatisfy({ !$0.isEmpty }) {
                applySlotFrames(Array(frames))
                return
            }
        }
        
        // 2. 在 TabBar 可用区域内均分（算法与 platter 均分一致，只是 region 不同）
        let layoutRegion = tabBarFallbackLayoutRegion(buttonInfos: buttonInfos)
        applySlotFrames(equalItemSlotFrames(in: layoutRegion, count: containers.count))
    }
    
    /// 应用 slot frame 到 container。
    private func applySlotFrames(_ slotFrames: [CGRect]) {
        for (idx, container) in containers.enumerated() where idx < slotFrames.count {
            container.frame = slotFrames[idx]
        }
    }
    
    /// iOS 26 回退布局的区域：系统按钮并集 → TabBar 内容区。
    private func tabBarFallbackLayoutRegion(buttonInfos: [SystemTabBarButtonInfo]) -> CGRect {
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map { $0.frameInTabBar }
            if frames.allSatisfy({ !$0.isEmpty }) {
                var union = frames[0]
                for frame in frames.dropFirst() {
                    union = union.union(frame)
                }
                if !union.isEmpty {
                    return union
                }
            }
        }
        
        return CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - safeAreaInsets.bottom
        )
    }
    
    /// 返回 _UITabBarPlatterView 的布局区域（布局基准）。
    private func liquidGlassPlatterLayoutRegion() -> CGRect? {
        return platterFrameInTabBar()
    }
    
    /// 根据 item 数量，在 platter 区域内计算每个 slot 的 frame。
    private func itemSlotFramesInPlatter(count: Int) -> [CGRect]? {
        guard count > 0, let platterFrame = liquidGlassPlatterLayoutRegion() else {
            return nil
        }
        return equalItemSlotFrames(in: platterFrame, count: count)
    }
    
    /// 在指定布局区域内均分 item 槽位。
    ///
    /// 计算公式（第 index 个 item）：
    ///   itemWidth = region.width / count
    ///   x      = region.minX + itemWidth × index
    ///   y      = region.minY
    ///   width  = itemWidth
    ///   height = region.height
    private func equalItemSlotFrames(in layoutRegion: CGRect, count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        
        let itemWidth = layoutRegion.width / CGFloat(count)
        var frames: [CGRect] = []
        frames.reserveCapacity(count)
        
        for index in 0..<count {
            frames.append(
                CGRect(
                    x: layoutRegion.minX + itemWidth * CGFloat(index),
                    y: layoutRegion.minY,
                    width: itemWidth,
                    height: layoutRegion.height
                )
            )
        }
        
        return frames
    }
    
    /// 隐藏系统选中装饰（选中胶囊、indicator 等），避免与自定义 item 视觉重复。
    private func hideSystemSelectionDecorations() {
        for subview in subviews {
            if subview is ESTabBarItemContainer {
                continue
            }
            // 顶层 UIControl 一般是系统 Tab 按钮，直接隐藏。
            if subview is UIControl {
                hideViewTree(subview)
                continue
            }
            // 递归处理 platter 等容器内部的装饰视图。
            hideSmallSystemDecorationSubviews(in: subview)
        }
    }
    
    /// 递归查找并隐藏与 container 重叠的系统装饰视图。
    private func hideSmallSystemDecorationSubviews(in view: UIView) {
        for subview in view.subviews {
            let frameInTabBar = subview.convert(subview.bounds, to: self)
            let className = NSStringFromClass(type(of: subview)).lowercased()
            
            // 判断是否与某个 container 区域重叠。
            let overlapsContainer = containers.contains { container in
                frameInTabBar.intersects(container.frame.insetBy(dx: -8.0, dy: -8.0))
            }
            
            // 尺寸较小的装饰视图（选中胶囊等）。
            let isSmallDecoration = !frameInTabBar.isEmpty
                && frameInTabBar.width < bounds.width * 0.8
                && frameInTabBar.height < bounds.height * 1.2
                && overlapsContainer
            
            // 通过私有类名特征识别系统装饰（selection / indicator / pill 等）。
            let nameLooksLikeDecoration = className.contains("selection")
                || className.contains("indicator")
                || className.contains("platter")
                || className.contains("pill")
                || className.contains("glass")
            
            if isSmallDecoration || nameLooksLikeDecoration {
                hideViewTree(subview)
            } else {
                hideSmallSystemDecorationSubviews(in: subview)
            }
        }
    }
    
    /// 递归隐藏 view 及其所有子 view（hidden + alpha=0 + 禁用交互）。
    private func hideViewTree(_ view: UIView) {
        view.isHidden = true
        view.alpha = 0.0
        view.isUserInteractionEnabled = false
        view.subviews.forEach { hideViewTree($0) }
    }
    
    /// 将 tabBar.selectedItem 的选中状态同步到 ESTabBarItem contentView / moreContentView。
    private func syncSelectionState() {
        guard let tabBarItems = self.items else { return }
        
        for (idx, item) in tabBarItems.enumerated() {
            let isSelected = item == selectedItem
            
            if let item = item as? ESTabBarItem {
                if item.contentView.selected != isSelected {
                    if isSelected {
                        item.contentView.select(animated: false, completion: nil)
                    } else {
                        item.contentView.deselect(animated: false, completion: nil)
                    }
                } else {
                    item.contentView.updateDisplay()
                }
            } else if isMoreItem(idx), let moreContentView = moreContentView {
                if moreContentView.selected != isSelected {
                    if isSelected {
                        moreContentView.select(animated: false, completion: nil)
                    } else {
                        moreContentView.deselect(animated: false, completion: nil)
                    }
                } else {
                    moreContentView.updateDisplay()
                }
            }
        }
        
        if isSystemGlassEffectActive {
            syncGlassLayerDisplaysIfNeeded()
        }
    }
}

@available(iOS 26.0, *)
private extension ESTabBar /* System Glass Effect Layout */ {
    
    // MARK: - iOS 26 系统玻璃双层嵌入布局说明
    //
    // 适用：`designType == .automatic` && `usesSystemGlassEffect == true` && iOS 26+
    //
    // 与叠加模式（updateLayoutForLiquidGlass）的核心区别：
    //   - 不隐藏 _UITabBarPlatterView 及 tabBarButton，保留系统 destOut 玻璃合成管线；
    //   - 不显示 ESTabBarItemContainer（隐藏，仅保留 frame 供无障碍）；
    //   - 自定义 UI 写入 platter 内两个内容层的 tabButton，分别展示选中/未选中态。
    //
    // 双层结构（均为 _UITabBarPlatterView 子视图）：
    //   _UITabBarPlatterView
    //     ├── SelectedContentView（高亮层：选中 tab 图标放大，参与 destOut 裁切）
    //     │     └── _UITabButton × N  ← 嵌入 selectedDisplay（强制选中态 UI）
    //     └── ContentView（显示层：所有 tab 未选中样式，合成在选中层下方）
    //           └── _UITabButton × N  ← 嵌入 normalDisplay（强制未选中态 UI）
    //
    // 为什么需要两个展示视图：
    //   iOS 26 选中/未选中由不同层渲染，切换 tab 时并非同一 button 改状态，
    //   而是两层分别合成。单层写入会导致切换时 UI 消失或颜色异常。
    //
    // 整体流程（updateLayoutForSystemGlassEffect）：
    //   1. 确认 platter 存在，否则回退到 updateLayoutForLiquidGlass
    //   2. 保持系统 tabBarButton 可见可交互；隐藏 container
    //   3. installGlassLayerContent：替换两层内 tabButton 的 icon/label
    //   4. syncGlassLayerDisplays：从主 contentView 同步视觉属性
    //   5. 对齐 container 隐藏 frame（无障碍）
    
    /// 系统玻璃嵌入布局主流程。
    ///
    /// 找不到 `_UITabBarPlatterView` 时（如 UIDesignRequiresCompatibility），
    /// 回退到叠加式 Liquid Glass 布局，保证功能可用。
    func updateLayoutForSystemGlassEffect(tabBarItems: [UITabBarItem]) {
        guard let platter = platterViewInTabBar() else {
            // 无 platter 时回退到叠加式 Liquid Glass 布局。
            updateLayoutForLiquidGlass(tabBarItems: tabBarItems)
            return
        }
        
        let buttonInfos = systemTabBarButtonInfos()
        
        if isCustomizing {
            removeGlassLayerDisplays()
            buttonInfos.forEach {
                $0.view.isHidden = false
                $0.view.alpha = 1.0
                $0.view.isUserInteractionEnabled = true
            }
            moreContentView?.isHidden = true
            containers.forEach { $0.isHidden = true }
            return
        }
        
        // 保留系统 tabBarButton 可见与可交互，隐藏叠加 container。
        buttonInfos.forEach {
            $0.view.isHidden = false
            $0.view.alpha = 1.0
            $0.view.isUserInteractionEnabled = true
        }
        containers.forEach { $0.isHidden = true }
        
        installGlassLayerContent(in: platter, tabBarItems: tabBarItems)
        syncGlassLayerDisplays(tabBarItems: tabBarItems)
        
        // 对齐隐藏 container 的 frame，供无障碍等逻辑使用。
        if buttonInfos.count >= containers.count {
            for (idx, container) in containers.enumerated() where idx < buttonInfos.count {
                container.frame = buttonInfos[idx].frameInTabBar
            }
        } else if let slotFrames = itemSlotFramesInPlatter(count: containers.count) {
            applySlotFrames(slotFrames)
        }
    }
    
    /// 定位 platter 内的 SelectedContentView（高亮层）与 ContentView（显示层）。
    ///
    /// 注意：ContentView 类名可能与 SelectedContentView 部分重叠，
    /// 需用 `isNormalContentLayerView` 排除 SelectedContentView 自身。
    private func platterContentLayers(in platter: UIView) -> (selected: UIView?, normal: UIView?) {
        let selected = platter.subviews.first(where: { isSelectedContentLayerView($0) })
        let normal = platter.subviews.first(where: { isNormalContentLayerView($0) })
        return (selected, normal)
    }
    
    /// 按 x 坐标排序，获取某一层内的系统 tab 按钮。
    private func sortedTabButtons(in layerView: UIView) -> [UIView] {
        return layerView.subviews
            .filter { isSystemTabBarButtonView($0) || ($0 is UIControl && !($0 is ESTabBarItemContainer)) }
            .sorted { $0.frame.origin.x < $1.frame.origin.x }
    }
    
    /// 遍历 tabBarItems，将 `glassLayerDisplayPairs` 中的展示视图安装到双层 tabButton。
    ///
    /// 仅处理 ESTabBarItem 与自定义 More；普通 UITabBarItem（mixture 模式）跳过，
    /// 保留系统原生渲染。
    private func installGlassLayerContent(in platter: UIView, tabBarItems: [UITabBarItem]) {
        let layers = platterContentLayers(in: platter)
        guard let selectedLayer = layers.selected, let normalLayer = layers.normal else {
            return
        }
        
        let selectedButtons = sortedTabButtons(in: selectedLayer)
        let normalButtons = sortedTabButtons(in: normalLayer)
        var pairIndex = 0
        
        for (idx, item) in tabBarItems.enumerated() {
            let contentView: ESTabBarItemContentView?
            if let item = item as? ESTabBarItem {
                contentView = item.contentView
            } else if isMoreItem(idx) {
                contentView = moreContentView
            } else {
                continue
            }
            
            guard pairIndex < glassLayerDisplayPairs.count,
                  let sourceContentView = contentView else {
                continue
            }
            
            let pair = glassLayerDisplayPairs[pairIndex]
            pairIndex += 1
            
            if idx < selectedButtons.count {
                embedGlassDisplayView(
                    pair.selectedDisplay,
                    in: selectedButtons[idx],
                    source: sourceContentView,
                    displayAsSelected: true
                )
            }
            if idx < normalButtons.count {
                embedGlassDisplayView(
                    pair.normalDisplay,
                    in: normalButtons[idx],
                    source: sourceContentView,
                    displayAsSelected: false
                )
            }
        }
    }
    
    /// 将单个展示视图嵌入系统 tabButton：隐藏系统 icon/label，添加自定义展示层。
    ///
    /// - Parameter displayAsSelected: `true` 写入 SelectedContentView 层（选中态）；
    ///   `false` 写入 ContentView 层（未选中态）。
    private func embedGlassDisplayView(
        _ displayView: ESTabBarItemContentView,
        in tabButton: UIView,
        source: ESTabBarItemContentView,
        displayAsSelected: Bool
    ) {
        hideSystemTabButtonContent(in: tabButton)
        
        displayView.syncVisualAppearance(from: source, displayAsSelected: displayAsSelected)
        displayView.tag = Self.glassCustomContentTag
        displayView.isUserInteractionEnabled = false
        displayView.frame = tabButton.bounds
        displayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if displayView.superview !== tabButton {
            displayView.removeFromSuperview()
            tabButton.addSubview(displayView)
        }
        
        tabButton.clipsToBounds = false
        displayView.setNeedsLayout()
        displayView.layoutIfNeeded()
    }
    
    /// 隐藏系统 tabBarButton 自带的 UIImageView / UILabel。
    private func hideSystemTabButtonContent(in tabButton: UIView) {
        for subview in tabButton.subviews where subview.tag != Self.glassCustomContentTag {
            if subview is UIImageView || subview is UILabel {
                subview.isHidden = true
                subview.alpha = 0.0
            }
        }
    }
    
    /// 清理所有双层展示视图，恢复系统 tabButton 原始 icon/label。
    /// 在 `reload()`、切换 `usesSystemGlassEffect` / `designType`、进入编辑模式时调用。
    func removeGlassLayerDisplays() {
        guard let platter = platterViewInTabBar() else {
            glassLayerDisplayPairs.removeAll()
            return
        }
        
        let layers = platterContentLayers(in: platter)
        let buttons = [layers.selected, layers.normal]
            .compactMap { $0 }
            .flatMap { sortedTabButtons(in: $0) }
        
        for button in buttons {
            restoreSystemTabButtonContent(in: button)
        }
        glassLayerDisplayPairs.removeAll()
    }
    
    private func restoreSystemTabButtonContent(in tabButton: UIView) {
        tabButton.viewWithTag(Self.glassCustomContentTag)?.removeFromSuperview()
        for subview in tabButton.subviews {
            if subview is UIImageView || subview is UILabel {
                subview.isHidden = false
                subview.alpha = 1.0
            }
        }
    }
    
    /// 将每个 ESTabBarItem 主 contentView 的视觉属性同步到双层镜像视图。
    /// 选中切换、badge 更新、hijack 动画结束后均需调用。
    func syncGlassLayerDisplays(tabBarItems: [UITabBarItem]) {
        var pairIndex = 0
        
        for (idx, item) in tabBarItems.enumerated() {
            let contentView: ESTabBarItemContentView?
            if let item = item as? ESTabBarItem {
                contentView = item.contentView
            } else if isMoreItem(idx) {
                contentView = moreContentView
            } else {
                continue
            }
            
            guard pairIndex < glassLayerDisplayPairs.count,
                  let sourceContentView = contentView else {
                continue
            }
            
            let pair = glassLayerDisplayPairs[pairIndex]
            pairIndex += 1
            
            pair.selectedDisplay.syncVisualAppearance(from: sourceContentView, displayAsSelected: true)
            pair.normalDisplay.syncVisualAppearance(from: sourceContentView, displayAsSelected: false)
        }
    }
}

internal extension ESTabBar /* Actions */ {
    
    /// 判断 index 是否为系统 More 项（tab 超过 4 个时最后一个为 More）。
    func isMoreItem(_ index: Int) -> Bool {
        return ESTabBarController.isShowingMore(tabBarController) && (index == (items?.count ?? 0) - 1)
    }
    
    /// 移除并清空所有 ESTabBarItemContainer。
    func removeAll() {
        for container in containers {
            container.removeFromSuperview()
        }
        containers.removeAll()
    }
    
    /// 根据 items 重建 container 与玻璃层展示视图。
    ///
    /// 两种构建模式（由 `isSystemGlassEffectActive` 决定）：
    ///
    /// **叠加模式 / 传统模式 / .old**（`usesGlass == false`）
    /// - 每个 item 创建 `ESTabBarItemContainer`，将 contentView 作为其子视图。
    /// - container 负责触摸事件（highlight / select / hijack）。
    ///
    /// **系统玻璃嵌入模式**（`usesGlass == true`）
    /// - container 仍创建但默认隐藏（`isHidden = true`），不参与触摸；
    /// - 为每个 ESTabBarItem 额外创建 `GlassLayerDisplayPair`（selected + normal），
    ///   在后续 `installGlassLayerContent` 中写入 platter 双层 tabButton。
    ///
    /// items / designType / usesSystemGlassEffect 变化时均会触发此方法。
    func reload() {
        if #available(iOS 26.0, *) {
            removeGlassLayerDisplays()
            if isLegacyOldDesignOnIOS26 && !isCustomizing {
                removeInstalledContinuousSelectionGestures()
            }
        }
        removeAll()
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        let usesGlass = isSystemGlassEffectActive
        
        for (idx, item) in tabBarItems.enumerated() {
            let container = ESTabBarItemContainer.init(self, tag: 1000 + idx)
            self.addSubview(container)
            self.containers.append(container)
            
            if usesGlass {
                container.isHidden = true
                if let item = item as? ESTabBarItem {
                    let selectedDisplay = makeGlassLayerDisplay(from: item.contentView)
                    let normalDisplay = makeGlassLayerDisplay(from: item.contentView)
                    glassLayerDisplayPairs.append(
                        GlassLayerDisplayPair(
                            selectedDisplay: selectedDisplay,
                            normalDisplay: normalDisplay,
                            sourceContentView: item.contentView
                        )
                    )
                } else if self.isMoreItem(idx), let moreContentView = moreContentView {
                    let selectedDisplay = makeGlassLayerDisplay(from: moreContentView)
                    let normalDisplay = makeGlassLayerDisplay(from: moreContentView)
                    glassLayerDisplayPairs.append(
                        GlassLayerDisplayPair(
                            selectedDisplay: selectedDisplay,
                            normalDisplay: normalDisplay,
                            sourceContentView: moreContentView
                        )
                    )
                }
            } else {
                if let item = item as? ESTabBarItem {
                    container.addSubview(item.contentView)
                }
                if self.isMoreItem(idx), let moreContentView = moreContentView {
                    container.addSubview(moreContentView)
                }
            }
        }
        
        self.updateAccessibilityLabels()
        self.setNeedsLayout()
    }
    
    /// 创建与源 contentView 同子类的玻璃层镜像视图。
    ///
    /// 使用 `type(of: source).init()` 保留自定义子类的 init 配置，
    /// 再通过 `syncVisualAppearance` 复制当前视觉属性。镜像视图禁用交互。
    private func makeGlassLayerDisplay(from source: ESTabBarItemContentView) -> ESTabBarItemContentView {
        let display = type(of: source).init()
        display.syncVisualAppearance(from: source, displayAsSelected: false)
        display.isUserInteractionEnabled = false
        return display
    }
    
    /// 系统玻璃模式下，hijack 被拦截时播放「选中后立即取消」的点击反馈动画。
    ///
    /// 玻璃模式由系统 tabBarButton 处理触摸，`selectAction` 不会触发，
    /// 因此在 `ESTabBarController.tabBar(_:shouldSelect:)` 中调用此方法。
    /// 动画结束后同步双层镜像视图。
    func performGlassHijackFeedback(at index: Int, animated: Bool) {
        guard index >= 0, index < items?.count ?? 0 else { return }
        
        if let item = items?[index] as? ESTabBarItem {
            item.contentView.select(animated: animated, completion: {
                item.contentView.deselect(animated: false, completion: nil)
            })
        } else if isMoreItem(index) {
            moreContentView?.select(animated: animated, completion: {
                self.moreContentView?.deselect(animated: animated, completion: nil)
            })
        }
        
        syncGlassLayerDisplaysIfNeeded()
    }
    
    @objc func highlightAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        let newIndex = max(0, container.tag - 1000)
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if let item = item as? ESTabBarItem {
            item.contentView.highlight(animated: true, completion: nil)
        } else if self.isMoreItem(newIndex) {
            moreContentView?.highlight(animated: true, completion: nil)
        }
    }
    
    @objc func dehighlightAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        let newIndex = max(0, container.tag - 1000)
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if let item = item as? ESTabBarItem {
            item.contentView.dehighlight(animated: true, completion: nil)
        } else if self.isMoreItem(newIndex) {
            moreContentView?.dehighlight(animated: true, completion: nil)
        }
    }
    
    @objc func selectAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else {
            return
        }
        select(itemAtIndex: container.tag - 1000, animated: true)
    }
    
    @objc func select(itemAtIndex idx: Int, animated: Bool) {
        let newIndex = max(0, idx)
        let currentIndex = (selectedItem != nil) ? (items?.firstIndex(of: selectedItem!) ?? -1) : -1
        guard newIndex < items?.count ?? 0, let item = self.items?[newIndex], item.isEnabled == true else {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldSelect: item) ?? true) == false {
            return
        }
        
        if (customDelegate?.tabBar(self, shouldHijack: item) ?? false) == true {
            customDelegate?.tabBar(self, didHijack: item)
            if animated {
                if let item = item as? ESTabBarItem {
                    item.contentView.select(animated: animated, completion: {
                        item.contentView.deselect(animated: false, completion: nil)
                    })
                } else if self.isMoreItem(newIndex) {
                    moreContentView?.select(animated: animated, completion: {
                        self.moreContentView?.deselect(animated: animated, completion: nil)
                    })
                }
            }
            return
        }
        
        if currentIndex != newIndex {
            if currentIndex != -1 && currentIndex < items?.count ?? 0{
                if let currentItem = items?[currentIndex] as? ESTabBarItem {
                    currentItem.contentView.deselect(animated: animated, completion: nil)
                } else if self.isMoreItem(currentIndex) {
                    moreContentView?.deselect(animated: animated, completion: nil)
                }
            }
            if let item = item as? ESTabBarItem {
                item.contentView.select(animated: animated, completion: nil)
            } else if self.isMoreItem(newIndex) {
                moreContentView?.select(animated: animated, completion: nil)
            }
        } else if currentIndex == newIndex {
            if let item = item as? ESTabBarItem {
                item.contentView.reselect(animated: animated, completion: nil)
            } else if self.isMoreItem(newIndex) {
                moreContentView?.reselect(animated: animated, completion: nil)
            }
            
            if let tabBarController = tabBarController {
                var navVC: UINavigationController?
                if let n = tabBarController.selectedViewController as? UINavigationController {
                    navVC = n
                } else if let n = tabBarController.selectedViewController?.navigationController {
                    navVC = n
                }
                
                if let navVC = navVC {
                    if navVC.viewControllers.contains(tabBarController) {
                        if navVC.viewControllers.count > 1 && navVC.viewControllers.last != tabBarController {
                            navVC.popToViewController(tabBarController, animated: true);
                        }
                    } else {
                        if navVC.viewControllers.count > 1 {
                            navVC.popToRootViewController(animated: animated)
                        }
                    }
                }
            
            }
        }
        
        delegate?.tabBar?(self, didSelect: item)
        self.updateAccessibilityLabels()
    }
    
    func updateAccessibilityLabels() {
        guard let tabBarItems = self.items, tabBarItems.count == self.containers.count else {
            return
        }
        
        for (idx, item) in tabBarItems.enumerated() {
            let container = self.containers[idx]
            container.accessibilityIdentifier = item.accessibilityIdentifier
            container.accessibilityTraits = item.accessibilityTraits
            
            if item == selectedItem {
                container.accessibilityTraits = container.accessibilityTraits.union(.selected)
            }
            
            if let explicitLabel = item.accessibilityLabel {
                container.accessibilityLabel = explicitLabel
                container.accessibilityHint = item.accessibilityHint ?? container.accessibilityHint
            } else {
                var accessibilityTitle = ""
                if let item = item as? ESTabBarItem {
                    accessibilityTitle = item.accessibilityLabel ?? item.title ?? ""
                }
                if self.isMoreItem(idx) {
                    accessibilityTitle = NSLocalizedString("More_TabBarItem", bundle: Bundle(for:ESTabBarController.self), comment: "")
                }
                
                let formatString = NSLocalizedString(item == selectedItem ? "TabBarItem_Selected_AccessibilityLabel" : "TabBarItem_AccessibilityLabel",
                                                     bundle: Bundle(for: ESTabBarController.self),
                                                     comment: "")
                container.accessibilityLabel = String(format: formatString, accessibilityTitle, idx + 1, tabBarItems.count)
            }
            
        }
    }
}
