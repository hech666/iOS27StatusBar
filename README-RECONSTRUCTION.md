# iOS27StatusBar 1.4.0~ios16native2 — 语义重构源码

> 本目录是基于用户提供的 deb 与其中的 Mach-O 做静态分析后编写的可读语义重构，不是作者原始源码，不保证逐指令等价。二进制已剥除本地符号，动态依赖的 iOS 私有类/ivar/API 未随包提供。请以 `evidence/RECONSTRUCTION-REPORT.md` 的逐项边界为准。

## 原始输入与完整性

- 包：`com.local.ios27statusbar_1.4.0~ios16native2_iphoneos-arm64e.deb`
- SHA-256：`c4941a3a6c34854420fa7c7bebcdad2768ede4c7392a052ca15bb5618fedddb7`
- dylib：SHA-256 `ed5fec8eb1decee02551a22278fefef6b3e105734b21975f21426e9a84cb6f94`
- 载荷：`iOS27StatusBar.dylib`、`iOS27StatusBar.plist`
- 包控制信息列出的作者：半生年华、yaowell、Benja Guo；描述中注明信号/Wi-Fi 素材来源 Benja Guo、电池源码感谢 yaowell。这里仅按原包元数据记录，不据此推断本重构与原作者有关系。

## 目前确认的目标与范围

- 过滤目标：`com.apple.springboard`、`com.apple.UIKit`。
- 二进制是 universal Mach-O：arm64 + arm64e（PAC00）；两片均声明 iOS 最低版本 16.0、SDK 16.5。
- 插件基于 `MSHookMessageEx`，使用 UIKit 的状态栏/电池视图私有类名及 Objective-C runtime 动态检查；没有面板、偏好项或随包图片资源。
- 主要行为：尝试用自绘图形覆盖/重绘系统蜂窝与 Wi-Fi 状态栏指示；兼容 UIKit 16 与 `STUIStatusBar*` 类路径；另调整电池百分比文字/充电闪电显示。

## 源码组成

- `Sources/I27REHooks.mm`：constructor、Substrate 注册、动态签名检查与参数透传。
- `Sources/I27RERuntime.mm`：状态栏分类/着色、原生图层抑制、overlay 与 Wi‑Fi item 更新。
- `Sources/I27REDrawing.mm`：Wi‑Fi/蜂窝模板图形及几何/缓存。
- `Sources/I27REBattery.mm`：百分比请求记忆、文字色、充电图层/标签行为。
- `Headers/`：上述模块的 I27RE 前缀接口。
- `../evidence/`：Hook/方法偏移映射、各模块证据/边界报告与纯静态校验脚本。

## 构建与验证状态

原始 Mach-O 从未运行、安装、链接或在设备验证。对四个 `.mm` 文件分别使用 iPhoneOS16.5.sdk 目录做 `-fsyntax-only -Werror -Wall -Wextra` 与 `-O2 -c -o /dev/null`，arm64 与 arm64e 均通过；绘图字面常量脚本另外逐位比较了两个 Mach-O 架构，共92个几何 double 和19组格数状态均通过。

注意：该 SDK 目录的 `SDKSettings.plist` 实际报告 iOS 16.4，而样本 Mach-O 的 LC_BUILD_VERSION 报告 SDK 16.5。Theos 环境变量未设置；没有执行完整 Theos build、链接、打包或 deb 对照。上述仅是语法/对象代码生成验证，不代表可直接安装、等价重建或兼容所有 iOS 版本。
