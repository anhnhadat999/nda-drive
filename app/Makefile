TARGET := iphone:clang:latest:15.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = NDADrive
NDADrive_FILES = main.m PAAppDelegate.m PARootViewController.m PACarsViewController.m PASettingsViewController.m PACalibrationViewController.m PALearnViewController.m PATripsViewController.m PAUpdater.m PALog.m PADiag.m PAEngine.m PAMotion.m PASynth.c PAFusion.c PALearn.c
NDADrive_FRAMEWORKS = UIKit AVFoundation CoreLocation CoreMotion
NDADrive_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk
