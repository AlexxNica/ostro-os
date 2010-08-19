inherit package

IMAGE_PKGTYPE ?= "ipk"

IPKGCONF_TARGET = "${WORKDIR}/opkg.conf"
IPKGCONF_SDK =  "${WORKDIR}/opkg-sdk.conf"

PKGWRITEDIRIPK = "${WORKDIR}/deploy-ipks"

python package_ipk_fn () {
	bb.data.setVar('PKGFN', bb.data.getVar('PKG',d), d)
}

python package_ipk_install () {
	pkg = bb.data.getVar('PKG', d, 1)
	pkgfn = bb.data.getVar('PKGFN', d, 1)
	rootfs = bb.data.getVar('IMAGE_ROOTFS', d, 1)
	ipkdir = bb.data.getVar('DEPLOY_DIR_IPK', d, 1)
	stagingdir = bb.data.getVar('STAGING_DIR', d, 1)
	tmpdir = bb.data.getVar('TMPDIR', d, 1)

	if None in (pkg,pkgfn,rootfs):
		raise bb.build.FuncFailed("missing variables (one or more of PKG, PKGFN, IMAGEROOTFS)")
	try:
		bb.mkdirhier(rootfs)
		os.chdir(rootfs)
	except OSError:
		import sys
		(type, value, traceback) = sys.exc_info()
		print value
		raise bb.build.FuncFailed

	# Generate ipk.conf if it or the stamp doesnt exist
	conffile = os.path.join(stagingdir,"ipkg.conf")
	if not os.access(conffile, os.R_OK):
		ipkg_archs = bb.data.getVar('PACKAGE_ARCHS',d)
		if ipkg_archs is None:
			bb.error("PACKAGE_ARCHS missing")
			raise FuncFailed
		ipkg_archs = ipkg_archs.split()
		arch_priority = 1

		f = open(conffile,"w")
		for arch in ipkg_archs:
			f.write("arch %s %s\n" % ( arch, arch_priority ))
			arch_priority += 1
		f.write("src local file:%s" % ipkdir)
		f.close()


	if (not os.access(os.path.join(ipkdir,"Packages"), os.R_OK) or
		not os.access(os.path.join(tmpdir, "stamps", "IPK_PACKAGE_INDEX_CLEAN"),os.R_OK):
		ret = os.system('opkg-make-index -p %s %s ' % (os.path.join(ipkdir, "Packages"), ipkdir))
		if (ret != 0 ):
			raise bb.build.FuncFailed
		f = open(os.path.join(tmpdir, "stamps", "IPK_PACKAGE_INDEX_CLEAN"),"w")
		f.close()

	ret = os.system('opkg-cl  -o %s -f %s update' % (rootfs, conffile))
	ret = os.system('opkg-cl  -o %s -f %s install %s' % (rootfs, conffile, pkgfn))
	if (ret != 0 ):
		raise bb.build.FuncFailed
}

#
# Update the Packages index files in ${DEPLOY_DIR_IPK}
#
package_update_index_ipk () {
	set -x

	ipkgarchs="${PACKAGE_ARCHS}"

	if [ ! -z "${DEPLOY_KEEP_PACKAGES}" ]; then
		return
	fi

	packagedirs="${DEPLOY_DIR_IPK}"
	for arch in $ipkgarchs; do
		sdkarch=`echo $arch | sed -e 's/${HOST_ARCH}/${SDK_ARCH}/'`
		packagedirs="$packagedirs ${DEPLOY_DIR_IPK}/$arch ${DEPLOY_DIR_IPK}/$sdkarch-nativesdk"
	done

	packagedirs="$packagedirs ${DEPLOY_DIR_IPK}/${SDK_ARCH}-${TARGET_ARCH}-canadian"

	for pkgdir in $packagedirs; do
		if [ -e $pkgdir/ ]; then
			touch $pkgdir/Packages
			flock $pkgdir/Packages.flock -c "opkg-make-index -r $pkgdir/Packages -p $pkgdir/Packages -l $pkgdir/Packages.filelist -m $pkgdir/"
		fi
	done
}

#
# Generate an ipkg conf file ${IPKGCONF_TARGET} suitable for use against 
# the target system and an ipkg conf file ${IPKGCONF_SDK} suitable for 
# use against the host system in sdk builds
#
package_generate_ipkg_conf () {
	package_generate_archlist
	echo "src oe file:${DEPLOY_DIR_IPK}" >> ${IPKGCONF_TARGET}
	echo "src oe file:${DEPLOY_DIR_IPK}" >> ${IPKGCONF_SDK}
	ipkgarchs="${PACKAGE_ARCHS}"
	for arch in $ipkgarchs; do
		if [ -e ${DEPLOY_DIR_IPK}/$arch/Packages ] ; then
		        echo "src oe-$arch file:${DEPLOY_DIR_IPK}/$arch" >> ${IPKGCONF_TARGET}
		fi
		sdkarch=`echo $arch | sed -e 's/${HOST_ARCH}/${SDK_ARCH}/'`
		extension=-nativesdk
		if [ "$sdkarch" = "all" -o "$sdkarch" = "any" -o "$sdkarch" = "noarch" ]; then
		    extension=""
		fi
		if [ -e ${DEPLOY_DIR_IPK}/$sdkarch$extension/Packages ] ; then
		        echo "src oe-$sdkarch$extension file:${DEPLOY_DIR_IPK}/$sdkarch$extension" >> ${IPKGCONF_SDK}
		fi
	done
	if [ -e ${DEPLOY_DIR_IPK}/${SDK_ARCH}-${TARGET_ARCH}-canadian/Packages ] ; then
	        echo "src oe-${SDK_ARCH}-${TARGET_ARCH}-canadian file:${DEPLOY_DIR_IPK}/${SDK_ARCH}-${TARGET_ARCH}-canadian" >> ${IPKGCONF_SDK}
	fi
}

package_generate_archlist () {
	ipkgarchs="${PACKAGE_ARCHS}"
	priority=1
	for arch in $ipkgarchs; do
		sdkarch=`echo $arch | sed -e 's/${HOST_ARCH}/${SDK_ARCH}/'`
		echo "arch $arch $priority" >> ${IPKGCONF_TARGET}
		extension=-nativesdk
		if [ "$sdkarch" = "all" -o "$sdkarch" = "any" -o "$sdkarch" = "noarch" ]; then
		    extension=""
		fi
		echo "arch $sdkarch$extension $priority" >> ${IPKGCONF_SDK}
		priority=$(expr $priority + 5)
	done
	echo "arch ${SDK_ARCH}-${TARGET_ARCH}-canadian $priority" >> ${IPKGCONF_SDK}
}

python do_package_ipk () {
	import re, copy

	workdir = bb.data.getVar('WORKDIR', d, True)
	outdir = bb.data.getVar('PKGWRITEDIRIPK', d, True)
	dvar = bb.data.getVar('D', d, True)
	tmpdir = bb.data.getVar('TMPDIR', d, True)
	pkgdest = bb.data.getVar('PKGDEST', d, True)
	if not workdir or not outdir or not dvar or not tmpdir:
		bb.error("Variables incorrectly set, unable to package")
		return

	if not os.path.exists(dvar):
		bb.debug(1, "Nothing installed, nothing to do")
		return

	packages = bb.data.getVar('PACKAGES', d, True)
	if not packages or packages == '':
		bb.debug(1, "No packages; nothing to do")
		return

	# We're about to add new packages so the index needs to be checked
        # so remove the appropriate stamp file.
	if os.access(os.path.join(tmpdir, "stamps", "IPK_PACKAGE_INDEX_CLEAN"), os.R_OK):
		os.unlink(os.path.join(tmpdir, "stamps", "IPK_PACKAGE_INDEX_CLEAN"))

	for pkg in packages.split():
		localdata = bb.data.createCopy(d)
		root = "%s/%s" % (pkgdest, pkg)

		lf = bb.utils.lockfile(root + ".lock")

		bb.data.setVar('ROOT', '', localdata)
		bb.data.setVar('ROOT_%s' % pkg, root, localdata)
		pkgname = bb.data.getVar('PKG_%s' % pkg, localdata, 1)
		if not pkgname:
			pkgname = pkg
		bb.data.setVar('PKG', pkgname, localdata)

		bb.data.setVar('OVERRIDES', pkg, localdata)

		bb.data.update_data(localdata)
		basedir = os.path.join(os.path.dirname(root))
		arch = bb.data.getVar('PACKAGE_ARCH', localdata, 1)
		pkgoutdir = "%s/%s" % (outdir, arch)
		bb.mkdirhier(pkgoutdir)
		os.chdir(root)
		from glob import glob
		g = glob('*')
		try:
			del g[g.index('CONTROL')]
			del g[g.index('./CONTROL')]
		except ValueError:
			pass
		if not g and bb.data.getVar('ALLOW_EMPTY', localdata) != "1":
			bb.note("Not creating empty archive for %s-%s-%s" % (pkg, bb.data.getVar('PV', localdata, 1), bb.data.getVar('PR', localdata, 1)))
			bb.utils.unlockfile(lf)
			continue

		controldir = os.path.join(root, 'CONTROL')
		bb.mkdirhier(controldir)
		try:
			ctrlfile = file(os.path.join(controldir, 'control'), 'w')
		except OSError:
			bb.utils.unlockfile(lf)
			raise bb.build.FuncFailed("unable to open control file for writing.")

		fields = []
		pe = bb.data.getVar('PE', d, 1)
		if pe and int(pe) > 0:
			fields.append(["Version: %s:%s-%s\n", ['PE', 'PV', 'PR']])
		else:
			fields.append(["Version: %s-%s\n", ['PV', 'PR']])
		fields.append(["Description: %s\n", ['DESCRIPTION']])
		fields.append(["Section: %s\n", ['SECTION']])
		fields.append(["Priority: %s\n", ['PRIORITY']])
		fields.append(["Maintainer: %s\n", ['MAINTAINER']])
		fields.append(["Architecture: %s\n", ['PACKAGE_ARCH']])
		fields.append(["OE: %s\n", ['PN']])
		fields.append(["Homepage: %s\n", ['HOMEPAGE']])

		def pullData(l, d):
			l2 = []
			for i in l:
				l2.append(bb.data.getVar(i, d, 1))
			return l2

		ctrlfile.write("Package: %s\n" % pkgname)
		# check for required fields
		try:
			for (c, fs) in fields:
				for f in fs:
					if bb.data.getVar(f, localdata) is None:
						raise KeyError(f)
				ctrlfile.write(c % tuple(pullData(fs, localdata)))
		except KeyError:
			import sys
			(type, value, traceback) = sys.exc_info()
			ctrlfile.close()
			bb.utils.unlockfile(lf)
			raise bb.build.FuncFailed("Missing field for ipk generation: %s" % value)
		# more fields

		bb.build.exec_func("mapping_rename_hook", localdata)

		rdepends = bb.utils.explode_dep_versions(bb.data.getVar("RDEPENDS", localdata, 1) or "")
		rrecommends = bb.utils.explode_dep_versions(bb.data.getVar("RRECOMMENDS", localdata, 1) or "")
		rsuggests = bb.utils.explode_dep_versions(bb.data.getVar("RSUGGESTS", localdata, 1) or "")
		rprovides = bb.utils.explode_dep_versions(bb.data.getVar("RPROVIDES", localdata, 1) or "")
		rreplaces = bb.utils.explode_dep_versions(bb.data.getVar("RREPLACES", localdata, 1) or "")
		rconflicts = bb.utils.explode_dep_versions(bb.data.getVar("RCONFLICTS", localdata, 1) or "")

		if rdepends:
			ctrlfile.write("Depends: %s\n" % bb.utils.join_deps(rdepends))
		if rsuggests:
			ctrlfile.write("Suggests: %s\n" % bb.utils.join_deps(rsuggests))
		if rrecommends:
			ctrlfile.write("Recommends: %s\n" % bb.utils.join_deps(rrecommends))
		if rprovides:
			ctrlfile.write("Provides: %s\n" % bb.utils.join_deps(rprovides))
		if rreplaces:
			ctrlfile.write("Replaces: %s\n" % bb.utils.join_deps(rreplaces))
		if rconflicts:
			ctrlfile.write("Conflicts: %s\n" % bb.utils.join_deps(rconflicts))
		src_uri = bb.data.getVar("SRC_URI", localdata, 1)
		if src_uri:
			src_uri = re.sub("\s+", " ", src_uri)
			ctrlfile.write("Source: %s\n" % " ".join(src_uri.split()))
		ctrlfile.close()

		for script in ["preinst", "postinst", "prerm", "postrm"]:
			scriptvar = bb.data.getVar('pkg_%s' % script, localdata, 1)
			if not scriptvar:
				continue
			try:
				scriptfile = file(os.path.join(controldir, script), 'w')
			except OSError:
				bb.utils.unlockfile(lf)
				raise bb.build.FuncFailed("unable to open %s script file for writing." % script)
			scriptfile.write(scriptvar)
			scriptfile.close()
			os.chmod(os.path.join(controldir, script), 0755)

		conffiles_str = bb.data.getVar("CONFFILES", localdata, 1)
		if conffiles_str:
			try:
				conffiles = file(os.path.join(controldir, 'conffiles'), 'w')
			except OSError:
				bb.utils.unlockfile(lf)
				raise bb.build.FuncFailed("unable to open conffiles for writing.")
			for f in conffiles_str.split():
				conffiles.write('%s\n' % f)
			conffiles.close()

		os.chdir(basedir)
		ret = os.system("PATH=\"%s\" %s %s %s" % (bb.data.getVar("PATH", localdata, 1), 
                                                          bb.data.getVar("OPKGBUILDCMD",d,1), pkg, pkgoutdir))
		if ret != 0:
			bb.utils.unlockfile(lf)
			raise bb.build.FuncFailed("opkg-build execution failed")

		bb.utils.prunedir(controldir)
		bb.utils.unlockfile(lf)

}

SSTATETASKS += "do_package_write_ipk"
do_package_write_ipk[sstate-name] = "deploy-ipk"
do_package_write_ipk[sstate-inputdirs] = "${PKGWRITEDIRIPK}"
do_package_write_ipk[sstate-outputdirs] = "${DEPLOY_DIR_IPK}"

python do_package_write_ipk_setscene () {
	sstate_setscene(d)
}
addtask do_package_write_ipk_setscene

python () {
    if bb.data.getVar('PACKAGES', d, True) != '':
        deps = (bb.data.getVarFlag('do_package_write_ipk', 'depends', d) or "").split()
        deps.append('opkg-utils-native:do_populate_sysroot')
        deps.append('virtual/fakeroot-native:do_populate_sysroot')
        bb.data.setVarFlag('do_package_write_ipk', 'depends', " ".join(deps), d)
        bb.data.setVarFlag('do_package_write_ipk', 'fakeroot', "1", d)
}

python do_package_write_ipk () {
	bb.build.exec_func("read_subpackage_metadata", d)
	bb.build.exec_func("do_package_ipk", d)
}
do_package_write_ipk[dirs] = "${PKGWRITEDIRIPK}"
addtask package_write_ipk before do_package_write after do_package
