#!/bin/bash

DIR=$PWD

mkdir -p ${PWD}/git/
mkdir -p ${PWD}/deploy/

function at91_loader {
echo "not implemented yet"
}

function build_omap_xloader {

echo ""
echo "Starting x-loader build"
echo ""

if ! ls ${DIR}/git/x-loader >/dev/null 2>&1;then
cd ${DIR}/git/
git clone git://gitorious.org/x-loader/x-loader.git
fi

cd ${DIR}/git/x-loader
make ARCH=arm distclean
git pull
GIT_VERSION=$(git rev-parse HEAD)
make ARCH=arm distclean
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- ${XLOAD_CONFIG}
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- ift

mkdir -p ${DIR}/deploy/${BOARD}
cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${GIT_VERSION}

make ARCH=arm distclean
cd ${DIR}/

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

cd ${DIR}/git/u-boot
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- distclean
git reset --hard
git fetch
git checkout master
git pull
git branch -D u-boot-scratch || true
git checkout -b ${UBOOT_TAG} -b u-boot-scratch
GIT_VERSION=$(git rev-parse HEAD)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- ${UBOOT_CONFIG}
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-

mkdir -p ${DIR}/deploy/${BOARD}
cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${UBOOT_TAG}-${BOARD}-${GIT_VERSION}

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- distclean
cd ${DIR}/

echo ""
echo "u-boot build completed"
echo ""

}

#Omap3 Boards

function beagleboard {
BOARD="beagleboard"
XLOAD_CONFIG="omap3530beagle_config"
build_omap_xloader

UBOOT_CONFIG="omap3_beagle_config"
UBOOT_TAG="v2010.12-rc3"
build_u-boot
}

#Omap4 Boards
function pandaboard {
BOARD="pandaboard"
XLOAD_CONFIG="omap4430panda_config"
build_omap_xloader

UBOOT_CONFIG="omap4_panda_config"
UBOOT_TAG="v2010.12-rc3"
build_u-boot

}

beagleboard
pandaboard


