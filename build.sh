#!/bin/bash -e
#
# Copyright (c) 2010-2013 Robert Nelson <robertcnelson@gmail.com>
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

ARCH=$(uname -m)
SYST=$(uname -n)

# Number of jobs for make to run in parallel.
NUMJOBS=$(cat /proc/cpuinfo | grep processor | wc -l)

stable_at91bootstrap_sha="d8d995620a7d0b413aa029f45463b4d3e940c907"

#v3.5.4
#latest_at91bootstrap_sha="bd45f35f9e205310f89bc6dd8233b40d3cf1d3ca"
latest_at91bootstrap_sha="7162da97d6d31bf0ba7580f5bef48f549bbf138b"

uboot_stable="v2013.04"
uboot_testing="v2013.07-rc3"

#uboot_latest="576aacdb915242dc60977049528b546fbe6135cc"
uboot_latest="50ffc3b64aa3c8113f0a9fc31ea96e596d60054a"

barebox_stable="v2013.02.0"
#barebox_testing="v2013.02.0"

#barebox_latest="8c82b1b2021591a8c3537958c7fa60816c584d8a"
barebox_latest="94e71b843f6456abacc2fe76a5c375a461fabdf7"

unset GIT_OPTS
unset GIT_NOEDIT
( LC_ALL=C git help pull | grep -m 1 -e "--no-edit" ) &>/dev/null && GIT_NOEDIT=1

if [ "${GIT_NOEDIT}" ] ; then
	GIT_OPTS="--no-edit"
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

dl_gcc_generic () {
	if [ ! -f ${DIR}/dl/${datestamp} ] ; then
		echo "Installing: ${toolchain_name}"
		echo "-----------------------------"
		${WGET} ${site}/${version}/+download/${filename}
		if [ -d ${DIR}/dl/${directory} ] ; then
			rm -rf ${DIR}/dl/${directory} || true
		fi
		${untar} ${DIR}/dl/${filename} -C ${DIR}/dl/
		touch ${DIR}/dl/${datestamp}
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/${directory}/${binary}"
	fi
}

armv5_embedded_toolchain () {
	#https://launchpad.net/gcc-arm-embedded/+download
	#https://launchpad.net/gcc-arm-embedded/4.7/4.7-2013-q2-update/+download/gcc-arm-none-eabi-4_7-2013q2-20130614-linux.tar.bz2

	toolchain_name="gcc-arm-none-eabi"
	site="https://launchpad.net/gcc-arm-embedded"
	version="4.7/4.7-2013-q2-update"
	version_date="20130614"
	directory="${toolchain_name}-4_7-2013q2"
	filename="${directory}-${version_date}-linux.tar.bz2"
	datestamp="${version_date}-${toolchain_name}"
	untar="tar -xjf"

	binary="bin/arm-none-eabi-"

	dl_gcc_generic
}

armv7_toolchain () {
	#https://launchpad.net/linaro-toolchain-binaries/+download
	#https://launchpad.net/linaro-toolchain-binaries/trunk/2012.04/+download/gcc-linaro-arm-linux-gnueabi-2012.04-20120426_linux.tar.bz2

	toolchain_name="gcc-arm toolchain"
	site="https://launchpad.net/linaro-toolchain-binaries/trunk"
	version="2012.04"
	filename="gcc-linaro-arm-linux-gnueabi-2012.04-20120426_linux.tar.bz2"
	directory="gcc-linaro-arm-linux-gnueabi-2012.04-20120426_linux"
	datestamp="20120426-gcc-linaro-arm-linux-gnueabi"
	untar="tar -xjf"

	binary="bin/arm-linux-gnueabi-"

	dl_gcc_generic
}

armv7hf_toolchain () {
	#https://launchpad.net/linaro-toolchain-binaries/+download
	#https://launchpad.net/linaro-toolchain-binaries/trunk/2013.06/+download/gcc-linaro-arm-linux-gnueabihf-4.8-2013.06_linux.tar.xz

	gcc_version="4.8"
	release="2013.06"
	toolchain_name="gcc-linaro-arm-linux-gnueabihf"
	site="https://launchpad.net/linaro-toolchain-binaries"
	version="trunk/${release}"
	directory="${toolchain_name}-${gcc_version}-${release}_linux"
	filename="${directory}.tar.xz"
	datestamp="${release}-${toolchain_name}"
	untar="tar -xJf"

	binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

git_generic () {
	echo "Starting ${project} build for: ${BOARD}"
	echo "-----------------------------"

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

halt_patching_uboot () {
	pwd
	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${BUILDTARGET}"
	echo "-----------------------------"
	exit
}

file_save () {
	cp -v ./${filename_search} ${DIR}/${filename_id}
	md5sum=$(md5sum ${DIR}/${filename_id} | awk '{print $1}')
	check=$(ls "${DIR}/${filename_id}#*" 2>/dev/null | head -n 1)
	if [ "x${check}" != "x" ] ; then
		rm -rf "${DIR}/${filename_id}#*" || true
	fi
	touch ${DIR}/${filename_id}_${md5sum}
	echo "${BOARD}#${MIRROR}/${filename_id}#${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
}

build_at91bootstrap () {
	project="at91bootstrap"
	git_generic
	RELEASE_VER="-r0"

	at91bootstrap_version=$(cat Makefile | grep 'VERSION :=' | awk '{print $3}')
	at91bootstrap_sha=$(git rev-parse --short HEAD)

	make CROSS_COMPILE=${CC} clean &> /dev/null
	make CROSS_COMPILE=${CC} ${at91bootstrap_config} > /dev/null
	echo "Building ${project}: ${BOARD}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
	make CROSS_COMPILE=${CC} -j${NUMJOBS} > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}/

	if [ -f ${DIR}/build/${project}/binaries/*.bin ] ; then
		filename_search="binaries/*.bin"
		filename_id="deploy/${BOARD}/${BOARD}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
		file_save
	fi

	git_cleanup
}

build_u_boot () {
	project="u-boot"
	git_generic
	RELEASE_VER="-r0"

	make ARCH=arm CROSS_COMPILE=${CC} distclean
	UGIT_VERSION=$(git describe)

	if [ "${v2013_04}" ] ; then
		#r1: mx51evk: improve old imx-bsp boot:
		#r2: bone black: boot off eMMc
		#r3: need mmcdev/mmcpart
		#r4: bbb: sync with angstrom changes. (gpio/lcdc/boot order)
		#r5: mx6qsabrelite boots of both sd cards now
		#r6: beaglexm: add musb/lcdcmd
		#r7: bone: ignore sd card if no uEnv.txt is present (booting off eMMC with data on microSD)
		#r8: mx23: pull in voltage changes...
		#r9: sama5 actually load zImage
		#r10: bone: add a little note about uenvcmd...
		#r11: wandboard: quad support...
		RELEASE_VER="-r11"

		unset only_patch
		if [ "x${BOARD}" = "xmx23olinuxino" ] ; then
			git pull --no-edit git://github.com/RobertCNelson/u-boot-boards.git v2013.04_mx23
			git am "${DIR}/patches/v2013.04/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			only_patch=1
		fi

		if [ ! "${only_patch}" ] ; then
		#Device Tree Only:
		git am "${DIR}/patches/v2013.04/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.04/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/v2013.04/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/v2013.04/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.04/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.04/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/v2013.04/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/v2013.04/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.04/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.04/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/v2013.04/board/0001-USB-ohci-at91-support-sama5d3x-devices.patch"
		git am "${DIR}/patches/v2013.04/board/0002-NET-macb-support-sama5d3x-devices.patch"
		git am "${DIR}/patches/v2013.04/board/0003-SPI-atmel_spi-support-sama5d3x-devices.patch"
		git am "${DIR}/patches/v2013.04/board/0004-ARM-atmel-add-sama5d3xek-support.patch"
		git am "${DIR}/patches/v2013.04/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		fi
	fi

	if [ "${v2013_07_rc1}" ] ; then
		#Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc1/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/v2013.07-rc1/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/v2013.07-rc1/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/v2013.07-rc1/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc1/board/0002-NET-macb-support-sama5d3x-devices.patch"
		git am "${DIR}/patches/v2013.07-rc1/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	if [ "${v2013_07_rc2}" ] ; then
		git pull --no-edit git://github.com/RobertCNelson/u-boot-boards.git v2013.07-rc2_fix-bootz
		#Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc2/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/v2013.07-rc2/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/v2013.07-rc2/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/v2013.07-rc2/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		#git am "${DIR}/patches/v2013.07-rc2/board/0002-NET-macb-support-sama5d3x-devices.patch"
		git am "${DIR}/patches/v2013.07-rc2/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	if [ "${v2013_07_rc3}" ] ; then
		#Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/v2013.07-rc3/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		#git am "${DIR}/patches/v2013.07-rc3/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/v2013.07-rc3/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	if [ "${v2013_07}" ] ; then
		#omap3 fix usb
		git am "${DIR}/patches/v2013.07/board/0001-usb-ehci-omap-Don-t-softreset-USB-High-speed-Host-UH.patch"

		#Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/v2013.07-rc3/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/v2013.07-rc3/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/v2013.07-rc3/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/v2013.07-rc3/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	unset BUILDTARGET
	if [ "x${BOARD}" == "xmx23olinuxino" ] ; then
		BUILDTARGET="u-boot.sb"
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

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.sb ] ; then
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
		time make ARCH=arm CROSS_COMPILE="${CC}" -j${NUMJOBS} ${BUILDTARGET} > /dev/null

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.imx ] ; then
			filename_search="u-boot.imx"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.imx"
			file_save
			UBOOT_DONE=1
		fi

		#Freescale mx23 targets just need u-boot.sb from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.sb ] ; then
			filename_search="u-boot.sb"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.sb"
			file_save
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/MLO ] && [ -f ${DIR}/build/${project}/u-boot.img ] ; then
			filename_search="MLO"
			filename_id="deploy/${BOARD}/MLO-${uboot_filename}"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#Samsung SPL
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/spl/u-boot-spl.bin ] && [ -f ${DIR}/build/${project}/u-boot.bin ] ; then
			filename_search="spl/u-boot-spl.bin"
			filename_id="deploy/${BOARD}/u-boot-spl-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.bin"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.bin"
			file_save
			UBOOT_DONE=1
		fi

		#Just u-boot.bin
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.bin ] ; then
			filename_search="u-boot.bin"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.bin"
			file_save
			UBOOT_DONE=1
		fi
	else
		echo "-----------------------------"
		echo "Skipping Binary Build: as [${uboot_filename}] was previously built."
		echo "To override skipping(and force rebuild): [touch force_rebuild]"
		echo "-----------------------------"
	fi

	git_cleanup
}

build_barebox () {
	project="barebox"
	git_generic
	RELEASE_VER="-r0"

	make ARCH=arm CROSS_COMPILE=${CC} distclean 2> /dev/null
	barebox_version=$(git describe)

	barebox_filename="${BOARD}-${barebox_version}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${BOARD}

	unset BUILDTARGET

	make ARCH=arm CROSS_COMPILE=${CC} ${barebox_config}
	echo "Building ${project}: ${barebox_filename}"
	time make ARCH=arm CROSS_COMPILE="${CC}" -j${NUMJOBS} ${BUILDTARGET} > /dev/null

	if [ -f ${DIR}/build/${project}/barebox-flash-image ] ; then
		filename_search="barebox-flash-image"
		filename_id="deploy/${BOARD}/zbarebox-${barebox_filename}.bin"
		file_save
	fi

	git_cleanup
}

cleanup () {
	unset GIT_SHA
}

build_uboot_stable () {
	v2013_04=1
	if [ "${uboot_stable}" ] ; then
		GIT_SHA=${uboot_stable}
		build_u_boot
	fi
	unset v2013_04
}

build_uboot_testing () {
#	v2013_07_rc1=1
#	v2013_07_rc2=1
	v2013_07_rc3=1
#	v2013_07=1
	if [ "${uboot_testing}" ] ; then
		GIT_SHA=${uboot_testing}
		build_u_boot
	fi
#	unset v2013_07_rc1
#	unset v2013_07_rc2
	unset v2013_07_rc3
#	unset v2013_07
}

build_uboot_latest () {
#	v2013_07_rc1=1
#	v2013_07_rc2=1
#	v2013_07_rc3=1
	v2013_07=1
	if [ "${uboot_latest}" ] ; then
		GIT_SHA=${uboot_latest}
		build_u_boot
	fi
#	unset v2013_07_rc1
#	unset v2013_07_rc2
#	unset v2013_07_rc3
	unset v2013_07
}

build_barebox_stable () {
	if [ "${barebox_stable}" ] ; then
		GIT_SHA=${barebox_stable}
		build_barebox
	fi
}

build_barebox_testing () {
	if [ "${barebox_stable}" ] ; then
		GIT_SHA=${barebox_testing}
		build_barebox
	fi
}

build_barebox_latest () {
	if [ "${barebox_stable}" ] ; then
		GIT_SHA=${barebox_latest}
		build_barebox
	fi
}

at91sam9g20ek () {
	cleanup
	armv5_embedded_toolchain

	BOARD="at91sam9g20ek"

	at91bootstrap_config="at91sam9g20eksd_uboot_defconfig"
	GIT_SHA="${stable_at91bootstrap_sha}"
	build_at91bootstrap

	if [ "${latest_at91bootstrap_sha}" ] ; then
		GIT_SHA="${latest_at91bootstrap_sha}"
		build_at91bootstrap
	fi

	UBOOT_CONFIG="at91sam9g20ek_2mmc_nandflash_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="at91sam9g20ek_2mmc_nandflash"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

at91sam9x5ek () {
	cleanup
	armv5_embedded_toolchain

	BOARD="at91sam9x5ek"

	at91bootstrap_config="at91sam9x5eksd_uboot_defconfig"
	GIT_SHA="${stable_at91bootstrap_sha}"
	build_at91bootstrap

	if [ "${latest_at91bootstrap_sha}" ] ; then
		GIT_SHA="${latest_at91bootstrap_sha}"
		build_at91bootstrap
	fi

	UBOOT_CONFIG="at91sam9x5ek_mmc_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="at91sam9x5ek_mmc"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

beagleboard () {
	cleanup
	armv7hf_toolchain

	BOARD="beagleboard"
	UBOOT_CONFIG="omap3_beagle_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="omap3_beagle"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

beaglebone () {
	cleanup
	armv7hf_toolchain

	BOARD="beaglebone"
	UBOOT_CONFIG="am335x_evm_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="am335x_evm"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

mx23olinuxino () {
	cleanup
	if [ $(which elftosb) ] ; then
		armv7_toolchain

		BOARD="mx23olinuxino"
		UBOOT_CONFIG="mx23_olinuxino_config"

		build_uboot_stable
		build_uboot_testing

		BOARD="mx23_olinuxino"
		UBOOT_CONFIG="${BOARD}_config"
		build_uboot_latest
	else
		echo "-----------------------------"
		echo "Skipping Binary Build of [mx23_olinuxino]: as elftosb is not installed."
		echo "See: http://eewiki.net/display/linuxonarm/iMX233-OLinuXino#iMX233-OLinuXino-elftosb"
		echo "-----------------------------"
	fi
}

mx51evk () {
	cleanup
	armv7hf_toolchain

	BOARD="mx51evk"
	UBOOT_CONFIG="${BOARD}_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx53loco () {
	cleanup
	armv7hf_toolchain

	BOARD="mx53loco"
	UBOOT_CONFIG="${BOARD}_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx6qsabresd () {
	cleanup
	armv7hf_toolchain

	BOARD="mx6qsabresd"
	UBOOT_CONFIG="${BOARD}_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

omap5_uevm () {
	cleanup
	armv7hf_toolchain

	BOARD="omap5_uevm"
	UBOOT_CONFIG="${BOARD}_config"

#	build_uboot_stable
#	build_uboot_testing
	build_uboot_latest
}

pandaboard () {
	cleanup
	armv7hf_toolchain

	BOARD="pandaboard"
	UBOOT_CONFIG="omap4_panda_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="omap4_panda"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

sama5d3xek () {
	cleanup
	armv7hf_toolchain

	BOARD="sama5d3xek"

	at91bootstrap_config="at91sama5d3xeksd_uboot_defconfig"
	GIT_SHA="${stable_at91bootstrap_sha}"
	build_at91bootstrap

	if [ "${latest_at91bootstrap_sha}" ] ; then
		GIT_SHA="${latest_at91bootstrap_sha}"
		build_at91bootstrap
	fi

	UBOOT_CONFIG="sama5d3xek_sdcard_config"

	build_uboot_stable

	UBOOT_CONFIG="sama5d3xek_mmc_config"
	build_uboot_testing

	BOARD="sama5d3xek_mmc"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

vf610twr () {
	cleanup
	armv7hf_toolchain

	BOARD="vf610twr"
	UBOOT_CONFIG="${BOARD}_config"

#	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

wandboard () {
	cleanup
	armv7hf_toolchain

	BOARD="wandboard-quad"
	UBOOT_CONFIG="wandboard_quad_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="wandboard_quad"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest

	BOARD="wandboard-dl"
	UBOOT_CONFIG="wandboard_dl_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="wandboard_dl"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest

	BOARD="wandboard-solo"
	UBOOT_CONFIG="wandboard_solo_config"

	build_uboot_stable
	build_uboot_testing

	BOARD="wandboard_solo"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_latest
}

at91sam9g20ek
at91sam9x5ek
beagleboard
beaglebone
mx23olinuxino
mx51evk
mx53loco
#mx6qsabresd
omap5_uevm
pandaboard
sama5d3xek
vf610twr
wandboard
#
