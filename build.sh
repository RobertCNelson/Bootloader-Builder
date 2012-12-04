#!/bin/bash -e
#
# Copyright (c) 2010-2012 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

unset STABLE
unset TESTING

DIR=$PWD
TEMPDIR=$(mktemp -d)

CCACHE=ccache

ARCH=$(uname -m)
SYST=$(uname -n)

STABLE="v2012.10"
TESTING="v2013.01-rc1"

#LATEST_GIT="66dc452bfe13b0e276adddf3997b9c5abc00115d"
LATEST_GIT="d41b3cc16fd97da23900f79e8fefdeedeebde8f6"

unset GIT_OPTS
unset GIT_NOEDIT
LC_ALL=C git help pull | grep -m 1 -e "--no-edit" &>/dev/null && GIT_NOEDIT=1

if [ "${GIT_NOEDIT}" ] ; then
	echo "Detected git 1.7.10 or later, this script will pull via [git pull --no-edit]"
	GIT_OPTS+="--no-edit"
fi

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/

rm -rf ${DIR}/deploy/latest-bootloader.log || true

#export MIRROR="http://example.com"
#./build.sh
if [ ! "${MIRROR}" ] ; then
	MIRROR="http:"
fi

WGET="wget -c --directory-prefix=${DIR}/dl/"

armv5_embedded_toolchain () {
	#https://launchpad.net/gcc-arm-embedded/4.6/4.6-2012-q4-update/+download/gcc-arm-none-eabi-4_6-2012q4-20121016.tar.bz2
	armv5_ver="gcc-arm-none-eabi-4_6-2012q4"
	armv5_date="20121016"
	ARMV5_GCC_EMBEDDED="${armv5_ver}-${armv5_date}.tar.bz2"
	if [ ! -f ${DIR}/dl/${armv5_date} ] ; then
		echo "Installing gcc-arm-embedded toolchain"
		echo "-----------------------------"
		${WGET} https://launchpad.net/gcc-arm-embedded/4.6/4.6-2012-q4-update/+download/${ARMV5_GCC_EMBEDDED}
		touch ${DIR}/dl/${armv5_date}
		if [ -d ${DIR}/dl/${armv5_ver} ] ; then
			rm -rf ${DIR}/dl/${armv5_ver} || true
		fi
		tar xjf ${DIR}/dl/${ARMV5_GCC_EMBEDDED} -C ${DIR}/dl/
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/${armv5_ver}/bin/arm-none-eabi-"
	fi
}

armv7_toolchain () {
	#https://launchpad.net/linaro-toolchain-binaries/+download
	#https://launchpad.net/linaro-toolchain-binaries/trunk/2012.04/+download/gcc-linaro-arm-linux-gnueabi-2012.04-20120426_linux.tar.bz2

	armv7_ver="2012.04"
	armv7_date="20120426"
	ARMV7_GCC="gcc-linaro-arm-linux-gnueabi-${armv7_ver}-${armv7_date}_linux.tar.bz2"
	if [ ! -f ${DIR}/dl/${armv7_date} ] ; then
		echo "Installing gcc-arm toolchain"
		echo "-----------------------------"
		${WGET} https://launchpad.net/linaro-toolchain-binaries/trunk/${armv7_ver}/+download/${ARMV7_GCC}
		touch ${DIR}/dl/${armv7_date}
		if [ -d ${DIR}/dl/${armv7_ver} ] ; then
			rm -rf ${DIR}/dl/${armv7_ver} || true
		fi
		tar xjf ${DIR}/dl/${ARMV7_GCC} -C ${DIR}/dl/
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/gcc-linaro-arm-linux-gnueabi-${armv7_ver}-${armv7_date}_linux/bin/arm-linux-gnueabi-"
	fi
}

git_generic () {
	echo "Starting ${project} build for: ${BOARD}"
	echo "-----------------------------"

	RELEASE_VER="-r0"

	if [ ! -f ${DIR}/git/${project}/.git/config ] ; then
		git clone git://github.com/RobertCNelson/${project}.git ${DIR}/git/${project}/
	fi

	cd ${DIR}/git/${project}/
	git pull ${GIT_OPTS} || true
	git fetch --tags || true
	cd -

	if [ -d ${DIR}/build/${project} ] ; then
		rm -rf ${DIR}/build/${project} || true
	fi

	mkdir -p ${DIR}/build/${project}
	git clone --shared ${DIR}/git/${project} ${DIR}/build/${project}

	cd ${DIR}/build/${project}

	if [ "${GIT_SHA}" ] ; then
		echo "Checking out: ${GIT_SHA}"
		git checkout ${GIT_SHA} -b ${project}-scratch
	fi
}

git_cleanup () {
	cd ${DIR}/

	rm -rf ${DIR}/build/${project} || true

	echo "${project} build completed for: ${BOARD}"
	echo "-----------------------------"
}

build_at91bootstrap () {
	project="at91bootstrap"
	git_generic

	make CROSS_COMPILE=${CC} clean &> /dev/null
	make CROSS_COMPILE=${CC} ${AT91BOOTSTRAP_CONFIG}_defconfig
	echo "Building ${project}: ${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin"
	make CROSS_COMPILE=${CC} > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}/
	cp -v binaries/*.bin ${DIR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin
	md5sum=$(md5sum ${DIR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin | awk '{print $1}')
	echo "${BOARD}_${MIRROR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log

	git_cleanup
}

build_omap_xloader () {
	project="x-loader"
	git_generic

	make ARCH=arm distclean

	XGIT_VERSION=$(git rev-parse --short HEAD)
	XGIT_MON=$(git show HEAD | grep Date: | awk '{print $3}')
	XGIT_DAY=$(git show HEAD | grep Date: | awk '{print $4}')

	make ARCH=arm distclean &> /dev/null
	make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
	echo "Building ${project}: ${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}"
	make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ift > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}
	cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}
	md5sum=$(md5sum ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION} | awk '{print $1}')
	echo "${BOARD}_${MIRROR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log

	git_cleanup
}

halt_patching_uboot () {
	pwd
	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${BUILDTARGET}"
	echo "-----------------------------"
	exit
}

build_u_boot () {
	project="u-boot"
	git_generic

	make ARCH=arm CROSS_COMPILE=${CC} distclean
	UGIT_VERSION=$(git describe)

	if [ "${mno_unaligned_access}" ] ; then
		git am "${DIR}/patches/v2012.10/0001-Revert-Revert-arm-armv7-add-compile-option-mno-unali.patch"
	fi

	if [ "${v2013_01_rc2}" ] ; then
		#bootz:
		git am "${DIR}/patches/v2013.01-rc2/0001-enable-bootz-support.patch"

		#TI:
		git am "${DIR}/patches/v2013.01-rc1/0002-ti-convert-to-uEnv.txt-n-fixes.patch"
		git am "${DIR}/patches/v2013.01-rc1/0003-panda-temp-enable-pads-and-clocks-for-kernel.patch"

		#Freescale:
		git am "${DIR}/patches/v2013.01-rc1/0002-imx-convert-to-uEnv.txt-n-fixes.patch"

		#Atmel:
		git am "${DIR}/patches/v2013.01-rc2/0001-at91-enable-bootz-and-uEnv.txt-support.patch"
	fi

	if [ "${v2013_01_rc1}" ] ; then
		#bootz:
		git am "${DIR}/patches/v2013.01-rc1/0001-enable-bootz-support.patch"

		#TI:
		git am "${DIR}/patches/v2013.01-rc1/0002-ti-convert-to-uEnv.txt-n-fixes.patch"
		git am "${DIR}/patches/v2013.01-rc1/0004-am335x-add-mux-config-for-DDR3-version-of-beaglebone.patch"

		#Freescale:
		git am "${DIR}/patches/v2013.01-rc1/0002-imx-convert-to-uEnv.txt-n-fixes.patch"

		#Atmel:
		git am "${DIR}/patches/v2013.01-rc1/0003-at91-enable-bootz-and-uEnv.txt-support.patch"

		#TI: v2012.04 functionality
		if [ "x${BOARD}" == "xpandaboard" ] ; then
			RELEASE_VER="-r1"
			git am "${DIR}/patches/v2013.01-rc1/0003-panda-temp-enable-pads-and-clocks-for-kernel.patch"
		fi
	fi

	if [ "${v2012_10}" ] ; then
		#bootz:
		git am "${DIR}/patches/v2012.10/0001-enable-bootz-support.patch"
		#uEnv.txt
		git am "${DIR}/patches/v2012.10/0002-ti-convert-to-uEnv.txt-n-fixes.patch"
		git am "${DIR}/patches/v2012.10/0002-imx-convert-to-uEnv.txt-n-fixes.patch"

		#Atmel:
		git am "${DIR}/patches/v2012.10/0001-mmc-at91-add-multi-block-read-write-support.patch"
		git am "${DIR}/patches/v2012.10/0002-ARM-at91sam9x5-enable-MCI0-support-for-9x5ek-board.patch"
		git am "${DIR}/patches/v2012.10/0003-at91-enable-bootz-and-uEnv.txt-support.patch"

		#Freescale: mx6qsabresd
		git am "${DIR}/patches/v2012.10/0001-mx6q-Factor-out-common-DDR3-init-code.patch"
		git am "${DIR}/patches/v2012.10/0002-mx6-Add-basic-support-for-mx6qsabresd-board.patch"

		#TI: DDR3 Bone:
		git am "${DIR}/patches/v2012.10/0002-am33xx-Enable-DDR3-for-DDR3-version-of-beaglebone.patch"
		if [ "x${BOARD}" == "xbeaglebone" ] ; then
			RELEASE_VER="-r1"
			git am "${DIR}/patches/v2012.10/0003-am335x-add-mux-config-for-DDR3-version-of-beaglebone.patch"
		fi

		#TI: v2012.04 functionality
		if [ "x${BOARD}" == "xpandaboard" ] ; then
			RELEASE_VER="-r1"
			git am "${DIR}/patches/v2012.10/0003-panda-temp-enable-pads-and-clocks-for-kernel.patch"
		fi
	fi

	if [ "${v2012_10_rc1}" ] ; then
		#Freescale: build fix: 
		git am "${DIR}/patches/v2012.10/0004-i.MX-mxc_ipuv3_fb-add-ipuv3_fb_shutdown-routine-to-s.patch"
		git am "${DIR}/patches/v2012.10/0005-i.MX-shut-down-video-before-launch-of-O-S.patch"
	fi

	if [ "${enable_zImage_support}" ] ; then
		if [ "${v2012_04}" ] ; then
			git am "${DIR}/patches/v2012.04/0001-enable-bootz-support-for-ti-omap-targets.patch"
		fi
	fi

	if [ "${enable_uenv_support}" ] ; then
		if [ "${v2012_04}" ] ; then
			git am "${DIR}/patches/v2012.04/0001-panda-convert-to-uEnv.txt-bootscript.patch"
		fi
	fi

	if [ "${panda_fixes}" ] ; then
		RELEASE_VER="-r1"
		git am "${DIR}/patches/v2012.04/0003-panda-let-the-bootloader-set-the-intial-screen-resol.patch"
		RELEASE_VER="-r2"
		git am "${DIR}/patches/v2012.04/0004-panda-set-dtb_file-based-on-core.patch"
	fi

	unset BUILDTARGET
	if [ "${mx6qsabrelite_patch}" ] ; then
		git pull ${GIT_OPTS} git://github.com/RobertCNelson/u-boot.git mx6qsabrelite_v2011.12_linaro_lt_imx6
		BUILDTARGET="u-boot.imx"
	fi

	if [ "${odroidx_patch}" ] ; then
		git am "${DIR}/patches/v2012.10/0001-Exynos-Add-minimal-support-for-ODROID-X.patch"
	fi

	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}"
		echo "make ARCH=arm CROSS_COMPILE=${CC} ${BUILDTARGET}"
		echo "-----------------------------"
		exit
	fi

	uboot_filename="${BOARD}-${UGIT_VERSION}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${BOARD}

	unset pre_built
	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/MLO-${uboot_filename} ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/force_rebuild ] ; then
		unset pre_built
	fi

	if [ ! "${pre_built}" ] ; then
		make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
		echo "Building ${project}: ${uboot_filename}"
		time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ${BUILDTARGET} > /dev/null

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.imx ] ; then
			cp -v u-boot.imx ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx
			md5sum=$(md5sum ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx | awk '{print $1}')
			if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx_* ] ; then
				rm -rf ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx_* || true
			fi
			touch ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx_${md5sum}
			echo "${BOARD}_${MIRROR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/MLO ] ; then
			cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${uboot_filename}
			md5sum=$(md5sum ${DIR}/deploy/${BOARD}/MLO-${uboot_filename} | awk '{print $1}')
			echo "${BOARD}_${MIRROR}/deploy/${BOARD}/MLO-${uboot_filename}_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
			if [ -f ${DIR}/build/${project}/u-boot.img ] ; then 
				cp -v u-boot.img ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.img
				md5sum=$(md5sum ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.img | awk '{print $1}')
				if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.img_* ] ; then
					rm -rf ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.img_* || true
				fi
				touch ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.img_${md5sum}
				echo "${BOARD}_${MIRROR}/deploy/${BOARD}/u-boot-${uboot_filename}.img_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
			fi
			UBOOT_DONE=1
		fi

		#Just u-boot.bin
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.bin ] ; then
			cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin
			md5sum=$(md5sum ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin | awk '{print $1}')
			if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin_* ] ; then
				rm -rf ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin_* || true
			fi
			touch ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin_${md5sum}
			echo "${BOARD}_${MIRROR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
			UBOOT_DONE=1
		fi
	else
		echo "-----------------------------"
		echo "Skipping Binary Build: as [${uboot_filename}] was previously built."
		echo "Override skipping with [touch force_rebuild] to force rebuild"
		echo "-----------------------------"
	fi

	git_cleanup
}

cleanup () {
	unset GIT_SHA
}

build_uboot_stable () {
	v2012_10=1
	if [ "${STABLE}" ] ; then
		GIT_SHA=${STABLE}
		build_u_boot
	fi
	unset v2012_10
}

build_uboot_testing () {
	v2013_01_rc1=1
	#v2013_01=1
	if [ "${TESTING}" ] ; then
		GIT_SHA=${TESTING}
		build_u_boot
	fi
	#unset v2013_01
	unset v2013_01_rc1
}

build_uboot_latest () {
	v2013_01_rc2=1
	#v2013_01=1
	if [ "${LATEST_GIT}" ] ; then
		GIT_SHA=${LATEST_GIT}
		build_u_boot
	fi
	#unset v2013_01
	unset v2013_01_rc2
}

at91sam9x5ek () {
	cleanup
	armv5_embedded_toolchain

	BOARD="at91sam9x5ek"
	GIT_SHA="8e099c3a47f11c03b1ebe5cbc8d7406063b55262"
	AT91BOOTSTRAP_CONFIG="at91sam9x5sduboot"
	build_at91bootstrap

	UBOOT_CONFIG="at91sam9x5ek_nandflash_config"

	build_uboot_stable
	build_uboot_testing

	UBOOT_CONFIG="at91sam9x5ek_mmc_config"
	build_uboot_latest
}

beagleboard () {
	cleanup
	armv7_toolchain

	BOARD="beagleboard"
	UBOOT_CONFIG="omap3_beagle_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

beaglebone () {
	cleanup
	armv7_toolchain

	BOARD="beaglebone"
	UBOOT_CONFIG="am335x_evm_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

igep00x0 () {
	cleanup
	armv7_toolchain

	BOARD="igep00x0"

	XLOAD_CONFIG="igep00x0_config"
	build_omap_xloader

	UBOOT_CONFIG="igep0020_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

am3517crane () {
	cleanup
	armv7_toolchain

	BOARD="am3517crane"
	UBOOT_CONFIG="am3517_crane_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

pandaboard () {
	cleanup
	armv7_toolchain

	BOARD="pandaboard"
	UBOOT_CONFIG="omap4_panda_config"

	v2012_04=1
	enable_zImage_support=1
	enable_uenv_support=1
	panda_fixes=1
	GIT_SHA="v2012.04.01"
	build_u_boot
	unset panda_fixes
	unset enable_uenv_support
	unset enable_zImage_support
	unset v2012_04

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx51evk () {
	cleanup
	armv7_toolchain

	BOARD="mx51evk"
	UBOOT_CONFIG="mx51evk_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx53loco () {
	cleanup
	armv7_toolchain

	BOARD="mx53loco"
	UBOOT_CONFIG="mx53loco_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx6qsabrelite () {
	cleanup
	armv7_toolchain

	BOARD="mx6qsabrelite"
	UBOOT_CONFIG="mx6qsabrelite_config"

	mx6qsabrelite_patch=1
	GIT_SHA="v2011.12"
	build_u_boot
	unset mx6qsabrelite_patch

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx6qsabresd () {
	cleanup
	armv7_toolchain

	BOARD="mx6qsabresd"
	UBOOT_CONFIG="mx6qsabresd_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

odroidx () {
	cleanup
	armv7_toolchain

	BOARD="odroidx"
	UBOOT_CONFIG="odroidx_config"

#	enable_zImage_support=1
#	enable_uenv_support=1
#	build_uboot_stable
#	unset enable_uenv_support
#	unset enable_zImage_support

	odroidx_patch=1
#	build_uboot_testing
#	build_uboot_latest
	unset odroidx_patch
}

rpib () {
	cleanup
	armv7_toolchain

	BOARD="rpib"
	UBOOT_CONFIG="rpi_b_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

at91sam9x5ek
am3517crane
beagleboard
beaglebone
igep00x0
mx51evk
mx53loco
mx6qsabrelite
mx6qsabresd
odroidx
pandaboard
rpib

