inherit siteinfo

# This function creates an environment-setup-script for use in a deployable SDK
toolchain_create_sdk_env_script () {
	# Create environment setup script
	script=${SDK_OUTPUT}/${SDKPATH}/environment-setup-${MULTIMACH_TARGET_SYS}
	rm -f $script
	touch $script
	echo 'if [ ! -e ${SDKPATHNATIVE}/etc/ld.so.cache ]; then' >> $script
	echo '    echo "Please run ${SDKPATH}/postinstall as root before using the toolchain"'  >> $script
	echo '    exit 1' >> $script
	echo 'fi' >> $script
	echo 'export PATH=${SDKPATHNATIVE}${bindir_nativesdk}:${SDKPATHNATIVE}${bindir_nativesdk}/${MULTIMACH_TARGET_SYS}:$PATH' >> $script
	echo 'export PKG_CONFIG_SYSROOT_DIR=${SDKTARGETSYSROOT}' >> $script
	echo 'export PKG_CONFIG_PATH=${SDKTARGETSYSROOT}${libdir}/pkgconfig' >> $script
	echo 'export CONFIG_SITE=${SDKPATH}/site-config-${MULTIMACH_TARGET_SYS}' >> $script
	echo 'export CC=${TARGET_PREFIX}gcc' >> $script
	echo 'export CXX=${TARGET_PREFIX}g++' >> $script
	echo 'export GDB=${TARGET_PREFIX}gdb' >> $script
	echo 'export TARGET_PREFIX=${TARGET_PREFIX}' >> $script
	echo 'export CONFIGURE_FLAGS="--target=${TARGET_SYS} --host=${TARGET_SYS} --build=${SDK_ARCH}-linux"' >> $script
	if [ "${TARGET_OS}" = "darwin8" ]; then
		echo 'export TARGET_CFLAGS="-I${SDKTARGETSYSROOT}${includedir}"' >> $script
		echo 'export TARGET_LDFLAGS="-L${SDKTARGETSYSROOT}${libdir}"' >> $script
		# Workaround darwin toolchain sysroot path problems
		cd ${SDK_OUTPUT}${SDKTARGETSYSROOT}/usr
		ln -s /usr/local local
	fi
	echo 'export CFLAGS="${TARGET_CC_ARCH}"' >> $script
	echo 'export CXXFLAGS="${TARGET_CC_ARCH}"' >> $script
	echo "alias opkg='LD_LIBRARY_PATH=${SDKPATHNATIVE}${libdir_nativesdk} ${SDKPATHNATIVE}${bindir_nativesdk}/opkg-cl -f ${SDKPATHNATIVE}/${sysconfdir}/opkg-sdk.conf -o ${SDKPATHNATIVE}'" >> $script
	echo "alias opkg-target='LD_LIBRARY_PATH=${SDKPATHNATIVE}${libdir_nativesdk} ${SDKPATHNATIVE}${bindir_nativesdk}/opkg-cl -f ${SDKTARGETSYSROOT}${sysconfdir}/opkg.conf -o ${SDKTARGETSYSROOT}'" >> $script
	echo 'export POKY_NATIVE_SYSROOT="${SDKPATHNATIVE}"' >> $script
	echo 'export POKY_TARGET_SYSROOT="${SDKTARGETSYSROOT}"' >> $script
	echo 'export POKY_DISTRO_VERSION="${DISTRO_VERSION}"' >> $script
}

# This function creates an environment-setup-script in the TMPDIR which enables
# a Poky IDE to integrate with the build tree
toolchain_create_tree_env_script () {
	script=${TMPDIR}/environment-setup-${MULTIMACH_TARGET_SYS}
	rm -f $script
	touch $script
	echo 'export PATH=${PATH}' >> $script
	echo 'export PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR}' >> $script
	echo 'export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}' >> $script

	echo 'export CONFIG_SITE="${@siteinfo_get_files(d)}"' >> $script

	echo 'export CC=${TARGET_PREFIX}gcc' >> $script
	echo 'export CXX=${TARGET_PREFIX}g++' >> $script
	echo 'export GDB=${TARGET_PREFIX}gdb' >> $script
	echo 'export TARGET_PREFIX=${TARGET_PREFIX}' >> $script
	echo 'export CONFIGURE_FLAGS="--target=${TARGET_SYS} --host=${TARGET_SYS} --build=${BUILD_SYS}"' >> $script
	if [ "${TARGET_OS}" = "darwin8" ]; then
		echo 'export TARGET_CFLAGS="-I${STAGING_DIR}${TARGET_SYS}${includedir}"' >> $script
		echo 'export TARGET_LDFLAGS="-L${STAGING_DIR}${TARGET_SYS}${libdir}"' >> $script
		# Workaround darwin toolchain sysroot path problems
		cd ${SDK_OUTPUT}${SDKTARGETSYSROOT}/usr
		ln -s /usr/local local
	fi
	echo 'export CFLAGS="${TARGET_CC_ARCH}"' >> $script
	echo 'export CXXFLAGS="${TARGET_CC_ARCH}"' >> $script
	echo 'export POKY_NATIVE_SYSROOT="${STAGING_DIR_NATIVE}"' >> $script
	echo 'export POKY_TARGET_SYSROOT="${STAGING_DIR_TARGET}"' >> $script
}
