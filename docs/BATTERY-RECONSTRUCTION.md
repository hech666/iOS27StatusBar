# 电池模块 ARC Objective-C 语义重构

## 范围与可信度

项目内本次仅新增 `source/Sources/I27REBattery.mm`、`source/Headers/I27REBattery.h` 与本报告；未修改 original、其他代理源码、配置、包内容或偏好面板。未运行、加载、安装原 Mach-O，未构建 deb。

恢复依据是 `evidence/arm64.dylib` 的真实 arm64 指令、`disasm-arm64.txt`、直接读取的选择子/常量/数据段及原始 unwind/LSDA。**没有使用 r2 pdc 伪代码作为语义依据。** 下文全部原地址为 arm64 slice 的未滑动虚拟地址，不是 arm64e 地址，也不是重编译源码的地址。

这是覆盖本 slice 电池钩子组及其全部可见本地帮助逻辑的可读语义重构，不是找回原作者文本、符号名或逐字节复制；无私有 UIKit 实现及真机测试，不能声称系统行为已经验证。arm64e 不作为独立等价性保证。

基准 SHA-256（静态读取）：

- `evidence/arm64.dylib`: `3fc3453c324cfb230107455b98de6738357c43602e66a8f8684376f91f1b49a3`
- `original/Library/MobileSubstrate/DynamicLibraries/iOS27StatusBar.dylib`: `ed5fec8eb1decee02551a22278fefef6b3e105734b21975f21426e9a84cb6f94`

## 原地址 → 新实现

| arm64 地址 | 可证身份 / 新实现 | 关键行为 |
|---|---|---|
| `0x6a58` 构造器中的 `0x6a80–0x6c4c` | `I27REInstallBatteryHooks` | UIApplication 门控，电池组最先安装；保留组内顺序、必需方法预检和两个可选 getter |
| `0x7818` | `I27REBatteryTextColor` / `_batteryTextColor` | 只在已知请求 OFF 时替代颜色；body、pin、resolved label 三层选择 |
| `0x7a20` | `I27REBatterySetShowsPercentage` / `setShowsPercentage:` | 记忆真实请求；ON/OFF 两支都调用原 setter(YES)，再分别显示/隐藏标签和刷新 |
| `0x7c30` | `I27REBatteryUpdateBolt` / `_updateBolt` | 已知 OFF 时进入临时 getter/raw-byte 覆盖，禁用隐式动画调用原实现 |
| `0x7e64` | `I27REBatteryUpdateLightningBoltAndPercentagePosition` | 与上一函数相同，仅 original IMP 不同；共享可读实现 `I27REBatteryUpdateWithPercentageOverride` |
| `0x8098` | `I27REBatteryLayoutSubviews` | 原布局先行；known+ON 显示；known+OFF 根据 raw 状态重新经过 setter hook 或隐藏后刷新 |
| `0x81e4` | `I27REBatteryTraitCollectionDidChange` | 原回调先行；仅 known+OFF 隐藏并刷新 |
| `0x82d4` | `I27REBatteryShowsPercentage` | depth≥1 且 known+OFF 时返回 NO，其余调用原 getter |
| `0x83d4` | `I27REBatteryCurrentlyShowsPercentage` | 同上一函数，调用它自己的原 getter |
| `0x84d4` | `I27REBatteryRequestedPercentage` | 返回请求值，同时写 known；首次可读 raw 值会记忆，未知与 OFF 严格区分 |
| `0x8640` | `I27REBatteryReadRawShowsPercentage` | 一次性解析 ivar，共享缓存；接受 B/c/C 编码，读取一个字节 |
| `0x8774` | `I27REBatteryWriteRawShowsPercentage` | 同一 ivar 缓存，B/c/C 时写一个字节，不调用 setter |
| `0x8884` | `I27REBatteryRefreshWithoutPercentage` | known+OFF 且未递归时更新闪电与位置、隐藏标签；清除 guard 并原样传播异常 |
| `0x8a98` | 编译器异常终止辅助 | `__cxa_begin_catch` / `std::terminate`，不是业务帮助函数；由 ObjC++ 编译器异常机制处理，不伪造 UIKit 方法 |
| `0x8aa8` | `I27REBatteryEndPercentageOverride` | depth>1 时减一，否则移除关联对象 |
| 上述函数中的内联片段 | `I27REBatteryOverrideDepth`、`I27REBatteryBeginPercentageOverride`、`I27REBatteryResolveShowsPercentageIvar` | 仅为源码可读性提取；没有宣称原二进制存在这些独立函数 |

`0x8bc8` 已是下一组信号视图 hook 起点，不纳入电池代码。`0x755c` 的窗口遍历异步 block 亦非本组电池业务实现。

## 安装行为

原构造器首先检查 `objc_getClass("UIApplication")`；随后电池已装标记 `0x14642` 为 0 才继续。`_UIBatteryView` 存在且以下四项 **全部存在** 才注册：

1. `setShowsPercentage:`
2. `_updateBolt`
3. `_updateLightningBoltAndPercentagePosition`
4. `_batteryTextColor`

`MSHookMessageEx` 的真实注册顺序及 original IMP 槽位为：

| 序号 | selector | replacement | original IMP 槽 |
|---|---|---|---|
| 1 | `_batteryTextColor` | `0x7818` | `0x14648` |
| 2 | `setShowsPercentage:` | `0x7a20` | `0x14650` |
| 3 | `_updateBolt` | `0x7c30` | `0x14658` |
| 4 | `_updateLightningBoltAndPercentagePosition` | `0x7e64` | `0x14660` |
| 5 | `layoutSubviews` | `0x8098` | `0x14668` |
| 6 | `traitCollectionDidChange:` | `0x81e4` | `0x14670` |
| 7 | `showsPercentage`（存在才装） | `0x82d4` | `0x14678` |
| 8 | `_currentlyShowsPercentage`（存在才装） | `0x83d4` | `0x14680` |

第 5/6 项原代码没有单独预检，重构亦不新增。末尾才置 installed=YES。缺类/缺四个必需方法不置标记，后续显式调用仍可重试；这与 ivar 查询失败的永不重试不同。原代码没有锁或 dispatch_once，未添加。

**电池组没有 OS major==16 条件。** `0x6c5c` 之后的系统版本判断属于后面的信号模块，不得移动到此组。

公开入口为 C linkage `BOOL I27REInstallBatteryHooks(void)`；`MSHookMessageEx` 以 `extern "C"` 手动声明。不依赖 substrate 头、Logos 或其他重构模块。YES 仅表示已注册/曾注册，不代表有返回值为空的底层 hook API 提供了额外成功证明。

没有新增自动 constructor：由总入口在其他 hook installer **之前**显式调用此函数，以还原 `0x6a58` 的跨组顺序。仅定义一个独立 constructor 无法保证其与其他文件的链接顺序，因此没有假装这种顺序已经集成。未修改其他代理的总入口。

## 三个关联对象与原始 ivar

`__DATA,__data` 中三处八字节静态键都是自指针，直接读值得到：

| 键槽与原始内容 | 重构键 | 值 |
|---|---|---|
| `0x14548 → 0x14548` | `I27REBatteryRequestedKey` | NSNumber(bool)，调用方真正请求的百分比状态 |
| `0x14550 → 0x14550` | `I27REBatteryRefreshGuardKey` | NSNumber(YES) / nil，刷新递归 guard |
| `0x14558 → 0x14558` | `I27REBatteryOverrideDepthKey` | NSNumber(NSInteger) / nil，临时 getter 覆盖深度 |

所有相关 `objc_setAssociatedObject` 的 policy 寄存器均为 1，即 `OBJC_ASSOCIATION_RETAIN_NONATOMIC`，包括移除（nil）时；没有改为 assign、copy、atomic 或全局对象缓存。重构生成新的私有键身份，并不与同时加载的原插件共享状态。

原始 ivar 查询共享 `0x14688`（attempted）和 `0x14690`（Ivar）。只在非 nil 对象上的首次查询中先标记 attempted，再查 `_UIBatteryView` 的 `_showsPercentage`，找不到才查 `showsPercentage`。查类或查 ivar 失败后永久保留失败结果，不重试。每次实际读/写仍调用 `ivar_getTypeEncoding` 和 `ivar_getOffset`；只检查类型编码首字符。

- 读：`B` 用原字节的低位 `raw & 1`；`c`/`C` 用整个字节是否非零。不能将三种类型统一为“非零”。
- 写：仅 `B`/`c`/`C`，直接写一字节 BOOL 参数，不走 getter/setter、KVC 或 object_getIvar。
- 读失败返回 NO，但不写出参。记忆帮助函数则无条件先把 known 置 NO。
- 缓存里存在 NSNumber(NO) 仍是 known=YES；没有缓存且无法读取 raw 才是未知。
- 临时覆盖从不覆盖 remembered 请求值；setter hook 的真实参数才更新该值。

## 关键分支：不以“修复”名义更改

### 颜色（0x7818）

仅 remembered=OFF 且 known 时进入替换路径，否则直接调用原 `_batteryTextColor`。

1. 取 `bodyColor`；如果 nil 或 `CGColorGetAlpha(CGColor) <= 0.01`，改取 `pinColor`。
2. 候选存在且其 alpha **严格大于** 0.01，返回同色的 alpha=1.0 版本。
3. 否则取 `UIColor.labelColor`，用当前 `traitCollection` 解析。
4. 上面所得结果若 nil，才回落到原 IMP；没有擅自添加 blackColor、tintColor 等补救路径。

阈值直接从 arm64 `__TEXT,__const` 地址 `0xf008` 读取为 IEEE-754 double `0.01`。两处候选 alpha 判断不可合并：`0x78a4 b.hi` 是第一处 `<=` 的逆跳转，`0x78f4 b.le` 是最终 `>` 的否定跳转。NaN 的边界也保留：body alpha=NaN 不转取 pin，但最终不被接受，进入 label 回退。边界 alpha=0.01 不被接受。

LLVM 注释会错误沿用上一条静态 selector，例如 `0x7894` 被标为 bodyColor、`0x78e4` 被标为 pinColor；真正加载的是 `0x142b0` 槽，其指针指向 `CGColor` 字符串。`0x8968` 注释显示 respondsToSelector，但运行寄存器 x1 为 `_updateBolt`；`0x8980` 则实际是 respondsToSelector:。本次按寄存器/selref 真实值判断，没有把这些注释误当调用事实。

### setter（0x7a20）

ON：保存 ON；raw 可读且真时先写 raw=NO；原 setter(YES)；调用两个更新 selector（不新增 respondsToSelector 检查）；label.hidden=NO、alpha=1；setNeedsLayout。

OFF：保存 OFF；**仍是原 setter(YES)**；label.hidden=YES、alpha=0；受 guard 约束地刷新。此分支不额外 setNeedsLayout。

因此不能把 OFF 分支“纠正”为原 setter(NO)，也不能把两个 getter 改成无条件返回 remembered 值。

### 两个更新 hook（0x7c30、0x7e64）

未知或请求 ON：只调用原 IMP，不接管事务，不处理 label。

已知 OFF，正常返回路径严格依次：

1. raw 保存变量先设 YES，再尝试读取 raw，单独保存读是否成功。
2. depth 加 1（arm64 ADD 位模式回绕；重构用无符号加法避免 C++ 有符号溢出 UB）。
3. 仅 raw 读取成功时写 raw=NO。
4. CATransaction.begin → setDisableActions:YES → 原 IMP → commit。
5. 仅先前读成功时恢复保存的 raw **布尔值**，不是恢复任意非规范原始字节。
6. depth 递减；旧 depth>1 才留 NSNumber(depth-1)，否则移除关联。
7. 隐藏百分比 label，alpha=0。

depth≥1 期间，两个可选 getter 在“已知请求 OFF”时才返回 NO；其余情况仍返回各自原 IMP 结果。这同时处理不支持原始 ivar 的系统。

**故意不为以上流程添加 @finally：** `0x7e20–0x7e60`、`0x8054–0x8094` 为 ARC 清理后 `__Unwind_Resume`，没有补 commit、恢复 raw 或调用 `0x8aa8`。如果事务/原 IMP/恢复动作抛异常，后续事务或覆盖深度可能留在原代码的中间状态，不能为了“安全”更改该语义。

### 刷新 guard 与异常（0x8884）

只有对象非 nil、已知请求 OFF 且 guard 不为真时执行。先关联 guard=YES；受保护体按需 respondsToSelector 后分别调用 `_updateBolt`、`_updateLightningBoltAndPercentagePosition`，再隐藏 label。正常结束与受保护体抛异常都移除 guard。

`__unwind_info` 将此函数关联至 LSDA `0xe648`；反汇编中 `0x8a74–0x8a80` 执行 objc_begin_catch 并跳回 `0x89e8` 的 guard 清除，随后到 `0x8a18 objc_exception_rethrow`。**这是 catch-all 清理并重新抛出，不是吞异常。** 源码以 `@try ... @finally` 表达同一行为，不添加日志或空 catch。设置 guard 本身在受保护体之外；如果 guard 设置抛异常，不执行后置清除，与原始结构一致。

### 布局与 trait

- layout 总是先调原方法；unknown 不再干预。
- known+ON 只确保 label 显示和 alpha=1。
- known+OFF：raw 可读且假时发送 `[battery setShowsPercentage:NO]`，经过 hook 后直接返回；否则先隐藏 label，再受 guard 约束刷新。
- trait 总是先调原回调；只有 known+OFF 隐藏并刷新。不新增色彩外观比较、动画或布局通知。

## 静态检查

用本机 Alpine clang 19.1.4、已有 `iPhoneOS16.5.sdk` 做以下两项，均退出 0，无诊断：

```sh
clang -target arm64-apple-ios15.0 \
  -isysroot /var/minis/shared/toolchains/sdks/iPhoneOS16.5.sdk \
  -fobjc-arc -fobjc-exceptions -fcxx-exceptions -fexceptions \
  -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
  source/Sources/I27REBattery.mm

clang -target arm64-apple-ios15.0 \
  -isysroot /var/minis/shared/toolchains/sdks/iPhoneOS16.5.sdk \
  -fobjc-arc -fobjc-exceptions -fcxx-exceptions -fexceptions \
  -std=c++17 -Wall -Wextra -Werror -O2 -c \
  source/Sources/I27REBattery.mm \
  -o /tmp/i27re-battery-check/I27REBattery.arm64.o
```

`llvm-nm` 确认公开符号为未进行 C++ 名字改编的 `_I27REInstallBatteryHooks`，外部引用为 `_MSHookMessageEx`，无 `_OBJC_CLASS_$_UIBatteryView` 静态链接依赖。生成对象只用于静态检查，未链接、加载或运行。仅声明实际出现的私有 selector 的 UIView category，不提供假 `_UIBatteryView` 实现。

## 未证边界与明确没有完成的事项

1. 无调试符号，原函数名、局部变量名、注释、原宏/Logos 写法不能恢复；新增 I27RE 名称及帮助函数提取是可读化选择。不是逐指令布局或 ARC retain/release 时点的二进制复刻。
2. 原私有 UIKit 方法体不在插件内：闪电层实际形状、布局坐标、百分比 label 具体类、绘图内部行为无法从本 slice 单独证明。仅通过原 IMP 和已证 selector 保留，不编造 bolt 子视图方法、frame 调整、充电状态或电池容量算法。
3. 未进行 arm64e 的逐指令/指针认证独立等价性审计，不能把 arm64 地址映射直接用于 arm64e。未做真机运行、系统兼容性、线程竞争、越狱注入或 Substrate 行为验证。
4. 接口由外部总构造器首先调用；本次刻意未越权修改其他代理正在编辑的入口文件。相对其他模块的实际注册顺序须在总入口集成时确认。
5. 复现了非线程安全 installed、ivar cache 与实例关联深度；未加锁、主线程转发、动态类重试、异常吞并、原 IMP 空指针防护等原文件没有的补救。
6. 保留一个字节 raw ivar 的约束；不声称适用于未来类型编码、位域、结构体或其他系统布局。缺少可读 raw 且无记忆请求时是 unknown，不强行当 OFF。
7. `MSHookMessageEx` 返回 void，无法凭本次静态检查证明底层 hook 在某设备成功。源码的 YES 是安装组状态，不是运行保证。
