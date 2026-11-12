# HCG Nexus — Theos build.
#
# The package layout depends on your jailbreak, so it must be chosen
# explicitly once the environment is confirmed (see docs/ENVIRONMENT.md):
#
#   make package HCG_ENV=rootless   # e.g. Dopamine / palera1n rootless (/var/jb)
#   make package HCG_ENV=rootful    # e.g. checkra1n / unc0ver / palera1n rootful (/)
#
# Neither choice has been verified on a physical device yet.
#
# Deliberately NOT set: INSTALL_TARGET_PROCESSES. `make install` therefore
# never resprings or kills anything; respring yourself when you choose to.

HCG_ENV ?=

_HCG_ONLY_CLEAN := $(if $(filter-out clean clean-packages distclean,$(MAKECMDGOALS)),,$(if $(MAKECMDGOALS),1,))

ifeq ($(HCG_ENV),rootless)
  THEOS_PACKAGE_SCHEME = rootless
  TARGET := iphone:clang:16.5:15.0
else ifeq ($(HCG_ENV),rootful)
  TARGET := iphone:clang:14.5:14.0
else ifeq ($(HCG_ENV),roothide)
  $(error roothide needs the roothide fork of Theos and has not been set up for this project yet; see docs/ENVIRONMENT.md)
else ifeq ($(_HCG_ONLY_CLEAN),)
  $(error Set HCG_ENV=rootless or HCG_ENV=rootful after confirming your jailbreak layout (see docs/ENVIRONMENT.md))
endif

# arm64e built with an old-ABI toolchain (e.g. clang 11 on Linux) is flagged by
# scripts/inspect-package.py; override with HCG_ARCHS once the device is known.
HCG_ARCHS ?= arm64 arm64e
ARCHS = $(HCG_ARCHS)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HCGNexus

HCGNexus_FILES = Tweak/Tweak.x \
	$(wildcard Sources/Core/*.m) \
	$(wildcard Sources/Panel/*.m) \
	$(wildcard Sources/Platform/SpringBoard/*.m)
HCGNexus_CFLAGS = -fobjc-arc -Wall -Werror \
	-ISources/Core -ISources/Panel -ISources/Platform/SpringBoard \
	-DHCG_PACKAGE_SCHEME=\"$(HCG_ENV)\"
HCGNexus_FRAMEWORKS = UIKit QuartzCore CoreFoundation
# No %hook is used, so generate runtime-only Logos code: the dylib does not
# link CydiaSubstrate and works with whichever injector loads it.
HCGNexus_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
