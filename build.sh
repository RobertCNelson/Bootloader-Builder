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

STABLE="v2012.04.01"
#TESTING="v2012.04-rc3"

#LATEST_GIT="2ab5be7af009b4a40efe2fa5471497c97e70ed28"
LATEST_GIT="b86a475c1a602c6ee44f4469d933df8792418a7a"

unset GIT_OPTS
unset GIT_NOEDIT
LC_ALL=C git help pull | grep -m 1 -e "--no-edit" &>/dev/null && GIT_NOEDIT=1

if [ "${GIT_NOEDIT}" ] ; then
	echo "Detected git 1.7.10 or later, this script will pull via [git pull --no-edit]"
	GIT_OPTS+="--no-edit"
fi

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/latest/

function dl_old_bootloaders {
	if [ -f ${DIR}/deploy/latest/bootloader ] ; then
		rm -f ${DIR}/deploy/latest/bootloader || true
	fi
	cd ${DIR}/deploy/latest/
	wget http://rcn-ee.net/deb/tools/latest/bootloader
	cd -
}

function set_cross_compiler {

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		#using Cross Compiler
		CC=arm-linux-gnueabi-
	fi

	if [ "x${SYST}" == "xhera" ] ; then
		#dl:http://rcn-ee.homeip.net:81/dl/bootloader/
		CC=/mnt/sata0/git_repo/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
	fi

	if [ "x${SYST}" == "xwork-e6400" ] || [ "x${SYST}" == "xhades" ] || [ "x${SYST}" == "xx4-955" ] ; then
		CC=/opt/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
	fi
}

function at91_loader {
	echo "Starting AT91Bootstrap build for: ${BOARD}"
	echo "-----------------------------"

	if ! ls ${DIR}/dl/AT91Bootstrap${AT91BOOTSTRAP}.zip >/dev/null 2>&1;then
		wget --directory-prefix=${DIR}/dl/ ftp://www.at91.com/pub/at91bootstrap/AT91Bootstrap${AT91BOOTSTRAP}.zip
	fi

	rm -rf ${DIR}/Bootstrap-v${AT91BOOTSTRAP} || true
	unzip -q ${DIR}/dl/AT91Bootstrap${AT91BOOTSTRAP}.zip

	cd ${DIR}/Bootstrap-v${AT91BOOTSTRAP}
	sed -i -e 's:/usr/local/bin/make-3.80:/usr/bin/make:g' go_build_bootstrap.sh
	sed -i -e 's:/opt/codesourcery/arm-2007q1/bin/arm-none-linux-gnueabi-:'${CC}':g' go_build_bootstrap.sh
	./go_build_bootstrap.sh

	cd -

	echo "AT91Bootstrap build completed for: ${BOARD}"
	echo "-----------------------------"
}

function build_omap_xloader {
	echo "Starting x-loader build for: ${BOARD}"
	echo "-----------------------------"

	if [ ! -f ${DIR}/git/x-loader/.git/config ] ; then
		cd ${DIR}/git/
		git clone git://gitorious.org/x-loader/x-loader.git
		cd -
	fi

	cd ${DIR}/git/x-loader/
	git pull ${GIT_OPTS}
	cd -

	rm -rf ${DIR}/build/x-loader || true
	mkdir -p ${DIR}/build/x-loader
	git clone --shared ${DIR}/git/x-loader ${DIR}/build/x-loader

	cd ${DIR}/build/x-loader
	make ARCH=arm distclean

	XGIT_VERSION=$(git rev-parse --short HEAD)
	XGIT_MON=$(git show HEAD | grep Date: | awk '{print $3}')
	XGIT_DAY=$(git show HEAD | grep Date: | awk '{print $4}')

	make ARCH=arm distclean &> /dev/null
	make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
	echo "Building x-loader: ${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}"
	make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ift > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}
	cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}

	cd ${DIR}/

	rm -rf ${DIR}/build/x-loader

	echo "x-loader build completed for: ${BOARD}"
	echo "-----------------------------"
}

function build_u-boot {
	echo "Starting u-boot build for: ${BOARD}"
	echo "-----------------------------"

	RELEASE_VER="-r0"

	if [ ! -f ${DIR}/git/u-boot/.git/config ] ; then
		#git clone git://git.denx.de/u-boot.git
		git clone git://github.com/RobertCNelson/u-boot.git ${DIR}/git/u-boot/
	fi

	cd ${DIR}/git/u-boot/
	git pull ${GIT_OPTS}
	cd -

	if [ -d ${DIR}/build/u-boot ] ; then
		rm -rf ${DIR}/build/u-boot || true
	fi

	mkdir -p ${DIR}/build/u-boot
	git clone --shared ${DIR}/git/u-boot ${DIR}/build/u-boot

	cd ${DIR}/build/u-boot
	make ARCH=arm CROSS_COMPILE=${CC} distclean

	if [ "${UBOOT_GIT}" ] ; then
		git checkout ${UBOOT_GIT} -b u-boot-scratch
	else
		git checkout ${UBOOT_TAG} -b u-boot-scratch
	fi

	UGIT_VERSION=$(git describe)

	if [ "${enable_zImage_support}" ] ; then
		if [ "${v2012_07}" ] ; then
			git am "${DIR}/patches/v2012.07/0001-enable-bootz-support-for-ti-omap-targets.patch"
			git am "${DIR}/patches/v2012.07/0001-enable-bootz-support-for-mx5x-targets.patch"
		else
			git am "${DIR}/patches/v2012.04/0001-enable-bootz-support-for-ti-omap-targets.patch"
			git am "${DIR}/patches/v2012.04/0001-enable-bootz-support-for-mx5x-targets.patch"
		fi
	fi

	if [ "${enable_uenv_support}" ] ; then
		if [ "${v2012_07}" ] ; then
			git am "${DIR}/patches/v2012.04/0001-panda-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-am3517_crane-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-mx51evk-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.07/0001-mx53loco-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-am335-convert-to-uEnv.txt-bootscript.patch"

		else
			git am "${DIR}/patches/v2012.04/0001-panda-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-igep0020-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-am3517_crane-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-mx51evk-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-mx53loco-convert-to-uEnv.txt-bootscript.patch"
			git am "${DIR}/patches/v2012.04/0001-am335-convert-to-uEnv.txt-bootscript.patch"
		fi
	fi

	if [ "${beagle_fixes}" ] ; then
		if [ "${v2012_07}" ] ; then
			git am "${DIR}/patches/v2012.04/0001-beagle-fix-dvi-variable-set-higher-resolution.patch"
			git am "${DIR}/patches/v2012.04/0001-beagle-ulcd-passthru-support.patch"
		else
			git am "${DIR}/patches/v2012.04/0001-beagle-fix-dvi-variable-set-higher-resolution.patch"
			git am "${DIR}/patches/v2012.04/0001-beagle-ulcd-passthru-support.patch"
			RELEASE_VER="-r1"
			git am "${DIR}/patches/v2012.04/0001-beagle-fix-timed-out-in-wait_for_bb-message-in-SPL.patch"
		fi
	fi

	if [ "${BEAGLEBONE_PATCH}" ] ; then
		RELEASE_VER="-r2"
		git pull ${GIT_OPTS} git://github.com/RobertCNelson/u-boot.git am335xpsp_04.06.00.08
	fi

	make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
	echo "Building u-boot: ${BOARD}-${UGIT_VERSION}${RELEASE_VER}"
	time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}

	unset UBOOT_DONE

	#Freescale targets just need u-boot.imx from u-boot
	if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/u-boot/u-boot.imx ] ; then
		cp -v u-boot.imx ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.imx
		UBOOT_DONE=1
	fi

	#SPL based targets, need MLO and u-boot.img from u-boot
	if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/u-boot/MLO ] ; then
		cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${UGIT_VERSION}${RELEASE_VER}
		if [ -f ${DIR}/build/u-boot/u-boot.img ] ; then 
			 cp -v u-boot.img ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.img
		fi
		UBOOT_DONE=1
	fi

	#Just u-boot.bin
	if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/u-boot/u-boot.bin ] ; then
		cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.bin
		UBOOT_DONE=1
	fi

	cd ${DIR}/

	rm -rf ${DIR}/build/u-boot || true

	echo "u-boot build completed for: ${BOARD}"
	echo "-----------------------------"
}

function cleanup {
	unset UBOOT_TAG
	unset UBOOT_GIT
	unset AT91BOOTSTRAP
	unset REVERT
	unset BEAGLEBONE_PATCH
}

function at91sam9xeek {
	cleanup

	BOARD="at91sam9xeek"
	AT91BOOTSTRAP="1.16"
	at91_loader
}

function build_stable {
	if [ "${STABLE}" ] ; then
		UBOOT_TAG=${STABLE}
		build_u-boot
	fi
}

function build_testing {
	if [ "${TESTING}" ] ; then
		UBOOT_TAG=${TESTING}
		build_u-boot
	fi
}

function build_latest {
	v2012_07=1
	if [ "${LATEST_GIT}" ] ; then
		UBOOT_GIT=${LATEST_GIT}
		build_u-boot
	fi
	unset v2012_07
}

function build_zimage {
	zImage_support=1
	if [ "${LATEST_GIT}" ] ; then
		UBOOT_GIT=${LATEST_GIT}
		build_u-boot
	fi
	unset zImage_support
}

function beagleboard {
	cleanup

	BOARD="beagleboard"
	UBOOT_CONFIG="omap3_beagle_config"

	enable_zImage_support=1
	beagle_fixes=1
	build_stable
	build_testing
	build_latest
	unset beagle_fixes
	unset enable_zImage_support
}


function beaglebone {
	cleanup

	BOARD="beaglebone"
	UBOOT_CONFIG="am335x_evm_config"

	BEAGLEBONE_PATCH=1
	UBOOT_TAG="v2011.09"
	build_u-boot
	unset BEAGLEBONE_PATCH

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

function igep00x0 {
	cleanup

	BOARD="igep00x0"

	XLOAD_CONFIG="igep00x0_config"
	build_omap_xloader

	UBOOT_CONFIG="igep0020_config"

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

function am3517crane {
	cleanup

	BOARD="am3517crane"
	UBOOT_CONFIG="am3517_crane_config"

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

function pandaboard {
	cleanup

	BOARD="pandaboard"
	UBOOT_CONFIG="omap4_panda_config"

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

function mx51evk {
	cleanup

	BOARD="mx51evk"
	UBOOT_CONFIG="mx51evk_config"

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

function mx53loco {
	cleanup

	BOARD="mx53loco"
	UBOOT_CONFIG="mx53loco_config"

	enable_zImage_support=1
	enable_uenv_support=1
	build_stable
	build_testing
	build_latest
	unset enable_uenv_support
	unset enable_zImage_support
}

dl_old_bootloaders
set_cross_compiler

#at91sam9xeek

am3517crane
beagleboard
beaglebone
igep00x0
mx51evk
mx53loco
pandaboard

