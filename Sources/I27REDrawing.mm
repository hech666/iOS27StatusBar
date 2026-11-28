// Static reconstruction from the supplied arm64/arm64e Mach-O slices.
// See evidence/DRAWING-RECONSTRUCTION.md and evidence/extract-drawing.py.
// Compile as Objective-C++ with ARC and UIKit/CoreGraphics. No private API.
#import "../Headers/I27REDrawing.h"
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>
#include <limits.h>

// Hexadecimal binary64 literals preserve the exact constants, not rounded
// redraws. Rows: start.xy, first control.xy, second control.xy, end.xy, width.
static const double I27REWiFiArcs[2][9] = {
    { 0x1.599999999999ap+2, 0x1.fcccccccccccdp+3, 0x1.9666666666666p+3, 0x1.1cccccccccccdp+3, 0x1.6e66666666666p+4, 0x1.5666666666666p+2, 0x1.0c00000000000p+5, 0x1.5666666666666p+2, 0x1.299999999999ap+3 },
    { 0x1.0bae147ae147bp+4, 0x1.bd9999999999ap+4, 0x1.54ccccccccccdp+4, 0x1.8cccccccccccdp+4, 0x1.a99999999999ap+4, 0x1.6666666666666p+4, 0x1.0c00000000000p+5, 0x1.6666666666666p+4, 0x1.2000000000000p+3 }
};
static const double I27REWiFiDotMove[2] = {
    0x1.0c00000000000p+5, 0x1.1d33333333333p+5
};
// Four cubic curves, six arguments per CGContextAddCurveToPoint.
static const double I27REWiFiDotCurves[4][6] = {
    { 0x1.c89eb851eb852p+4, 0x1.1d33333333333p+5, 0x1.80ccccccccccdp+4, 0x1.32dc28f5c28f6p+5, 0x1.80ccccccccccdp+4, 0x1.4accccccccccdp+5 },
    { 0x1.80ccccccccccdp+4, 0x1.5333333333333p+5, 0x1.d68f5c28f5c29p+4, 0x1.8933333333333p+5, 0x1.0c00000000000p+5, 0x1.8d33333333333p+5 },
    { 0x1.2cb851eb851ecp+5, 0x1.8933333333333p+5, 0x1.579999999999ap+5, 0x1.5333333333333p+5, 0x1.579999999999ap+5, 0x1.4accccccccccdp+5 },
    { 0x1.579999999999ap+5, 0x1.32dc28f5c28f6p+5, 0x1.33b0a3d70a3d7p+5, 0x1.1d33333333333p+5, 0x1.0c00000000000p+5, 0x1.1d33333333333p+5 }
};
// Rows are CGRect x,y,width,height, in the original 72 x 54 design space.
// In particular, x=-2.95 and rightmost x+width=74.95 are NOT corrected.
static const double I27RESingleSIMRects[4][4] = {
    { -0x1.799999999999ap+1, 0x1.d000000000000p+4, 0x1.999999999999ap+3, 0x1.6000000000000p+4 },
    { 0x1.2c00000000000p+4, 0x1.6000000000000p+4, 0x1.999999999999ap+3, 0x1.d000000000000p+4 },
    { 0x1.439999999999ap+5, 0x1.a000000000000p+3, 0x1.999999999999ap+3, 0x1.3000000000000p+5 },
    { 0x1.f133333333333p+5, 0x1.4000000000000p+2, 0x1.999999999999ap+3, 0x1.7000000000000p+5 }
};
static const double I27RECellularRects[4][4] = {
    { -0x1.799999999999ap+1, 0x1.04ccccccccccdp+4, 0x1.999999999999ap+3, 0x1.14ccccccccccdp+4 },
    { 0x1.2c00000000000p+4, 0x1.7666666666666p+3, 0x1.999999999999ap+3, 0x1.5e66666666666p+4 },
    { 0x1.439999999999ap+5, 0x1.799999999999ap+2, 0x1.999999999999ap+3, 0x1.bb33333333333p+4 },
    { 0x1.f133333333333p+5, 0x1.6666666666666p-1, 0x1.999999999999ap+3, 0x1.0733333333333p+5 }
};
static const double I27RECellular2Rects[4][4] = {
    { -0x1.799999999999ap+1, 0x1.3666666666666p+5, 0x1.999999999999ap+3, 0x1.d666666666666p+3 },
    { 0x1.2c00000000000p+4, 0x1.3666666666666p+5, 0x1.999999999999ap+3, 0x1.d666666666666p+3 },
    { 0x1.439999999999ap+5, 0x1.3666666666666p+5, 0x1.999999999999ap+3, 0x1.d666666666666p+3 },
    { 0x1.f133333333333p+5, 0x1.3666666666666p+5, 0x1.999999999999ap+3, 0x1.d666666666666p+3 }
};

static BOOL I27REValidKind(NSInteger kind) {
    return kind >= I27REGlyphKindWiFi && kind <= I27REGlyphKindCellular2;
}

static CGFloat I27REAlpha(CGFloat alpha) {
    return fmax(fmin(alpha, 1.0), 0.0);
}

static void I27REConfigureContext(CGContextRef context) {
    CGContextSetShouldAntialias(context, true);
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh); // raw 3
}

// arm64 0xba30: draw TWO cubics, reflecting in x=33.5. Retain the original
// subtract-then-add order: (center - x) + center, not a resampled arc.
static void I27REStrokeWiFiArc(CGContextRef context,
                               const double p[9], CGFloat alpha) {
    CGContextSaveGState(context);
    I27REConfigureContext(context);
    CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, I27REAlpha(alpha));
    CGContextSetLineWidth(context, p[8]);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, p[0], p[1]);
    CGContextAddCurveToPoint(context, p[2], p[3], p[4], p[5], p[6], p[7]);
    const double center = 0x1.0c00000000000p+5;
    CGContextAddCurveToPoint(context,
                            (center - p[4]) + center, p[5],
                            (center - p[2]) + center, p[3],
                            (center - p[0]) + center, p[1]);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

// arm64 0xb298...0xb4b0: outer arc, inner arc, then the filled Bezier dot.
static void I27REDrawWiFi(CGContextRef context, NSInteger bars) {
    const CGFloat inactive = 0x1.999999999999ap-2; // 0xf038: 0.4
    I27REStrokeWiFiArc(context, I27REWiFiArcs[0], bars == 3 ? 1.0 : inactive);
    I27REStrokeWiFiArc(context, I27REWiFiArcs[1], bars > 1 ? 1.0 : inactive);
    CGContextSaveGState(context);
    I27REConfigureContext(context);
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, bars == 0 ? inactive : 1.0);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, I27REWiFiDotMove[0], I27REWiFiDotMove[1]);
    for (NSInteger i = 0; i < 4; ++i) {
        const double *p = I27REWiFiDotCurves[i];
        CGContextAddCurveToPoint(context, p[0], p[1], p[2], p[3], p[4], p[5]);
    }
    CGContextClosePath(context);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

// arm64 0xd200. CGPath clamps the radius against the actual rectangle itself.
static void I27REFillSignalRect(CGContextRef context, CGRect rect, CGFloat alpha) {
    if (CGRectIsEmpty(rect)) return;
    const CGFloat radius = 0x1.999999999999ap+2; // 0xf138: 6.4
    CGPathRef path = CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, I27REAlpha(alpha));
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGPathRelease(path);
}

static void I27REDrawCellular(CGContextRef context, NSInteger kind, NSInteger bars) {
    const double (*rects)[4] = kind == I27REGlyphKindSingleSIM
        ? I27RESingleSIMRects : kind == I27REGlyphKindCellular
        ? I27RECellularRects : I27RECellular2Rects;
    const CGFloat inactive = 0x1.0a3d70a3d70a4p-2; // 0xf0e0: 0.26
    for (NSInteger i = 0; i < 4; ++i) {
        const double *r = rects[i];
        I27REFillSignalRect(context, CGRectMake(r[0], r[1], r[2], r[3]),
                           bars > i ? 1.0 : inactive);
    }
}

NSInteger I27REClampBars(NSInteger kind, NSInteger bars) {
    if (!I27REValidKind(kind)) return NSNotFound;
    const NSInteger maximum = kind == I27REGlyphKindWiFi ? 3 : 4;
    return bars < 0 ? 0 : bars > maximum ? maximum : bars;
}

CGSize I27REGlyphSize(NSInteger kind, CGSize nativeBoundsSize) {
    const double epsilon = 0x1.999999999999ap-4; // 0xf020: 0.1
    if (!I27REValidKind(kind) || !isfinite(nativeBoundsSize.width) ||
        !isfinite(nativeBoundsSize.height) || nativeBoundsSize.width <= epsilon ||
        nativeBoundsSize.height <= epsilon) return CGSizeZero;
    const double enlargement = 0x1.147ae147ae148p+0; // 0xf028: 1.08
    const double aspect = kind == I27REGlyphKindWiFi
        ? 0x1.570a3d70a3d71p+0  // 0xf030: 1.34, NOT 67/50 recomputed
        : 0x1.5555555555555p+0; // immediate: binary64 4/3
    CGSize result = CGSizeMake(nativeBoundsSize.width * enlargement,
                               nativeBoundsSize.height * enlargement);
    if (result.width / result.height > aspect) {
        result.width = result.height * aspect;
    } else {
        result.height = result.width / aspect;
    }
    return result;
}

void I27RECenterGlyphView(UIView *host, UIView *glyphView, CGSize size) {
    if (!glyphView) return;
    const CGRect hostBounds = host.bounds;
    glyphView.transform = CGAffineTransformIdentity;
    const double epsilon = 0x1.999999999999ap-4;
    const CGSize target = fmin(size.width, size.height) <= epsilon
        ? hostBounds.size : size;
    glyphView.bounds = (CGRect){ CGPointZero, target };
    glyphView.center = CGPointMake(CGRectGetMidX(hostBounds), CGRectGetMidY(hostBounds));
    [host bringSubviewToFront:glyphView];
}

UIImage *I27REMakeGlyph(NSInteger kind, NSInteger bars, CGSize drawingSize) {
    const double epsilon = 0x1.999999999999ap-4;
    if (!I27REValidKind(kind) || bars < 0 ||
        bars > (kind == I27REGlyphKindWiFi ? 3 : 4) ||
        !isfinite(drawingSize.width) || !isfinite(drawingSize.height) ||
        drawingSize.width <= epsilon || drawingSize.height <= epsilon) return nil;

    CGFloat scale = [UIScreen mainScreen].scale;
    if (!isfinite(scale)) return nil; // safety outside recovered normal domain
    if (scale < 1.0) scale = 2.0; // exactly <1, not <=1 or max(2,scale)
    const BOOL wifi = kind == I27REGlyphKindWiFi;
    const double widthPixels = (drawingSize.width + (wifi ? 1.5 : 2.5)) * scale;
    const double heightPixels = (drawingSize.height + 2.0) * scale;
    // Avoid C llround overflow for pathological input; original FCVTAS saturates.
    if (!isfinite(widthPixels) || !isfinite(heightPixels) ||
        widthPixels >= 0x1p63 || heightPixels >= 0x1p63) return nil;
    const int64_t roundedWidth = llround(widthPixels);
    const int64_t roundedHeight = llround(heightPixels);
    const int64_t pixelWidth = roundedWidth > 1 ? roundedWidth : 1;
    const int64_t pixelHeight = roundedHeight > 1 ? roundedHeight : 1;

    // Original caches remember only the most recent physical pixel width/height
    // per family and bars. Deliberately do NOT add raw point size or scale keys.
    static UIImage *I27REImages[4][5];
    static int64_t I27REPixelWidths[4][5];
    static int64_t I27REPixelHeights[4][5];
    UIImage *cached = I27REImages[kind][bars];
    if (cached && I27REPixelWidths[kind][bars] == pixelWidth &&
        I27REPixelHeights[kind][bars] == pixelHeight) return cached;

    const CGSize imageSize = CGSizeMake((double)pixelWidth / scale,
                                       (double)pixelHeight / scale);
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return nil;
    }
    I27REConfigureContext(context);
    CGContextTranslateCTM(context, wifi ? 0.75 : 1.25, 1.0);
    CGContextScaleCTM(context, drawingSize.width / (wifi ? 67.0 : 72.0),
                     drawingSize.height / (wifi ? 50.0 : 54.0));
    if (wifi) I27REDrawWiFi(context, bars);
    else I27REDrawCellular(context, kind, bars);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!image) return nil;
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    I27REImages[kind][bars] = image;
    I27REPixelWidths[kind][bars] = pixelWidth;
    I27REPixelHeights[kind][bars] = pixelHeight;
    return image;
}
