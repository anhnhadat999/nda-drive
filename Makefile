TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME ?= rootless
export THEOS_PACKAGE_SCHEME

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += app tweak

include $(THEOS_MAKE_PATH)/aggregate.mk
