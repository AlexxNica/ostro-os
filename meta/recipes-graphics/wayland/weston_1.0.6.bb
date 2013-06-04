SUMMARY = "Weston, a Wayland compositor"
DESCRIPTION = "Weston is the reference implementation of a Wayland compositor"
HOMEPAGE = "http://wayland.freedesktop.org"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://COPYING;md5=275efac2559a224527bd4fd593d38466 \
                    file://src/compositor.c;endline=23;md5=aa98a8db03480fe7d500d0b1f4b8850c"

SRC_URI = "http://wayland.freedesktop.org/releases/${BPN}-${PV}.tar.xz \
           file://install-examples.patch \
           file://weston.png \
           file://weston.desktop"
SRC_URI[md5sum] = "63202129d66d5514e572814da5dfa1f7"
SRC_URI[sha256sum] = "c833bc4dc8667561d2639b57220541531c039aa9332ce2a7022a3c466eb894f1"

inherit autotools pkgconfig useradd

DEPENDS = "libxkbcommon gdk-pixbuf pixman cairo glib-2.0 mtdev jpeg"
DEPENDS += "wayland mesa virtual/egl"

EXTRA_OECONF = "--disable-android-compositor \
                --enable-setuid-install \
                --disable-tablet-shell \
                --disable-xwayland \
                --enable-simple-clients \
                --enable-clients \
                --disable-simple-egl-clients"

PACKAGECONFIG ??= "${@base_contains('DISTRO_FEATURES', 'wayland', 'kms wayland', '', d)} \
                   ${@base_contains('DISTRO_FEATURES', 'x11', 'x11', '', d)} \
                   ${@base_contains('DISTRO_FEATURES', 'opengles2', 'gles', '', d)} \
                  "
#
# Compositor choices
#
# Weston on KMS
PACKAGECONFIG[kms] = "--enable-drm-compositor --enable-weston-launch,--disable-drm-compositor --disable-weston-launch,drm udev mesa libpam"
# Weston on Wayland (nested Weston)
PACKAGECONFIG[wayland] = "--enable-wayland-compositor,--disable-wayland-compositor,mesa"
# Weston on X11
PACKAGECONFIG[x11] = "--enable-x11-compositor,--disable-x11-compositor,virtual/libx11 libxcb libxcb libxcursor cairo"

# Use cairo-gl or cairo-glesv2
PACKAGECONFIG[gles] = "--with-cairo-glesv2,,virtual/libgles2"

do_install_append() {
	# Weston doesn't need the .la files to load modules, so wipe them
	rm -f ${D}/${libdir}/weston/*.la

	for feature in ${DISTRO_FEATURES}; do
		# If X11, ship a desktop file to launch it
		if [ "$feature" = "x11" ]; then
			install -d ${D}${datadir}/applications
			install ${WORKDIR}/weston.desktop ${D}${datadir}/applications

			install -d ${D}${datadir}/icons/hicolor/48x48/apps
			install ${WORKDIR}/weston.png ${D}${datadir}/icons/hicolor/48x48/apps
                fi
	done
}

PACKAGES += "${PN}-examples"

FILES_${PN} = "${bindir}/weston* ${bindir}/wcap-decode ${libexecdir} ${datadir}"
FILES_${PN}-examples = "${bindir}/*"

RDEPENDS_${PN} += "xkeyboard-config"
RRECOMMENDS_${PN} = "liberation-fonts"

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM_${PN} = "--system weston-launch"
