# 最终静态验证记录

## 输入完整性

- 用户上传 deb SHA-256：`c4941a3a6c34854420fa7c7bebcdad2768ede4c7392a052ca15bb5618fedddb7`
- 原包中 universal dylib SHA-256：`ed5fec8eb1decee02551a22278fefef6b3e105734b21975f21426e9a84cb6f94`
- thin arm64 SHA-256：`3fc3453c324cfb230107455b98de6738357c43602e66a8f8684376f91f1b49a3`
- thin arm64e SHA-256：`e55b762347ac25413100c572d522cf3e79df69db6e1091c80a7fc97a904538c6`
- 最终复核时原始 deb、原始 universal dylib 哈希仍与初始值一致；仅解包读取，未运行或安装。

## 源码验证

对 `source/Sources/I27REBattery.mm`、`I27REDrawing.mm`、`I27RERuntime.mm`、`I27REHooks.mm` 逐文件执行：

- Objective-C++17，ARC/blocks/exceptions，`-Wall -Wextra -Werror` 的 `-fsyntax-only`。
- `-O2 -c -o /dev/null` 对象代码生成，输出丢弃。
- arm64：Alpine `/usr/bin/clang++` 19.1.4。
- arm64e：`/var/minis/shared/toolchains/arm64e-modern/clang++`，其包装器调用 Clang 21.1.2 并开启指针认证编译参数。
- 两架构均退出 0，无诊断；未链接 dylib、未签名、未生成 deb。

图形数据复核：`python3 evidence/extract-drawing.py --check-source` 实际输出 `PASS: both architectures, 92 source geometry doubles, all 19 bar states.` 该检查解析 Mach-O 和静态指令常量，不执行二进制。

## SDK/工具链限定

命令使用目录 `/var/minis/shared/toolchains/sdks/iPhoneOS16.5.sdk`；但该目录的 `SDKSettings.plist` 实际标记 `Version=16.4`、`CanonicalName=iphoneos16.4`、deployment target 16.4。样本 Mach-O 自身 LC_BUILD_VERSION 为 SDK 16.5、minimum OS 16.0。报告中保留这一区别，不把目录名当作真实 SDK 元数据。

`THEOS` 环境变量未设置。本任务没有运行 Theos make、最终链接/签名/打包，也未在 iOS 设备测试。静态源编译通过不等于可直接安装或和原二进制完全等价。

## 交付范围

源码归档只含重构源码、公开接口、注入 plist/control 参考文本及模块证据报告；不含用户原始 deb、dylib、设备文件或凭据。源码是 stripped Mach-O 的独立语义重构，不是作者原文件。
