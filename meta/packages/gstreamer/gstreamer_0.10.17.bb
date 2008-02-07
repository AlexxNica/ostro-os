DESCRIPTION = "GStreamer is a multimedia framework for encoding and decoding video and sound. \
It supports a wide range of formats including mp3, ogg, avi, mpeg and quicktime."
SECTION = "multimedia"
PRIORITY = "optional"
LICENSE = "LGPL"
HOMEPAGE = "http://www.gstreamer.net/"
DEPENDS = "glib-2.0 gettext-native libxml2 bison-native flex-native"
PR = "r4"

inherit autotools pkgconfig

SRC_URI = "http://gstreamer.freedesktop.org/src/gstreamer/gstreamer-${PV}.tar.bz2 \
           file://gst-inspect-check-error.patch;patch=1 \
        file://gstreamer-omit-debug-directories.patch;patch=1"
#           file://gstregistrybinary.c \
#           file://gstregistrybinary.h \
#           file://gstreamer-0.9-binary-registry.patch;patch=1"
EXTRA_OECONF = "--disable-docs-build --disable-dependency-tracking --with-check=no --disable-examples --disable-tests --disable-valgrind --disable-debug"

#do_compile_prepend () {
#	mv ${WORKDIR}/gstregistrybinary.[ch] ${S}/gst/
#}

PARALLEL_MAKE = ""

do_stage() {
	autotools_stage_all
}

FILES_${PN} += " ${libdir}/gstreamer-0.10/*.so"
FILES_${PN}-dev += " ${libdir}/gstreamer-0.10/*.la ${libdir}/gstreamer-0.10/*.a"
FILES_${PN}-dbg += " ${libdir}/gstreamer-0.10/.debug/"
