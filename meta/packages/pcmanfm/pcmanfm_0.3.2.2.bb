LICENSE = "GPL"
DESCRIPTION = "procfs tools"
SECTION = "x11"
PRIORITY = "optional"
DEPENDS = "gtk+ startup-notification"
DEPENDS_append_poky = " libowl"

PR = "r5"

COMPATIBLE_HOST = '(x86_64|i.86.*|arm.*)-(linux|freebsd.*)'

SRC_URI = "${SOURCEFORGE_MIRROR}/pcmanfm/pcmanfm-${PV}.tar.gz \
	   file://gnome-fs-directory.png \
	   file://gnome-fs-regular.png \
	   file://gnome-mime-text-plain.png \
	   file://emblem-symbolic-link.png \
	   file://desktop.patch;patch=1 \
	   file://no-warnings.patch;patch=1"

SRC_URI_append_poky = " file://owl-window-menu.patch;patch=1"

EXTRA_OECONF = "--enable-inotify --disable-hal"

inherit autotools pkgconfig

do_install_append () {
	install -d ${D}/${datadir}
	install -d ${D}/${datadir}/pixmaps/

	install -m 0644 ${WORKDIR}/*.png ${D}/${datadir}/pixmaps
}

FILES_${PN} += "${datadir}/pixmaps/*.png"
