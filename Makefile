TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard Preferences
ARCHS = arm64 arm64e
SYSROOT = $(THEOS)/sdks/iPhoneOS14.2.sdk
DEBUG = 1
FINALPACKAGE = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PreferenceLocalizer

PreferenceLocalizer_FILES = Tweak.xm
PreferenceLocalizer_CFLAGS = -fobjc-arc -Wdeprecated-declarations -Wno-deprecated-declarations
PreferenceLocalizer_PRIVATE_FRAMEWORKS = Preferences BackBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
