//
//  ExampleViewController.swift
//  ESTabBarControllerExample
//
//  Created by lihao on 16/5/16.
//  Copyright © 2018年 Egg Swift. All rights reserved.
//

import Foundation
import UIKit

public class ExampleGlassTabbarController: ESTabBarController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if let tabbar = self.tabBar as? ESTabBar {
            tabbar.usesSystemGlassEffect = true
        }
    }
    
    
    
}
