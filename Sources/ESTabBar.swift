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
    
    func updateLayoutLegacy(tabBarItems: [UITabBarItem]) {
        let tabBarButtons = subviews.filter { subview -> Bool in
            if let cls = NSClassFromString("UITabBarButton") {
                return subview.isKind(of: cls)
            }
            return false
            } .sorted { (subview1, subview2) -> Bool in
                return subview1.frame.origin.x < subview2.frame.origin.x
        }
        
        if isCustomizing {
            for (idx, _) in tabBarItems.enumerated() {
                tabBarButtons[idx].isHidden = false
                moreContentView?.isHidden = true
            }
            for (_, container) in containers.enumerated(){
                container.isHidden = true
            }
        } else {
            for (idx, item) in tabBarItems.enumerated() {
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
            // System itemPositioning
            for (idx, container) in containers.enumerated(){
                if !tabBarButtons[idx].frame.isEmpty {
                    container.frame = tabBarButtons[idx].frame
                }
            }
        } else {
            // Custom itemPositioning
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
}

@available(iOS 26.0, *)
private extension ESTabBar /* Liquid Glass Layout */ {
    
    struct SystemTabBarButtonInfo {
        let view: UIView
        let frameInTabBar: CGRect
    }
    
    func updateLayoutForLiquidGlass(tabBarItems: [UITabBarItem]) {
        // Capture system button frames before hiding any subviews.
        let buttonInfos = systemTabBarButtonInfos()
        let slotFrames = systemTabItemSlotFrames(buttonInfos: buttonInfos)
        
        if isCustomizing {
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
        layoutContainers(buttonInfos: buttonInfos, slotFrames: slotFrames)
        hideSystemSelectionDecorations()
        containers.forEach { bringSubviewToFront($0) }
        syncSelectionState()
    }
    
    /// Collects UIKit-generated tab bar buttons and their frames in ESTabBar coordinates.
    private func systemTabBarButtonInfos() -> [SystemTabBarButtonInfo] {
        let itemCount = items?.count ?? 0
        
        for className in ["UITabBarButton", "_UITabBarButton"] {
            guard let cls = NSClassFromString(className) else { continue }
            let views = findSubviewRecursive(in: self, matching: cls)
                .filter { !($0 is ESTabBarItemContainer) }
            if !views.isEmpty {
                return makeButtonInfos(from: views)
            }
        }
        
        let platterButtons = systemButtonsInsidePlatter()
        if !platterButtons.isEmpty {
            return makeButtonInfos(from: platterButtons)
        }
        
        let directControls = subviews.filter { subview in
            subview is UIControl && !(subview is ESTabBarItemContainer)
        }
        if directControls.count >= itemCount || !directControls.isEmpty {
            return makeButtonInfos(from: directControls)
        }
        
        return []
    }
    
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
    
    private func systemButtonsInsidePlatter() -> [UIView] {
        for className in ["_UITabBarPlatterView", "UITabBarPlatterView"] {
            guard let platterClass = NSClassFromString(className) else { continue }
            
            let platters = findSubviewRecursive(in: self, matching: platterClass)
            for platter in platters {
                if let buttonClass = NSClassFromString("UITabBarButton") {
                    let buttons = findSubviewRecursive(in: platter, matching: buttonClass)
                        .filter { !($0 is ESTabBarItemContainer) }
                    if !buttons.isEmpty {
                        return buttons
                    }
                }
                
                let controls = platter.subviews.filter { subview in
                    subview is UIControl && !(subview is ESTabBarItemContainer)
                }
                if !controls.isEmpty {
                    return controls
                }
            }
        }
        return []
    }
    
    private func findSubviewRecursive(in view: UIView, matching cls: AnyClass) -> [UIView] {
        var results: [UIView] = []
        for subview in view.subviews {
            if subview.isKind(of: cls) && !(subview is ESTabBarItemContainer) {
                results.append(subview)
            }
            results.append(contentsOf: findSubviewRecursive(in: subview, matching: cls))
        }
        return results
    }
    
    private func platterFrameInTabBar() -> CGRect? {
        for className in ["_UITabBarPlatterView", "UITabBarPlatterView"] {
            guard let cls = NSClassFromString(className) else { continue }
            let platters = findSubviewRecursive(in: self, matching: cls)
            for platter in platters {
                let frame = platter.convert(platter.bounds, to: self)
                if !frame.isEmpty {
                    return frame
                }
            }
        }
        return nil
    }
    
    private func layoutContainers(
        buttonInfos: [SystemTabBarButtonInfo],
        slotFrames: [CGRect]? = nil
    ) {
        var layoutBaseSystem = true
        if let itemCustomPositioning = itemCustomPositioning {
            switch itemCustomPositioning {
            case .fill, .automatic, .centered:
                break
            case .fillIncludeSeparator, .fillExcludeSeparator:
                layoutBaseSystem = false
            }
        }
        
        if !layoutBaseSystem {
            layoutContainersManually(buttonInfos: buttonInfos)
            return
        }
        
        let resolvedSlotFrames = slotFrames ?? systemTabItemSlotFrames(buttonInfos: buttonInfos)
        if let resolvedSlotFrames,
           resolvedSlotFrames.count >= containers.count {
            for (idx, container) in containers.enumerated() {
                container.frame = resolvedSlotFrames[idx]
            }
            return
        }
        
        layoutContainersManually(buttonInfos: buttonInfos)
    }
    
    /// Returns per-item layout frames from the system's tab bar item container.
    private func systemTabItemSlotFrames(buttonInfos: [SystemTabBarButtonInfo]) -> [CGRect]? {
        if let stackFrames = horizontalStackItemFramesInTabBar(),
           stackFrames.count >= containers.count {
            return Array(stackFrames.prefix(containers.count))
        }
        
        if let siblingFrames = horizontalSiblingItemFramesInTabBar(),
           siblingFrames.count >= containers.count {
            return Array(siblingFrames.prefix(containers.count))
        }
        
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map { $0.frameInTabBar }
            if frames.allSatisfy({ !$0.isEmpty }), validateTabItemSlotFrames(frames) {
                return Array(frames)
            }
        }
        
        return nil
    }
    
    private func validateTabItemSlotFrames(_ frames: [CGRect]) -> Bool {
        guard !frames.isEmpty else { return false }
        
        let widths = frames.map { $0.width }
        let averageWidth = widths.reduce(0, +) / CGFloat(widths.count)
        guard averageWidth > 10,
              widths.allSatisfy({ abs($0 - averageWidth) < averageWidth * 0.6 }) else {
            return false
        }
        
        guard let platterFrame = platterFrameInTabBar() else { return true }
        
        let firstFrame = frames[0]
        let lastFrame = frames[frames.count - 1]
        let leftGap = firstFrame.minX - platterFrame.minX
        let rightGap = platterFrame.maxX - lastFrame.maxX
        let spanRatio = (lastFrame.maxX - firstFrame.minX) / platterFrame.width
        
        return spanRatio < 0.95 || (leftGap >= 6 && rightGap >= 6)
    }
    
    private func horizontalStackItemFramesInTabBar() -> [CGRect]? {
        let searchRoot = platterView() ?? self
        guard let stack = findHorizontalStackView(in: searchRoot) else { return nil }
        
        let frames = stack.arrangedSubviews
            .map { $0.convert($0.bounds, to: self) }
            .filter { !$0.isEmpty }
            .sorted { $0.origin.x < $1.origin.x }
        
        return frames.isEmpty ? nil : frames
    }
    
    private func horizontalSiblingItemFramesInTabBar() -> [CGRect]? {
        guard let platter = platterView() else { return nil }
        return findMatchingSiblingItemFrames(in: platter, matchingCount: containers.count)
    }
    
    private func findMatchingSiblingItemFrames(in view: UIView, matchingCount: Int) -> [CGRect]? {
        for subview in view.subviews where !(subview is ESTabBarItemContainer) {
            let children = subview.subviews.filter { child in
                !(child is ESTabBarItemContainer) && !child.frame.isEmpty
            }
            
            if children.count == matchingCount {
                let frames = children
                    .map { $0.convert($0.bounds, to: self) }
                    .sorted { $0.origin.x < $1.origin.x }
                if validateTabItemSlotFrames(frames) {
                    return frames
                }
            }
            
            if let frames = findMatchingSiblingItemFrames(in: subview, matchingCount: matchingCount) {
                return frames
            }
        }
        return nil
    }
    
    private func findHorizontalStackView(in view: UIView) -> UIStackView? {
        for subview in view.subviews {
            if let stack = subview as? UIStackView,
               stack.axis == .horizontal,
               !stack.arrangedSubviews.isEmpty {
                return stack
            }
            if let stack = findHorizontalStackView(in: subview) {
                return stack
            }
        }
        return nil
    }
    
    private func platterView() -> UIView? {
        for className in ["_UITabBarPlatterView", "UITabBarPlatterView"] {
            guard let cls = NSClassFromString(className) else { continue }
            if let platter = findSubviewRecursive(in: self, matching: cls).first {
                return platter
            }
        }
        return nil
    }
    
    private func layoutContainersManually(buttonInfos: [SystemTabBarButtonInfo] = []) {
        guard !containers.isEmpty else { return }
        
        let count = CGFloat(containers.count)
        let layoutRegion = tabBarItemLayoutRegion(buttonInfos: buttonInfos)
        let bottomInset = itemEdgeInsets.bottom
        
        var top = layoutRegion.origin.y + itemEdgeInsets.top
        if itemCustomPositioning == .fillExcludeSeparator, top <= layoutRegion.origin.y {
            top = layoutRegion.origin.y + 1.0
        }
        
        let left = layoutRegion.origin.x + itemEdgeInsets.left
        let availableWidth = layoutRegion.width - itemEdgeInsets.left - itemEdgeInsets.right
        let availableHeight = layoutRegion.height - (top - layoutRegion.origin.y) - bottomInset
        let spacing = itemSpacing == 0.0 ? 0.0 : itemSpacing
        let totalSpacing = spacing * max(0, count - 1)
        let itemW = itemWidth == 0.0
            ? (availableWidth - totalSpacing) / count
            : itemWidth
        
        var x = left
        for container in containers {
            container.frame = CGRect(x: x, y: top, width: itemW, height: availableHeight)
            x += itemW + spacing
        }
    }
    
    private func tabBarItemLayoutRegion(buttonInfos: [SystemTabBarButtonInfo]) -> CGRect {
        if let stack = findHorizontalStackView(in: platterView() ?? self) {
            let stackFrame = stack.convert(stack.bounds, to: self)
            if !stackFrame.isEmpty {
                return stackFrame
            }
        }
        
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map { $0.frameInTabBar }
            var union = frames[0]
            for frame in frames.dropFirst() {
                union = union.union(frame)
            }
            if let platterFrame = platterFrameInTabBar() {
                let leftGap = union.minX - platterFrame.minX
                let rightGap = platterFrame.maxX - union.maxX
                if leftGap >= 8 && rightGap >= 8 {
                    return union
                }
            } else if !union.isEmpty {
                return union
            }
        }
        
        if let platterFrame = platterFrameInTabBar() {
            let horizontalInset = liquidGlassContentHorizontalInset(platterWidth: platterFrame.width)
            return platterFrame.insetBy(dx: horizontalInset, dy: 0)
        }
        
        return CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - safeAreaInsets.bottom
        )
    }
    
    private func liquidGlassContentHorizontalInset(platterWidth: CGFloat) -> CGFloat {
        return max(24.0, platterWidth * 0.1)
    }
    
    private func hideSystemSelectionDecorations() {
        for subview in subviews {
            if subview is ESTabBarItemContainer {
                continue
            }
            if subview is UIControl {
                hideViewTree(subview)
                continue
            }
            hideSmallSystemDecorationSubviews(in: subview)
        }
    }
    
    private func hideSmallSystemDecorationSubviews(in view: UIView) {
        for subview in view.subviews {
            let frameInTabBar = subview.convert(subview.bounds, to: self)
            let className = NSStringFromClass(type(of: subview)).lowercased()
            
            let overlapsContainer = containers.contains { container in
                frameInTabBar.intersects(container.frame.insetBy(dx: -8.0, dy: -8.0))
            }
            
            let isSmallDecoration = !frameInTabBar.isEmpty
                && frameInTabBar.width < bounds.width * 0.8
                && frameInTabBar.height < bounds.height * 1.2
                && overlapsContainer
            
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
    
    private func hideViewTree(_ view: UIView) {
        view.isHidden = true
        view.alpha = 0.0
        view.isUserInteractionEnabled = false
        view.subviews.forEach { hideViewTree($0) }
    }
    
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
    
    func isMoreItem(_ index: Int) -> Bool {
        return ESTabBarController.isShowingMore(tabBarController) && (index == (items?.count ?? 0) - 1)
    }
    
    func removeAll() {
        for container in containers {
            container.removeFromSuperview()
        }
        containers.removeAll()
    }
    
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
