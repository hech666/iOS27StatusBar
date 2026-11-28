// Semantic reconstruction; suffixes are original arm64 addresses.
// The entry/registration order is recovered from constructor 0x6a58.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import "../Headers/I27REBattery.h"
#import "../Headers/I27RERuntime.h"
#include <stdlib.h>
#include <string.h>

extern "C" void MSHookMessageEx(Class, SEL, IMP, IMP *);

// Each statically generated hook has its OWN original IMP, like the input.
#define I27RE_POST0(hex) \
static void (*I27REOrig##hex)(UIView *, SEL); \
static void I27REH##hex(UIView *view, SEL cmd) { \
    I27REOrig##hex(view, cmd); I27RERenderView(view); \
}
#define I27RE_POSTOBJ(hex) \
static void (*I27REOrig##hex)(UIView *, SEL, id); \
static void I27REH##hex(UIView *view, SEL cmd, id arg) { \
    id __attribute__((objc_precise_lifetime)) keep = arg; \
    I27REOrig##hex(view, cmd, keep); I27RERenderView(view); \
}
I27RE_POST0(8bc8)
I27RE_POST0(8bf4)
I27RE_POST0(8c20)
I27RE_POST0(8cf0)
I27RE_POST0(8d1c)
I27RE_POST0(8d48)
I27RE_POST0(8d74)
I27RE_POST0(8da0)
I27RE_POSTOBJ(8e74)
I27RE_POST0(8ee0)
I27RE_POST0(8f0c)
I27RE_POST0(8f38)
I27RE_POST0(8f64)
I27RE_POST0(8f90)
I27RE_POST0(8fbc)
I27RE_POST0(8fe8)
I27RE_POST0(9014)
I27RE_POSTOBJ(9040)
I27RE_POST0(90ac)
I27RE_POST0(90d8)
I27RE_POST0(9104)
I27RE_POST0(9130)
I27RE_POSTOBJ(9788)
I27RE_POSTOBJ(97f4)
I27RE_POST0(9860)
I27RE_POST0(988c)
I27RE_POSTOBJ(98b8)

// 0x8c4c caches the incoming STUI cellular color BEFORE original, with no
// post-render. 0x960c does the UIKit variant AFTER original and then renders.
static void (*I27REOrig8c4c)(UIView *, SEL, UIColor *);
static void I27REH8c4c(UIView *view, SEL cmd, UIColor *color) {
    UIColor *__attribute__((objc_precise_lifetime)) keep = color;
    I27RECaptureSTUICellularColor(view, keep);
    I27REOrig8c4c(view, cmd, keep);
}
static void (*I27REOrig8dcc)(UIView *, SEL, UIColor *);
static void I27REH8dcc(UIView *view, SEL cmd, UIColor *color) {
    I27REOrig8dcc(view, cmd, color);
    I27RERefreshWifiTint(view);
}
static IMP I27REOrig915c; // The hook's original returns an object.
static id I27REH915c(id item, SEL cmd, id update, id displayItem) {
    id __attribute__((objc_precise_lifetime)) keep = update;
    id result = ((id (*)(id, SEL, id, id))I27REOrig915c)(item, cmd, keep, displayItem);
    I27REUpdateWifiItem(item, keep);
    return result;
}
static void (*I27REOrig95e0)(UIView *, SEL, NSInteger);
static void I27REH95e0(UIView *view, SEL cmd, NSInteger bars) {
    I27REOrig95e0(view, cmd, bars);
    I27RERenderView(view);
}
static void (*I27REOrig960c)(UIView *, SEL, UIColor *);
static void I27REH960c(UIView *view, SEL cmd, UIColor *color) {
    UIColor *__attribute__((objc_precise_lifetime)) keep = color;
    I27REOrig960c(view, cmd, keep);
    I27RECaptureUIKitCellularColor(view, keep);
    I27RERenderView(view);
}

static void (*I27REOrig9924)(UIImageView *, SEL);
static void I27REH9924(UIImageView *view, SEL cmd) {
    I27REOrig9924(view, cmd);
    if (I27REIsManagedWifiImage(view)) I27RERenderNetworkImage(view);
    else I27RESuppressNativeNetworkImage(view);
}
static void (*I27REOrig99ac)(UIImageView *, SEL, UIImage *);
static void I27REH99ac(UIImageView *view, SEL cmd, UIImage *image) {
    UIImage *__attribute__((objc_precise_lifetime)) keep = image;
    if (I27REIsManagedWifiImage(view) && !I27REIsUpdatingNetworkImage(view)) {
        UIImage *replacement = I27RENetworkReplacementImage(view);
        I27REOrig99ac(view, cmd, replacement ?: keep);
    } else if (I27REShouldHideNetworkImage(view)) {
        I27REOrig99ac(view, cmd, nil);
        I27RESuppressNativeNetworkImage(view);
    } else {
        I27REOrig99ac(view, cmd, keep);
    }
}
static void (*I27REOrig9b10)(UIView *, SEL, BOOL);
static void I27REH9b10(UIView *view, SEL cmd, BOOL hidden) {
    if (I27REShouldHideNetworkImage(view)) {
        I27REOrig9b10(view, cmd, YES);
        I27RESuppressNativeNetworkImage(view);
    } else I27REOrig9b10(view, cmd, hidden);
}
static void (*I27REOrig9b7c)(UIView *, SEL, CGFloat);
static void I27REH9b7c(UIView *view, SEL cmd, CGFloat alpha) {
    if (I27REShouldHideNetworkImage(view)) {
        I27REOrig9b7c(view, cmd, 0.0);
        I27RESuppressNativeNetworkImage(view);
    } else I27REOrig9b7c(view, cmd, alpha);
}
static void (*I27REOrig9be8)(UIView *, SEL);
static void I27REH9be8(UIView *view, SEL cmd) {
    I27REOrig9be8(view, cmd); I27RESuppressNativeNetworkImage(view);
}
static void (*I27REOrig9c14)(UIView *, SEL);
static void I27REH9c14(UIView *view, SEL cmd) {
    I27REOrig9c14(view, cmd); I27RESuppressNativeNetworkImage(view);
}

// 0x9c40: hook only an OWN, no-argument method with exact return encoding v.
// Merely asking class_getInstanceMethod would also match inherited methods.
static void I27REHookOwnVoidMethod(Class cls, const char *name) {
    if (cls == Nil) return;
    SEL sel = sel_registerName(name);
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method chosen = nullptr;
    for (unsigned int i = 0; i < count; ++i) {
        if (sel_isEqual(method_getName(methods[i]), sel)) {
            chosen = methods[i]; break;
        }
    }
    free(methods);
    if (chosen == nullptr || method_getNumberOfArguments(chosen) != 2) return;
    char *type = method_copyReturnType(chosen);
    if (type == nullptr) return;
    BOOL valid = strcmp(type, "v") == 0;
    free(type);
    if (!valid) return;
    __block IMP original = nullptr;
    IMP replacement = imp_implementationWithBlock(^(UIView *view) {
        if (original != nullptr) ((void (*)(UIView *, SEL))original)(view, sel);
        I27RERenderView(view);
    });
    MSHookMessageEx(cls, sel, replacement, &original);
}

#define I27RE_HOOK(cls, selectorName, hex) \
    MSHookMessageEx((cls), sel_registerName(selectorName), (IMP)I27REH##hex, \
                   (IMP *)&I27REOrig##hex)

static BOOL I27REUIKit16Installed;
static BOOL I27RESTUIInstalled;

static void I27REInstallUIKit16(void) {
    if (I27REUIKit16Installed) return;
    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion != 16) return;
    Class signal = objc_getClass("_UIStatusBarSignalView");
    if (signal == Nil) return;
    I27RE_HOOK(signal, "layoutSubviews", 8fe8);
    I27RE_HOOK(signal, "didMoveToWindow", 9014);
    I27RE_HOOK(signal, "traitCollectionDidChange:", 9040);
    Class wifi = objc_getClass("_UIStatusBarWifiSignalView");
    Class cellular = objc_getClass("_UIStatusBarCellularSignalView");
    if (wifi != Nil) {
        I27RE_HOOK(wifi, "layoutSubviews", 90ac);
        I27RE_HOOK(wifi, "didMoveToWindow", 90d8);
    }
    if (cellular != Nil) {
        I27RE_HOOK(cellular, "layoutSubviews", 9104);
        I27RE_HOOK(cellular, "didMoveToWindow", 9130);
    }
    Class item = objc_getClass("_UIStatusBarWifiItem");
    if (item != Nil && class_getInstanceMethod(item,
              sel_registerName("applyUpdate:toDisplayItem:")) != nullptr) {
        I27RE_HOOK(item, "applyUpdate:toDisplayItem:", 915c);
    }
    if (class_getInstanceMethod(signal,
              sel_registerName("setNumberOfActiveBars:")) != nullptr) {
        I27RE_HOOK(signal, "setNumberOfActiveBars:", 95e0);
    }
    if (class_getInstanceMethod(signal, sel_registerName("setActiveColor:")) != nullptr) {
        I27RE_HOOK(signal, "setActiveColor:", 960c);
    }
    if (wifi != Nil) {
        if (class_getInstanceMethod(wifi, sel_registerName("setActiveColor:")) != nullptr) {
            I27RE_HOOK(wifi, "setActiveColor:", 9788);
        }
        if (class_getInstanceMethod(wifi, sel_registerName("applyStyleAttributes:")) != nullptr) {
            I27RE_HOOK(wifi, "applyStyleAttributes:", 97f4);
        }
    }
    Class dual = objc_getClass("_UIStatusBarDualCellularSignalView");
    if (dual != Nil) {
        I27RE_HOOK(dual, "layoutSubviews", 9860);
        I27RE_HOOK(dual, "didMoveToWindow", 988c);
        I27RE_HOOK(dual, "traitCollectionDidChange:", 98b8);
    }
    Class image = objc_getClass("_UIStatusBarImageView");
    if (image != Nil) {
        I27RE_HOOK(image, "layoutSubviews", 9924);
        I27RE_HOOK(image, "setImage:", 99ac);
        I27RE_HOOK(image, "setHidden:", 9b10);
        I27RE_HOOK(image, "setAlpha:", 9b7c);
        I27RE_HOOK(image, "didMoveToSuperview", 9be8);
        I27RE_HOOK(image, "didMoveToWindow", 9c14);
    }
    const char *classes[] = {
        "_UIStatusBarSignalView", "_UIStatusBarWifiSignalView",
        "_UIStatusBarCellularSignalView", "_UIStatusBarCellularSmallSignalView",
        "_UIStatusBarCellularFlatSignalView"
    };
    const char *updates[] = {"_updateBars", "_updateActiveBars", "_colorsDidChange",
        "_updateCycleAnimationIfNeeded", "_updateCycleAnimationNow"};
    for (unsigned i = 0; i < 5; ++i) {
        Class cls = objc_getClass(classes[i]);
        for (const char *method : updates) I27REHookOwnVoidMethod(cls, method);
        if (i >= 3) {
            I27REHookOwnVoidMethod(cls, "layoutSubviews");
            I27REHookOwnVoidMethod(cls, "didMoveToWindow");
        }
    }
    I27REUIKit16Installed = YES;
}

static void I27REInstallSTUI(void) {
    if (I27RESTUIInstalled) return;
    Class signal = objc_getClass("STUIStatusBarSignalView");
    if (signal == Nil) return;
    // No independent version or per-method guard is present in this group.
    I27RE_HOOK(signal, "_updateBars", 8bc8);
    I27RE_HOOK(signal, "_updateActiveBars", 8bf4);
    I27RE_HOOK(signal, "layoutSubviews", 8c20);
    I27RE_HOOK(signal, "setActiveColor:", 8c4c);
    Class cellular = objc_getClass("STUIStatusBarCellularSignalView");
    I27RE_HOOK(cellular, "_updateBars", 8cf0);
    I27RE_HOOK(cellular, "_updateActiveBars", 8d1c);
    I27RE_HOOK(cellular, "layoutSubviews", 8d48);
    Class small = objc_getClass("STUIStatusBarCellularSmallSignalView");
    I27RE_HOOK(small, "layoutSubviews", 8d74);
    Class flat = objc_getClass("STUIStatusBarCellularFlatSignalView");
    I27RE_HOOK(flat, "layoutSubviews", 8da0);
    Class wifi = objc_getClass("STUIStatusBarWifiSignalView");
    I27RE_HOOK(wifi, "setActiveColor:", 8dcc);
    I27RE_HOOK(wifi, "applyStyleAttributes:", 8e74);
    I27RE_HOOK(wifi, "_updateBars", 8ee0);
    I27RE_HOOK(wifi, "_updateActiveBars", 8f0c);
    I27RE_HOOK(wifi, "_updateCycleAnimationIfNeeded", 8f38);
    I27RE_HOOK(wifi, "_updateCycleAnimationNow", 8f64);
    I27RE_HOOK(wifi, "layoutSubviews", 8f90);
    Class dual = objc_getClass("STUIStatusBarDualCellularSignalView");
    I27RE_HOOK(dual, "layoutSubviews", 8fbc);
    I27RESTUIInstalled = YES;
}

__attribute__((constructor)) static void I27RELoad(void) {
    @autoreleasepool {
        if (objc_getClass("UIApplication") == Nil) return;
        BOOL battery = I27REInstallBatteryHooks();
        I27REInstallUIKit16();
        I27REInstallSTUI();
        dispatch_async(dispatch_get_main_queue(), ^{ I27REInitialRefresh(); });
        NSLog(@"[iOS27StatusBar native16] loaded; UIKit16 hooks=%d, STUI hooks=%d, battery hooks=%d",
              I27REUIKit16Installed, I27RESTUIInstalled, battery);
    }
}
