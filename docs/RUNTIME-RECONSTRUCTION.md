# Runtime 语义重构与证据边界

本模块是对给定已剥符号 Mach-O 的独立、可编译语义重构，不是原作者源码，也不是逐指令等价声明。仅新建／修改 `source/Headers/I27RERuntime.h`、`source/Sources/I27RERuntime.mm` 和本文件；不负责 hook 安装、constructor、电池、绘图。原 dylib 未运行、未安装、未修改。

输入 SHA-256：`ed5fec8eb1decee02551a22278fefef6b3e105734b21975f21426e9a84cb6f94`，实现完成后复核不变。

以下地址均为切片未 slide 的 VA，不是 fat 文件偏移。arm64 切片起点 `0x4000`，arm64e 起点 `0x20000`。关联键在本重构中使用独立静态 char 身份地址替代；不会拿原 VA 当对象 ivar 偏移。

## 1. 接口与父级 hook 集成

头文件已包含父级要求的全部接口：

- `I27RERenderView(UIView *)`
- `I27RECaptureSTUICellularColor(UIView *, UIColor *)`
- `I27RECaptureUIKitCellularColor(UIView *, UIColor *)`
- `I27RERefreshWifiTint(UIView *)`
- `I27REUpdateWifiItem(id item, id update)`，**两个参数**
- `I27REIsManagedWifiImage(UIView *)`
- `I27REIsUpdatingNetworkImage(UIView *)`
- `I27RERenderNetworkImage(UIImageView *)`
- `I27RENetworkReplacementImage(UIImageView *)`
- `I27REShouldHideNetworkImage(UIView *)`
- `I27RESuppressNativeNetworkImage(UIView *)`
- `I27REInitialRefresh(void)`

另保留早期接口 `I27RECaptureCellularColor`（0xd2d0 的纯缓存）与 `I27RECaptureWifiColor`（忽略传入颜色、只更新既有 Wi-Fi 覆盖图 tint），后者由 `RefreshWifiTint` 调用；均不安装任何 hook。

### 不能改变的 hook 顺序

1. STUI Signal `setActiveColor:`（0x8c4c）：先调用 STUI 捕获 helper，再 orig；无 post-render。该 helper 先直接向非 nil 传入颜色取 CGColor／alpha，不提前做 UIColor 类型判断，然后进入 0xd2d0 的带类型检查缓存。透明／nil 输入不清除旧缓存。
2. UIKit Signal `setActiveColor:`（0x960c）：orig 后调用 UIKit 捕获 helper。它先取 bb80(`activeColor`) 结果，否则用传入颜色，再验证／缓存；helper 不 render，父 hook 随后调用 RenderView。
3. STUI Wi-Fi `setActiveColor:`（0x8dcc）：orig 后只 RefreshWifiTint；不创建图、不缓存参数、不 RenderView。**0x8df0 的 LDR 字面地址为 0x8df0+0xb778=0x14568；Wi-Fi overlay 键是 0x14568，不是 0x14570。** 0x14570 是双卡上排键。
4. `_UIStatusBarImageView setImage:`（0x99ac）：managed（关联等级对象非 nil，@0 也算）且 !updating 时先求 replacement，orig(replacement ?: input)；否则若 ShouldHide，orig(nil) 后 SuppressNativeNetworkImage；其他 orig(input)。helper 不自行调用 orig。
5. `layoutSubviews`（0x9924）必须为 orig 后 managed ? RenderNetworkImage : SuppressNativeNetworkImage。父级 `I27REHooks.mm` 已按此条件补齐 else 分支；整套重构源码后来分别在 arm64 与 arm64e 做了严格语法和 `-O2` 对象代码生成检查，但未链接或运行。
6. Wi-Fi item `applyUpdate:toDisplayItem:`（0x915c）必须保留／返回 orig 的对象返回值，再把 self 和第一个显式实参 update 交给 UpdateWifiItem；不能用 displayItem 替代 update，也不能省略第二参数。
7. constructor 自行 dispatch_async(main, InitialRefresh)。本模块 InitialRefresh 是 block body，不会再异步调度或安装 hooks。

## 2. 函数映射

| arm64 | arm64e | 已实现语义 |
|---|---|---|
| 0x755c | 0x5e50 | UIApplication → connectedScenes → UIWindowScene → windows 初次扫描 |
| 0x9dc0 | 0x8b14 | 主线程门槛、双卡提升、日志、guard、分发、特定异常捕获、finally |
| 0xa144 | 0x8eac | 类名包含 StatusBar+Signal 后识别 Wi-Fi／蜂窝／双卡 |
| 0xa224 | 0x8f90 | 从自身开始沿 superview 找双卡容器 |
| 0xa2b8 | 0x9038 | Wi-Fi 生成／着色／原生遮盖／覆盖层布局 |
| 0xa558 | 0x92ec | 双卡两模板、两路等级、子视图回退搜索、完整尺寸居中 |
| 0xa9bc | 0x9764 | 单卡；必要时转双卡；SingleSIM 失败回退 Cellular |
| 0xac84 | 0x9a40 | 同时响应 top/bottom accessor，或类名 DualCellularSignal |
| 0xad5c | 0x9b1c | getter／五个 ivar 名／类型解码／合理范围与裁切 |
| 0xb570 | 0xa348 | Wi-Fi 前景色优先级 |
| 0xb708 | 0xa4f4 | overlay 缓存／重挂载／属性初始化 |
| 0xbb80 | 0xa998 | selector 颜色 getter、UIColor 验证、alpha>0.01 |
| 0xbce4 | 0xab10 | 最多 40 个节点，首个真实状态栏祖先上的样式色 |
| 0xbee8 | 0xad28 | 递归 sublayers、delegate 和 overlay tag 豁免 |
| 0xc170 | 0xafb4 | 递归 subviews、UIImageView 遮盖、overlay 可见性恢复 |
| 0xc960 | 0xb7bc | 蜂窝前景色与有效色缓存 |
| 0xcc34 | 0xbaa4 | >=17 清原生 active/inactive color；全部版本清原生图层 |
| 0xce38 | 0xbcac | UIView getter／object ivar fallback |
| 0xcfa0 | 0xbe28 | 子树中按 centerY 选最小两个候选 |
| 0xd2d0 | 0xc170 | 非透明 UIColor 关联缓存 |
| 0xd3f8 | 0xc2ac | managed network image 更新、guard、日志、finally |
| 0xd664 | 0xc52c | 原图尺寸／bounds → drawing size → Wi-Fi replacement |
| 0xd7f0 | 0xc6cc | 原生 image layer contents=nil、hidden=YES、opacity=0 |
| 0xd928 | 0xc818 | 排除 managed Wi-Fi，按信号祖先 overlay 存在判定隐藏 |
| 0xdb90 | 0xca98 | 递归视图树扫描 |

## 3. 关键语义（非经验性修补）

### 分类与数值

- 分类只处理真实类名含 `StatusBar` 和 `Signal` 的对象，先判断双卡，再 Wifi/WiFi，再 Cellular，其他不处理。不把普通 UIImageView 当信号视图。
- 双卡 ancestor 搜索包含起点，不人为加深度上限。
- numberOfActiveBars getter 只有 `0 <= n <= maximum+2` 时直接采用并 min(maximum,n)，否则回退 `_numberOfActiveBars`、`numberOfActiveBars`、`_activeBars`、`activeBars`、`_displayValue`，沿继承链找 ivar；支持第一个类型字符 B/C/c/s/S/i/I/l/L/q/Q。无可用值返回 0。unsupported 类型继续下个名字；没有 KVC 或新增异常吞噬。
- 64 位 Q/L 也按原 LDR 后的有符号比较裁切；不擅自当成无符号最大值满格。
- 双卡 child getter 返回值必须是 UIView，否则查 `_topSignalView`／`_bottomSignalView`。原 object_getIvar 路径没有额外类型编码验证，本实现没有凭经验增加它。
- 回退子树搜索只要求响应 numberOfActiveBars，初始递归预算 4；预算 0 仍检查直接子项。选最小两个 centerY，不是最上／最下；不新增去重或 !=host 条件。

### 颜色

- 有效颜色定义为 UIColor 且 CGColor alpha > 精确二进制常量 0.01。
- Wi-Fi：有效 activeColor → 状态栏样式 → trait。
- 蜂窝：状态栏样式 → 关联有效色 → 有效 activeColor（并缓存）→ trait。
- 样式查找从自身开始最多 40 个节点，找到第一个 STUIStatusBar／_UIStatusBar 实例就停止；依次取 attrs.imageTintColor、attrs.textColor、**状态栏 view.foregroundColor**。不是 attrs.foregroundColor，也不因这一层没有颜色而继续更高祖先。
- trait 为 Light 返回黑；其余返回白。非 Light 分支再次读取 traitCollection.userInterfaceStyle，保留原可观察的第二次 accessor 调用。
- 不把色缓存清成 clearColor，也不从 tintColor／labelColor 发明信号色回退。

### 原生遮盖与 overlay

- overlay tag：Wi-Fi 83369，单卡 110234，双卡上排 110235、下排 110236。初建 frame=host.bounds，先 contentMode=2，再由渲染调用者设为 4；禁用交互、clipsToBounds=NO、非 accessibility element。复用时必要则 remove／add，随后 bringToFront。
- `bee8` 只直接隐藏 **delegate 为 nil** 的 CALayer（removeAllAnimations、opacity=0、hidden=YES）；有非 nil 非 UIView delegate 的 layer 也不会直接被隐藏，而是递归。UIView delegate 若是受保护 overlay tag，连其子层都跳过；其他 UIView delegate 继续递归。
- `c170` 遇受保护 tag 仅恢复 view.hidden=NO、alpha=1，并跳过递归；其他 UIImageView 隐藏 view、alpha=0、隐藏其 layer、opacity=0、contents=nil，再递归。未增添 removeFromSuperview 或清 view.image。
- Wi-Fi 根视图清 layer.contents、递归遮盖；蜂窝另外仅在 OS major>=17 时发 setActiveColor:clear 和 setInactiveColor:clear。没有改成所有版本透明原色。
- 两张双卡图都用 host 全尺寸设计空间各自居中；upper/lower 模板本身带上下行坐标，不能改成两个半高 frame。
- `I27RECenterGlyphView` 完整委托 drawing 模块的 b8cc 重构，传入 **带像素舍入 padding 的 UIImage.size**；仅相应图像 nil 时双卡用未 padding drawing size。没有另加偏移、缩放 transform 或 aspect-fit。
- 保留原 CATransaction begin/setDisableActions/commit 次序；未为这些绘制遮盖 transaction 添加原本不存在的 finally commit。异常中断时可能留下未 commit transaction，这不是已证明应修复的行为。

### 网络图像状态

- 0x14590 记录首次受管前的原图 size；0x14598 的 NSNumber 等级非 nil 即 managed，@0 也是 managed；0x145a0 为 boolValue 更新 guard。
- UpdateWifiItem 从 **update.data.wifiEntry.displayValue** 取 unsigned 范围 0..3 值，不合范围则从 item.signalView 的通用等级读取回退。没有有效来源时不清先前状态。
- 没有旧图则不写原尺寸，replacement 用 imageView.bounds.size；有原尺寸但无效时返回 nil，不擅自再回退 bounds，也不直接用当前 replacement image 的尺寸反馈扩大。
- RenderNetworkImage 只在主线程执行；NetworkReplacementImage 本身没有主线程门槛，因为 99ac 直接调用工厂的原分支也没有该门槛。没有擅自 dispatch_async 修正它。
- ShouldHide 先排除 managed Wi-Fi，再从 **superview**（不是自身）向上找类名含 StatusBar+Signal 且有任一覆盖图关联对象的祖先；只看存在，不读 boolValue，不查询 tag 替代身份键。
- SuppressNativeNetworkImage 重查 ShouldHide，只清／隐藏原 layer，不自行发 view.setImage/setHidden/setAlpha。

### 异常处理边界

没有把所有私有 API 都包进 @catch(id)：颜色 getter、getter/ivar、单／双卡绘制、网络 replacement、Wi-Fi item 更新等不新增本地 catch。

- 主渲染 9dc0 的设置 guard 后分发区域：特定 `@catch(NSException *)` 吞掉 NSException，finally 无条件删除 guard；其他异常清 guard 后继续传播。
- network d3f8：只有 finally 删除 guard，不吞异常。
- 初次扫描 755c：整个 block body 捕获 NSException；无新增异步调度。
- 分类、主日志、guard 检查及置位在主分发 try 外，保持原边界；不可通过扩大 try 把这些位置的异常也吞掉。

核验不仅依赖反汇编伪注释：`__unwind_info` 给出 755c/9dc0/d3f8 的 LSDA 分别为 e43c/e894/eea4。e43c 的类型 1、e894 的类型 2 指向 0x10018（绑定 `_OBJC_EHTYPE_$_NSException`）；eea4 的类型项为 0，且 d628→d58c 清理后 d5c8 重新抛出，故不是额外的 NSException 吞噬。

## 4. 关联键对照

| 原 arm64 地址 | 本实现身份键 |
|---|---|
| 0x14560 | I27RERenderingKey |
| 0x14568 | I27REWifiOverlayKey |
| 0x14570 | I27RETopOverlayKey |
| 0x14578 | I27REBottomOverlayKey |
| 0x14580 | I27RECellularColorKey |
| 0x14588 | I27RESingleOverlayKey |
| 0x14590 | I27RENetworkSizeKey |
| 0x14598 | I27RENetworkBarsKey |
| 0x145a0 | I27RENetworkUpdatingKey |

关联策略均为原值 1，即 RETAIN_NONATOMIC。日志文案保留二进制中的 native16 标识，但源码／API 命名为 I27RE。没有偏好设置、注册 API、延迟重试、额外日志或新增自定义 ObjC 类。

## 5. 验证状态与真实未证清单

完成以下静态验证，未加载任何目标二进制到 iOS 进程：

1. Alpine clang++ 19.1.4，使用名为 `iPhoneOS16.5.sdk` 的目录，分别 `-target arm64-apple-ios16.0` 和 `arm64e-apple-ios16.0`。父级最终核对该目录 `SDKSettings.plist` 实为 iOS 16.4；不能将目录名当成真实 SDK 版本。父级后来另以 Clang21 的现代 arm64e 包装器复验，见 `VALIDATION.md`。
2. `-fsyntax-only -fobjc-arc -fobjc-exceptions -fblocks -std=c++17 -Wall -Wextra -Werror -Wno-deprecated-declarations -Wno-ignored-attributes`：两架构通过，无诊断。
3. 同样参数加 `-O2 -c -o /dev/null`：两架构对象代码生成通过，输出丢弃，没有创建要分发的 dylib／安装包。
4. 原输入 SHA-256 复核不变。没有修改 drawing、battery、hooks、构建脚本或其他文件。

仍不能声称已验证：

- 没有运行时 UI、截图、hook 成功率、设备／iOS16 小版本／锁屏／横屏／双卡状态组合验证，也未做最终 dylib 链接。
- 私有方法真实签名、ivar 存在及布局来自运行系统，不随该包提供。typed objc_msgSend 保留二进制调用形状，但不会证明未来系统 ABI 稳定。
- 语义映射不是全 CFG 或逐指令形式化等价，ARC 的临时对象精确生存期、调用数及原内联优化不承诺逐条一致；未猜出原作者源文件／变量名。
- drawing 模块公开接口在病态 NaN／Infinity／像素计数溢出输入上有显式安全拒绝；本 runtime 委托该模块，不声称对这些非正常 UIKit 几何域与原 FCMP/FCVTAS 行为逐位等价。正常有限尺寸的 1.08、比例、padding 与 center 参数有指令证据。
- fallback 原始 getter／object_getIvar 故意未加未证类型、selector 签名或“更安全”的异常处理。这保留原语义，也保留原实现对私有对象正确性的假设，不能当安全审计通过声明。
- InitialRefresh 对视图树递归深度没有额外上限；状态栏样式祖先查找 40 节点、双卡候选搜索预算 4 来自二进制，不应用经验替换。
