![ESTabBarController](logo.png)

[![Swift v5](https://img.shields.io/badge/Swift-5-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![GitHub](https://img.shields.io/badge/GitHub-theNightLight-blue.svg?style=flat)](https://github.com/theNightLight)

### [中文介绍](README_CN.md)

> **Note:** This is a community fork of [eggswift/ESTabBarController](https://github.com/eggswift/ESTabBarController) with iOS 26 Liquid Glass support. **CocoaPods / Swift Package Manager are not provided** here to avoid conflicting with the upstream release. Please integrate by downloading the source code.

**ESTabBarController** is a highly customizable TabBarController component, which is inherited from UITabBarController.

This fork adds iOS 26 layout properties on `ESTabBar`. **Defaults work out of the box:**

- **`designType`** (default `.automatic`): `.automatic` adapts layout by OS version; `.old` always uses legacy TabBar layout (hides platter and distributes tabs evenly on iOS 26+)
- **`usesSystemGlassEffect`** (default `true`): effective only when `designType == .automatic` on iOS 26+; `true` enables system Liquid Glass dual-layer embedding, `false` hides system buttons and uses full-width `ESTabBarItemContainer` layout

**Default behavior:** with no configuration, iOS 26 shows the system glass TabBar; below iOS 26 matches upstream legacy layout.

### Why?

In real-world development, we may encounter the situation of customizing the UITabBar. For instance: change font style, add animation, and use bigger items. However it's hard to do with UITabBarItem.

**With ESTabBarController, You can easily achieve these！**

-| Feature |Description
-------------|-------------|-------------
1| Default style | You can get a system-like style by initializing the TabBar with ESTabBarController directly.  </p> UITabBarController style: </p> ![System native style](Resources/SystemStyle.png) </p> ESTabBarController default style: </p> ![ES system-like style](Resources/CustomStyle.png)
2| Default style with "More" item | If the items are more than the maximum number of displays, there will be a "More" item. </p> UITabBarController with "More": </p> ![enter image description here](Resources/SystemMoreStyle.png) </p> ESTabBarController with "More": </p> ![enter image description here](Resources/CustomMoreStyle.png)
3| Mix UITabBarItem and ESTabBarItem | You can set any item as you want, including UITabBarItem and ESTabBarItem. </p> ESTabBar and UITabBar mixed style: </p> ![enter image description here](Resources/MixtureStyle.png) </p> ESTabBar and UITabBar mixed style with "More": </p> ![enter image description here](Resources/MixtureMoreStyle.png)
4| UIKit attributes | ESTabBarController is compatible with UITabBarController, UITabBar and UITabBarItem's most API attributes. You can migrate to ESTabBarController without any modification of the origin code.  </p> Compatible with UITabBarController's `selectedIndex`: </p> ![enter image description here](Resources/SelectIndexCode.png)
5| Any nesting with UINavigationController | Developing with`UITabBarController`, there are two common ways to handle layers: </p> First : </p> ├── UITabBarController </p> └──── UINavigationController </p> └────── UIViewController </p> └──────── SubviewControllers </p> Second : </p> ├── UINavigationController </p> └──── UITabBarController </p> └────── UIViewController </p> └──────── SubviewControllers </p> In the first case, need to set `hidesBottomBarWhenPushed = true` when pushing subViews. The second is not. </p> In ESTabBarController, add Container views to UITabBar to be compatible with these two ways。
6| Customizable style | With ESTabBarController, you can：</p> 1. Customize selected item's color and style: </p> ![enter image description here](Resources/CustomSelectStyleGif.gif) </p> 2. Add selecting animation:  </p> ![enter image description here](Resources/CustomSelectAnimateGif.gif) </p> 3. Customize item's background color: </p> ![enter image description here](Resources/CustomBackgroundGif.gif) </p> 4. Add highlight animation: </p> ![enter image description here](Resources/CustomHighlightGif.gif) </p> 5. Add animation to prompt users: </p> ![enter image description here](Resources/CustomImpliesGif.gif) </p> 6. And much more ... </p>
7| Customizable item's size </p> Customizable click event | You can easily customize item's size using ESTabBarController. </p> **When the button's frame is larger than TabBar, HitTest makes the outer TabBar area click valid.** </p> In addition, ESTabBarController can customize click event, and through a block to callback super-layer to handle. </p> With big item in the middle of TabBar: </p> ![enter image description here](Resources/CustomStyle2.png) </p> With a special hint style: </p> ![enter image description here](Resources/CustomStyle3.png) </p> Customize click event: </p> ![enter image description here](Resources/CustomHitGif.gif)
8| Default notification style |  You can get a system-like notification style by initializing the TabBar with ESTabBarController directly. </p> UITabBarController notification style: </p> ![enter image description here](Resources/SystemNotificationStyle.png) </p> ESTabBarController system-like notification style: </p> ![enter image description here](Resources/CustomNotificationStyle.png)
9| Customizable notification style | With ESTabBarController, you can：</p> 1. Customize notification animation: </p> ![enter image description here](Resources/CustomNofticationGif.gif) </p> ![enter image description here](Resources/CustomNofticationGif2.gif) </p> 2. Customize prompt style: </p> ![enter image description here](Resources/CustomNofticationGif3.gif) </p> 3. And much more ... </p>
10| Lottie | Through customizing ContentView, you are able to add Lottie's LAAnimationView to Item(s) </p> ![enter image description here](Resources/LottieGif.gif)
11| iOS 26 Liquid Glass | iOS 26 introduces Liquid Glass on the system TabBar. ESTabBarController adapts via `designType` and `usesSystemGlassEffect` (iOS 26+):</p> 1. **System glass** (default): `designType = .automatic`, `usesSystemGlassEffect = true`. Custom items embed into the system `_UITabBarPlatterView` dual-layer structure, preserving system glass compositing and selection animation.</p> ![System glass mode](Resources/systemAndGlass.gif) </p> 2. **Custom container**: `designType = .automatic`, `usesSystemGlassEffect = false`. Hides system buttons and lays out `ESTabBarItemContainer` across the full width for fully custom appearance.</p> ![No system glass mode](Resources/systemNoGlass.gif) </p> 3. **Mandatory old design**: `designType = .old`. Always uses legacy layout; on iOS 26+ hides the platter and distributes tabs evenly, matching pre-iOS 26 behavior.</p> ![Mandatory old design](Resources/mandatoryOldDesign.gif) </p> 4. **System glass + Badge**: Badges show on unselected items in glass mode; the selected item hides its badge automatically.</p> ![System glass with badge](Resources/systemWithBadgeAndGlass.gif)

## Requirements

* Xcode 8 or later
* iOS 8.0 or later (Liquid Glass requires iOS 26.0+)
* ARC
* Swift 5 or later

## Demo

You can download and build ESTabBarControllerExample project, and you will find more examples to use ESTabBarController, and also more examples to customize UITabBar. The Basic section includes the iOS 26 layout modes above.

### iOS 26 Liquid Glass

```swift
let tabBarController = ESTabBarController()
if let tabBar = tabBarController.tabBar as? ESTabBar {
    // .automatic (default, adapts by OS) or .old (force legacy layout)
    tabBar.designType = .automatic

    // Only when designType == .automatic on iOS 26+
    // true: system glass dual-layer embed (default); false: custom container full-width layout
    tabBar.usesSystemGlassEffect = true
}
```

| Property | Default | Description |
|----------|---------|-------------|
| `designType` | `.automatic` | `.old` ignores `usesSystemGlassEffect` and always uses legacy layout |
| `usesSystemGlassEffect` | `true` | Effective only with `.automatic` on iOS 26+ |

## Usage

This fork supports **source download / manual integration only**. CocoaPods and Swift Package Manager are intentionally not published.

### Download

```bash
git clone https://github.com/theNightLight/ESTabBarController.git
cd ESTabBarController
open ESTabBarControllerExample/ESTabBarControllerExample.xcodeproj
```

### Integrate into your project

1. Drag all Swift files from `ESTabBarControllerExample/ESTabBarControllerExample/Sources/` into your Xcode target.
2. Use `ESTabBarController` as your root controller — see the Example project for reference.

> For official CocoaPods / SPM from upstream, use [eggswift/ESTabBarController](https://github.com/eggswift/ESTabBarController).

## TODO

1. The Containers' layout is purely based on code，using Autolayout will be better.
2. When there is "More," if edited, problems occur.
3. Partial UITabBarItem attributes are not bridge to ESTabBarItem.
4. ~~The picture of 'More' item in ESTabBarItemMoreContentView is not set into framework, plan to convert it to CGBitmap.~~


## Sponsor

If this project helps you, consider buying me a coffee:

| Alipay | WeChat |
|--------|--------|
| ![Alipay](Resources/sponsorship_ali.JPG) | ![WeChat](Resources/sponsorship_wx.JPG) |


## Acknowledgement

* [animated-tab-bar](https://github.com/Ramotion/animated-tab-bar) by <http://ramotion.com> 
* Partial pictures in Example are from <http://www.iconfont.cn>


## About

Maintained by [haochen](https://github.com/theNightLight). Questions and contributions welcome via [Issues](https://github.com/theNightLight/ESTabBarController/issues) and [Pull Requests](https://github.com/theNightLight/ESTabBarController/pulls).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

The MIT License (MIT)

Copyright (c) 2013-2016 eggswift  
Copyright (c) 2026 haochen

See [LICENSE](LICENSE) for the full text.

## Original Author

This project is modified based on [eggswift/ESTabBarController](https://github.com/eggswift/ESTabBarController). Original author: [eggswift](https://github.com/eggswift/ESTabBarController)

