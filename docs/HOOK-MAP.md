# Hook registry mapping

All addresses below are **arm64 slice virtual addresses**, not universal-file offsets. Evidence: constructor `0x6a58`, direct `MSHookMessageEx` call arguments in `disasm-arm64.txt`, saved IMP slots in `__DATA`. Function labels are descriptive reconstructor names only. The arm64e mapping is separately checked by the final report; do not reuse arm64 addresses on arm64e.

## `_UIBatteryView` (battery hook registry, registered first)

| Selector | Replacement | Original IMP slot | Registration condition |
|---|---:|---:|---|
| `_batteryTextColor` | `0x7818` | `0x14648` | Mandatory group |
| `setShowsPercentage:` | `0x7a20` | `0x14650` | Mandatory group |
| `_updateBolt` | `0x7c30` | `0x14658` | Mandatory group |
| `_updateLightningBoltAndPercentagePosition` | `0x7e64` | `0x14660` | Mandatory group |
| `layoutSubviews` | `0x8098` | `0x14668` | Same group, no standalone precheck |
| `traitCollectionDidChange:` | `0x81e4` | `0x14670` | Same group, no standalone precheck |
| `showsPercentage` | `0x82d4` | `0x14678` | Only if method exists |
| `_currentlyShowsPercentage` | `0x83d4` | `0x14680` | Only if method exists |

The first four are checked as a set before any battery hook is registered. The group is not gated by major OS==16. See `BATTERY-RECONSTRUCTION.md`.

## UIKit 16 native status-bar hooks

The direct group runs only when `NSProcessInfo.operatingSystemVersion.majorVersion == 16` and `_UIStatusBarSignalView` exists. Conditional presence checks are shown explicitly; many other calls are passed to Substrate without a separate method guard in the original.

| Class | Selector | Replacement | Original IMP slot | Method check in constructor |
|---|---|---:|---:|---|
| `_UIStatusBarSignalView` | `layoutSubviews` | `0x8fe8` | `0x14720` | no |
| `_UIStatusBarSignalView` | `didMoveToWindow` | `0x9014` | `0x14728` | no |
| `_UIStatusBarSignalView` | `traitCollectionDidChange:` | `0x9040` | `0x14730` | no |
| `_UIStatusBarWifiSignalView` | `layoutSubviews` | `0x90ac` | `0x14738` | class present |
| `_UIStatusBarWifiSignalView` | `didMoveToWindow` | `0x90d8` | `0x14740` | class present |
| `_UIStatusBarCellularSignalView` | `layoutSubviews` | `0x9104` | `0x14748` | class present |
| `_UIStatusBarCellularSignalView` | `didMoveToWindow` | `0x9130` | `0x14750` | class present |
| `_UIStatusBarWifiItem` | `applyUpdate:toDisplayItem:` | `0x915c` | `0x14758` | method present |
| `_UIStatusBarSignalView` | `setNumberOfActiveBars:` | `0x95e0` | `0x14760` | method present |
| `_UIStatusBarSignalView` | `setActiveColor:` | `0x960c` | `0x14768` | method present |
| `_UIStatusBarWifiSignalView` | `setActiveColor:` | `0x9788` | `0x14770` | method present |
| `_UIStatusBarWifiSignalView` | `applyStyleAttributes:` | `0x97f4` | `0x14778` | method present |
| `_UIStatusBarDualCellularSignalView` | `layoutSubviews` | `0x9860` | `0x14780` | class present |
| `_UIStatusBarDualCellularSignalView` | `didMoveToWindow` | `0x988c` | `0x14788` | class present |
| `_UIStatusBarDualCellularSignalView` | `traitCollectionDidChange:` | `0x98b8` | `0x14790` | class present |
| `_UIStatusBarImageView` | `layoutSubviews` | `0x9924` | `0x14798` | class present |
| `_UIStatusBarImageView` | `setImage:` | `0x99ac` | `0x147a0` | class present |
| `_UIStatusBarImageView` | `setHidden:` | `0x9b10` | `0x147a8` | class present |
| `_UIStatusBarImageView` | `setAlpha:` | `0x9b7c` | `0x147b0` | class present |
| `_UIStatusBarImageView` | `didMoveToSuperview` | `0x9be8` | `0x147b8` | class present |
| `_UIStatusBarImageView` | `didMoveToWindow` | `0x9c14` | `0x147c0` | class present |

The last image-view selector is `didMoveToWindow`, not `traitCollectionDidChange:`. The latter is hooked on `_UIStatusBarSignalView` and `_UIStatusBarDualCellularSignalView`.

### Signature-checked dynamic UIKit methods (`0x9c40`)

| Class | Candidate selectors |
|---|---|
| `_UIStatusBarSignalView` | `_updateBars`, `_updateActiveBars`, `_colorsDidChange`, `_updateCycleAnimationIfNeeded`, `_updateCycleAnimationNow` |
| `_UIStatusBarWifiSignalView` | Same five, plus `layoutSubviews`, `didMoveToWindow` |
| `_UIStatusBarCellularSignalView` | Same five |
| `_UIStatusBarCellularSmallSignalView` | Same five, plus `layoutSubviews`, `didMoveToWindow` |
| `_UIStatusBarCellularFlatSignalView` | Same five, plus `layoutSubviews`, `didMoveToWindow` |

The scanner examines only `class_copyMethodList` results (methods defined on that exact class), requires exactly two ObjC arguments (`self`, `_cmd`) and a return type string exactly `v`, then uses a block IMP. The block invokes the saved original IMP first, then the common renderer. This guarded path differs from the direct hooks above.

## STUI status-bar hooks

When `STUIStatusBarSignalView` exists, the constructor installs this group without a separate major-OS check. Other STUI classes are looked up by name and hooked directly; the source description must not imply those calls had method-presence/signature checks that are absent in the original constructor.

| Class | Selector | Replacement | Original IMP slot |
|---|---|---:|---:|
| `STUIStatusBarSignalView` | `_updateBars` | `0x8bc8` | `0x14698` |
| | `_updateActiveBars` | `0x8bf4` | `0x146a0` |
| | `layoutSubviews` | `0x8c20` | `0x146a8` |
| | `setActiveColor:` | `0x8c4c` | `0x146b0` |
| `STUIStatusBarCellularSignalView` | `_updateBars` | `0x8cf0` | `0x146b8` |
| | `_updateActiveBars` | `0x8d1c` | `0x146c0` |
| | `layoutSubviews` | `0x8d48` | `0x146c8` |
| `STUIStatusBarCellularSmallSignalView` | `layoutSubviews` | `0x8d74` | `0x146d0` |
| `STUIStatusBarCellularFlatSignalView` | `layoutSubviews` | `0x8da0` | `0x146d8` |
| `STUIStatusBarWifiSignalView` | `setActiveColor:` | `0x8dcc` | `0x146e0` |
| | `applyStyleAttributes:` | `0x8e74` | `0x146e8` |
| | `_updateBars` | `0x8ee0` | `0x146f0` |
| | `_updateActiveBars` | `0x8f0c` | `0x146f8` |
| | `_updateCycleAnimationIfNeeded` | `0x8f38` | `0x14700` |
| | `_updateCycleAnimationNow` | `0x8f64` | `0x14708` |
| | `layoutSubviews` | `0x8f90` | `0x14710` |
| `STUIStatusBarDualCellularSignalView` | `layoutSubviews` | `0x8fbc` | `0x14718` |

STUI signal color setup is not identical to UIKit 16: `0x8c4c` considers an incoming alpha>0.01 color before original and does not run the renderer; `0x960c` calls the UIKit original first, resolves its activeColor/fallback, conditionally captures a UIColor with alpha>0.01, then runs the renderer. STUI Wi-Fi `0x8dcc` calls original then refreshes tint only for an existing overlay.

## Constructor gates and counters

Constructor is arm64 `0x6a58`; it checks UIApplication, installs battery hooks, applies the UIKit16 major-version gate, installs STUI hooks if applicable, schedules a main-queue initial tree pass, and logs the three status flags. Three bytes at `0x14640..0x14642` are 0/1 “installed” flags; the log `%d` values are flags, not hook counts. `__mod_init_func` contains one pointer. No custom Objective-C class list or asset bundle is present.

## Evidence boundary

This map records registration sites and prototype-level observations from the supplied static ARM64 slice; it is not a hook deployment log, selector ABI guarantee across iOS versions, or device result. `MSHookMessageEx` takes a void original-slot pointer and provides no success result. The arm64e code has separate pointer-authenticated fixups and must be assessed against its own disassembly.
