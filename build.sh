#!/bin/sh -e
#
# Copyright (c) 2010-2015 Robert Nelson <robertcnelson@gmail.com>
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

if [ "x${ARCH}" = "xi686" ] ; then
	echo "Linaro no longer supports 32bit cross compilers, thus 32bit is no longer suppored by this script..."
	exit
fi

# Number of jobs for make to run in parallel.
NUMJOBS=$(getconf _NPROCESSORS_ONLN)

. ./version.sh

git="git am"

#Debian 7 (Wheezy): git version 1.7.10.4 and later needs "--no-edit"
unset git_opts
git_no_edit=$(LC_ALL=C git help pull | grep -m 1 -e "--no-edit" || true)
if [ ! "x${git_no_edit}" = "x" ] ; then
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
	site="https://releases.linaro.org"
	if [ ! -f ${DIR}/dl/${datestamp} ] ; then
		echo "Installing: ${toolchain_name}"
		echo "-----------------------------"
		${WGET} ${site}/${version}/${filename}
		if [ -d ${DIR}/dl/${directory} ] ; then
			rm -rf ${DIR}/dl/${directory} || true
		fi
		tar xf ${DIR}/dl/${filename} -C ${DIR}/dl/
		touch ${DIR}/dl/${datestamp}
	fi

	if [ "x${ARCH}" = "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		if [ -f /usr/bin/ccache ] ; then
			CC="ccache ${DIR}/dl/${directory}/${binary}"
		else
			CC="${DIR}/dl/${directory}/${binary}"
		fi
	fi
}

#NOTE: ignore formatting, as this is just: meld build.sh ../stable-kernel/scripts/gcc.sh
gcc_arm_embedded_4_8 () {
		#https://releases.linaro.org/14.04/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.8-2014.04_linux.tar.xz
		#
		gcc_version="4.8"
		release="2014.04"
		toolchain_name="gcc-linaro-arm-none-eabi"
		version="14.04/components/toolchain/binaries"
		directory="${toolchain_name}-${gcc_version}-${release}_linux"
		filename="${directory}.tar.xz"
		datestamp="${release}-${toolchain_name}"

		binary="bin/arm-none-eabi-"

	dl_gcc_generic
}

gcc_arm_embedded_4_9 () {
		#
		#https://releases.linaro.org/14.11/components/toolchain/binaries/arm-none-eabi/gcc-linaro-4.9-2014.11-x86_64_arm-eabi.tar.xz
		#

		gcc_version="4.9"
		release="14.11"
		target="arm-none-eabi"

		version="${release}/components/toolchain/binaries/${target}"
		filename="gcc-linaro-${gcc_version}-20${release}-x86_64_arm-eabi.tar.xz"
		directory="gcc-linaro-${gcc_version}-20${release}-x86_64_arm-eabi"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}


gcc_linaro_gnueabihf_4_8 () {
		#
		#https://releases.linaro.org/14.04/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux.tar.xz
		#
		gcc_version="4.8"
		release="2014.04"
		toolchain_name="gcc-linaro-arm-linux-gnueabihf"
		version="14.04/components/toolchain/binaries"
		directory="${toolchain_name}-${gcc_version}-${release}_linux"
		filename="${directory}.tar.xz"
		datestamp="${release}-${toolchain_name}"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_4_9 () {
		#
		#https://releases.linaro.org/14.11/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2014.11-x86_64_arm-linux-gnueabihf.tar.xz
		#

		gcc_version="4.9"
		release="14.11"
		target="arm-linux-gnueabihf"

		version="${release}/components/toolchain/binaries/${target}"
		filename="gcc-linaro-${gcc_version}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

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

	if [ -d ${DIR}/scratch/${project} ] ; then
		rm -rf ${DIR}/scratch/${project} || true
	fi

	mkdir -p ${DIR}/scratch/${project}
	git clone --shared ${DIR}/git/${project} ${DIR}/scratch/${project}

	cd ${DIR}/scratch/${project}

	if [ "${GIT_SHA}" ] ; then
		echo "Checking out: ${GIT_SHA}"
		git checkout ${GIT_SHA} -b ${project}-scratch
	fi
}

git_cleanup () {
	cd ${DIR}/

	rm -rf ${DIR}/scratch/${project} || true

	echo "${project} build completed for: ${BOARD}"
	echo "-----------------------------"
}

halt_patching_uboot () {
	pwd
	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE="${CC}" ${UBOOT_CONFIG}"
	echo "make ARCH=arm CROSS_COMPILE="${CC}" ${BUILDTARGET}"
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

	make CROSS_COMPILE="${CC}" clean >/dev/null 2>&1
	make CROSS_COMPILE="${CC}" ${at91bootstrap_config} > /dev/null
	echo "Building ${project}: ${BOARD}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
	make CROSS_COMPILE="${CC}" -j${NUMJOBS} > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}/

	if [ -f ${DIR}/scratch/${project}/binaries/at91bootstrap.bin ] ; then
		filename_search="binaries/at91bootstrap.bin"
		filename_id="deploy/${BOARD}/${BOARD}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
		file_save
	fi

	git_cleanup
}

build_u_boot () {
	project="u-boot"
	git_generic
	RELEASE_VER="-r0"

	make ARCH=arm CROSS_COMPILE="${CC}" distclean
	UGIT_VERSION=$(git describe)

	p_dir="${uboot_old}"
	if [ "${old}" ] ; then
		#r1: initial release
		#r2: add: A20-OLinuXino-LIME2
		#r3: am335x_evm: disable 1.5v -> 1.35v regulator change & mmcpart to 1 when /etc/fstab is in x:1
		#r4: (pending)
		RELEASE_VER="-r3" #bump on every change...
		#halt_patching_uboot

		#Allwinner Technology
		${git} "${DIR}/patches/${p_dir}/0001-sun7i-Add-support-for-Olimex-A20-OLinuXino-LIME2.patch"

		#Atmel:
		${git} "${DIR}/patches/${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

		#Atmel: sama5d4ek
		${git} "${DIR}/patches/${p_dir}/board/0001-mtd-atmel_nand-runtime-to-build-gf-table-for-pmecc.patch"
		${git} "${DIR}/patches/${p_dir}/board/0002-net-macb-enable-GMAC-IP-without-GE-feature-support.patch"
		${git} "${DIR}/patches/${p_dir}/board/0003-ARM-atmel-add-sama5d4ek-board-support.patch"
		${git} "${DIR}/patches/${p_dir}/board/0004-ARM-atmel-add-sama5d4-xplained-ultra-board-support.patch"
		${git} "${DIR}/patches/${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		${git} "${DIR}/patches/${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		${git} "${DIR}/patches/${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		if [ "x${BOARD}" = "xam335x_boneblack" ] ; then
			${git} "${DIR}/patches/${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
		fi
		${git} "${DIR}/patches/${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		${git} "${DIR}/patches/${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
	fi

	p_dir="${DIR}/patches/${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: am335x_evm: some users are setting dtb=fullpath to the full path...
		#r3: am335x_evm: fix spl boot in raw mode
		#r4: omap: raw mode broken, revert...
		#r5: omap: spl: mmc: Fix raw boot mode
		#r6: am335x_evm: enable USB Mass Storage function
		#r7: am335x_evm: force USB Mass Storage on boot failure...
		#r8: (pending)
		RELEASE_VER="-r7" #bump on every change...
		#halt_patching_uboot

		case "${BOARD}" in
		am335x_evm)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		beagle_x15)
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		*)
			#Atmel:
			${git} "${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

			#Freescale:
			${git} "${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

			#TI:
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	p_dir="${DIR}/patches/${uboot_testing}"
	if [ "${testing}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		case "${BOARD}" in
		am335x_evm)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		beagle_x15)
			${git} "${p_dir}/board/0001-ARM-OMAP-Change-set_pl310_ctrl_reg-to-be-generic.patch"
			${git} "${p_dir}/board/0002-ARM-OMAP5-DRA7-Setup-L2-Aux-Control-Register-with-re.patch"
			${git} "${p_dir}/board/0003-ARM-OMAP5-Add-workaround-for-ARM-errata-798870.patch"
			${git} "${p_dir}/board/0004-configs-ti_omap5_common-Enable-workaround-for-ARM-er.patch"
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			${git} "${p_dir}/board/0001-ARM-OMAP-Change-set_pl310_ctrl_reg-to-be-generic.patch"
			${git} "${p_dir}/board/0002-ARM-OMAP5-DRA7-Setup-L2-Aux-Control-Register-with-re.patch"
			${git} "${p_dir}/board/0003-ARM-OMAP5-Add-workaround-for-ARM-errata-798870.patch"
			${git} "${p_dir}/board/0004-configs-ti_omap5_common-Enable-workaround-for-ARM-er.patch"
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d4ek_mmc)
			${git} "${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		*)
			#Atmel:
			${git} "${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

			#Freescale:
			${git} "${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

			#TI:
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	p_dir="${DIR}/patches/next"
	if [ "${next}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		${git} "${p_dir}/errata/0001-ARM-Introduce-erratum-workaround-for-798870.patch"
		${git} "${p_dir}/errata/0002-ARM-Introduce-erratum-workaround-for-454179.patch"
		${git} "${p_dir}/errata/0003-ARM-Introduce-erratum-workaround-for-430973.patch"
		${git} "${p_dir}/errata/0004-ARM-Introduce-erratum-workaround-for-621766.patch"
		${git} "${p_dir}/errata/0005-ARM-OMAP-Change-set_pl310_ctrl_reg-to-be-generic.patch"
		${git} "${p_dir}/errata/0006-ARM-OMAP3-Rename-omap3.h-to-omap.h-to-be-generic-as-.patch"
		${git} "${p_dir}/errata/0007-ARM-OMAP3-Get-rid-of-omap3_gp_romcode_call-and-repla.patch"
		${git} "${p_dir}/errata/0008-ARM-DRA7-OMAP5-Add-workaround-for-ARM-errata-798870.patch"
		${git} "${p_dir}/errata/0009-ARM-OMAP5-DRA7-Setup-L2-Aux-Control-Register-with-re.patch"
		${git} "${p_dir}/errata/0010-ARM-OMAP3-Enable-workaround-for-ARM-errata-454179-43.patch"
		${git} "${p_dir}/errata/0011-ARM-OMAP3-rx51-Enable-workaround-for-ARM-errata-4541.patch"

		case "${BOARD}" in
		am335x_evm)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			${git} "${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		beagle_x15)
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx23_olinuxino)
			${git} "${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx51evk)
			${git} "${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx53loco)
			${git} "${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx6qsabresd)
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap3_beagle)
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap4_panda)
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d3xek_mmc)
			${git} "${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d3_xplained_mmc)
			${git} "${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d4ek_mmc)
			${git} "${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		udoo_quad|udoo_dl)
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		wandboard_quad|wandboard_dl|wandboard_solo)
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	unset BUILDTARGET
	if [ "x${BOARD}" = "xmx23_olinuxino" ] ; then
		BUILDTARGET="u-boot.sb"
	fi

	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE="${CC}" ${UBOOT_CONFIG}"
		echo "make ARCH=arm CROSS_COMPILE="${CC}" ${BUILDTARGET}"
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

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.sunxi ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/force_rebuild ] ; then
		unset pre_built
	fi

	if [ ! "${pre_built}" ] ; then
		make ARCH=arm CROSS_COMPILE="${CC}" ${UBOOT_CONFIG}
		echo "Building ${project}: ${uboot_filename}"
		echo "-----------------------------"
		make ARCH=arm CROSS_COMPILE="${CC}" -j${NUMJOBS} ${BUILDTARGET}
		echo "-----------------------------"

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.imx ] ; then
			filename_search="u-boot.imx"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.imx"
			file_save
			UBOOT_DONE=1
		fi

		#Freescale mx23 targets just need u-boot.sb from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.sb ] ; then
			filename_search="u-boot.sb"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.sb"
			file_save
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/MLO ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="MLO"
			filename_id="deploy/${BOARD}/MLO-${uboot_filename}"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: sunxi
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-sunxi-with-spl.bin ] ; then
			filename_search="u-boot-sunxi-with-spl.bin"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.sunxi"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: Atmel
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/boot.bin ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="boot.bin"
			filename_id="deploy/${BOARD}/boot-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: Samsung (old Atmel)
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/spl/u-boot-spl.bin ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="spl/u-boot-spl.bin"
			filename_id="deploy/${BOARD}/u-boot-spl-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#Just u-boot.bin
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.bin ] ; then
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
	unset transitioned_to_testing
}

build_at91bootstrap_all () {
	GIT_SHA="${stable_at91bootstrap_sha}"
	build_at91bootstrap

	if [ "${latest_at91bootstrap_sha}" ] ; then
		GIT_SHA="${latest_at91bootstrap_sha}"
		build_at91bootstrap
	fi
}

build_uboot_old () {
	old=1
	if [ "${uboot_old}" ] ; then
		GIT_SHA=${uboot_old}
		build_u_boot
	fi
	unset old
}

build_uboot_stable () {
	if [ "x${transitioned_to_testing}" = "x" ] ; then
		stable=1
		if [ "${uboot_stable}" ] ; then
			GIT_SHA=${uboot_stable}
			build_u_boot
		fi
		unset stable
	fi
}

build_uboot_testing () {
	testing=1
	if [ "${uboot_testing}" ] ; then
		GIT_SHA=${uboot_testing}
		build_u_boot
	fi
	unset testing
}

build_uboot_latest () {
	next=1
	if [ "${uboot_latest}" ] ; then
		GIT_SHA=${uboot_latest}
		build_u_boot
	fi
	unset next
}

build_uboot_eabi () {
	UBOOT_CONFIG="${BOARD}_defconfig"
	gcc_arm_embedded_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

build_uboot_gnueabihf () {
	UBOOT_CONFIG="${BOARD}_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

A10_OLinuXino_Lime () {
	cleanup
	transitioned_to_testing="true"

	BOARD="A10-OLinuXino-Lime"
	build_uboot_gnueabihf
}

A20_OLinuXino_Lime () {
	cleanup
	transitioned_to_testing="true"

	BOARD="A20-OLinuXino-Lime"
	build_uboot_gnueabihf
}

A20_OLinuXino_Lime2 () {
	cleanup
	transitioned_to_testing="true"

	BOARD="A20-OLinuXino-Lime2"
	build_uboot_gnueabihf
}

A20_OLinuXino_MICRO () {
	cleanup
	transitioned_to_testing="true"

	BOARD="A20-OLinuXino_MICRO"
	build_uboot_gnueabihf
}

am335x_evm () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="am335x_evm"
	build_uboot_gnueabihf
}

am335x_boneblack_flasher () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="am335x_boneblack"
	UBOOT_CONFIG="am335x_evm_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

am43xx_evm () {
	cleanup
	transitioned_to_testing="true"

	BOARD="am43xx_evm"
	build_uboot_gnueabihf
}

at91sam9x5ek () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="at91sam9x5ek_mmc"
	build_uboot_eabi

	at91bootstrap_config="at91sam9x5eksd_uboot_defconfig"
	build_at91bootstrap_all
}

beagle_x15 () {
	cleanup
	transitioned_to_testing="true"

	BOARD="beagle_x15"
	build_uboot_gnueabihf
}

cm_fx6 () {
	cleanup
	transitioned_to_testing="true"

	BOARD="cm_fx6"
	build_uboot_gnueabihf
}

mx23_olinuxino () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="mx23_olinuxino"
	build_uboot_eabi
}

mx51evk () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="mx51evk"
	build_uboot_gnueabihf
}

mx53loco () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="mx53loco"
	build_uboot_gnueabihf
}

mx6qsabresd () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="mx6qsabresd"
	build_uboot_gnueabihf
}

omap3_beagle () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="omap3_beagle"
	build_uboot_gnueabihf
}

omap4_panda () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="omap4_panda"
	build_uboot_gnueabihf
}

omap5_uevm () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="omap5_uevm"
	build_uboot_gnueabihf
}

rpi_2 () {
	cleanup
	transitioned_to_testing="true"

	BOARD="rpi_2"
#	build_uboot_gnueabihf

	UBOOT_CONFIG="rpi_2_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_latest
}

sama5d3xek () {
	cleanup
	transitioned_to_testing="true"

	BOARD="sama5d3xek_mmc"
	build_uboot_gnueabihf
}

sama5d3_xplained () {
	cleanup
	transitioned_to_testing="true"

	BOARD="sama5d3_xplained_mmc"
	build_uboot_gnueabihf
}

sama5d4ek () {
	cleanup
	transitioned_to_testing="true"

	BOARD="sama5d4ek_mmc"
	build_uboot_gnueabihf
}

sama5d4_xplained () {
	cleanup
	transitioned_to_testing="true"

	BOARD="sama5d4_xplained_mmc"
	build_uboot_gnueabihf
}

udoo () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="udoo_quad"
	build_uboot_gnueabihf

	cleanup
	#transitioned_to_testing="true"

	BOARD="udoo_dl"
	build_uboot_gnueabihf
}

vf610twr () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="vf610twr"
	build_uboot_gnueabihf
}

wandboard () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="wandboard_quad"
	build_uboot_gnueabihf

	cleanup
	#transitioned_to_testing="true"

	BOARD="wandboard_dl"
	build_uboot_gnueabihf

	cleanup
	#transitioned_to_testing="true"

	BOARD="wandboard_solo"
	build_uboot_gnueabihf
}

A10_OLinuXino_Lime
A20_OLinuXino_Lime
A20_OLinuXino_Lime2
A20_OLinuXino_MICRO
am335x_evm
am335x_boneblack_flasher
am43xx_evm
at91sam9x5ek
beagle_x15
cm_fx6
mx23_olinuxino
mx51evk
mx53loco
mx6qsabresd
omap3_beagle
omap4_panda
omap5_uevm
rpi_2
sama5d3xek
sama5d3_xplained
sama5d4ek
sama5d4_xplained
udoo
vf610twr
wandboard
#
