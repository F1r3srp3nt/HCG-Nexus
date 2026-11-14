# HCG Nexus — Theos build.
#
# Confirmed target (docs/ENVIRONMENT.md): iPhone 13 Pro (A15, arm64e),
# iOS 16.5, Dopamine rootless (/var/jb), ElleKit, Sileo. HCG_ENV therefore
# defaults to rootless; HCG_ENV=rootful remains for other devices.
#
#   gmake package FINALPACKAGE=1                # rootless → packages/rootless/
#   gmake package FINALPACKAGE=1 HCG_ENV=rootful # rootful  → packages/rootful/ (unverified)
#   scripts/build-jailbreak-deb.sh               # same, with toolchain preflight + verification
#
# The arm64e slice MUST be built with Apple's clang (Xcode 12 or later): the
# open-source Linux toolchains emit the pre-iOS-14 arm64e ABI, which
# scripts/inspect-package.py --require-new-arm64e-abi rejects. Use the
# "Build package" GitHub Actions workflow (macOS runner) or a Mac.
#
# Deliberately NOT set: INSTALL_TARGET_PROCESSES. `make install` therefore
# never resprings or kills anything; respring yourself when you choose to.

HCG_ENV ?= rootless

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

# Theos needs GNU Make 4 or newer (macOS ships 3.81: `brew install make`, then gmake).
ifeq ($(filter 4.% 5.% 6.% 7.%,$(MAKE_VERSION)),)
  $(error GNU Make 4 or newer is required (this is $(MAKE_VERSION)). On macOS: brew install make, then run gmake)
endif

# Build identity, shown in Settings › HCG Nexus and in diagnostics. Override
# with HCG_BUILD_ID=… when building from a tree without git metadata.
ifeq ($(origin HCG_BUILD_ID),undefined)
  HCG_BUILD_ID := $(or $(shell git -C "$(CURDIR)" rev-parse --short=10 HEAD 2>/dev/null),nogit)$(if $(shell git -C "$(CURDIR)" status --porcelain --untracked-files=no 2>/dev/null),-dirty)
endif
HCG_BUILD_CONFIG := $(HCG_ENV)-$(if $(FINALPACKAGE),release,debug)

# Separate outputs per configuration so a rootless build can never pick up
# rootful objects (or the reverse): .theos/obj/<env>…, .theos/_<env>,
# packages/<env>/. Exported so the Prefs subproject uses the same layout and
# the same HCG_ENV/build identity.
THEOS_OBJ_DIR_NAME = obj/$(HCG_ENV)$(_THEOS_OBJ_DIR_EXTENSION)
THEOS_STAGING_DIR_NAME = _$(HCG_ENV)
THEOS_PACKAGE_DIR_NAME = packages/$(HCG_ENV)
export HCG_ENV HCG_BUILD_ID HCG_BUILD_CONFIG THEOS_OBJ_DIR_NAME THEOS_STAGING_DIR_NAME THEOS_PACKAGE_DIR_NAME

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
	-DHCG_PACKAGE_SCHEME=\"$(HCG_ENV)\" -DHCG_BUILD_ID=\"$(HCG_BUILD_ID)\" -DHCG_BUILD_CONFIG=\"$(HCG_BUILD_CONFIG)\"
HCGNexus_FRAMEWORKS = UIKit QuartzCore CoreFoundation
# No %hook is used, so generate runtime-only Logos code: the dylib does not
# link CydiaSubstrate and works with whichever injector loads it.
HCGNexus_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
