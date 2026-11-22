include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iOS27StatusBar

iOS27StatusBar_FILES = Tweak.xm
iOS27StatusBar_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
