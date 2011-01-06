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
TEMPDIR=$(mktemp -d)

CCACHE=ccache

unset BISECT

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/

ARCH=$(uname -m)
SYST=$(uname -n)

if test "-$ARCH-" = "-armv7l-" || test "-$ARCH-" = "-armv5tel-"
then
 #using native gcc
 CC=
else
 if test "-$SYST-" = "-voodoo-e6400-"
 then
   CC=/media/build/angstrom/angstrom-setup-scripts/build/tmp-.6/sysroots/x86_64-linux/usr/armv7a/bin/arm-angstrom-linux-gnueabi-
 else
   #using Cross Compiler
   #CC=arm-linux-gnueabi-
   CC=~/git_repo/angstrom-setup-scripts/build/tmp-angstrom_2008_1/sysroots/x86_64-linux/usr/armv7a/bin/arm-angstrom-linux-gnueabi-
 fi
fi

function git_bisect {

git bisect start
git bisect bad v2010.12
git bisect good 6644c195733ed4687014015dfd5cb5e220e8ec9a

## Executing script at 82000000
#Testing
#reading uImage
#locks up... so bad/good...
#git bisect bad e780d82b96b43a0dafc7b6511127a4c807b80012
#git bisect bad 0fc43a417c4ba5ab63dad6736a18f3bf7008f35f
#git bisect good def412b6618f5b887b80fcdad6ab4ee2fee0a110
#git bisect bad ac657c42af6b0bbc52a382667c1ab9fc26123c99
#git bisect bad f49d7b6cab188e704444736b23bdd7a8b7dc24b4
#git bisect bad 4a1a06bc8b21c6787a22458142e3ca3c06935517
#first bad: 4a1a06bc8b21c6787a22458142e3ca3c06935517


#2 e78 doesnt make sense...
#git bisect good v2010.09
#git bisect good b18815752f3d6db27877606e4e069e3f6cfe3a19
#git bisect good 9b107e6138e719ea5a0b924862a9b109c020c7ac
#git bisect bad f899198a7f7bff6e6b1ec9c3478c35fcede9a588
#git bisect bad 41bb7531e1382e730b8a6b06d249ea72d936c468

#git bisect bad e780d82b96b43a0dafc7b6511127a4c807b80012
#git bisect good 0fc43a417c4ba5ab63dad6736a18f3bf7008f35f
#git bisect good aaeb0a890a050b58be87fa2b165eec5fa947dc86
#git bisect good f7ac99fdd9eaf64df9731c2e8fdf97e9d3e2c82a
#git bisect good e3ce686c6ed6889935574dcb176f3884826f66a1
#git bisect good 6644c195733ed4687014015dfd5cb5e220e8ec9a

git bisect good 52eb2c79110151b9017a0829c4d44ee7b8e2ca04
git bisect good f9de0997d773699fb4bda1c1ad7462aa2fcd00e9
git bisect good b5d58d8500bfb918c7fec56f241e6ee1078c2be0
git bisect good 2a9a2339a4ea04636ed0968e76eeaf784e987f52
git bisect good b606ef41f6ba7dc16bffd8e29ceb2e0506484d8d
git bisect good d42f60ffca51c02d7545c465ef488f0d796027e1
git bisect good 2956532625cf8414ad3efb37598ba34db08d67ec

}

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
XGIT_VERSION=$(git rev-parse HEAD)
XGIT_MON=$(git show HEAD | grep Date: | awk '{print $3}')
XGIT_DAY=$(git show HEAD | grep Date: | awk '{print $4}')
make ARCH=arm distclean &> /dev/null
make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
echo "Building x-loader"
make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ift > /dev/null

mkdir -p ${DIR}/deploy/${BOARD}
cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}

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

#patch -p1 < "${DIR}/patches/<>"
#git add .
#git commit -a -m 'patchset'

if [ "${BISECT}" ] ; then
git_bisect
fi

git describe
UGIT_VERSION=$(git rev-parse HEAD)

#cat ${DIR}/git/u-boot/fs/fat/fat.c | grep "LINEAR_PREFETCH_SIZE," && git am ${DIR}/patches/0001-FAT-buffer-overflow-with-FAT12-16.patch
##cat ${DIR}/git/u-boot/arch/arm/config.mk | grep "CONFIG_SYS_ARM_WITHOUT_RELOC" && git am ${DIR}/patches/0001-Drop-support-for-CONFIG_SYS_ARM_WITHOUT_RELOC.patch
#cat ${DIR}/git/u-boot/arch/arm/cpu/armv7/omap-common/timer.c | grep "DECLARE_GLOBAL_DATA_PTR;" || git am ${DIR}/patches/0001-OMAP-Timer-Replace-bss-variable-by-gd.patch
#cat ${DIR}/git/u-boot/arch/arm/include/asm/global_data.h | grep "lastinc" || git am ${DIR}/patches/0001-arm920t-at91-timer-replace-bss-variables-by-gd.patch
#cat ${DIR}/git/u-boot/arch/arm/include/asm/global_data.h | grep "#ifdef CONFIG_ARM" || git am ${DIR}/patches/0001-ARM-make-timer-variables-in-gt_t-available-for-all-A.patch

git revert --no-edit 4a1a06bc8b21c6787a22458142e3ca3c06935517

make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
echo "Building u-boot"
time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" > /dev/null

mkdir -p ${DIR}/deploy/${BOARD}
cp -v u-boot.bin ${DIR}/deploy/${BOARD}/u-boot-${UBOOT_TAG}-${BOARD}-${UGIT_VERSION}

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

function test_omap {

if ! ls ${DIR}/deploy/${BOARD}/u-boot-${UBOOT_TAG}-${BOARD}-${UGIT_VERSION} >/dev/null 2>&1;then
exit 1
fi

#Software Qwerks
#fdisk 2.18, dos no longer default
unset FDISK_DOS

if fdisk -v | grep 2.18 >/dev/null ; then
 FDISK_DOS="-c=dos -u=cylinders"
fi

if [[ "${MMC}" =~ "mmcblk" ]]
then
 PARTITION_PREFIX="p"
fi

NUM_MOUNTS=$(mount | grep -v none | grep "$MMC" | wc -l)

for (( c=1; c<=$NUM_MOUNTS; c++ ))
do
 DRIVE=$(mount | grep -v none | grep "$MMC" | tail -1 | awk '{print $1}')
 sudo umount ${DRIVE} &> /dev/null || true
done

sudo parted -s ${MMC} mklabel msdos

sudo fdisk ${FDISK_DOS} ${MMC} << END
n
p
1
1
+64M
a
1
t
e
p
w
END

sync

echo ""
echo "Formating Boot Partition"
echo ""

sudo mkfs.vfat -F 16 ${MMC}${PARTITION_PREFIX}1 -n boot

mkdir ${TEMPDIR}/disk
sudo mount ${MMC}${PARTITION_PREFIX}1 ${TEMPDIR}/disk

sudo cp -v ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION} ${TEMPDIR}/disk/MLO
sudo cp -v ${DIR}/deploy/${BOARD}/u-boot-${UBOOT_TAG}-${BOARD}-${UGIT_VERSION} ${TEMPDIR}/disk/u-boot.bin

cat > /tmp/boot.cmd <<beagle_cmd

echo "Testing"
setenv bootcmd 'mmc init; fatload mmc 0:1 0x80300000 uImage; bootm 0x80300000'
setenv bootargs console=ttyS2,115200n8 
boot
beagle_cmd

sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d /tmp/boot.cmd ${TEMPDIR}/disk/boot.scr
sudo cp -v ${DIR}/uImage ${TEMPDIR}/disk/uImage

cd ${TEMPDIR}/disk
sync
cd ${DIR}/
sudo umount ${TEMPDIR}/disk || true
echo "done"

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
#UBOOT_TAG="v2010.09"
#BISECT=1
#UBOOT_GIT="2956532625cf8414ad3efb37598ba34db08d67ec"
build_u-boot

#MMC=/dev/mmcblk0
MMC=/dev/sde
test_omap

#UBOOT_CONFIG="omap3_beagle_config"
#UBOOT_TAG="v2010.09"
#BISECT=1
#UBOOT_GIT="2956532625cf8414ad3efb37598ba34db08d67ec"
#build_u-boot

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
#igep0020
#pandaboard


