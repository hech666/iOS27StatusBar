# Wi-Fi / 蜂窝图像与几何恢复

## 范围与结论

依据 `disasm-arm64.txt` 的真实指令、Mach-O 中的 binary64 常量和 arm64e 对照，恢复了独立 ARC/CoreGraphics/UIKit 源码：

- `source/Headers/I27REDrawing.h`
- `source/Sources/I27REDrawing.mm`
- 可复核的纯静态提取脚本 `evidence/extract-drawing.py`

未使用 `pseudocode-arm64.txt` 作推理依据；未注入、加载或执行原 dylib，未联网、安装、生成 Theos 工程或 deb，未修改 battery/hooks/runtime 文件。所有新增函数使用 `I27RE` 前缀。

**关键纠正：真正的 Wi-Fi 图像工厂是 arm64 `0xb110`，不是 `0xb8cc`。后者只负责现有 UIView 的 bounds/center 几何。** 多个指定地址实际上属于颜色探测、运行时视图定位或隐藏原生图层，不能混进绘图模块。

## 入口与调用图

以下均为对应 thin Mach-O 的虚拟地址，不是 fat 文件偏移；arm64e 的 PAC 指令使偏移差并不全局固定。

| arm64 | arm64e | 真实职责 | 本模块处理 |
|---|---|---|---|
| `0xb110` | `0x9ed4` | Wi-Fi 工厂：bars、width、height；位图、缓存、两弧一填充路径 | 已恢复 |
| `0xb8cc` | `0xa6cc` | host/overlay/CGSize：复位 transform、bounds、center、置前 | `I27RECenterGlyphView` |
| `0xba30` | `0xa834` | CGContext + 8 个坐标 double + 栈上传入线宽、alpha；左右双三次曲线描边 | `I27REStrokeWiFiArc` |
| `0xbb80` | `0xa998` | `(id, const char *)` getter 探测 UIColor；alpha > 0.01 才接受 | 不实现，交 runtime |
| `0xbce4` | `0xab10` | 最多向祖先走 40 层寻找 STUIStatusBar/_UIStatusBar，探测 styleAttributes/imageTintColor/textColor/foregroundColor | 不实现，交 runtime |
| `0xbee8` | `0xad28` | 递归 sublayers、跳过插件 overlay tag，removeAllAnimations、opacity=0、hidden=YES | 非绘图，不实现 |
| `0xc170` | `0xafb4` | 递归 subviews；插件 overlay 例外，隐藏原生 UIImageView 并清 contents | 非绘图，不实现 |
| `0xc474` | `0xb2bc` | `const char *family, NSInteger bars, CGFloat width, CGFloat height` 蜂窝工厂 | 已恢复 |
| `0xc960` | `0xb7bc` | 取样/缓存 tint；调用 0xbce4、0xbb80、0xd2d0，按 trait 回退黑白色 | 不实现，交 runtime |
| `0xcc34` | `0xbaa4` | iOS >=17 时清 active/inactiveColor；CATransaction 中清 contents 并调用两个隐藏 helper | 非绘图，不实现 |
| `0xce38` | `0xbcac` | `(id, getterName, ivarName)` 找 UIView：先 getter，后查类及父类 ivar | 不实现，交 runtime |
| `0xcfa0` | `0xbe28` | 深度受限遍历子视图，探测 numberOfActiveBars，convertRect 后按 midY 保存最上面两个候选 | 不实现，交 runtime |
| `0xd200` | `0xc08c` | `(CGContextRef, CGRect, CGFloat alpha)` 创建圆角路径并填白色 alpha | `I27REFillSignalRect` |

调用关系：

```text
0xa2b8 Wi-Fi 更新
  -> 0xad5c(view, 3) 读取/限幅 bars（运行时部分不在本模块）
  -> bounds * 1.08 + aspect-fit(1.34)
  -> 0xb110(bars, width, height)
       -> 0xba30 外弧
       -> 0xba30 内弧
       -> 四段 cubic 的闭合填充点
  -> image.size -> 0xb8cc(host, imageView, size)

0xa558 双卡更新
  -> 0xce38 top/bottomSignalView；不全时 0xcfa0(..., depth=4)
  -> 0xad5c(top,4), 0xad5c(bottom,4)
  -> bounds * 1.08 + aspect-fit(binary64 4/3)
  -> 0xc474("Cellular", topBars, width, height)
  -> 0xc474("Cellular2", bottomBars, width, height)
       -> 各自四次 0xd200
  -> 0xc960 tint, 0xcc34 hide-native（均外部）
  -> 两个 image.size 分别调用 0xb8cc

0xa9bc 单卡更新的独立路径
  -> 0xad5c(view,4) -> 相同蜂窝 aspect-fit
  -> 0xc474("SingleSIM", bars, width, height)
     失败才回退 "Cellular"
  -> 0xc960 / 0xcc34 / 0xb8cc
```

## 公开接口：尺寸参数不可省略

```objc
typedef NS_ENUM(NSInteger, I27REGlyphKind) {
    I27REGlyphKindWiFi = 0,
    I27REGlyphKindSingleSIM = 1,
    I27REGlyphKindCellular = 2,
    I27REGlyphKindCellular2 = 3
};
CGSize I27REGlyphSize(NSInteger kind, CGSize nativeBoundsSize);
UIImage * _Nullable I27REMakeGlyph(NSInteger kind, NSInteger bars, CGSize drawingSize);
NSInteger I27REClampBars(NSInteger kind, NSInteger bars);
void I27RECenterGlyphView(UIView *host, UIView * _Nullable glyphView, CGSize size);
```

原始两个工厂都接受动态 width/height，不存在证据支持的固定 point size，因此没有伪造两参数 MakeGlyph 或单参数 GlyphSize。这里 `I27REGlyphSize` 返回**未加边距的拟合绘图大小**，`I27REMakeGlyph` 接受这个大小，返回图像的 `.size` 才是带像素舍入边距的真实 point size。

这些 kind 是本模块自定义公共枚举。不要把 `0xa144` 的运行时类别值直接传入：原分类的 0=Wi-Fi、1=蜂窝、2=双卡容器、3=无关视图，并非本枚举。

使用方式（不安装 hook）：

```objc
CGSize size = I27REGlyphSize(I27REGlyphKindWiFi, nativeView.bounds.size);
NSInteger bars = I27REClampBars(I27REGlyphKindWiFi, rawBars);
UIImage *image = I27REMakeGlyph(I27REGlyphKindWiFi, bars, size);
imageView.image = image;
// tintColor 来自外部 runtime 的真实颜色探测；本模块不猜颜色。
if (image) I27RECenterGlyphView(nativeView, imageView, image.size);
```

UI 工厂、缓存及 UIView 几何按主线程使用，与原状态栏调用环境一致。纯数值限幅不访问原生 view/ivar，不替代 0xad5c 的读取优先级与异常 getter 回退。

## 格数、alpha 与缓存

- 原始 Wi-Fi 工厂 `0xb140...0xb164` 无符号检查 bars <=3，负数也拒绝；蜂窝 `0xc514...0xc538` 检查 0...4 与 family。**工厂越界返回 nil，不是自动夹到最大格数。** 源码保留该行为。
- `0xad5c` 是读取器：getter 值非负且 <= maximum+2 时取 min(maximum,value)，否则按多个整数 ivar 回退；尾部 `0xb0a0...0xb0a8` 为 max(0,min(maximum,ivarValue))。本模块仅暴露已读取数值的 clamp，运行时读取交由其他模块。
- Wi-Fi 外弧 alpha=1 iff bars=3；内弧 alpha=1 iff bars>=2；底部点 alpha=1 iff bars>=1。其他部分 alpha 精确为 0.4 (`0xf038`)。bars=0 仍画完整的 0.4 轮廓。
- 蜂窝从左至右四段，段 i 为 1 iff bars>i，否则 alpha=0.26 (`0xf0e0`)。bars=0 仍画四个暗格。
- 描边与圆角填充 helper 会把 alpha 夹到 [0,1]；颜色为 RGB=(1,1,1)。返回 `imageWithRenderingMode:2`，即 AlwaysTemplate，不把主题 tint 烘焙进像素。
- Wi-Fi 缓存 4 槽；蜂窝为三族各 5 槽。每槽只记上次图像的 physical width/height，匹配就复用；**不含 point size 或 scale 键**。源码保留这个可观察的原实现特性，未“修正”为新缓存策略。

## 尺寸、scale、CTM、几何

- 基本有效尺寸阈值：每边 > binary64 0.1 (`0xf020`)。
- 更新器把 native bounds 两边乘 binary64 1.08 (`0xf028`) 再 aspect-fit。Wi-Fi 比例用存储的 1.34 (`0xf030`)，蜂窝用立即数 `0x3ff5555555555555`，即 binary64 4/3。不是固定 point size。
- Wi-Fi 工厂 `0xb1a0...0xb230` / 蜂窝 `0xc574...0xc61c`：`s=UIScreen.mainScreen.scale`，仅 s<1 时换成 2；s=1 保留。像素数按 ARM64 FCVTAS（最近整数，中点远离零）舍入，再各夹到至少 1。

```text
Wi-Fi:  pixelW=max(1,roundAway((W+1.5)*s)), pixelH=max(1,roundAway((H+2)*s))
蜂窝:   pixelW=max(1,roundAway((W+2.5)*s)), pixelH=max(1,roundAway((H+2)*s))
image.size = (pixelW/s, pixelH/s)
UIGraphicsBeginImageContextWithOptions(image.size, NO, s)
Wi-Fi: Translate(0.75,1.0); Scale(W/67,H/50)
蜂窝:  Translate(1.25,1.0); Scale(W/72,H/54)
```

平移量是 point，不随后续 scale 一起预乘；不要反转这两个 CGContext 操作。图像透明，抗锯齿两开关都 YES，插值 quality=3（High）。未额外加 clipping 路径，负坐标/越设计宽度部分由位图边界自然裁剪。

`0xb8cc` 先取 host.bounds，再把 overlay.transform=identity；尺寸 min<=0.1 时采用 host.bounds.size；overlay.bounds=(CGPointZero,size)，center=(CGRectGetMidX(host.bounds),CGRectGetMidY(host.bounds))，最后 bringSubviewToFront。不是简单 frame=host.bounds，也不丢掉非零 bounds.origin 的居中语义。

## 精确几何与取值证据

源码全部静态坐标使用 IEEE-754 binary64 的十六进制浮点字面量。以下十进制仅便于阅读；应以源码字面量和提取脚本为精度权威。

### Wi-Fi

左半弧参数顺序为 start、control1、control2、end；每弧第二段按 `x'=(33.5-x)+33.5` 反射，交换控制点次序，最终结束于反射后的 start。

| 路径 | start | control1 | control2 | end | 线宽 |
|---|---|---|---|---|---|
| 外弧 | (5.4,15.9) | (12.7,8.9) | (22.9,5.35) | (33.5,5.35) | 9.3 |
| 内弧 | (16.73,27.85) | (21.3,24.8) | (26.6,22.4) | (33.5,22.4) | 9.0 |

- 外弧参数装载在 `0xb2bc...0xb31c`；内弧在 `0xb320...0xb36c`。
- `0xba70...0xbb5c` 保存状态、开抗锯齿、白色描边、round cap/join、绘制两 cubic 并恢复。`0xbb1c...0xbb50` 明确给出 33.5 镜像计算，不可替换为圆弧拟合。
- dot 的 MoveTo 是 (33.5,35.65)，随后四个 cubic：

```text
control1            control2            end
(28.53875,35.65)    (24.05,38.3575)      (24.05,41.35)
(24.05,42.4)        (29.41,49.15)        (33.5,49.65)
(37.59,49.15)       (42.95,42.4)         (42.95,41.35)
(42.95,38.3575)     (38.46125,35.65)     (33.5,35.65)
```

这些参数在 `0xb3bc...0xb498`，`0xb4a0` close、`0xb4a8` fill。它不是 ellipse，源码不调用 FillEllipse。

### 蜂窝

三个 family 都使用 x=(-2.95,18.75,40.45,62.15)、width=12.8；圆角横纵半径都精确 6.4（`0xd254` 从 `0xf138` 读取，`0xd270` 调用 CGPathCreateWithRoundedRect）。

| family | y[0..3] | height[0..3] |
|---|---|---|
| SingleSIM | 29,22,13,5 | 22,29,38,47 |
| Cellular | 16.3,11.7,5.9,0.7 | 17.3,21.9,27.7,32.9 |
| Cellular2 | 38.8,38.8,38.8,38.8 | 14.7,14.7,14.7,14.7 |

`0xc680...0xc7cc` 选择 SingleSIM/Cellular 参数，`0xc7d8...0xc890` 为 Cellular2。上卡四段顶边递升，下卡四个等高格；不能把 SingleSIM 高度简单除二代替。原双卡是两个同尺寸透明图像叠加，各自路径已带设计空间内的上/下位置，不需要额外猜 y 位移。

### 常量地址与脚本

- arm64 `__TEXT,__const` 位于 `0xf008`，arm64e 同段起于 `0xdcb8`，对应偏差为 `0x1350`。
- Wi-Fi literals: `0xf038...0xf0d8`；蜂窝 literals: `0xf0e0...0xf138`。并非所有值来自常量池：5.35、12.7、22.4、33.5、42.4、18.75、11.7、0.7、38.8、14.7 等由 MOV/MOVK + FMOV 拼装，脚本亦按位恢复，不靠十进制外观猜值。
- `0xf010/0xf018` 是夹在常量区域的其他数据，不因所在 section 名为 const 就当成 double；脚本跳过它们的浮点打印，但跨架构原始区域比较仍含这些字节。
- 脚本自己解析 LC_SEGMENT_64 的 VA→file offset，对每条解析到的反汇编指令先比较原文件 4 字节。随后仅对选定的常量构造片段静态求值 MOV/MOVK、FMOV、LDR、STR、CMP、FCSEL 和片段内 B；BL 只记录指定 CoreGraphics/几何 helper 参数，不执行调用或原机器码。遇到未知指令直接报错。
- 两个架构分别提取：4 种 Wi-Fi 格数状态和 3×5 种蜂窝状态；比较弧参数、dot 四段控制点、矩形、alpha 与相关原始常量区域，并逐位核对 `.mm` 的 92 个静态几何 double。

运行（无第三方 Python 包）：

```sh
cd /var/minis/workspace/ios27statusbar-reconstruction
python3 evidence/extract-drawing.py                 # 输出精确 C 数组
python3 evidence/extract-drawing.py --json          # 机器可读全部参数
python3 evidence/extract-drawing.py --check-source  # 对照实际恢复源码
```

实际结果：`PASS: both architectures, 92 source geometry doubles, all 19 bar states.` JSON 输出亦已用 json.load 验证。

## 编译验证与非等价边界

已使用现有本地 iPhoneOS16.5.sdk，分别以 `arm64-apple-ios13.0` 和 `arm64e-apple-ios13.0` 做 ARC Objective-C++17 语法检查，`-Werror -Wall -Wextra` 均成功，无需联网或安装工具：

```sh
clang++ -target arm64-apple-ios13.0 \
  -isysroot /var/minis/shared/toolchains/sdks/iPhoneOS16.5.sdk \
  -fobjc-arc -std=c++17 -fsyntax-only -Werror -Wall -Wextra \
  -Wno-deprecated-declarations source/Sources/I27REDrawing.mm
# arm64e 用 -target arm64e-apple-ios13.0，其余相同
```

- 这是语法/静态证据验证，**不是**设备截图对比、链接打包或运行原插件验证；没有声称逐像素设备比对已通过。
- 仅对病态输入加入明确安全收敛：NaN/Infinity 的尺寸或 scale 返回 nil/zero，超出 int64 像素舍入范围也返回 nil。原 ARM FCVTAS 的饱和/无效浮点边缘未硬复制到 UIKit，也不借此画占位图。正常有限状态栏输入的几何、格数规则、alpha、scale、padding、缓存和 template rendering 已依据证据恢复。
- `I27REGlyphSize` 是从更新器提取出的便利接口，不伪装为原二进制原名；原厂函数原名不可由 stripped 符号证明。没有猜测未证实的私有 selector 签名。
- 颜色解析、runtime 分类/取值、原生隐藏、overlay 创建/tag、hook 生命周期留给对应模块。没有图形恢复阻塞；按要求未运行原二进制，另未进行设备逐像素对比。
