ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PalmGuard
PalmGuard_FILES = Tweak.xm
PalmGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
PalmGuard_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
