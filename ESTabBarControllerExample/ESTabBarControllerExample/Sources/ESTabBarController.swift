//
//  ESTabBarController.swift
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

/// 是否需要自定义点击事件回调类型
public typealias ESTabBarControllerShouldHijackHandler = ((_ tabBarController: UITabBarController, _ viewController: UIViewController, _ index: Int) -> (Bool))
/// 自定义点击事件回调类型
public typealias ESTabBarControllerDidHijackHandler = ((_ tabBarController: UITabBarController, _ viewController: UIViewController, _ index: Int) -> (Void))

open class ESTabBarController: UITabBarController, ESTabBarDelegate {
    
    /// 打印异常
    public static func printError(_ description: String) {
        #if DEBUG
            print("ERROR: ESTabBarController catch an error '\(description)' \n")
        #endif
    }
    
    /// 当前tabBarController是否存在"More"tab
    public static func isShowingMore(_ tabBarController: UITabBarController?) -> Bool {
        return tabBarController?.moreNavigationController.parent != nil
    }

    /// Ignore next selection or not.
    fileprivate var ignoreNextSelection = false

    /// Should hijack select action or not.
    open var shouldHijackHandler: ESTabBarControllerShouldHijackHandler?
    /// Hijack select action.
    open var didHijackHandler: ESTabBarControllerDidHijackHandler?
    
    /// Observer tabBarController's selectedViewController. change its selection when it will-set.
    open override var selectedViewController: UIViewController? {
        get { super.selectedViewController }
        set {
            if ignoreNextSelection {
                ignoreNextSelection = false
                super.selectedViewController = newValue
                return
            }
            guard let newValue else {
                super.selectedViewController = nil
                return
            }
//            if delegate?.tabBarController?(self, shouldSelect: newValue) == false {
//                revertTabBarVisualSelection()
//                return
//            }
            super.selectedViewController = newValue
            syncTabBarSelectionFromViewController(newValue, animated: false)
        }
    }

    /// Observer tabBarController's selectedIndex. change its selection when it will-set.
    open override var selectedIndex: Int {
        get { super.selectedIndex }
        set {
            if newValue == selectedIndex {
                return
            }
            if ignoreNextSelection {
                ignoreNextSelection = false
                super.selectedIndex = newValue
                return
            }
            guard let tabBar = tabBar as? ESTabBar,
                  let items = tabBar.items,
                  let viewControllers,
                  !viewControllers.isEmpty else {
                super.selectedIndex = newValue
                return
            }
            let value = (ESTabBarController.isShowingMore(self) && newValue > items.count - 1)
                ? items.count - 1
                : newValue
            guard value >= 0, value < viewControllers.count,
                  let item = tabBar.items?[value],
                  tabBar.customDelegate?.tabBar(tabBar, shouldSelect: item) ?? true else {
                revertTabBarVisualSelection()
                return
            }
            super.selectedIndex = newValue
            tabBar.select(itemAtIndex: value, animated: false)
        }
    }

    private func syncTabBarSelectionFromViewController(_ viewController: UIViewController, animated: Bool) {
        guard let tabBar = tabBar as? ESTabBar,
              let items = tabBar.items,
              let index = viewControllers?.firstIndex(of: viewController) else { return }
        let value = (ESTabBarController.isShowingMore(self) && index > items.count - 1) ? items.count - 1 : index
        tabBar.select(itemAtIndex: value, animated: animated)
    }

    private func revertTabBarVisualSelection() {
        guard let tabBar = tabBar as? ESTabBar,
              viewControllers?.indices.contains(selectedIndex) == true else { return }
        tabBar.syncSelectionState(selectedIndex: selectedIndex)
    }
    
    /// Customize set tabBar use KVC.
    open override func viewDidLoad() {
        super.viewDidLoad()
        let tabBar = { () -> ESTabBar in
            let tabBar = ESTabBar()
            tabBar.delegate = self
            tabBar.customDelegate = self
            tabBar.tabBarController = self
            return tabBar
        }()
        self.setValue(tabBar, forKey: "tabBar")
    }

    // MARK: - UITabBar / ESTabBar delegate

    open func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool {
        guard let idx = tabBar.items?.firstIndex(of: item),
              let vc = viewControllers?[idx] else { return true }
        if idx == selectedIndex {
            return false
        }
        return delegate?.tabBarController?(self, shouldSelect: vc) ?? true
    }

    open override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let idx = tabBar.items?.firstIndex(of: item) else { return }
        if idx == selectedIndex {
            return
        }
        if idx == tabBar.items!.count - 1, ESTabBarController.isShowingMore(self) {
            ignoreNextSelection = true
            selectedViewController = moreNavigationController
            return
        }

        guard let vc = viewControllers?[idx] else { return }

        if delegate?.tabBarController?(self, shouldSelect: vc) == false {
            revertTabBarVisualSelection()
            return
        }

        ignoreNextSelection = true
        selectedIndex = idx
        delegate?.tabBarController?(self, didSelect: vc)
    }
    
    open override func tabBar(_ tabBar: UITabBar, willBeginCustomizing items: [UITabBarItem]) {
        if let tabBar = tabBar as? ESTabBar {
            tabBar.updateLayout()
        }
    }
    
    open override func tabBar(_ tabBar: UITabBar, didEndCustomizing items: [UITabBarItem], changed: Bool) {
        if let tabBar = tabBar as? ESTabBar {
            tabBar.updateLayout()
        }
    }
    
    internal func tabBar(_ tabBar: UITabBar, shouldHijack item: UITabBarItem) -> Bool {
        if let idx = tabBar.items?.firstIndex(of: item), let vc = viewControllers?[idx] {
            return shouldHijackHandler?(self, vc, idx) ?? false
        }
        return false
    }
    
    internal func tabBar(_ tabBar: UITabBar, didHijack item: UITabBarItem) {
        if let idx = tabBar.items?.firstIndex(of: item), let vc = viewControllers?[idx] {
            didHijackHandler?(self, vc, idx)
        }
    }
    
}
