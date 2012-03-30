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

STABLE="v2011.12"
#TESTING="v2011.12-rc3"

#Using as stable for panda/panda_es:
#LATEST_GIT="6751b05f855bbe56005d5b88d4eb58bcd52170d2"

LATEST_GIT="7cb30b13f12077c7eec8ce2419cd96cd65ace8e2"

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

	if [ "x${SYST}" == "xlvrm" ] ; then
		CC=/opt/sata1/git_repo/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
	fi

	if [ "x${SYST}" == "xwork-e6400" ] || [ "x${SYST}" == "xwork-p4" ] || [ "x${SYST}" == "xx4-955" ] ; then
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
	git pull
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
	git pull
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

	if [ "${zImage_support}" ] ; then
		RELEASE_VER="-rz1"
		git am "${DIR}/patches/0001-BOOT-Add-bootz-command-to-boot-Linux-zImage-on-ARM.patch"
		git am "${DIR}/patches/0002-BOOT-Add-RAW-ramdisk-support-to-bootz.patch"
		git am "${DIR}/patches/0001-add-bootz-support.patch"
		git am "${DIR}/patches/0001-panda-convert-to-uEnv.txt.patch"
	fi

	if [ "${OMAP3_PATCH}" ] ; then
		RELEASE_VER="-r3"
		git am "${DIR}/patches/0001-Revert-armv7-disable-L2-cache-in-cleanup_before_linu.patch"
		git am "${DIR}/patches/0001-beagleboard-add-support-for-scanning-loop-through-ex.patch"
		git am "${DIR}/patches/0002-omap-beagle-re-add-c4-support.patch"
		git am "${DIR}/patches/0001-omap_hsmmc-Wait-for-CMDI-to-be-clear.patch"
		git am "${DIR}/patches/0001-beagle-make-ulcd-configure-correctly-out-of-the-box.patch"
	fi

	if [ "${OMAP4_PATCH}" ] ; then
		RELEASE_VER="-r1"
		git am "${DIR}/patches/0001-omap4-fix-boot-issue-on-ES2.0-Panda.patch"
		git am "${DIR}/patches/0001-panda-convert-to-uEnv.txt.patch"
	fi

	if [ "${panda_latest_patch}" ] ; then
		RELEASE_VER="-r1"
		git am "${DIR}/patches/0001-panda-convert-to-uEnv.txt.patch"
	fi

	if [ "${igep00x0_patch}" ] ; then
		RELEASE_VER="-r1"
		git am "${DIR}/patches/0001-Revert-armv7-disable-L2-cache-in-cleanup_before_linu.patch"
		git am "${DIR}/patches/0001-omap_hsmmc-Wait-for-CMDI-to-be-clear.patch"
		git am "${DIR}/patches/0001-convert-igep-to-uEnv.txt.patch"
	fi

	if [ "${BEAGLEBONE_PATCH}" ] ; then
		RELEASE_VER="-r1"
		git pull git://github.com/RobertCNelson/u-boot.git am335xpsp_05.03.01.00
	fi

	if [ "${AM3517_PATCH}" ] ; then
		RELEASE_VER="-r2"
		git am "${DIR}/patches/0001-am3517_crane-switch-to-uenv.txt.patch"
	fi

	if [ "${MX51EVK_PATCH}" ] ; then
		RELEASE_VER="-r2"
		git am "${DIR}/patches/0001-mx51evk-enable-ext2-support.patch"
		git am "${DIR}/patches/0002-mx51evk-use-partition-1.patch"
		git am "${DIR}/patches/0003-net-eth.c-fix-eth_write_hwaddr-to-use-dev-enetaddr-a.patch"
		git am "${DIR}/patches/0004-convert-mx51evk-to-uEnv.txt-bootscript.patch"
	fi

	if [ "${MX53LOCO_PATCH}" ] ; then
		RELEASE_VER="-r2"
		git am "${DIR}/patches/0001-mx53loco-enable-ext-support.patch"
		git am "${DIR}/patches/0002-mx53loco-use-part-1.patch"
		git am "${DIR}/patches/0003-net-eth.c-fix-eth_write_hwaddr-to-use-dev-enetaddr-a.patch"
		git am "${DIR}/patches/0004-convert-mx53loco-to-uEnv.txt-bootscript.patch"
	fi

	make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
	echo "Building u-boot: ${BOARD}-${UGIT_VERSION}${RELEASE_VER}"
	time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ${UBOOT_TARGET} > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}

	#MLO loads u-boot.img by default over u-boot.bin
	if [ -f ${DIR}/build/u-boot/MLO ] ; then
		cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${UGIT_VERSION}${RELEASE_VER}
		if [ -f ${DIR}/build/u-boot/u-boot.img ] ; then 
			 cp -v u-boot.img ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.img
		fi
	else
		if [ -f ${DIR}/build/u-boot/u-boot.bin ] ; then
			cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.bin
		fi
	fi

	if [ -f ${DIR}/build/u-boot/u-boot.imx ] ; then
		cp -v u-boot.imx ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}${RELEASE_VER}.imx
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
	unset OMAP3_PATCH
	unset AM3517_PATCH
	unset BEAGLEBONE_PATCH
	unset UBOOT_TARGET
}

function at91sam9xeek {
	cleanup

	BOARD="at91sam9xeek"
	AT91BOOTSTRAP="1.16"
	at91_loader
}

function build_testing {
	if [ "${TESTING}" ] ; then
		UBOOT_TAG=${TESTING}
		build_u-boot
	fi
}

function build_latest {
	if [ "${LATEST_GIT}" ] ; then
		UBOOT_GIT=${LATEST_GIT}
		build_u-boot
	fi
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

	OMAP3_PATCH=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset OMAP3_PATCH

	build_testing
	build_latest
	build_zimage
}


function beaglebone {
	cleanup

	BOARD="beaglebone"
	UBOOT_CONFIG="am335x_evm_config"

	BEAGLEBONE_PATCH=1
	UBOOT_TAG="v2011.09"
	build_u-boot
	unset BEAGLEBONE_PATCH

	build_latest
}

function igep00x0 {
	cleanup

	BOARD="igep00x0"

	XLOAD_CONFIG="igep00x0_config"
	build_omap_xloader

	UBOOT_CONFIG="igep0020_config"

	igep00x0_patch=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset igep00x0_patch

	build_testing
	build_latest
}

function am3517crane {
	cleanup

	BOARD="am3517crane"
	UBOOT_CONFIG="am3517_crane_config"

	AM3517_PATCH=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset AM3517_PATCH

	build_testing
	build_latest
}

function pandaboard {
	cleanup

	BOARD="pandaboard"
	UBOOT_CONFIG="omap4_panda_config"

	OMAP4_PATCH=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset OMAP4_PATCH

	build_testing

	panda_latest_patch=1
	build_latest
	unset panda_latest_patch
	build_zimage
}

function mx51evk {
	cleanup

	BOARD="mx51evk"
	UBOOT_CONFIG="mx51evk_config"
	UBOOT_TARGET="u-boot.imx"

	MX51EVK_PATCH=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset MX51EVK_PATCH

	build_testing
	build_latest
}

function mx53loco {
	cleanup

	BOARD="mx53loco"
	UBOOT_CONFIG="mx53loco_config"
	UBOOT_TARGET="u-boot.imx"

	MX53LOCO_PATCH=1
	UBOOT_TAG=${STABLE}
	build_u-boot
	unset MX53LOCO_PATCH

	build_testing
	build_latest
}

dl_old_bootloaders
set_cross_compiler

#at91sam9xeek

beagleboard
beaglebone
igep00x0
am3517crane
pandaboard
mx51evk
mx53loco

