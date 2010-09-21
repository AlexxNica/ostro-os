HOMEPAGE = "http://gitorious.org/opensuse/zypper"
DESCRIPTION  = "The ZYpp Linux Software management framework"

LICENSE  = "GPLv2+"
LIC_FILES_CHKSUM = "file://COPYING;md5=3201406e350b39e05a82e28b5020f413"

DEPENDS  = "libzypp augeas"
RRECOMMENDS = "procps"
PR = "r1"

inherit cmake

SRC_URI = "git://gitorious.org/opensuse/zypper.git;protocol=git \
           file://cmake.patch \
          "
S = "${WORKDIR}/git"

PV = "1.4.7-git${SRCPV}"
