TARGET := iphone:clang:latest:15.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PoAo
PoAo_FILES = main.m PAAppDelegate.m PARootViewController.m PAEngine.m PASynth.c
PoAo_FRAMEWORKS = UIKit AVFoundation CoreLocation
PoAo_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk
