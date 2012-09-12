require libx11.inc

DESCRIPTION += " Support for XCMS and XLOCALE is disabled in \
this version."

PR = "${INC_PR}.2"

SRC_URI += "file://x11_disable_makekeys.patch \
            file://X18NCMSstubs.diff \
            file://keysymdef_include.patch \
            file://fix-disable-xlocale.diff \
            file://fix-utf8-wrong-define.patch \
           "

RPROVIDES_${PN}-dev = "libx11-dev"
RPROVIDES_${PN}-locale = "libx11-locale"

SRC_URI[md5sum] = "78b4b3bab4acbdf0abcfca30a8c70cc6"
SRC_URI[sha256sum] = "c382efd7e92bfc3cef39a4b7f1ecf2744ba4414a705e3bc1e697f75502bd4d86"

DEPENDS += "libxcb bigreqsproto xproto xextproto xtrans libxau xcmiscproto \
            libxdmcp xf86bigfontproto kbproto inputproto xproto-native"

FILESDIR = "${@os.path.dirname(d.getVar('FILE', True))}/libx11"

EXTRA_OECONF += "--disable-xlocale"
CFLAGS += "-D_GNU_SOURCE"

