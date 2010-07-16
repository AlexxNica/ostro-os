#
# Copyright 2006-2008 OpenedHand Ltd.
#

inherit package

IMAGE_PKGTYPE ?= "deb"

# Map TARGET_ARCH to Debian's ideas about architectures
DPKG_ARCH ?= "${TARGET_ARCH}" 
DPKG_ARCH_x86 ?= "i386"
DPKG_ARCH_i486 ?= "i386"
DPKG_ARCH_i586 ?= "i386"
DPKG_ARCH_i686 ?= "i386"
DPKG_ARCH_pentium ?= "i386"

python package_deb_fn () {
    bb.data.setVar('PKGFN', bb.data.getVar('PKG',d), d)
}

addtask package_deb_install
python do_package_deb_install () {
    pkg = bb.data.getVar('PKG', d, True)
    pkgfn = bb.data.getVar('PKGFN', d, True)
    rootfs = bb.data.getVar('IMAGE_ROOTFS', d, True)
    debdir = bb.data.getVar('DEPLOY_DIR_DEB', d, True)
    apt_config = bb.data.expand('${STAGING_ETCDIR_NATIVE}/apt/apt.conf', d)
    stagingbindir = bb.data.getVar('STAGING_BINDIR_NATIVE', d, True)
    tmpdir = bb.data.getVar('TMPDIR', d, True)

    if None in (pkg,pkgfn,rootfs):
        raise bb.build.FuncFailed("missing variables (one or more of PKG, PKGFN, IMAGE_ROOTFS)")
    try:
        if not os.exists(rootfs):
            os.makedirs(rootfs)
        os.chdir(rootfs)
    except OSError:
        import sys
        raise bb.build.FuncFailed(str(sys.exc_value))

    # update packages file
    (exitstatus, output) = commands.getstatusoutput('dpkg-scanpackages %s > %s/Packages' % (debdir, debdir))
    if (exitstatus != 0 ):
        raise bb.build.FuncFailed(output)

    f = open(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"), "w")
    f.close()

    # NOTE: this env stuff is racy at best, we need something more capable
    # than 'commands' for command execution, which includes manipulating the
    # env of the fork+execve'd processs

    # Set up environment
    apt_config_backup = os.getenv('APT_CONFIG')
    os.putenv('APT_CONFIG', apt_config)
    path = os.getenv('PATH')
    os.putenv('PATH', '%s:%s' % (stagingbindir, os.getenv('PATH')))

    # install package
    commands.getstatusoutput('apt-get update')
    commands.getstatusoutput('apt-get install -y %s' % pkgfn)

    # revert environment
    os.putenv('APT_CONFIG', apt_config_backup)
    os.putenv('PATH', path)
}

python do_package_deb () {
    import re, copy

    workdir = bb.data.getVar('WORKDIR', d, True)
    if not workdir:
        bb.error("WORKDIR not defined, unable to package")
        return

    outdir = bb.data.getVar('DEPLOY_DIR_DEB', d, True)
    if not outdir:
        bb.error("DEPLOY_DIR_DEB not defined, unable to package")
        return

    dvar = bb.data.getVar('D', d, True)
    if not dvar:
        bb.error("D not defined, unable to package")
        return
    bb.mkdirhier(dvar)

    packages = bb.data.getVar('PACKAGES', d, True)
    if not packages:
        bb.debug(1, "PACKAGES not defined, nothing to package")
        return

    tmpdir = bb.data.getVar('TMPDIR', d, True)

    if os.access(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"),os.R_OK):
        os.unlink(os.path.join(tmpdir, "stamps", "DEB_PACKAGE_INDEX_CLEAN"))

    if packages == []:
        bb.debug(1, "No packages; nothing to do")
        return

    for pkg in packages.split():
        localdata = bb.data.createCopy(d)
        pkgdest = bb.data.getVar('PKGDEST', d, True)
        root = "%s/%s" % (pkgdest, pkg)

        lf = bb.utils.lockfile(root + ".lock")

        bb.data.setVar('ROOT', '', localdata)
        bb.data.setVar('ROOT_%s' % pkg, root, localdata)
        pkgname = bb.data.getVar('PKG_%s' % pkg, localdata, True)
        if not pkgname:
            pkgname = pkg
        bb.data.setVar('PKG', pkgname, localdata)

        bb.data.setVar('OVERRIDES', pkg, localdata)

        bb.data.update_data(localdata)
        basedir = os.path.join(os.path.dirname(root))

        pkgoutdir = os.path.join(outdir, bb.data.getVar('PACKAGE_ARCH', localdata, True))
        bb.mkdirhier(pkgoutdir)

        os.chdir(root)
        from glob import glob
        g = glob('*')
        try:
            del g[g.index('DEBIAN')]
            del g[g.index('./DEBIAN')]
        except ValueError:
            pass
        if not g and bb.data.getVar('ALLOW_EMPTY', localdata) != "1":
            bb.note("Not creating empty archive for %s-%s-%s" % (pkg, bb.data.getVar('PV', localdata, True), bb.data.getVar('PR', localdata, True)))
            bb.utils.unlockfile(lf)
            continue

        controldir = os.path.join(root, 'DEBIAN')
        bb.mkdirhier(controldir)
        os.chmod(controldir, 0755)
        try:
            ctrlfile = file(os.path.join(controldir, 'control'), 'wb')
            # import codecs
            # ctrlfile = codecs.open("someFile", "w", "utf-8")
        except OSError:
            bb.utils.unlockfile(lf)
            raise bb.build.FuncFailed("unable to open control file for writing.")

        fields = []
        pe = bb.data.getVar('PE', d, True)
        if pe and int(pe) > 0:
            fields.append(["Version: %s:%s-%s\n", ['PE', 'PV', 'PR']])
        else:
            fields.append(["Version: %s-%s\n", ['PV', 'PR']])
        fields.append(["Description: %s\n", ['DESCRIPTION']])
        fields.append(["Section: %s\n", ['SECTION']])
        fields.append(["Priority: %s\n", ['PRIORITY']])
        fields.append(["Maintainer: %s\n", ['MAINTAINER']])
        fields.append(["Architecture: %s\n", ['DPKG_ARCH']])
        fields.append(["OE: %s\n", ['PN']])
        fields.append(["Homepage: %s\n", ['HOMEPAGE']])

#        Package, Version, Maintainer, Description - mandatory
#        Section, Priority, Essential, Architecture, Source, Depends, Pre-Depends, Recommends, Suggests, Conflicts, Replaces, Provides - Optional


        def pullData(l, d):
            l2 = []
            for i in l:
                data = bb.data.getVar(i, d, True)
                if data is None:
                    raise KeyError(f)
		if i == 'DPKG_ARCH' and bb.data.getVar('PACKAGE_ARCH', d, True) == 'all':
                    data = 'all'
                l2.append(data)
            return l2

        ctrlfile.write("Package: %s\n" % pkgname)
        # check for required fields
        try:
            for (c, fs) in fields:
                ctrlfile.write(unicode(c % tuple(pullData(fs, localdata))))
        except KeyError:
            import sys
            (type, value, traceback) = sys.exc_info()
            bb.utils.unlockfile(lf)
            ctrlfile.close()
            raise bb.build.FuncFailed("Missing field for deb generation: %s" % value)
        # more fields

        bb.build.exec_func("mapping_rename_hook", localdata)

        rdepends = bb.utils.explode_dep_versions(bb.data.getVar("RDEPENDS", localdata, True) or "")
	for dep in rdepends:
		if '*' in dep:
			del rdepends[dep]
        rrecommends = bb.utils.explode_dep_versions(bb.data.getVar("RRECOMMENDS", localdata, True) or "")
	for dep in rrecommends:
		if '*' in dep:
			del rrecommends[dep]
        rsuggests = bb.utils.explode_dep_versions(bb.data.getVar("RSUGGESTS", localdata, True) or "")
        rprovides = bb.utils.explode_dep_versions(bb.data.getVar("RPROVIDES", localdata, True) or "")
        rreplaces = bb.utils.explode_dep_versions(bb.data.getVar("RREPLACES", localdata, True) or "")
        rconflicts = bb.utils.explode_dep_versions(bb.data.getVar("RCONFLICTS", localdata, True) or "")
        if rdepends:
            ctrlfile.write("Depends: %s\n" % unicode(bb.utils.join_deps(rdepends)))
        if rsuggests:
            ctrlfile.write("Suggests: %s\n" % unicode(bb.utils.join_deps(rsuggests)))
        if rrecommends:
            ctrlfile.write("Recommends: %s\n" % unicode(bb.utils.join_deps(rrecommends)))
        if rprovides:
            ctrlfile.write("Provides: %s\n" % unicode(bb.utils.join_deps(rprovides)))
        if rreplaces:
            ctrlfile.write("Replaces: %s\n" % unicode(bb.utils.join_deps(rreplaces)))
        if rconflicts:
            ctrlfile.write("Conflicts: %s\n" % unicode(bb.utils.join_deps(rconflicts)))
        ctrlfile.close()

        for script in ["preinst", "postinst", "prerm", "postrm"]:
            scriptvar = bb.data.getVar('pkg_%s' % script, localdata, True)
            if not scriptvar:
                continue
            try:
                scriptfile = file(os.path.join(controldir, script), 'w')
            except OSError:
                bb.utils.unlockfile(lf)
                raise bb.build.FuncFailed("unable to open %s script file for writing." % script)
            scriptfile.write("#!/bin/sh\n")
            scriptfile.write(scriptvar)
            scriptfile.close()
            os.chmod(os.path.join(controldir, script), 0755)

        conffiles_str = bb.data.getVar("CONFFILES", localdata, True)
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
        ret = os.system("PATH=\"%s\" %s dpkg-deb -b %s %s" % (bb.data.getVar("PATH", localdata, True), bb.data.getVar("FAKEROOT", localdata, True) or "fakeroot", root, pkgoutdir))
        if ret != 0:
            bb.utils.unlockfile(lf)
            raise bb.build.FuncFailed("dpkg-deb execution failed")

        bb.utils.prunedir(controldir)
        bb.utils.unlockfile(lf)
}

python () {
    if bb.data.getVar('PACKAGES', d, True) != '':
        deps = (bb.data.getVarFlag('do_package_write_deb', 'depends', d) or "").split()
        deps.append('dpkg-native:do_populate_sysroot')
        deps.append('virtual/fakeroot-native:do_populate_sysroot')
        bb.data.setVarFlag('do_package_write_deb', 'depends', " ".join(deps), d)
}

python do_package_write_deb () {
	bb.build.exec_func("read_subpackage_metadata", d)
	bb.build.exec_func("do_package_deb", d)
}
do_package_write_deb[dirs] = "${D}"
addtask package_write_deb before do_package_write after do_package

