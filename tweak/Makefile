TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NDADriveLauncher NDACarPlayDiag
NDADriveLauncher_FILES = Tweak.x
NDADriveLauncher_FRAMEWORKS = UIKit AVFoundation
NDADriveLauncher_CFLAGS = -fobjc-arc -Wno-error

# Chan doan CarPlay (chi doc): nap vao airplayd / carkitd / mediaserverd / audiomxd
NDACarPlayDiag_FILES = CarPlayDiag.x
NDACarPlayDiag_FRAMEWORKS = Foundation CoreFoundation AudioToolbox
NDACarPlayDiag_CFLAGS = -fobjc-arc -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
