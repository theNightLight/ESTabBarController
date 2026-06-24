# Changelog

本仓库为 [eggswift/ESTabBarController](https://github.com/eggswift/ESTabBarController) 的衍生维护分支，**不提供 CocoaPods / Swift Package Manager 发布**，请通过下载源码手动集成。

## [3.0.0] - 2026-06-23

### Added

- iOS 26 Liquid Glass 适配，支持三种布局策略：
  - `usesSystemGlassEffect = true`：系统玻璃双层嵌入（默认）
  - `usesSystemGlassEffect = false`：自定义容器全宽布局
  - `designType = .old`：强制旧版 TabBar 布局
- 新增 `ESTabBarDesignType`（`.automatic` / `.old`）
- 新增 `usesSystemGlassEffect` 属性
- Example：`mandatoryOldDesignStyle()` 强制旧版 UI 示例
- README 演示 GIF：`systemAndGlass`、`systemNoGlass`、`mandatoryOldDesign`

### Changed

- 重构精简 `ESTabBar.swift` 布局与玻璃模式逻辑
- 选中态 badge 仅在未选中层显示
- 自定义 item 在玻璃模式下与系统 tabButton 同级替换显示

### Docs

- 更新中英文 README，注明原作者与维护者
- 集成方式改为仅支持源码下载/manual 集成

## 上游版本

基于上游 ESTabBarController **2.9.0** 及后续本地改动。上游 CocoaPods / SPM 请继续使用 [eggswift/ESTabBarController](https://github.com/eggswift/ESTabBarController)。

[3.0.0]: https://github.com/theNightLight/ESTabBarController/releases/tag/v3.0.0
