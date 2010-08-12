DESCRIPTION = "Pseudo gives fake root capabilities to a normal user"
HOMEPAGE = "http://wiki.github.com/wrpseudo/pseudo/"
LIC_FILES_CHKSUM = "file://COPYING;md5=243b725d71bb5df4a1e5920b344b86ad"
SECTION = "base"
LICENSE = "LGPL2.1"
DEPENDS = "sqlite3"

PV = "0.0+git${SRCPV}"
PR = "r13"

SRC_URI = "git://github.com/wrpseudo/pseudo.git;protocol=git \
           file://static_sqlite.patch"

FILES_${PN} = "${libdir}/libpseudo.so ${bindir}/* ${localstatedir}/pseudo"
PROVIDES += "virtual/fakeroot"

S = "${WORKDIR}/git"

inherit siteinfo

do_configure () {
	:
}

do_compile () {
	if [ "${SITEINFO_BITS}" == "64" -a -e "/usr/include/gnu/stubs-32.h" -a "${PN}" == "pseudo-native" ]; then
		# We need the 32-bit libpseudo on a 64-bit machine...
		./configure --prefix=${prefix} --with-sqlite=${STAGING_DIR_TARGET}${exec_prefix} --bits=32
		oe_runmake 'CFLAGS=-m32' 'LIB=lib/pseudo/lib' libpseudo
		# prevent it from removing the lib, but remove everything else
		make 'LIB=foo' distclean 
	fi
	${S}/configure --prefix=${prefix} --with-sqlite=${STAGING_DIR_TARGET}${exec_prefix} --bits=${SITEINFO_BITS}
	oe_runmake 'LIB=lib/pseudo/lib$(MARK64)'
}

do_install () {
	oe_runmake 'DESTDIR=${D}' 'LIB=lib/pseudo/lib$(MARK64)' install
	if [ "${SITEINFO_BITS}" == "64" -a -e "/usr/include/gnu/stubs-32.h" -a "${PN}" == "pseudo-native" ]; then
		mkdir -p ${D}${prefix}/lib/pseudo/lib
		cp lib/pseudo/lib/libpseudo.so ${D}${prefix}/lib/pseudo/lib/.
	fi
}

BBCLASSEXTEND = "native"


