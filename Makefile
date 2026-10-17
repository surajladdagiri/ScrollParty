TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IGCoupleRot

IGCoupleRot_FILES = Tweak.x
IGCoupleRot_CFLAGS = -fobjc-arc
IGCoupleRot_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk
