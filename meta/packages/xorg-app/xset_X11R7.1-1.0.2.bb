require xorg-app-common.inc

DESCRIPTION = "user preference utility for X"
LICENSE = "MIT"

PR="r1"

# Remove libraries that are not hard depends
DEPENDS += " libxext virtual/libx11 libxxf86misc libxfontcache libxmuu"

SRC_URI += "file://disable-xkb.patch;patch=1"

CFLAGS += "-D_GNU_SOURCE"
EXTRA_OECONF = "--disable-xkb"

