//
//  ViewController.swift
//  ESTabBarControllerExample
//
//  Created by lihao on 2017/2/8.
//  Copyright © 2018年 Egg Swift. All rights reserved.
//

import UIKit

public class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITabBarControllerDelegate, UIAdaptivePresentationControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    private weak var previousSelectedViewController: UIViewController?
    private var previousSelectedIndex: Int?
    private var pendingDialogRestoreSelection: (() -> Void)?
    private var pendingViewControllerSwap: (currentIndex: Int, photoIndex: Int)?
    
    public let sectionTitleArray = ["Basic", "Embed", "Animation", "Irregular", "Customize click", "Remind", "Lottie"]
    public let sectionSubtitleArray = ["基本", "嵌套", "动画", "不规则", "自定义点击", "提醒", "Lottie"]
    public let titleArray = [
        [
            "UITabBarController style",
            "ESTabBarController like system style",
            "Mix ESTabBar and UITabBar",
            "ESTabBarController style with GlassEffect",
            "UITabBarController style with 'More'",
            "ESTabBarController style with 'More'",
            "Mix ESTabBar and UITabBar with 'More'",
            "ESTabBarController style with GlassEffect and 'More' ",
            "UITabBarController style with non-zero default index",
            "ESTabBarController style with non-zero default index",
            "ESTabBarController style Mandatory Old Design",
            "ESTabBarController style with GlassEffect and Badge",
            "UITabBarController tab style",
        ],
        [
            "ESTabBarController embeds the UINavigationController style",
            "UINavigationController embeds the ESTabBarController style",
        ],
        [
            "Customize the selected color style",
            "Spring animation style",
            "Background color change style",
            "With a selected effect style",
            "Suggested clicks style",
        ],
        [
            "In the middle with a larger button style",
        ],
        [
            "Hijack button click event",
            "Add a special reminder box",
        ],
        [
            "System remind style",
            "Imitate system remind style",
            "Remind style with animation",
            "Remind style with animation(2)",
            "Customize remind style",
        ],
        [
            "Lottie",
        ],
    ]
    
    public let subtitleArray = [
        [
            "UITabBarController样式",
            "ESTabBarController仿系统样式",
            "ESTabBar和UITabBar混合样式",
            "ESTabBarController 玻璃效果",
            "带有'More'的UITabBarController样式",
            "带有'More'的ESTabBarController样式",
            "带有'More'的ESTabBar和UITabBar混合样式",
            "带有'More'的ESTabBarController 玻璃效果",
            "默认index非0的UITabBarController样式",
            "默认index非0的ESTabBarController样式",
            "ESTabBarController 强制使用旧版本UI",
            "ESTabBarController 玻璃效果 + Badge",
            "UITabBarController tab 样式",
        ],
        [
            "UINavigationController内嵌UITabBarController样式",
            "UITabBarController内嵌UINavigationController样式",
        ],
        [
            "自定义选中颜色样式",
            "弹簧动画样式",
            "背景颜色变化样式",
            "带有选中效果样式",
            "暗示用户点击样式",
        ],
        [
            "中间带有较大按钮样式",
        ],
        [
            "劫持按钮的点击事件",
            "添加一个特殊的提醒框",
        ],
        [
            "系统提醒样式",
            "仿系统提醒样式",
            "带动画提醒样式",
            "带动画提醒样式(2)",
            "自定义提醒样式",
        ],
        [
            "Lottie",
        ],
    ]
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.init(white: 245.0 / 255.0, alpha: 1.0)
        self.navigationItem.title = "Example"
    }
    
    // MARK: UITableViewDataSource
    public func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitleArray.count
    }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleArray[section].count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68.0
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 42.0
    }
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitleArray[section] + " " + "(" + sectionSubtitleArray[section] + ")"
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell") ?? UITableViewCell.init(style: .subtitle, reuseIdentifier: "UITableViewCell")
        
        cell.textLabel?.textColor = UIColor.init(white: 0.0, alpha: 0.6)
        cell.textLabel?.font = UIFont.init(name: "ChalkboardSE-Bold", size: 14.0)
        cell.textLabel?.lineBreakMode = .byCharWrapping
        cell.textLabel?.text = "\(indexPath.section + 1).\(indexPath.row + 1) \(titleArray[indexPath.section][indexPath.row])"
        cell.textLabel?.numberOfLines = 2
        
        cell.detailTextLabel?.textColor = UIColor.init(white: 0.0, alpha: 0.5)
        cell.detailTextLabel?.font = UIFont.init(name: "ChalkboardSE-Bold", size: 11.0)
        cell.detailTextLabel?.text = "\(indexPath.section + 1).\(indexPath.row + 1) \(subtitleArray[indexPath.section][indexPath.row])"
        cell.detailTextLabel?.numberOfLines = 2
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.systemStyle(), animated: true, completion: nil)
            case 1:
                self.present(ExampleProvider.customStyle(), animated: true, completion: nil)
            case 2:
                self.present(ExampleProvider.mixtureStyle(), animated: true, completion: nil)
            case 3:
                
                    let tabBarController = ExampleProvider.customGlassStyle()
                    tabBarController.delegate = self
                self.present(tabBarController, animated: true, completion: nil)
            case 4:
                let tabBarController = ExampleProvider.systemMoreStyle()
                tabBarController.delegate = self
                self.present(tabBarController, animated: true, completion: nil)
                
            case 5:
                self.present(ExampleProvider.customMoreStyle(), animated: true, completion: nil)
            case 6:
                self.present(ExampleProvider.mixtureMoreStyle(), animated: true, completion: nil)
            case 7:
                self.present(ExampleProvider.customGlassMoreStyle(), animated: true, completion: nil)
            case 8:
                let tabBarController = ExampleProvider.systemStyle()
                self.present(tabBarController, animated: true, completion: nil)
                tabBarController.selectedIndex = 2
            case 9:
                let tabBarController = ExampleProvider.customStyle()
                self.present(tabBarController, animated: true, completion: nil)
                tabBarController.selectedIndex = 2
            case 10:
                let tabBarController = ExampleProvider.mandatoryOldDesignStyle()
                tabBarController.delegate = self
                self.present(tabBarController, animated: true, completion: nil)
            case 11:
                self.present(ExampleProvider.customGlassWithBadgeStyle(), animated: true, completion: nil)
            case 12:
                let tabBarController = ExampleProvider.systemTabStyle()
                tabBarController.delegate = self
                self.present(tabBarController, animated: true, completion: nil)
            default:
                break
            }
        case 1:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.navigationWithTabbarStyle(), animated: true, completion: nil)
            case 1:
                self.present(ExampleProvider.tabbarWithNavigationStyle(), animated: true, completion: nil)
            default:
                break
            }
        case 2:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.customColorStyle(), animated: true, completion: nil)
            case 1:
                self.present(ExampleProvider.customBouncesStyle(), animated: true, completion: nil)
            case 2:
                self.present(ExampleProvider.customBackgroundColorStyle(implies: false), animated: true, completion: nil)
            case 3:
                self.present(ExampleProvider.customHighlightableStyle(), animated: true, completion: nil)
            case 4:
                self.present(ExampleProvider.customBackgroundColorStyle(implies: true), animated: true, completion: nil)
            default:
                break
            }
        case 3:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.customIrregularityStyle(delegate: nil), animated: true, completion: nil)
            default:
                break
            }
        case 4:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.customIrregularityStyle(delegate: self), animated: true, completion: nil)
            case 1:
                self.present(ExampleProvider.customTipsStyle(delegate: self), animated: true, completion: nil)
            default:
                break
            }
        case 5:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.systemRemindStyle(), animated: true, completion: nil)
            case 1:
                self.present(ExampleProvider.customRemindStyle(), animated: true, completion: nil)
            case 2:
                self.present(ExampleProvider.customAnimateRemindStyle(implies: false), animated: true, completion: nil)
            case 3:
                self.present(ExampleProvider.customAnimateRemindStyle2(implies: false), animated: true, completion: nil)
            case 4:
                self.present(ExampleProvider.customAnimateRemindStyle3(implies: false), animated: true, completion: nil)
            default:
                break
            }
        case 6:
            switch indexPath.row {
            case 0:
                self.present(ExampleProvider.lottieSytle(), animated: true, completion: nil)
            default:
                break
            }
        default:
            break
        }
        
    }
    
    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard isPhotoViewController(viewController),
              let photoIndex = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            rememberSelection(in: tabBarController, viewController: viewController)
            return true
        }
        return interceptPhotoTab(in: tabBarController, photoIndex: photoIndex)
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard !isPhotoViewController(viewController) else { return }
        rememberSelection(in: tabBarController, viewController: viewController)
    }

    @available(iOS 18.0, *)
    public func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        guard tab.title == "Photo", let photoIndex = tabBarController.tabs.firstIndex(of: tab) else {
            previousSelectedViewController = tabBarController.selectedViewController
            previousSelectedIndex = tabBarController.tabs.firstIndex(of: tab) ?? tabBarController.selectedIndex
            return true
        }
        return interceptPhotoTab(in: tabBarController, photoIndex: photoIndex)
    }

    private func rememberSelection(in tabBarController: UITabBarController, viewController: UIViewController) {
        previousSelectedViewController = viewController
        previousSelectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController)
    }

    private func interceptPhotoTab(in tabBarController: UITabBarController, photoIndex: Int) -> Bool {
        let currentIndex = tabBarController.selectedIndex
        guard currentIndex != photoIndex else { return false }

        previousSelectedViewController = tabBarController.selectedViewController
        previousSelectedIndex = currentIndex
        applyPhotoTabSwap(in: tabBarController, currentIndex: currentIndex, photoIndex: photoIndex)
        showCustomMoreDialog(from: tabBarController) { [weak self, weak tabBarController] in
            guard let self, let tabBarController else { return }
            self.restorePhotoTabSwap(in: tabBarController)
        }
        return false
    }

    private func isPhotoViewController(_ viewController: UIViewController) -> Bool {
        if let item = viewController.tabBarItem as? ESTabBarItem, item.contentView.title == "Photo" { return true }
        return viewController.tabBarItem?.title == "Photo"
    }

    private func usesTabsAPI(_ tabBarController: UITabBarController) -> Bool {
        if #available(iOS 18.0, *) { return !tabBarController.tabs.isEmpty }
        return false
    }

    private func swapTabEntryPair(in tabBarController: UITabBarController, at firstIndex: Int, with secondIndex: Int) {
        if usesTabsAPI(tabBarController), #available(iOS 18.0, *) {
            var tabs = tabBarController.tabs
            guard tabs.indices.contains(firstIndex), tabs.indices.contains(secondIndex) else { return }
            tabs.swapAt(firstIndex, secondIndex)
            tabBarController.tabs = tabs
            let a = tabBarController.tabs[firstIndex]
            let b = tabBarController.tabs[secondIndex]
            (a.title, b.title) = (b.title, a.title)
            (a.subtitle, b.subtitle) = (b.subtitle, a.subtitle)
            (a.image, b.image) = (b.image, a.image)
            (a.badgeValue, b.badgeValue) = (b.badgeValue, a.badgeValue)
            return
        }

        guard var viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(firstIndex),
              viewControllers.indices.contains(secondIndex) else { return }
        viewControllers.swapAt(firstIndex, secondIndex)
        tabBarController.setViewControllers(viewControllers, animated: false)
        let first = tabBarController.viewControllers![firstIndex]
        let second = tabBarController.viewControllers![secondIndex]
        (first.tabBarItem, second.tabBarItem) = (second.tabBarItem, first.tabBarItem)
    }
    

    private func performPhotoTabSwap(in tabBarController: UITabBarController, selectedIndex: Int) {
        guard let swap = pendingViewControllerSwap else { return }
        swapTabEntryPair(in: tabBarController, at: swap.currentIndex, with: swap.photoIndex)
        tabBarController.selectedIndex = selectedIndex
        (tabBarController.tabBar as? ESTabBar)?.syncSelectionState(selectedIndex: selectedIndex)
    }

    private func applyPhotoTabSwap(in tabBarController: UITabBarController, currentIndex: Int, photoIndex: Int) {
        pendingViewControllerSwap = (currentIndex, photoIndex)
        performPhotoTabSwap(in: tabBarController, selectedIndex: photoIndex)
    }

    private func restorePhotoTabSwap(in tabBarController: UITabBarController) {
        guard let swap = pendingViewControllerSwap else { return }
        performPhotoTabSwap(in: tabBarController, selectedIndex: swap.currentIndex)
        pendingViewControllerSwap = nil
        previousSelectedIndex = swap.currentIndex
        previousSelectedViewController = tabBarController.selectedViewController
    }

    private func performPendingDialogRestoreSelection() {
        let restoreSelection = pendingDialogRestoreSelection
        pendingDialogRestoreSelection = nil
        restoreSelection?()
    }

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        performPendingDialogRestoreSelection()
    }

    func showCustomMoreDialog(from tabBarController: UITabBarController, restoreSelection: @escaping () -> Void) {
        guard tabBarController.presentedViewController == nil else {
            restoreSelection()
            return
        }

        pendingDialogRestoreSelection = restoreSelection
        let alert = UIAlertController(title: "更多功能", message: nil, preferredStyle: .alert)
        let dismiss = { [weak self] in self?.performPendingDialogRestoreSelection() }

        alert.addAction(UIAlertAction(title: "设置", style: .default) { _ in dismiss() })
        alert.addAction(UIAlertAction(title: "关于我们", style: .default) { _ in dismiss() })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in dismiss() })

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tabBarController.tabBar
            popover.sourceRect = tabBarController.tabBar.bounds
        }

        tabBarController.present(alert, animated: true)
    }
}


