//
//  ExampleViewController.swift
//  ESTabBarControllerExample
//
//  Created by lihao on 16/5/16.
//  Copyright © 2018年 Egg Swift. All rights reserved.
//

import Foundation
import UIKit

public class ExampleViewController: UIViewController {
    
    static let textArray = [
        "Genius only means hard-working all one's life.",
        "The man who has made up his mind to win will never say \"impossible \".",
        "There is no such thing as a great talent without great will - power.",
        "Cease to struggle and you cease to live.",
        "A strong man will struggle with the storms of fate.",
        "Living without an aim is like sailing without a compass.",
        "Live a noble and honest life. Reviving past times in your old age will help you to enjoy your life again.",
        "Accept what was and what is, and you’ll have more positive energy to pursue what will be.",
        "Behind every successful man there's a lot u unsuccessful years.",
        "Enrich your life today, yesterday is history, tomorrow is mystery.",
        "The secret of success is constancy to purpose.",
        "Between two stools one falls to the ground.",
        "You have to believe in yourself. That's the secret of success.",
        "Success grows out of struggles to overcome difficulties.",
        "The dictionary is the only place where success comes before work.",
        "There are no shortcuts to any place worth going.",
        "You're unique, nothing can replace you.",
        "Great works are performed not by strengh, but by perseverance.",
        "Until you make peace with who you are, you’ll never be content with what you have.",
        "Keep trying no matter how hard it seems. it will get easier."
    ]
    
    let tip: UILabel = UILabel()
    let icon: UIButton = UIButton()
    let button: UIButton = UIButton()
    private var textTimer: Timer?

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.init(red: 244.0 / 255.0, green: 245.0 / 255.0, blue: 245.0 / 255.0, alpha: 1.0)

        tip.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        tip.textColor = UIColor.darkGray
        tip.text = randomTipText(excluding: nil)
        tip.numberOfLines = 0
        tip.textAlignment = .center

        icon.addTarget(self, action: #selector(ExampleViewController.homePageAction), for: .touchUpInside)

        button.setTitle("  Click to pop or dismiss  ", for: .normal)
        button.backgroundColor = self.view.backgroundColor
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(white: 100.0 / 255.0, alpha: 1.0).cgColor
        button.layer.cornerRadius = 16.0
        button.setTitleColor(UIColor(white: 100.0 / 255.0, alpha: 1.0), for: .normal)
        button.addTarget(self, action: #selector(ExampleViewController.backAction), for: .touchUpInside)

        view.addSubview(icon)
        view.addSubview(tip)
        view.addSubview(button)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTextTimer()
    }

    deinit {
        stopTextTimer()
    }

    private func startTextTimer() {
        stopTextTimer()
        textTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.advanceTipText()
        }
    }

    private func stopTextTimer() {
        textTimer?.invalidate()
        textTimer = nil
    }

    private func advanceTipText() {
        tip.text = randomTipText(excluding: tip.text)
        view.setNeedsLayout()
    }

    private func randomTipText(excluding current: String?) -> String {
        guard ExampleViewController.textArray.count > 1 else {
            return ExampleViewController.textArray.first ?? ""
        }
        var next = ExampleViewController.textArray.randomElement() ?? ""
        while next == current {
            next = ExampleViewController.textArray.randomElement() ?? next
        }
        return next
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        icon.frame = self.view.bounds

        let horizontalPadding: CGFloat = 24
        let labelWidth = view.bounds.width - horizontalPadding * 2
        let labelSize = tip.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        tip.frame = CGRect(
            x: horizontalPadding,
            y: (view.bounds.height - labelSize.height) / 2 - 24,
            width: labelWidth,
            height: labelSize.height
        )

        let size = button.sizeThatFits(self.view.bounds.size)
        button.frame = CGRect.init(x: (self.view.bounds.size.width - size.width) / 2.0, y: self.view.bounds.size.height - 120, width: size.width, height: 42.0)
    }
    
    @objc public func homePageAction() {
        let vc = WebViewController.instanceFromStoryBoard()
        vc.hidesBottomBarWhenPushed = true
        if let navigationController = navigationController {
            navigationController.pushViewController(vc, animated: true)
            return
        }
        present(vc, animated: true, completion: nil)
    }
    
    @objc public func backAction() {
        if let navigationController = navigationController {
            if navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
                return
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
}
