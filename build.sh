#!/bin/bash -e
#
# Copyright (c) 2010 Robert Nelson <robertcnelson@gmail.com>
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

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/

ARCH=$(uname -m)

if test "-$ARCH-" = "-armv7l-" || test "-$ARCH-" = "-armv5tel-"
then
 #using native gcc
 CC=
else
 #using Cross Compiler
 CC=arm-linux-gnueabi-
fi

function at91_loader {
echo ""
echo "Starting AT91Bootstrap build"
echo ""

if ! ls ${DIR}/dl/AT91Bootstrap${AT91BOOTSTRAP}.zip >/dev/null 2>&1;then
wget --directory-prefix=${DIR}/dl/ ftp://www.at91.com/pub/at91bootstrap/AT91Bootstrap${AT91BOOTSTRAP}.zip
fi

rm -rfd ${DIR}/Bootstrap-v${AT91BOOTSTRAP} || true
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
fi

cd ${DIR}/git/x-loader
make ARCH=arm distclean
git pull
GIT_VERSION=$(git rev-parse HEAD)
GIT_MON=$(git show HEAD | grep Date: | awk '{print $3}')
GIT_DAY=$(git show HEAD | grep Date: | awk '{print $4}')
make ARCH=arm distclean &> /dev/null
make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
echo "Building x-loader"
make ARCH=arm CROSS_COMPILE=${CC} ift

mkdir -p ${DIR}/deploy/${BOARD}
cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${GIT_MON}-${GIT_DAY}-${GIT_VERSION}

make ARCH=arm distclean &> /dev/null
git checkout master
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
make ARCH=arm CROSS_COMPILE=${CC} distclean &> /dev/null
git reset --hard
git fetch
git checkout master
git pull
git branch -D u-boot-scratch || true

if [ "${UBOOT_GIT}" ] ; then
git checkout ${UBOOT_GIT} -b u-boot-scratch
else
git checkout ${UBOOT_TAG} -b u-boot-scratch
fi

patch -p1 < "${DIR}/patches/0001-arm-omap-beagle-older-bx-boards-need-more-time.patch"
git add .
git commit -a -m 'patchset'

git describe
GIT_VERSION=$(git rev-parse HEAD)

make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
echo "Building u-boot"
make ARCH=arm CROSS_COMPILE=${CC}

mkdir -p ${DIR}/deploy/${BOARD}
cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${UBOOT_TAG}-${BOARD}-${GIT_VERSION}

make ARCH=arm CROSS_COMPILE=${CC} distclean &> /dev/null
git checkout master
cd ${DIR}/

echo ""
echo "u-boot build completed"
echo ""

}

function cleanup {
unset UBOOT_TAG
unset UBOOT_GIT
unset AT91BOOTSTRAP
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
UBOOT_TAG="v2010.12"
#UBOOT_GIT="2956532625cf8414ad3efb37598ba34db08d67ec"
build_u-boot
}

function igep0020 {
cleanup

BOARD="igep0020"
#posted but not merged
#XLOAD_CONFIG="igep0020_config"
#build_omap_xloader

UBOOT_CONFIG="igep0020_config"
UBOOT_TAG="v2010.12"
#UBOOT_GIT="2956532625cf8414ad3efb37598ba34db08d67ec"
build_u-boot
}

#Omap4 Boards
function pandaboard {
cleanup

BOARD="pandaboard"
XLOAD_CONFIG="omap4430panda_config"
build_omap_xloader

UBOOT_CONFIG="omap4_panda_config"
UBOOT_TAG="v2010.12"
#UBOOT_GIT="2956532625cf8414ad3efb37598ba34db08d67ec"
build_u-boot
}

#at91sam9xeek
beagleboard
igep0020
pandaboard


