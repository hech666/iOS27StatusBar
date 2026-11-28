// Independent static semantic reconstruction; not the original author's source.
// arm64 addresses below identify evidence, not hard-coded runtime addresses.
#import "../Headers/I27RERuntime.h"
#import "../Headers/I27REDrawing.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <float.h>

// Identity keys replace the original self-pointing globals 0x14560..0x145a0.
static char I27RERenderingKey;       // 0x14560
static char I27REWifiOverlayKey;     // 0x14568
static char I27RETopOverlayKey;      // 0x14570
static char I27REBottomOverlayKey;   // 0x14578
static char I27RECellularColorKey;   // 0x14580
static char I27RESingleOverlayKey;   // 0x14588
static char I27RENetworkSizeKey;     // 0x14590
static char I27RENetworkBarsKey;     // 0x14598
static char I27RENetworkUpdatingKey; // 0x145a0
static BOOL I27RELoggedKind[3];
static BOOL I27RELoggedNetworkImage;

static const NSInteger I27REWifiTag = 83369;
static const NSInteger I27RESingleTag = 110234;
static const NSInteger I27RETopTag = 110235;
static const NSInteger I27REBottomTag = 110236;

typedef NS_ENUM(NSInteger, I27RERuntimeKind) {
    I27RERuntimeWifi = 0, I27RERuntimeCellular = 1,
    I27RERuntimeDual = 2, I27RERuntimeOther = 3
};

static id I27REGet(id object, const void *key) {
    return object ? objc_getAssociatedObject(object, key) : nil;
}
static void I27RESet(id object, const void *key, id value) {
    if (object) objc_setAssociatedObject(object, key, value,
                                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static id I27REObjectGetter(id object, const char *name) {
    SEL selector = sel_registerName(name);
    if (![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}
static BOOL I27REVisibleColor(id color) {
    return [color isKindOfClass:[UIColor class]] &&
           CGColorGetAlpha([(UIColor *)color CGColor]) > 0x1.47ae147ae147bp-7;
}
// 0xbb80: no local exception swallowing and no KVC.
static UIColor *I27REColorGetter(id object, const char *name) {
    if (!object || !name) return nil;
    id value = I27REObjectGetter(object, name);
    return I27REVisibleColor(value) ? value : nil;
}

// 0xac84: both accessors suffice; otherwise use the class-name substring.
static BOOL I27REIsDual(UIView *view) {
    if ([view respondsToSelector:sel_registerName("topSignalView")] &&
        [view respondsToSelector:sel_registerName("bottomSignalView")]) return YES;
    const char *name = class_getName(object_getClass(view));
    return name && strstr(name, "DualCellularSignal") != NULL;
}
// 0xa144: deliberately do not classify arbitrary UIImageViews as signal views.
static I27RERuntimeKind I27REKind(UIView *view) {
    const char *name = class_getName(object_getClass(view));
    if (!name || !strstr(name, "StatusBar") || !strstr(name, "Signal"))
        return I27RERuntimeOther;
    if (I27REIsDual(view)) return I27RERuntimeDual;
    if (strstr(name, "Wifi") || strstr(name, "WiFi")) return I27RERuntimeWifi;
    return strstr(name, "Cellular") ? I27RERuntimeCellular : I27RERuntimeOther;
}
// 0xa224: includes the starting view, with no invented depth limit.
static UIView *I27REDualAncestor(UIView *view) {
    for (UIView *cursor = view; cursor; cursor = cursor.superview)
        if (I27REIsDual(cursor)) return cursor;
    return nil;
}
static Ivar I27REFindIvar(id object, const char *name) {
    for (Class cls = object_getClass(object); cls; cls = class_getSuperclass(cls)) {
        Ivar ivar = class_getInstanceVariable(cls, name);
        if (ivar) return ivar;
    }
    return NULL;
}

// 0xad5c type jump tables: B/C unsigned byte, c signed byte, s/S 16,
// i/I 32, l/L/q/Q 64. A 64-bit unsigned payload is clamped as signed by
// the original LDR + signed CSEL sequence; do not turn it into NSUInteger.
static BOOL I27REReadIntegralIvar(id object, Ivar ivar, NSInteger *value) {
    const char *type = ivar_getTypeEncoding(ivar);
    if (!type) return NO;
    const uint8_t *p = (const uint8_t *)(__bridge const void *)object
                       + ivar_getOffset(ivar);
    switch (*type) {
        case 'B': case 'C': { uint8_t x; memcpy(&x, p, 1); *value = x; break; }
        case 'c': { int8_t x; memcpy(&x, p, 1); *value = x; break; }
        case 's': { int16_t x; memcpy(&x, p, 2); *value = x; break; }
        case 'S': { uint16_t x; memcpy(&x, p, 2); *value = x; break; }
        case 'i': { int32_t x; memcpy(&x, p, 4); *value = x; break; }
        case 'I': { uint32_t x; memcpy(&x, p, 4); *value = x; break; }
        case 'l': case 'L': case 'q': case 'Q': {
            int64_t x; memcpy(&x, p, 8); *value = (NSInteger)x; break;
        }
        default: return NO;
    }
    return YES;
}
static NSInteger I27REBars(UIView *view, NSInteger maximum) {
    SEL getter = sel_registerName("numberOfActiveBars");
    if ([view respondsToSelector:getter]) {
        NSInteger n = ((NSInteger (*)(id, SEL))objc_msgSend)(view, getter);
        if (n >= 0 && (NSUInteger)n <= (NSUInteger)(maximum + 2))
            return n < maximum ? n : maximum;
    }
    static const char *const names[] = {
        "_numberOfActiveBars", "numberOfActiveBars", "_activeBars",
        "activeBars", "_displayValue"
    };
    for (const char *name : names) {
        Ivar ivar = I27REFindIvar(view, name);
        NSInteger n;
        if (ivar && I27REReadIntegralIvar(view, ivar, &n))
            return n < 0 ? 0 : n > maximum ? maximum : n;
    }
    return 0;
}

// 0xbce4: inspect at most 40 views, including self. Only the FIRST actual
// status-bar ancestor is queried. foregroundColor is on that VIEW, not attrs.
static UIColor *I27REStatusBarColor(UIView *view) {
    Class stui = (Class)objc_getClass("STUIStatusBar");
    Class uikit = (Class)objc_getClass("_UIStatusBar");
    UIView *cursor = view;
    for (unsigned n = 0; cursor && n < 40; ++n, cursor = cursor.superview) {
        if ((stui && [cursor isKindOfClass:stui]) ||
            (uikit && [cursor isKindOfClass:uikit])) {
            id attrs = I27REObjectGetter(cursor, "styleAttributes");
            UIColor *color = I27REColorGetter(attrs, "imageTintColor");
            if (!color) color = I27REColorGetter(attrs, "textColor");
            if (!color) color = I27REColorGetter(cursor, "foregroundColor");
            return color;
        }
    }
    return nil;
}
static UIColor *I27RETraitColor(UIView *view) {
    if (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight)
        return [UIColor blackColor];
    // The non-light branch evaluates this accessor again in 0xb638/0xcb18.
    (void)view.traitCollection.userInterfaceStyle;
    return [UIColor whiteColor];
}
static UIColor *I27REWifiColor(UIView *view) { // 0xb570
    UIColor *color = I27REColorGetter(view, "activeColor");
    if (!color) color = I27REStatusBarColor(view);
    return color ?: I27RETraitColor(view);
}
void I27RECaptureCellularColor(UIView *view, UIColor *color) { // 0xd2d0
    if (view && I27REVisibleColor(color)) I27RESet(view, &I27RECellularColorKey, color);
}
static UIColor *I27RECellularColor(UIView *view) { // 0xc960
    UIColor *color = I27REStatusBarColor(view);
    if (color) return color;
    color = I27REGet(view, &I27RECellularColorKey);
    if (I27REVisibleColor(color)) return color;
    color = I27REColorGetter(view, "activeColor");
    if (color) { I27RECaptureCellularColor(view, color); return color; }
    return I27RETraitColor(view);
}
void I27RECaptureWifiColor(UIView *view, UIColor *color) { // 0x8dcc post-orig
    (void)color;
    UIImageView *overlay = I27REGet(view, &I27REWifiOverlayKey);
    if (overlay) overlay.tintColor = I27REWifiColor(view);
}

static BOOL I27REProtectedTag(NSInteger tag) {
    return tag == I27REWifiTag || (tag >= I27RESingleTag && tag <= I27REBottomTag);
}
// 0xbee8: a non-UIView, NON-nil delegate is not itself hidden. Only a nil
// delegate causes removeAllAnimations/opacity=0/hidden=YES. Other layers recurse.
static void I27REHideNativeSublayers(CALayer *root) {
    if (!root) return;
    for (CALayer *layer in root.sublayers) {
        id delegate = layer.delegate;
        if ([delegate isKindOfClass:[UIView class]] &&
            I27REProtectedTag([(UIView *)delegate tag])) continue;
        if (!delegate) {
            [layer removeAllAnimations];
            layer.opacity = 0.0f;
            layer.hidden = YES;
        }
        I27REHideNativeSublayers(layer);
    }
}
// 0xc170: preserve tagged overlays, restoring their VIEW hidden/alpha only.
static void I27REHideNativeSubviews(UIView *root) {
    if (!root) return;
    for (UIView *child in root.subviews) {
        if (I27REProtectedTag(child.tag)) {
            child.hidden = NO;
            child.alpha = 1.0;
            continue;
        }
        if ([child isKindOfClass:[UIImageView class]]) {
            child.hidden = YES;
            child.alpha = 0.0;
            child.layer.hidden = YES;
            child.layer.opacity = 0.0f;
            child.layer.contents = nil;
        }
        I27REHideNativeSubviews(child);
    }
}
// 0xa384 / 0xcd38. No added @finally around CATransaction: the original
// cleanup paths do not commit the transaction when a private API throws.
static void I27REEraseNativeDrawing(UIView *view) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.contents = nil;
    I27REHideNativeSublayers(view.layer);
    I27REHideNativeSubviews(view);
    [CATransaction commit];
}
static void I27RESuppressCellular(UIView *view) { // 0xcc34
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 17) {
        UIColor *clear = [UIColor clearColor];
        SEL active = sel_registerName("setActiveColor:");
        SEL inactive = sel_registerName("setInactiveColor:");
        if ([view respondsToSelector:active])
            ((void (*)(id, SEL, id))objc_msgSend)(view, active, clear);
        if ([view respondsToSelector:inactive])
            ((void (*)(id, SEL, id))objc_msgSend)(view, inactive, clear);
    }
    I27REEraseNativeDrawing(view);
}
static UIImageView *I27REOverlay(UIView *host, const void *key, NSInteger tag) {
    UIImageView *overlay = I27REGet(host, key); // 0xb708
    if (overlay) {
        if (overlay.superview != host) {
            [overlay removeFromSuperview];
            [host addSubview:overlay];
        }
    } else {
        overlay = [[UIImageView alloc] initWithFrame:host.bounds];
        overlay.tag = tag;
        overlay.contentMode = UIViewContentModeScaleAspectFill; // initial raw 2
        overlay.userInteractionEnabled = NO;
        overlay.clipsToBounds = NO;
        overlay.isAccessibilityElement = NO;
        I27RESet(host, key, overlay);
        [host addSubview:overlay];
    }
    [host bringSubviewToFront:overlay];
    return overlay;
}

// 0xce38: getter result is type checked; then object_getIvar, with no invented
// type-encoding validation (the original assumes these are object ivars).
static UIView *I27REChildView(id object, const char *getter, const char *ivarName) {
    id candidate = I27REObjectGetter(object, getter);
    if ([candidate isKindOfClass:[UIView class]]) return candidate;
    Ivar ivar = I27REFindIvar(object, ivarName);
    candidate = ivar ? object_getIvar(object, ivar) : nil;
    return [candidate isKindOfClass:[UIView class]] ? candidate : nil;
}
struct I27RESignalPair {
    __unsafe_unretained UIView *top;
    CGFloat topY;
    __unsafe_unretained UIView *bottom;
    CGFloat bottomY;
};
// 0xcfa0: selects the two SMALLEST centerY values, not min/max. Initial budget
// 4 still examines immediate children at budget 0; do not introduce !=root or
// class-name tests. Responding to numberOfActiveBars is the entire predicate.
static void I27REFindSignalPair(UIView *node, UIView *coordinateHost,
                              I27RESignalPair *pair, NSUInteger budget) {
    if (!node) return;
    SEL bars = sel_registerName("numberOfActiveBars");
    for (UIView *child in node.subviews) {
        if ([child respondsToSelector:bars]) {
            CGFloat y = CGRectGetMidY([child convertRect:child.bounds
                                                 toView:coordinateHost]);
            if (!pair->top || y < pair->topY) {
                pair->bottom = pair->top;
                pair->bottomY = pair->topY;
                pair->top = child;
                pair->topY = y;
            } else if (!pair->bottom || y < pair->bottomY) {
                pair->bottom = child;
                pair->bottomY = y;
            }
        }
        if (budget) I27REFindSignalPair(child, coordinateHost, pair, budget - 1);
    }
}
static void I27RERenderDual(UIView *view);
static void I27RERenderWifi(UIView *view) { // 0xa2b8
    NSInteger bars = I27REBars(view, 3);
    CGRect bounds = view.bounds;
    if (!(bounds.size.width > 0.1 && bounds.size.height > 0.1)) return;
    CGSize size = I27REGlyphSize(I27REGlyphKindWiFi, bounds.size);
    UIImage *image = I27REMakeGlyph(I27REGlyphKindWiFi, bars, size);
    if (!image) return;
    UIColor *color = I27REWifiColor(view);
    I27REEraseNativeDrawing(view);
    UIImageView *overlay = I27REOverlay(view, &I27REWifiOverlayKey, I27REWifiTag);
    overlay.contentMode = UIViewContentModeCenter; // raw 4, not aspect-fit
    overlay.image = image;
    overlay.tintColor = color;
    I27RECenterGlyphView(view, overlay, image.size);
}
static void I27RERenderSingle(UIView *view) { // 0xa9bc
    UIView *dual = I27REDualAncestor(view);
    if (dual && dual != view) { I27RERenderDual(dual); return; }
    NSInteger bars = I27REBars(view, 4);
    CGSize size = I27REGlyphSize(I27REGlyphKindSingleSIM, view.bounds.size);
    UIImage *image = I27REMakeGlyph(I27REGlyphKindSingleSIM, bars, size);
    if (!image) image = I27REMakeGlyph(I27REGlyphKindCellular, bars, size);
    if (!image) return;
    UIColor *color = I27RECellularColor(view);
    I27RESuppressCellular(view);
    UIImageView *overlay = I27REOverlay(view, &I27RESingleOverlayKey, I27RESingleTag);
    overlay.contentMode = UIViewContentModeCenter;
    overlay.image = image;
    overlay.tintColor = color;
    I27RECenterGlyphView(view, overlay, image.size);
}
static void I27RERenderDual(UIView *view) { // 0xa558
    UIView *top = I27REChildView(view, "topSignalView", "_topSignalView");
    UIView *bottom = I27REChildView(view, "bottomSignalView", "_bottomSignalView");
    if (!top || !bottom) {
        I27RESignalPair pair = { nil, DBL_MAX, nil, DBL_MAX };
        I27REFindSignalPair(view, view, &pair, 4);
        if (!top) top = pair.top;
        if (!bottom) bottom = pair.bottom;
    }
    NSInteger topBars = top ? I27REBars(top, 4) : 0;
    NSInteger bottomBars = bottom ? I27REBars(bottom, 4) : 0;
    CGSize size = I27REGlyphSize(I27REGlyphKindCellular, view.bounds.size);
    UIImage *upper = I27REMakeGlyph(I27REGlyphKindCellular, topBars, size);
    UIImage *lower = I27REMakeGlyph(I27REGlyphKindCellular2, bottomBars, size);
    if (!upper && !lower) return;
    UIColor *color = I27RECellularColor(view);
    if (top) I27RESuppressCellular(top);
    if (bottom) I27RESuppressCellular(bottom);
    I27RESuppressCellular(view);
    UIImageView *upperView = I27REOverlay(view, &I27RETopOverlayKey, I27RETopTag);
    upperView.hidden = upper == nil;
    upperView.contentMode = UIViewContentModeCenter;
    upperView.image = upper;
    upperView.tintColor = color;
    I27RECenterGlyphView(view, upperView, upper ? upper.size : size);
    UIImageView *lowerView = I27REOverlay(view, &I27REBottomOverlayKey, I27REBottomTag);
    lowerView.hidden = lower == nil;
    lowerView.contentMode = UIViewContentModeCenter;
    lowerView.image = lower;
    lowerView.tintColor = color;
    I27RECenterGlyphView(view, lowerView, lower ? lower.size : size);
}

void I27RERenderView(UIView *view) { // 0x9dc0
    if (!view || ![NSThread isMainThread]) return;
    if (I27REKind(view) == I27RERuntimeCellular) {
        UIView *dual = I27REDualAncestor(view);
        if (dual) view = dual;
    }
    I27RERuntimeKind kind = I27REKind(view);
    if (kind == I27RERuntimeOther) return;
    if ([I27REGet(view, &I27RERenderingKey) boolValue]) return;
    if (!I27RELoggedKind[kind] && view.bounds.size.width > 0.1 &&
        view.bounds.size.height > 0.1) {
        I27RELoggedKind[kind] = YES;
        NSLog(@"[iOS27StatusBar native16] rendering class=%@ kind=%ld bounds=%@",
              NSStringFromClass(view.class), (long)kind, NSStringFromCGRect(view.bounds));
    }
    I27RESet(view, &I27RERenderingKey, @YES);
    @try {
        switch (I27REKind(view)) {
            case I27RERuntimeWifi: I27RERenderWifi(view); break;
            case I27RERuntimeDual: I27RERenderDual(view); break;
            case I27RERuntimeCellular: {
                UIView *dual = I27REDualAncestor(view);
                if (dual && dual != view) I27RERenderDual(dual);
                else I27RERenderSingle(view);
                break;
            }
            default: break;
        }
    } @catch (NSException *exception) {
        (void)exception; // observed specific handler, not @catch(id)
    } @finally {
        I27RESet(view, &I27RERenderingKey, nil);
    }
}

void I27RERefreshWifiTint(UIView *view) {
    I27RECaptureWifiColor(view, nil);
}
BOOL I27REIsManagedWifiImage(UIView *view) {
    return I27REGet(view, &I27RENetworkBarsKey) != nil;
}
BOOL I27REIsUpdatingNetworkImage(UIView *view) {
    return [I27REGet(view, &I27RENetworkUpdatingKey) boolValue];
}
// 0xd928: the managed network-icon mark excludes an image even at level @0.
// Only ANCESTORS with both class-name substrings and any signal overlay count.
BOOL I27REShouldHideNetworkImage(UIView *view) {
    if (I27REIsManagedWifiImage(view)) return NO;
    for (UIView *cursor = view.superview; cursor; cursor = cursor.superview) {
        const char *name = class_getName(object_getClass(cursor));
        if (!name || !strstr(name, "StatusBar") || !strstr(name, "Signal")) continue;
        if (I27REGet(cursor, &I27RESingleOverlayKey) ||
            I27REGet(cursor, &I27RETopOverlayKey) ||
            I27REGet(cursor, &I27REBottomOverlayKey) ||
            I27REGet(cursor, &I27REWifiOverlayKey)) return YES;
    }
    return NO;
}
void I27RESuppressNativeNetworkImage(UIView *view) { // 0xd7f0
    if (!view || !I27REShouldHideNetworkImage(view)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.contents = nil;
    view.layer.hidden = YES;
    view.layer.opacity = 0.0f;
    [CATransaction commit];
}
// 0xd664: this is intentionally NOT main-thread gated, since setImage:'s
// managed/no-guard branch calls this factory directly in the original binary.
UIImage *I27RENetworkReplacementImage(UIImageView *imageView) {
    NSNumber *bars = I27REGet(imageView, &I27RENetworkBarsKey);
    if (!bars) return nil;
    NSValue *saved = I27REGet(imageView, &I27RENetworkSizeKey);
    CGSize nativeSize = saved ? saved.CGSizeValue : imageView.bounds.size;
    if (!(nativeSize.width > 0.1 && nativeSize.height > 0.1)) return nil;
    CGSize size = I27REGlyphSize(I27REGlyphKindWiFi, nativeSize);
    return I27REMakeGlyph(I27REGlyphKindWiFi, bars.integerValue, size);
}
void I27RERenderNetworkImage(UIImageView *imageView) { // 0xd3f8
    if (!imageView || ![NSThread isMainThread] ||
        !I27REIsManagedWifiImage(imageView) ||
        I27REIsUpdatingNetworkImage(imageView)) return;
    UIImage *image = I27RENetworkReplacementImage(imageView);
    if (!image) return;
    I27RESet(imageView, &I27RENetworkUpdatingKey, @YES);
    @try {
        imageView.contentMode = UIViewContentModeCenter;
        imageView.image = image;
        if (!I27RELoggedNetworkImage) {
            I27RELoggedNetworkImage = YES;
            NSLog(@"[iOS27StatusBar native16] rendering networkIconView class=%@ bounds=%@",
                  NSStringFromClass(imageView.class), NSStringFromCGRect(imageView.bounds));
        }
    } @finally {
        // No catch here: 0xd628 catches only to execute cleanup then rethrows.
        I27RESet(imageView, &I27RENetworkUpdatingKey, nil);
    }
}
void I27REUpdateWifiItem(id item, id update) { // 0x915c post-orig body
    id candidate = I27REObjectGetter(item, "networkIconView");
    if (![candidate isKindOfClass:[UIImageView class]]) return;
    UIImageView *imageView = candidate;
    if (!I27REIsManagedWifiImage(imageView)) {
        UIImage *oldImage = imageView.image;
        if (oldImage) I27RESet(imageView, &I27RENetworkSizeKey,
                              [NSValue valueWithCGSize:oldImage.size]);
    }
    id data = I27REObjectGetter(update, "data");
    id entry = I27REObjectGetter(data, "wifiEntry");
    SEL display = sel_registerName("displayValue");
    NSInteger bars = -1;
    if ([entry respondsToSelector:display])
        bars = ((NSInteger (*)(id, SEL))objc_msgSend)(entry, display);
    // Unsigned test also rejects negative values, exactly as CMP + B.LO.
    if ((NSUInteger)bars > 3) {
        id signalView = I27REObjectGetter(item, "signalView");
        if (!signalView) return;
        bars = I27REBars(signalView, 3);
        if ((NSUInteger)bars > 3) return;
    }
    I27RESet(imageView, &I27RENetworkBarsKey, @(bars));
    I27RERenderNetworkImage(imageView);
}

static void I27REWalkViewTree(UIView *view) { // 0xdb90
    if (!view) return;
    if (I27REKind(view) != I27RERuntimeOther) I27RERenderView(view);
    for (UIView *child in view.subviews) I27REWalkViewTree(child);
}
void I27REInitialRefresh(void) { // 0x755c block body, dispatch is external
    @try {
        UIApplication *application = [UIApplication sharedApplication];
        if (!application) return;
        for (id scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in [(UIWindowScene *)scene windows])
                I27REWalkViewTree(window);
        }
    } @catch (NSException *exception) {
        (void)exception;
    }
}

// Hook-facing adapters preserve the distinct 0x8c4c and 0x960c ordering.
// Neither calls an original IMP nor renders; those operations belong to hooks.
void I27RECaptureSTUICellularColor(UIView *view, UIColor *color) {
    if (color && CGColorGetAlpha(color.CGColor) > 0x1.47ae147ae147bp-7)
        I27RECaptureCellularColor(view, color);
}
void I27RECaptureUIKitCellularColor(UIView *view, UIColor *color) {
    UIColor *effective = I27REColorGetter(view, "activeColor") ?: color;
    if (I27REVisibleColor(effective)) I27RECaptureCellularColor(view, effective);
}
