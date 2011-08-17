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

DIR=$PWD
TEMPDIR=$(mktemp -d)

CCACHE=ccache

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
 if test "-$SYST-" = "-atom330-"
 then
   CC=~/git_repo/setup-scripts/build/tmp-angstrom_2008_1/sysroots/x86_64-linux/usr/armv7a/bin/arm-angstrom-linux-gnueabi-
 else
   #using Cross Compiler
   CC=arm-linux-gnueabi-
 fi
fi

function git_bisect {

git bisect start

}

function at91_loader {
echo ""
echo "Starting AT91Bootstrap build"
echo ""

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

}

function build_omap_xloader {

echo ""
echo "Starting x-loader build"
echo ""

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

if [ "${AM3517_PATCH}" ] ; then
patch -p1 < "${DIR}/patches/0001-intial-merge-from-craneboard-xload-repo-i2c-not-work.patch"
git add -f .
git commit -a -m 'port of x-load for am3517crane'
fi

make ARCH=arm distclean &> /dev/null
make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
echo "Building x-loader"
make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ift

mkdir -p ${DIR}/deploy/${BOARD}
cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}

cd ${DIR}/

rm -rf ${DIR}/build/x-loader

echo ""
echo "x-loader build completed"
echo ""

}

function build_u-boot {

echo ""
echo "Starting u-boot build"
echo ""

if ! ls ${DIR}/git/u-boot >/dev/null 2>&1;then
cd ${DIR}/git/
git clone git://git.denx.de/u-boot.git
fi

cd ${DIR}/git/u-boot/
git pull
cd ${DIR}/

rm -rf ${DIR}/build/u-boot || true
mkdir -p ${DIR}/build/u-boot
git clone --shared ${DIR}/git/u-boot ${DIR}/build/u-boot

cd ${DIR}/build/u-boot
make ARCH=arm CROSS_COMPILE=${CC} distclean &> /dev/null

if [ "${UBOOT_GIT}" ] ; then
git checkout ${UBOOT_GIT} -b u-boot-scratch
else
git checkout ${UBOOT_TAG} -b u-boot-scratch
fi

UGIT_VERSION=$(git describe)

if [ "${BISECT}" ] ; then
git_bisect
fi

#if [ "${REVERT}" ] ; then
#git revert --no-edit 4a1a06bc8b21c6787a22458142e3ca3c06935517
#fi

#fix for gcc-4.5.x
#git am "${DIR}/patches/0001-ARM-Avoid-compiler-optimization-for-readb-writeb-and.patch"

if [ "${AM3517_PATCH}" ] ; then
patch -p1 < "${DIR}/patches/0001-port-of-u-boot-for-am3517crane.patch"
git add -f .
git commit -a -m 'port of u-boot for am3517crane'
fi

if [ "${IGEP0020_PATCH}" ] ; then
patch -p1 < "${DIR}/patches/0001-ARM-OMAP3-Revamp-IGEP-v2-default-configuration.patch"
git add -f .
git commit -a -m 'boot.scr fixes for igepv2'
fi

if [ "${MX51EVK_PATCH}" ] ; then
git am "${DIR}/patches/0001-mx51evk-enable-ext2-support.patch"
git am "${DIR}/patches/0002-mx51evk-use-partition-1.patch"
fi

if [ "${MX53LOCO_PATCH}" ] ; then
git am "${DIR}/patches/0001-mx53loco-enable-ext-support.patch"
git am "${DIR}/patches/0002-mx53loco-use-part-1.patch"
fi

make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
echo "Building u-boot"
time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ${UBOOT_TARGET}

mkdir -p ${DIR}/deploy/${BOARD}

if ls u-boot.bin 2>&1;then
 cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}.bin
fi

if ls u-boot.imx 2>&1;then
 cp -v u-boot.imx ${DIR}/deploy/${BOARD}/u-boot-${BOARD}-${UGIT_VERSION}.imx
fi

cd ${DIR}/

rm -rf ${DIR}/build/u-boot

echo ""
echo "u-boot build completed"
echo ""

}

function cleanup {
unset UBOOT_TAG
unset UBOOT_GIT
unset AT91BOOTSTRAP
unset REVERT
unset BISECT
unset AM3517_PATCH
unset IGEP0020_PATCH
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
XLOAD_CONFIG="omap3530beagle_config"
build_omap_xloader

UBOOT_CONFIG="omap3_beagle_config"
UBOOT_TAG="v2011.03"
build_u-boot
UBOOT_TAG="v2011.06"
REVERT=1
build_u-boot
}

function igep00x0 {
cleanup
#IGEP0020_PATCH=1

BOARD="igep00x0"
XLOAD_CONFIG="igep00x0_config"
build_omap_xloader

UBOOT_CONFIG="igep0020_config"
UBOOT_TAG="v2011.03"
build_u-boot
UBOOT_TAG="v2011.06"
build_u-boot
}

function am3517crane {
cleanup
#AM3517_PATCH=1

BOARD="am3517crane"
#XLOAD_CONFIG="am3517crane_config"
#build_omap_xloader

UBOOT_CONFIG="am3517_crane_config"
UBOOT_TAG="v2011.06"
build_u-boot
}

#Omap4 Boards
function pandaboard {
cleanup

BOARD="pandaboard"
XLOAD_CONFIG="omap4430panda_config"
build_omap_xloader

UBOOT_CONFIG="omap4_panda_config"
UBOOT_TAG="v2011.03"
build_u-boot
UBOOT_TAG="v2011.06"
build_u-boot
}

function mx51evk {
cleanup
MX51EVK_PATCH=1

BOARD="mx51evk"

UBOOT_CONFIG="mx51evk_config"
UBOOT_TAG="v2011.06"
UBOOT_TARGET="u-boot.imx"
build_u-boot
}

function mx53loco {
cleanup
MX53LOCO_PATCH=1

BOARD="mx53loco"

UBOOT_CONFIG="mx53loco_config"
UBOOT_TAG="v2011.06"
UBOOT_TARGET="u-boot.imx"
build_u-boot
}

#at91sam9xeek
beagleboard
igep00x0
am3517crane
pandaboard
mx51evk
mx53loco

