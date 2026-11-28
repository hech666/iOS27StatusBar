include iOS27StatusBarBuild.mk
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iOS27StatusBar
iOS27StatusBar_FILES = $(wildcard Sources/*.mm)
iOS27StatusBar_CFLAGS = -fobjc-arc -fobjc-exceptions -fblocks -I$(THEOS_PROJECT_DIR)/Headers
iOS27StatusBar_CCFLAGS = -std=gnu++17 -fcxx-exceptions -fexceptions -fobjc-arc-exceptions
iOS27StatusBar_FRAMEWORKS = Foundation UIKit QuartzCore CoreGraphics
iOS27StatusBar_LIBRARIES = substrate roothide

include $(THEOS_MAKE_PATH)/tweak.mk
