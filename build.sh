#!/bin/bash -e
#
# Copyright (c) 2010-2011 Robert Nelson <robertcnelson@gmail.com>
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


STABLE="v2011.12"
#TESTING="v2011.12-rc3"
LATEST_GIT="137703b811502dfea364650fb3e17f20b4c21333"

unset BISECT

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/latest/

cd ${DIR}/deploy/latest/
rm -f bootloader || true
wget http://rcn-ee.net/deb/tools/latest/bootloader
cd ${DIR}/

ARCH=$(uname -m)
SYST=$(uname -n)

if test "-$ARCH-" = "-armv7l-" || test "-$ARCH-" = "-armv5tel-"
then
 #using native gcc
 CC=
else
 #using Cross Compiler
 CC=arm-linux-gnueabi-
fi

if [ "-$SYST-" == "-hera-" ]; then
 #dl:http://rcn-ee.homeip.net:81/dl/bootloader/
 CC=/mnt/sata0/git_repo/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
fi

if [ "-$SYST-" == "-lvrm-" ]; then
 CC=/opt/sata1/git_repo/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
fi

if [ "-$SYST-" == "-work-e6400-" ]; then
 CC=/opt/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
fi

function git_bisect {

git bisect start

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

cd ${DIR}/

echo "AT91Bootstrap build completed for: ${BOARD}"
echo "-----------------------------"

}

function build_omap_xloader {

echo "Starting x-loader build for: ${BOARD}"
echo "-----------------------------"

if ! ls ${DIR}/git/x-loader >/dev/null 2>&1;then
cd ${DIR}/git/
git clone git://gitorious.org/x-loader/x-loader.git
cd ${DIR}/
fi

cd ${DIR}/git/x-loader/
git pull
cd ${DIR}/

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

if [ ! -f ${DIR}/git/u-boot/.git/config ] ; then
 cd ${DIR}/git/
 #git clone git://git.denx.de/u-boot.git
 git clone git://github.com/RobertCNelson/u-boot.git
fi

cd ${DIR}/git/u-boot/
git pull
cd ${DIR}/

rm -rf ${DIR}/build/u-boot || true
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

if [ "${BISECT}" ] ; then
git_bisect
fi

if [ "${OMAP3_PATCH}" ] ; then
 git am "${DIR}/patches/0001-Revert-armv7-disable-L2-cache-in-cleanup_before_linu.patch"
 git am "${DIR}/patches/0001-beagleboard-add-support-for-scanning-loop-through-ex.patch"
 git am "${DIR}/patches/0002-OMAP-MMC-Add-delay-before-waiting-for-status.patch"
 git am "${DIR}/patches/0001-omap-beagle-this-is-Special-Computing-C4.patch"
 git am "${DIR}/patches/0002-omap-beagle-re-add-c4-support.patch"
fi

if [ "${OMAP4_PATCH}" ] ; then
 git am "${DIR}/patches/0001-omap4-fix-boot-issue-on-ES2.0-Panda.patch"
fi

if [ "${BEAGLEBONE_PATCH}" ] ; then
git pull git://github.com/RobertCNelson/u-boot.git am335xpsp_05.03.01.00
fi

if [ "${AM3517_PATCH}" ] ; then
git am "${DIR}/patches/0001-am3517_crane-switch-to-uenv.txt.patch"
fi

if [ "${MX51EVK_PATCH}" ] ; then
git am "${DIR}/patches/0001-mx51evk-enable-ext2-support.patch"
git am "${DIR}/patches/0002-mx51evk-use-partition-1.patch"
git am "${DIR}/patches/0001-net-eth.c-fix-eth_write_hwaddr-to-use-dev-enetaddr-a.patch"
fi

if [ "${MX53LOCO_PATCH}" ] ; then
git am "${DIR}/patches/0001-mx53loco-enable-ext-support.patch"
git am "${DIR}/patches/0002-mx53loco-use-part-1.patch"
git am "${DIR}/patches/0001-net-eth.c-fix-eth_write_hwaddr-to-use-dev-enetaddr-a.patch"
fi

make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
echo "Building u-boot: ${BOARD}-${UGIT_VERSION}"
time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ${UBOOT_TARGET} > /dev/null

mkdir -p ${DIR}/deploy/${BOARD}

#MLO loads u-boot.img by default over u-boot.bin
if ls MLO >/dev/null 2>&1;then
 cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${UGIT_VERSION}
 if ls u-boot.img >/dev/null 2>&1;then
  cp -v u-boot.img ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}.img
 fi
else
 if ls u-boot.bin >/dev/null 2>&1;then
  cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}.bin
 fi
fi

if ls u-boot.imx >/dev/null 2>&1;then
 cp -v u-boot.imx ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}.imx
fi

cd ${DIR}/

rm -rf ${DIR}/build/u-boot

echo "u-boot build completed for: ${BOARD}"
echo "-----------------------------"
}

function cleanup {
unset UBOOT_TAG
unset UBOOT_GIT
unset AT91BOOTSTRAP
unset REVERT
unset BISECT
unset OMAP3_PATCH
unset OMAP4_PATCH
unset AM3517_PATCH
unset IGEP0020_PATCH
unset BEAGLEBONE_PATCH
unset MX51EVK_PATCH
unset MX53LOCO_PATCH
unset UBOOT_TARGET
}

#AT91Sam Boards
function at91sam9xeek {
cleanup

BOARD="at91sam9xeek"
AT91BOOTSTRAP="1.16"
at91_loader
}

#Omap3 Boards
function beagleboard {
cleanup

BOARD="beagleboard"

UBOOT_CONFIG="omap3_beagle_config"

OMAP3_PATCH=1
UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi
}

function beaglebone {
cleanup

BOARD="beaglebone"

BEAGLEBONE_PATCH=1
UBOOT_CONFIG="am335x_evm_config"
UBOOT_TAG="v2011.09"
build_u-boot

#UBOOT_TAG="v2011.09-rc2"
#build_u-boot

if [ "${LATEST_GIT}" ] ; then
 unset BEAGLEBONE_PATCH
 UBOOT_GIT=${LATEST_GIT}
 build_u-boot
fi
}

function igep00x0 {
cleanup
#IGEP0020_PATCH=1

BOARD="igep00x0"
XLOAD_CONFIG="igep00x0_config"
build_omap_xloader

UBOOT_CONFIG="igep0020_config"
UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi
}

function am3517crane {
cleanup

BOARD="am3517crane"
AM3517_PATCH=1
UBOOT_CONFIG="am3517_crane_config"
UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi
}

#Omap4 Boards
function pandaboard {
cleanup

BOARD="pandaboard"

OMAP4_PATCH=1
UBOOT_CONFIG="omap4_panda_config"
UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi

if [ "${LATEST_GIT}" ] ; then
 unset OMAP4_PATCH
 UBOOT_GIT=${LATEST_GIT}
 build_u-boot
fi
}

function mx51evk {
cleanup
MX51EVK_PATCH=1

BOARD="mx51evk"

UBOOT_CONFIG="mx51evk_config"
UBOOT_TARGET="u-boot.imx"

UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi
}

function mx53loco {
cleanup
MX53LOCO_PATCH=1

BOARD="mx53loco"

UBOOT_CONFIG="mx53loco_config"
UBOOT_TARGET="u-boot.imx"

UBOOT_TAG=${STABLE}
build_u-boot

if [ "${TESTING}" ] ; then
 UBOOT_TAG=${TESTING}
 build_u-boot
fi
}

#at91sam9xeek

beagleboard
beaglebone
igep00x0
am3517crane
pandaboard
mx51evk
mx53loco

