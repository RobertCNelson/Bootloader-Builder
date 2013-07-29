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
#latest_at91bootstrap_sha="7162da97d6d31bf0ba7580f5bef48f549bbf138b"
latest_at91bootstrap_sha="8692a6653fffa7b484eaa05a166c31b9ca75a649"

uboot_stable="v2013.07"
#uboot_testing="v2013.07"

#uboot_latest="aaf5e825606a70ddc8fca8e366d8c16a6fd3cc7c"
uboot_latest="9fab4bf4cc077c21e43941866f3f2c196f28670d"

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

	if [ "${v2013_07}" ] ; then
		uboot_patch_dir="v2013.07"
		#r0: initial release
		#r1:
		RELEASE_VER="-r0"

		#omap3 fix usb
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-usb-ehci-omap-Don-t-softreset-USB-High-speed-Host-UH.patch"

		#Device Tree Only:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	if [ "${uboot_next}" ] ; then
		uboot_patch_dir="next"
		#omap3 fix usb
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-usb-ehci-omap-Don-t-softreset-USB-High-speed-Host-UH.patch"

		#Device Tree Only:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9g20ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"

		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"

		#Device Tree/Board File:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"

		#Board File Only:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d3: Device Tree Only:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
	fi

	unset BUILDTARGET
	if [ "x${BOARD}" == "xmx23_olinuxino" ] ; then
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

cleanup () {
	unset GIT_SHA
}

build_uboot_stable () {
	v2013_07=1
	if [ "${uboot_stable}" ] ; then
		GIT_SHA=${uboot_stable}
		build_u_boot
	fi
	unset v2013_07
}

build_uboot_testing () {
#	uboot_next=1
#	v2013_07_rc1=1
#	v2013_07_rc2=1
#	v2013_07_rc3=1
#	v2013_07=1
	if [ "${uboot_testing}" ] ; then
		GIT_SHA=${uboot_testing}
		build_u_boot
	fi
#	unset uboot_next
#	unset v2013_07_rc1
#	unset v2013_07_rc2
#	unset v2013_07_rc3
#	unset v2013_07
}

build_uboot_latest () {
	uboot_next=1
#	v2013_07_rc1=1
#	v2013_07_rc2=1
#	v2013_07_rc3=1
#	v2013_07=1
	if [ "${uboot_latest}" ] ; then
		GIT_SHA=${uboot_latest}
		build_u_boot
	fi
	unset uboot_next
#	unset v2013_07_rc1
#	unset v2013_07_rc2
#	unset v2013_07_rc3
#	unset v2013_07
}

build_uboot_all () {
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

am335x_evm () {
	cleanup
	armv7hf_toolchain

	BOARD="am335x_evm"
	build_uboot_all
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

	BOARD="at91sam9g20ek_2mmc_nandflash"
	build_uboot_all
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

	BOARD="at91sam9x5ek_mmc"
	build_uboot_all
}

mx23_olinuxino () {
	cleanup
	if [ $(which elftosb) ] ; then
		armv7_toolchain

		BOARD="mx23_olinuxino"
		build_uboot_all
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
	build_uboot_all
}

mx53loco () {
	cleanup
	armv7hf_toolchain

	BOARD="mx53loco"
	build_uboot_all
}

mx6qsabresd () {
	cleanup
	armv7hf_toolchain

	BOARD="mx6qsabresd"
	build_uboot_all
}

omap3_beagle () {
	cleanup
	armv7hf_toolchain

	BOARD="omap3_beagle"
	build_uboot_all
}

omap4_panda () {
	cleanup
	armv7hf_toolchain

	BOARD="omap4_panda"
	build_uboot_all
}

omap5_uevm () {
	cleanup
	armv7hf_toolchain

	BOARD="omap5_uevm"
	build_uboot_all
}

sama5d3xek () {
	cleanup
	armv7hf_toolchain

	BOARD="sama5d3xek"

	at91bootstrap_config="at91sama5d3xeksd_uboot_defconfig"
	GIT_SHA="${stable_at91bootstrap_sha}"
	build_at91bootstrap

	if [ "${latest_at91bootstrap_sha}" ] ; then
		at91bootstrap_config="sama5d3xeksd_uboot_defconfig"
		GIT_SHA="${latest_at91bootstrap_sha}"
		build_at91bootstrap
	fi

	BOARD="sama5d3xek_mmc"
	build_uboot_all
}

vf610twr () {
	cleanup
	armv7hf_toolchain

	BOARD="vf610twr"
	build_uboot_all
}

wandboard () {
	cleanup
	armv7hf_toolchain

	BOARD="wandboard_quad"
	build_uboot_all

	BOARD="wandboard_dl"
	build_uboot_all

	BOARD="wandboard_solo"
	build_uboot_all
}

am335x_evm
at91sam9g20ek
at91sam9x5ek
mx23_olinuxino
mx51evk
mx53loco
mx6qsabresd
omap3_beagle
omap4_panda
omap5_uevm
sama5d3xek
vf610twr
wandboard
#
