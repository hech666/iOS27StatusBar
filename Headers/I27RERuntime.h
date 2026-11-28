#ifndef I27RE_RUNTIME_H
#define I27RE_RUNTIME_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Independent static semantic reconstruction, not the original author's source.
// No constructor, swizzling, MSHookMessageEx, or original IMP calls live here.
// The hook owner must call its original IMP at the binary-observed position.
FOUNDATION_EXPORT void I27RERenderView(UIView * _Nullable view);

// arm64 0x915c AFTER the original applyUpdate:toDisplayItem: has returned.
// update is its FIRST explicit argument; the binary reads update.data.wifiEntry.
// The hook must preserve/return the original method's object return value.
FOUNDATION_EXPORT void I27REUpdateWifiItem(id _Nullable item, id _Nullable update);
FOUNDATION_EXPORT void I27RERenderNetworkImage(UIImageView * _Nullable imageView);
FOUNDATION_EXPORT BOOL I27REShouldHideNetworkImage(UIView * _Nullable view);

// Precisely the low-level 0xd2d0 cache operation: keep a UIColor only if alpha
// >0.01; do not clear a previous color for nil/transparent input; no rendering.
// STUI SignalView calls this before orig. UIKit SignalView calls it after orig
// with (valid activeColor getter result ?: supplied color), then RenderView.
FOUNDATION_EXPORT void I27RECaptureCellularColor(UIView * _Nullable view,
                                               UIColor * _Nullable color);
// 0x8c4c PRE-orig: first test the supplied object's CGColor alpha (without
// a preceding UIColor class test), then call the checked 0xd2d0 cache helper.
FOUNDATION_EXPORT void I27RECaptureSTUICellularColor(UIView * _Nullable view,
                                                   UIColor * _Nullable color);
// 0x960c POST-orig: bb80(activeColor) ?: supplied argument; validate/cache only.
// This helper does not RenderView; the hook does so after this helper returns.
FOUNDATION_EXPORT void I27RECaptureUIKitCellularColor(UIView * _Nullable view,
                                                    UIColor * _Nullable color);

// STUI WifiSignalView's post-orig 0x8dcc behavior: tint an EXISTING WiFi overlay
// using the current color-selection chain; do not create/cache/render a glyph.
// The supplied color is deliberately unused by the observed post-orig path.
// UIKit WifiSignalView setActiveColor: instead calls RenderView after orig.
FOUNDATION_EXPORT void I27RECaptureWifiColor(UIView * _Nullable view,
                                           UIColor * _Nullable color);
// Preferred hook-facing spelling; same post-orig operation without a dummy arg.
// The arm64 selector-key load at 0x8df0 resolves to 0x14568, not 0x14570.
FOUNDATION_EXPORT void I27RERefreshWifiTint(UIView * _Nullable view);

// Execute the original initial-refresh block body on its caller's thread.
// The constructor owner, not this module, dispatches this once to main queue.
FOUNDATION_EXPORT void I27REInitialRefresh(void);

// Exact pieces required to assemble arm64 0x99ac setImage: without weakening
// its state distinction. A non-nil @0 level IS managed; it is not boolValue.
FOUNDATION_EXPORT BOOL I27REIsManagedWifiImage(UIView * _Nullable view);
FOUNDATION_EXPORT BOOL I27REIsUpdatingNetworkImage(UIView * _Nullable view);
FOUNDATION_EXPORT UIImage * _Nullable I27RENetworkReplacementImage(
    UIImageView * _Nullable imageView);
// arm64 0xd7f0: recheck ShouldHide; suppress the layer in a disabled-actions
// CATransaction. Does not send setImage:, setHidden:, or setAlpha: to the view.
FOUNDATION_EXPORT void I27RESuppressNativeNetworkImage(UIView * _Nullable view);

NS_ASSUME_NONNULL_END
#endif
