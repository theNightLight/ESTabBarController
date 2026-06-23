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
    
    /// 布局入口：iOS 26 优先 Liquid Glass（platter 均分）；iOS 25 及以下走传统布局。
    func updateLayout() {
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        
        if #available(iOS 26.0, *) {
            updateLayoutForLiquidGlass(tabBarItems: tabBarItems)
        } else {
            updateLayoutLegacy(tabBarItems: tabBarItems)
        }
    }
    
    /// iOS 25 及以下的传统布局：直接对齐系统 `UITabBarButton` 的 frame。
    func updateLayoutLegacy(tabBarItems: [UITabBarItem]) {
        let tabBarButtons = legacySystemTabBarButtons()
        
        if isCustomizing {
            // 编辑模式：显示系统按钮，隐藏自定义 container。
            for (idx, _) in tabBarItems.enumerated() {
                guard idx < tabBarButtons.count else { continue }
                tabBarButtons[idx].isHidden = false
                moreContentView?.isHidden = true
            }
            for (_, container) in containers.enumerated(){
                container.isHidden = true
            }
        } else {
            // 使用 ESTabBarItem / 自定义 More 时隐藏对应系统按钮，避免与自定义视图重叠。
            for (idx, item) in tabBarItems.enumerated() {
                guard idx < tabBarButtons.count else { continue }
                if let _ = item as? ESTabBarItem {
                    tabBarButtons[idx].isHidden = true
                } else {
                    tabBarButtons[idx].isHidden = false
                }
                if isMoreItem(idx), let _ = moreContentView {
                    tabBarButtons[idx].isHidden = true
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
            // 默认模式：container  frame 与系统按钮一致。
            for (idx, container) in containers.enumerated(){
                if idx < tabBarButtons.count, !tabBarButtons[idx].frame.isEmpty {
                    container.frame = tabBarButtons[idx].frame
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
    }
    
    /// 查找系统 Tab 按钮（传统布局用），按 x 坐标从左到右排序。
    func legacySystemTabBarButtons() -> [UIView] {
        if let cls = NSClassFromString("UITabBarButton") {
            let buttons = subviews
                .filter { $0.isKind(of: cls) && !($0 is ESTabBarItemContainer) }
                .sorted { $0.frame.origin.x < $1.frame.origin.x }
            if !buttons.isEmpty {
                return buttons
            }
        }
        
        // iOS 26 回退时，按钮可能在子视图深层，用类名匹配兜底。
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
    
    // MARK: - iOS 26 Liquid Glass 布局说明
    //
    // iOS 26 的 TabBar 结构变为：
    //   ESTabBar
    //     └── _UITabBarPlatterView（玻璃背景容器，浮动胶囊）
    //           └── UITabBarButton × N（系统 Tab 按钮）
    //
    // ESTabBar 在系统按钮之上叠加 ESTabBarItemContainer（自定义 icon/文字）。
    // 布局规则：以 _UITabBarPlatterView 的 frame 为基准，均分给每个 item。
    //
    // 整体流程（updateLayoutForLiquidGlass）：
    //   1. 收集系统按钮信息
    //   2. 隐藏有自定义内容的系统按钮（避免重复显示）
    //   3. 有 platter → 按 _UITabBarPlatterView 均分；无 platter → iOS 26 回退布局
    //   4. 隐藏系统选中装饰（避免与自定义选中态重叠）
    //   5. 同步自定义 contentView 的选中状态
    
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
    
    /// 是否为系统 Tab 按钮（`_UITabBarButton` / `UITabBarButton`）。
    private func isSystemTabBarButtonView(_ view: UIView) -> Bool {
        guard !(view is ESTabBarItemContainer) else { return false }
        return matchesSystemClassName(view, target: "_UITabBarButton")
            || matchesSystemClassName(view, target: "UITabBarButton")
    }
    
    /// 匹配 UIKit 私有类的真实类名（兼容模块前缀，如 `UIKit._UITabBarPlatterView`）。
    private func matchesSystemClassName(_ view: UIView, target: String) -> Bool {
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
    
    /// 根据 items 重建 container，并将 ESTabBarItem.contentView / moreContentView 放入对应 container。
    func reload() {
        removeAll()
        guard let tabBarItems = self.items else {
            ESTabBarController.printError("empty items")
            return
        }
        for (idx, item) in tabBarItems.enumerated() {
            let container = ESTabBarItemContainer.init(self, tag: 1000 + idx)
            self.addSubview(container)
            self.containers.append(container)
            
            if let item = item as? ESTabBarItem {
                container.addSubview(item.contentView)
            }
            if self.isMoreItem(idx), let moreContentView = moreContentView {
                container.addSubview(moreContentView)
            }
        }
        
        self.updateAccessibilityLabels()
        self.setNeedsLayout()
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
