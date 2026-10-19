TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScrollParty

ScrollParty_FILES = Tweak.x
ScrollParty_CFLAGS = -fobjc-arc
ScrollParty_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk
