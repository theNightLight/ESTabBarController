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

public enum ESTabBarItemPositioning: Int {
    case automatic
    case fill
    case centered
    case fillExcludeSeparator
    case fillIncludeSeparator
}

/// TabBar 布局风格：`.automatic` 随系统版本适配；`.old` 始终传统布局（iOS 26+ 隐藏 platter）。
public enum ESTabBarDesignType: Int {
    case automatic
    case old
}

internal protocol ESTabBarDelegate: NSObjectProtocol {
    func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool
    func tabBar(_ tabBar: UITabBar, shouldHijack item: UITabBarItem) -> Bool
    func tabBar(_ tabBar: UITabBar, didHijack item: UITabBarItem)
}

/// 自定义 TabBar：通过 `ESTabBarItemContainer` 承载自定义 item，iOS 26+ 可选系统玻璃双层嵌入。
open class ESTabBar: UITabBar {

    internal weak var customDelegate: ESTabBarDelegate?
    internal var containers = [ESTabBarItemContainer]()
    internal weak var tabBarController: UITabBarController?

    /// iOS 26 玻璃模式：每个 item 的选中层 / 未选中层镜像视图。
    internal struct GlassLayerDisplayPair {
        let selectedDisplay: ESTabBarItemContentView
        let normalDisplay: ESTabBarItemContentView
        weak var sourceContentView: ESTabBarItemContentView?
    }

    internal var glassLayerDisplayPairs = [GlassLayerDisplayPair]()
    private static let glassCustomContentTag = 9_001

    public var tabBarHeight: CGFloat? {
        didSet {
            guard tabBarHeight ?? 0 > 0 else { return }
            setNeedsLayout()
        }
    }

    public var itemEdgeInsets = UIEdgeInsets.zero

    public var itemCustomPositioning: ESTabBarItemPositioning? {
        didSet {
            if let itemCustomPositioning {
                switch itemCustomPositioning {
                case .fill: itemPositioning = .fill
                case .automatic: itemPositioning = .automatic
                case .centered: itemPositioning = .centered
                default: break
                }
            }
            reload()
        }
    }

    open var moreContentView: ESTabBarItemContentView? = ESTabBarItemMoreContentView() {
        didSet { reload() }
    }

    /// 默认 `.automatic`。`.old` 时忽略 `usesSystemGlassEffect`。
    open var designType: ESTabBarDesignType = .automatic {
        didSet { if oldValue != designType { reload() } }
    }

    /// 仅 `designType == .automatic` 且 iOS 26+ 有效。`true` 时双层 mirror 替换系统 button，container 负责触摸。
    open var usesSystemGlassEffect: Bool = true {
        didSet { if oldValue != usesSystemGlassEffect { reload() } }
    }

    open override var items: [UITabBarItem]? {
        didSet { reload() }
    }

    open var isEditing: Bool = false {
        didSet { if oldValue != isEditing { updateLayout() } }
    }

    open override func setItems(_ items: [UITabBarItem]?, animated: Bool) {
        super.setItems(items, animated: animated)
        reload()
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
        updateLayout()
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let defaultSize = super.sizeThatFits(size)
        if let tabBarHeight, tabBarHeight > 0 {
            return CGSize(width: defaultSize.width, height: tabBarHeight)
        }
        return defaultSize
    }

    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) { return true }
        return containers.contains {
            $0.point(inside: CGPoint(x: point.x - $0.frame.origin.x, y: point.y - $0.frame.origin.y), with: event)
        }
    }
}

// MARK: - Layout

internal extension ESTabBar {

    struct TabBarButtonInfo {
        let view: UIView
        let frameInTabBar: CGRect
    }

    var usesModernDesignLayout: Bool {
        designType == .automatic && isIOS26OrLater
    }

    var isSystemGlassEffectActive: Bool {
        usesModernDesignLayout && usesSystemGlassEffect
    }

    var isLegacyOldDesignOnIOS26: Bool {
        designType == .old && isIOS26OrLater
    }

    private var isIOS26OrLater: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// 布局路由：`.old` → legacy；`.automatic` + iOS 26 → glass / overlay；其余 → legacy。
    func updateLayout() {
        guard let tabBarItems = items else {
            ESTabBarController.printError("empty items")
            return
        }

        if designType == .old {
            updateLayoutLegacy(tabBarItems: tabBarItems)
            return
        }

        if #available(iOS 26.0, *) {
            setPlatterViewsHidden(false)
            if usesSystemGlassEffect {
                updateLayoutForSystemGlassEffect(tabBarItems: tabBarItems)
            } else {
                updateLayoutForLiquidGlass(tabBarItems: tabBarItems)
            }
        } else {
            updateLayoutLegacy(tabBarItems: tabBarItems)
        }
    }

    func syncGlassLayerDisplaysIfNeeded() {
        guard isSystemGlassEffectActive, let tabBarItems = items else { return }
        if #available(iOS 26.0, *) {
            syncGlassLayerDisplays(tabBarItems: tabBarItems)
        }
    }

    // MARK: Legacy

    func updateLayoutLegacy(tabBarItems: [UITabBarItem]) {
        let flatOldOnIOS26 = isLegacyOldDesignOnIOS26 && !isCustomizing

        if flatOldOnIOS26 {
            setPlatterViewsHidden(true)
        } else if #available(iOS 26.0, *) {
            setPlatterViewsHidden(false)
        }

        let buttonInfos = systemTabBarButtonInfos()

        if isCustomizing {
            if isLegacyOldDesignOnIOS26 { setPlatterViewsHidden(false) }
            buttonInfos.forEach { showViewTree($0.view) }
            moreContentView?.isHidden = true
            containers.forEach { $0.isHidden = true }
        } else {
            if !flatOldOnIOS26 {
                for (idx, item) in tabBarItems.enumerated() where idx < buttonInfos.count {
                    buttonInfos[idx].view.isHidden = isCustomTabItem(item, at: idx)
                }
            }
            containers.forEach { $0.isHidden = false }
        }

        if usesManualFillLayout {
            layoutContainersWithFillMode()
        } else if flatOldOnIOS26 {
            layoutContainersEquallyInTabBar()
        } else {
            zip(containers, buttonInfos).forEach { container, info in
                if !info.frameInTabBar.isEmpty {
                    container.frame = info.frameInTabBar
                }
            }
        }

        if flatOldOnIOS26 {
            containers.forEach { bringSubviewToFront($0) }
        }
    }

    private var usesManualFillLayout: Bool {
        guard let positioning = itemCustomPositioning else { return false }
        switch positioning {
        case .fillIncludeSeparator, .fillExcludeSeparator: return true
        default: return false
        }
    }

    private func layoutContainersWithFillMode() {
        var x = itemEdgeInsets.left
        var y = itemEdgeInsets.top
        if itemCustomPositioning == .fillExcludeSeparator, y <= 0 { y = 1 }
        let width = bounds.width - itemEdgeInsets.left - itemEdgeInsets.right
        let height = bounds.height - y - itemEdgeInsets.bottom
        let eachWidth = itemWidth == 0 ? width / CGFloat(containers.count) : itemWidth
        let spacing = itemSpacing == 0 ? 0 : itemSpacing
        for container in containers {
            container.frame = CGRect(x: x, y: y, width: eachWidth, height: height)
            x += eachWidth + spacing
        }
    }

    /// iOS 26 `.old`：TabBar 全宽均分（扣除底部安全区）。
    private func layoutContainersEquallyInTabBar() {
        guard !containers.isEmpty else { return }
        let y = max(itemEdgeInsets.top, 0)
        let layoutWidth = bounds.width - itemEdgeInsets.left - itemEdgeInsets.right
        let layoutHeight = bounds.height - y - itemEdgeInsets.bottom - safeAreaInsets.bottom
        let eachWidth = itemWidth == 0 ? layoutWidth / CGFloat(containers.count) : itemWidth
        let spacing = itemSpacing == 0 ? 0 : itemSpacing
        var x = itemEdgeInsets.left
        for container in containers {
            container.frame = CGRect(x: x, y: y, width: eachWidth, height: layoutHeight)
            x += eachWidth + spacing
        }
    }

    func setPlatterViewsHidden(_ hidden: Bool) {
        if #available(iOS 26.0, *) {
            findSubviews(in: self) { matchesSystemClassName($0, target: "_UITabBarPlatterView") }
                .forEach { view in
                    view.isHidden = hidden
                    view.alpha = hidden ? 0 : 1
                    view.isUserInteractionEnabled = !hidden
                }
        }
    }

    func removeInstalledContinuousSelectionGestures() {
        guard #available(iOS 26.0, *), isLegacyOldDesignOnIOS26, !isCustomizing else { return }
        removeContinuousSelectionGestures(in: self)
    }

    private func removeContinuousSelectionGestures(in view: UIView) {
        view.gestureRecognizers?
            .filter { isContinuousSelectionGesture($0) }
            .forEach { view.removeGestureRecognizer($0) }
        view.subviews.forEach { removeContinuousSelectionGestures(in: $0) }
    }

    private func isContinuousSelectionGesture(_ gesture: UIGestureRecognizer) -> Bool {
        String(describing: type(of: gesture)).hasSuffix("_UIContinuousSelectionGestureRecognizer")
    }

    func systemTabBarButtonInfos() -> [TabBarButtonInfo] {
        let buttons = systemTabBarButtonViews()
        return buttons
            .map { TabBarButtonInfo(view: $0, frameInTabBar: frameInTabBar($0)) }
            .sorted { $0.frameInTabBar.minX < $1.frameInTabBar.minX }
    }

    private func systemTabBarButtonViews() -> [UIView] {
        if let cls = NSClassFromString("UITabBarButton") {
            let direct = subviews
                .filter { $0.isKind(of: cls) && !($0 is ESTabBarItemContainer) }
                .sorted { $0.frame.minX < $1.frame.minX }
            if !direct.isEmpty { return direct }
        }
        return findSubviews(in: self) { isSystemTabBarButtonView($0) }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    // MARK: View helpers

    func isCustomTabItem(_ item: UITabBarItem, at index: Int) -> Bool {
        item is ESTabBarItem || (isMoreItem(index) && moreContentView != nil)
    }

    func contentView(for item: UITabBarItem, at index: Int) -> ESTabBarItemContentView? {
        if let item = item as? ESTabBarItem { return item.contentView }
        if isMoreItem(index) { return moreContentView }
        return nil
    }

    func frameInTabBar(_ view: UIView) -> CGRect {
        view.convert(view.bounds, to: self)
    }

    func matchesSystemClassName(_ view: UIView, target: String) -> Bool {
        for name in [NSStringFromClass(type(of: view)), String(describing: type(of: view))] {
            if name == target || name.hasSuffix(".\(target)") { return true }
        }
        return false
    }

    func isSystemTabBarButtonView(_ view: UIView) -> Bool {
        guard !(view is ESTabBarItemContainer) else { return false }
        return ["_UITabBarButton", "UITabBarButton", "_UITabButton", "UITabButton"]
            .contains { matchesSystemClassName(view, target: $0) }
    }

    func findSubviews(in view: UIView, where predicate: (UIView) -> Bool) -> [UIView] {
        var results: [UIView] = []
        for subview in view.subviews {
            if predicate(subview) { results.append(subview) }
            results.append(contentsOf: findSubviews(in: subview, where: predicate))
        }
        return results
    }

    func hideViewTree(_ view: UIView) {
        view.isHidden = true
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.subviews.forEach { hideViewTree($0) }
    }

    func showViewTree(_ view: UIView) {
        view.isHidden = false
        view.alpha = 1
        view.isUserInteractionEnabled = true
    }

    func applySlotFrames(_ frames: [CGRect]) {
        for (idx, container) in containers.enumerated() where idx < frames.count {
            container.frame = frames[idx]
        }
    }

    func equalSlotFrames(in region: CGRect, count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        let slotWidth = region.width / CGFloat(count)
        return (0..<count).map { index in
            CGRect(x: region.minX + slotWidth * CGFloat(index), y: region.minY, width: slotWidth, height: region.height)
        }
    }

    func syncSelectionState() {
        guard let tabBarItems = items else { return }
        for (idx, item) in tabBarItems.enumerated() {
            let selected = item == selectedItem
            if let cv = contentView(for: item, at: idx) {
                updateContentViewSelection(cv, selected: selected)
            }
        }
        syncGlassLayerDisplaysIfNeeded()
    }

    private func updateContentViewSelection(_ contentView: ESTabBarItemContentView, selected: Bool) {
        if contentView.selected != selected {
            if selected {
                contentView.select(animated: false, completion: nil)
            } else {
                contentView.deselect(animated: false, completion: nil)
            }
        } else {
            contentView.updateDisplay()
        }
    }
}

// MARK: - iOS 26

@available(iOS 26.0, *)
private extension ESTabBar {

    func updateLayoutForLiquidGlass(tabBarItems: [UITabBarItem]) {
        let buttonInfos = systemTabBarButtonInfos()

        if isCustomizing {
            buttonInfos.forEach { showViewTree($0.view) }
            moreContentView?.isHidden = true
            containers.forEach { $0.isHidden = true }
            return
        }

        for (idx, item) in tabBarItems.enumerated() {
            guard idx < buttonInfos.count else { continue }
            let button = buttonInfos[idx].view
            if isCustomTabItem(item, at: idx) {
                hideViewTree(button)
            } else {
                showViewTree(button)
            }
        }

        containers.forEach { $0.isHidden = false }
        if let platterFrame = platterFrameInTabBar() {
            applySlotFrames(equalSlotFrames(in: platterFrame, count: containers.count))
        } else {
            layoutContainersFallback(buttonInfos: buttonInfos)
        }
        hideSystemSelectionDecorations()
        containers.forEach { bringSubviewToFront($0) }
        syncSelectionState()
    }

    func updateLayoutForSystemGlassEffect(tabBarItems: [UITabBarItem]) {
        guard platterView() != nil else {
            updateLayoutForLiquidGlass(tabBarItems: tabBarItems)
            return
        }

        let buttonInfos = systemTabBarButtonInfos()

        if isCustomizing {
            removeGlassLayerDisplays()
            buttonInfos.forEach { showViewTree($0.view) }
            moreContentView?.isHidden = true
            containers.forEach { $0.isHidden = true }
            return
        }

        installGlassLayerContent(tabBarItems: tabBarItems)
        syncGlassLayerDisplays(tabBarItems: tabBarItems)

        for (idx, container) in containers.enumerated() {
            guard idx < tabBarItems.count else { continue }
            let show = isCustomTabItem(tabBarItems[idx], at: idx)
            container.isHidden = !show
            if show { bringSubviewToFront(container) }
        }

        if buttonInfos.count >= containers.count {
            zip(containers, buttonInfos).forEach { $0.frame = $1.frameInTabBar }
        } else if let platterFrame = platterFrameInTabBar() {
            applySlotFrames(equalSlotFrames(in: platterFrame, count: containers.count))
        }
    }

    func installGlassLayerContent(tabBarItems: [UITabBarItem]) {
        guard let platter = platterView(),
              let selectedLayer = platter.subviews.first(where: { matchesSystemClassName($0, target: "SelectedContentView") }),
              let normalLayer = platter.subviews.first(where: {
                  matchesSystemClassName($0, target: "ContentView") && !matchesSystemClassName($0, target: "SelectedContentView")
              }) else { return }

        let selectedButtons = sortedTabButtons(in: selectedLayer)
        let normalButtons = sortedTabButtons(in: normalLayer)
        var pairIndex = 0

        for (idx, item) in tabBarItems.enumerated() {
            guard isCustomTabItem(item, at: idx),
                  pairIndex < glassLayerDisplayPairs.count,
                  let source = contentView(for: item, at: idx) else { continue }
            let pair = glassLayerDisplayPairs[pairIndex]
            pairIndex += 1
            if idx < selectedButtons.count {
                replaceGlassDisplay(pair.selectedDisplay, replacing: selectedButtons[idx], source: source, selected: true)
            }
            if idx < normalButtons.count {
                replaceGlassDisplay(pair.normalDisplay, replacing: normalButtons[idx], source: source, selected: false)
            }
        }
    }

    func replaceGlassDisplay(
        _ display: ESTabBarItemContentView,
        replacing tabButton: UIView,
        source: ESTabBarItemContentView,
        selected: Bool
    ) {
        guard let layer = tabButton.superview else { return }
        display.syncVisualAppearance(from: source, displayAsSelected: selected)
        display.tag = Self.glassCustomContentTag
        display.isUserInteractionEnabled = false
        display.frame = tabButton.frame
        display.autoresizingMask = tabButton.autoresizingMask
        hideViewTree(tabButton)
        if display.superview !== layer {
            display.removeFromSuperview()
            let index = layer.subviews.firstIndex(of: tabButton).map { $0 + 1 } ?? layer.subviews.count
            layer.insertSubview(display, at: index)
        }
        display.setNeedsLayout()
        display.layoutIfNeeded()
    }

    func removeGlassLayerDisplays() {
        defer { glassLayerDisplayPairs.removeAll() }
        guard let platter = platterView() else { return }

        for layer in platterContentLayers(in: platter) {
            layer.subviews.filter { $0.tag == Self.glassCustomContentTag }.forEach { $0.removeFromSuperview() }
            sortedTabButtons(in: layer).forEach { showViewTree($0) }
        }
    }

    func syncGlassLayerDisplays(tabBarItems: [UITabBarItem]) {
        var pairIndex = 0
        for (idx, item) in tabBarItems.enumerated() {
            guard isCustomTabItem(item, at: idx),
                  pairIndex < glassLayerDisplayPairs.count,
                  let source = contentView(for: item, at: idx) else { continue }
            let pair = glassLayerDisplayPairs[pairIndex]
            pairIndex += 1
            pair.selectedDisplay.syncVisualAppearance(from: source, displayAsSelected: true)
            pair.normalDisplay.syncVisualAppearance(from: source, displayAsSelected: false)
        }
    }

    private func platterView() -> UIView? {
        subviews.first(where: { matchesSystemClassName($0, target: "_UITabBarPlatterView") })
            ?? findSubviews(in: self) { matchesSystemClassName($0, target: "_UITabBarPlatterView") }.first
    }

    private func platterFrameInTabBar() -> CGRect? {
        guard let platter = platterView() else { return nil }
        let frame = frameInTabBar(platter)
        return frame.isEmpty ? nil : frame
    }

    private func platterContentLayers(in platter: UIView) -> [UIView] {
        platter.subviews.filter {
            matchesSystemClassName($0, target: "SelectedContentView")
                || (matchesSystemClassName($0, target: "ContentView") && !matchesSystemClassName($0, target: "SelectedContentView"))
        }
    }

    private func sortedTabButtons(in layer: UIView) -> [UIView] {
        layer.subviews
            .filter { isSystemTabBarButtonView($0) || ($0 is UIControl && !($0 is ESTabBarItemContainer)) }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    private func layoutContainersFallback(buttonInfos: [TabBarButtonInfo]) {
        guard !containers.isEmpty else { return }
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map(\.frameInTabBar)
            if frames.allSatisfy({ !$0.isEmpty }) {
                applySlotFrames(Array(frames))
                return
            }
        }
        let region = fallbackLayoutRegion(buttonInfos: buttonInfos)
        applySlotFrames(equalSlotFrames(in: region, count: containers.count))
    }

    private func fallbackLayoutRegion(buttonInfos: [TabBarButtonInfo]) -> CGRect {
        if buttonInfos.count >= containers.count {
            let frames = buttonInfos.prefix(containers.count).map(\.frameInTabBar)
            if frames.allSatisfy({ !$0.isEmpty }) {
                return frames.reduce(frames[0]) { $0.union($1) }
            }
        }
        return CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - safeAreaInsets.bottom)
    }

    private func hideSystemSelectionDecorations() {
        for subview in subviews where !(subview is ESTabBarItemContainer) {
            if subview is UIControl {
                hideViewTree(subview)
            } else {
                hideDecorationSubviews(in: subview)
            }
        }
    }

    private func hideDecorationSubviews(in view: UIView) {
        for subview in view.subviews {
            let frame = frameInTabBar(subview)
            let name = NSStringFromClass(type(of: subview)).lowercased()
            let overlaps = containers.contains { frame.intersects($0.frame.insetBy(dx: -8, dy: -8)) }
            let isSmall = !frame.isEmpty && frame.width < bounds.width * 0.8 && frame.height < bounds.height * 1.2 && overlaps
            let nameMatch = ["selection", "indicator", "platter", "pill", "glass"].contains { name.contains($0) }
            if isSmall || nameMatch {
                hideViewTree(subview)
            } else {
                hideDecorationSubviews(in: subview)
            }
        }
    }
}

// MARK: - Actions

internal extension ESTabBar {

    func isMoreItem(_ index: Int) -> Bool {
        ESTabBarController.isShowingMore(tabBarController) && index == (items?.count ?? 0) - 1
    }

    func removeAll() {
        containers.forEach { $0.removeFromSuperview() }
        containers.removeAll()
    }

    func reload() {
        if #available(iOS 26.0, *) {
            removeGlassLayerDisplays()
            if isLegacyOldDesignOnIOS26 && !isCustomizing {
                removeInstalledContinuousSelectionGestures()
            }
        }
        removeAll()
        guard let tabBarItems = items else {
            ESTabBarController.printError("empty items")
            return
        }

        let usesGlass = isSystemGlassEffectActive
        for (idx, item) in tabBarItems.enumerated() {
            let container = ESTabBarItemContainer(self, tag: 1000 + idx)
            addSubview(container)
            containers.append(container)

            if usesGlass, let source = contentView(for: item, at: idx) {
                appendGlassLayerPair(from: source)
            } else {
                if let item = item as? ESTabBarItem {
                    container.addSubview(item.contentView)
                }
                if isMoreItem(idx), let moreContentView {
                    container.addSubview(moreContentView)
                }
            }
        }

        updateAccessibilityLabels()
        setNeedsLayout()
    }

    private func appendGlassLayerPair(from source: ESTabBarItemContentView) {
        glassLayerDisplayPairs.append(
            GlassLayerDisplayPair(
                selectedDisplay: makeGlassLayerDisplay(from: source),
                normalDisplay: makeGlassLayerDisplay(from: source),
                sourceContentView: source
            )
        )
    }

    private func makeGlassLayerDisplay(from source: ESTabBarItemContentView) -> ESTabBarItemContentView {
        let display = type(of: source).init()
        display.syncVisualAppearance(from: source, displayAsSelected: false)
        display.isUserInteractionEnabled = false
        return display
    }

    func performGlassHijackFeedback(at index: Int, animated: Bool) {
        guard index >= 0, index < items?.count ?? 0 else { return }
        if let item = items?[index] as? ESTabBarItem {
            item.contentView.select(animated: animated) {
                item.contentView.deselect(animated: false, completion: nil)
            }
        } else if isMoreItem(index) {
            moreContentView?.select(animated: animated) {
                self.moreContentView?.deselect(animated: animated, completion: nil)
            }
        }
        syncGlassLayerDisplaysIfNeeded()
    }

    @objc func highlightAction(_ sender: AnyObject?) {
        performContainerAction(sender, highlight: true)
    }

    @objc func dehighlightAction(_ sender: AnyObject?) {
        performContainerAction(sender, highlight: false)
    }

    @objc func selectAction(_ sender: AnyObject?) {
        guard let container = sender as? ESTabBarItemContainer else { return }
        select(itemAtIndex: container.tag - 1000, animated: true)
    }

    private func performContainerAction(_ sender: AnyObject?, highlight: Bool) {
        guard let container = sender as? ESTabBarItemContainer else { return }
        let index = max(0, container.tag - 1000)
        guard index < items?.count ?? 0, let item = items?[index], item.isEnabled,
              customDelegate?.tabBar(self, shouldSelect: item) ?? true else { return }
        if let cv = contentView(for: item, at: index) {
            if highlight { cv.highlight(animated: true, completion: nil) }
            else { cv.dehighlight(animated: true, completion: nil) }
        }
    }

    @objc func select(itemAtIndex idx: Int, animated: Bool) {
        let newIndex = max(0, idx)
        let currentIndex = selectedItem.flatMap { items?.firstIndex(of: $0) } ?? -1
        guard newIndex < items?.count ?? 0, let item = items?[newIndex], item.isEnabled,
              customDelegate?.tabBar(self, shouldSelect: item) ?? true else { return }

        if customDelegate?.tabBar(self, shouldHijack: item) ?? false {
            customDelegate?.tabBar(self, didHijack: item)
            if animated, let cv = contentView(for: item, at: newIndex) {
                cv.select(animated: true) { cv.deselect(animated: false, completion: nil) }
            }
            return
        }

        if currentIndex != newIndex {
            if currentIndex >= 0, currentIndex < items?.count ?? 0, let prev = items?[currentIndex] {
                contentView(for: prev, at: currentIndex)?.deselect(animated: animated, completion: nil)
            }
            contentView(for: item, at: newIndex)?.select(animated: animated, completion: nil)
        } else if let cv = contentView(for: item, at: newIndex) {
            cv.reselect(animated: animated, completion: nil)
            popNavigationIfNeeded(animated: animated)
        }

        delegate?.tabBar?(self, didSelect: item)
        updateAccessibilityLabels()
    }

    private func popNavigationIfNeeded(animated: Bool) {
        guard let tabBarController else { return }
        let navVC = (tabBarController.selectedViewController as? UINavigationController)
            ?? tabBarController.selectedViewController?.navigationController
        guard let navVC else { return }
        if navVC.viewControllers.contains(tabBarController) {
            if navVC.viewControllers.count > 1, navVC.viewControllers.last != tabBarController {
                navVC.popToViewController(tabBarController, animated: true)
            }
        } else if navVC.viewControllers.count > 1 {
            navVC.popToRootViewController(animated: animated)
        }
    }

    func updateAccessibilityLabels() {
        guard let tabBarItems = items, tabBarItems.count == containers.count else { return }
        for (idx, item) in tabBarItems.enumerated() {
            let container = containers[idx]
            container.accessibilityIdentifier = item.accessibilityIdentifier
            container.accessibilityTraits = item.accessibilityTraits
            if item == selectedItem {
                container.accessibilityTraits.insert(.selected)
            }
            if let explicitLabel = item.accessibilityLabel {
                container.accessibilityLabel = explicitLabel
                container.accessibilityHint = item.accessibilityHint ?? container.accessibilityHint
            } else {
                var title = (item as? ESTabBarItem).flatMap { $0.accessibilityLabel ?? $0.title } ?? ""
                if isMoreItem(idx) {
                    title = NSLocalizedString("More_TabBarItem", bundle: Bundle(for: ESTabBarController.self), comment: "")
                }
                let key = item == selectedItem ? "TabBarItem_Selected_AccessibilityLabel" : "TabBarItem_AccessibilityLabel"
                let format = NSLocalizedString(key, bundle: Bundle(for: ESTabBarController.self), comment: "")
                container.accessibilityLabel = String(format: format, title, idx + 1, tabBarItems.count)
            }
        }
    }
}
