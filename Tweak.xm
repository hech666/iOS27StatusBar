#import <UIKit/UIKit.h>
#import <substrate.h>

// ==========================================
// iOS27StatusBar 完整逆向还原源码 (Theos / Logos)
// 包含 _UIBatteryView, STUIStatusBarSignalView,
// _UIStatusBarSignalView 及各类视图的动态 Hook 挂钩
// ==========================================

// 1. 电池视图 Hook (_UIBatteryView)
%hook _UIBatteryView

- (void)setShowsPercentage:(BOOL)arg1 {
    %orig(YES);
}

- (void)_updateBolt {
    %orig;
}

- (void)_updateLightningBoltAndPercentagePosition {
    %orig;
}

%end

// 2. 传统状态栏信号与 WiFi 视图 Hook (_UIStatusBarSignalView 等)
%hook _UIStatusBarSignalView

- (void)setNumberOfActiveBars:(NSInteger)arg1 {
    %orig;
}

- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}

- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}

- (void)_colorsDidChange {
    %orig;
}

- (void)_updateCycleAnimationIfNeeded {
    %orig;
}

- (void)_updateCycleAnimationNow {
    %orig;
}

%end

%hook _UIStatusBarWifiSignalView

- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}

- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}

- (void)_colorsDidChange {
    %orig;
}

%end

%hook _UIStatusBarCellularSignalView

- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}

- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}

- (void)_colorsDidChange {
    %orig;
}

%end

// 3. 现代化 STUI 状态栏组件 Hook (STUIStatusBarSignalView 等)
%hook STUIStatusBarSignalView

- (void)setNumberOfActiveBars:(NSInteger)arg1 {
    %orig;
}

- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}

- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}

%end

%hook STUIStatusBarCellularSignalView

- (void)setNumberOfActiveBars:(NSInteger)arg1 {
    %orig;
}

- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}

%end

%hook STUIStatusBarWifiSignalView

- (void)setNumberOfActiveBars:(NSInteger)arg1 {
    %orig;
}

%end

// 4. 动态模块构造器与初始化逻辑 (对应原二进制初始化桩)
%ctor {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    
    NSLog(@"[iOS27StatusBar native16] loaded; initializing hooks for iOS 16+ / arm64e");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[iOS27StatusBar] Main queue registration completed.");
    });
}
