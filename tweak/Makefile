TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NDADriveLauncher
NDADriveLauncher_FILES = Tweak.x
NDADriveLauncher_FRAMEWORKS = UIKit AVFoundation
NDADriveLauncher_CFLAGS = -fobjc-arc -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
