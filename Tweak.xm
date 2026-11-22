#include <UIKit/UIKit.h>
#include <substrate.h>

@interface _UIBatteryView : UIView
- (void)setShowsPercentage:(BOOL)arg1;
- (void)_updateBolt;
- (void)_updateLightningBoltAndPercentagePosition;
@end

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

%hook STUIStatusBarSignalView
- (void)setNumberOfActiveBars:(NSInteger)arg1 {
    %orig;
}
- (void)setActiveColor:(UIColor *)arg1 {
    %orig;
}
%end

%hook STUIStatusBarCellularSignalView
- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}
%end

%hook STUIStatusBarWifiSignalView
- (void)applyStyleAttributes:(id)arg1 {
    %orig;
}
%end

%ctor {
    NSLog(@"[iOS27StatusBar] Initialized successfully on iOS 16+ / arm64e");
}
