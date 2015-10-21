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
CORES=$(getconf _NPROCESSORS_ONLN)

. ./version.sh

git="git am"

#Debian 7 (Wheezy): git version 1.7.10.4 and later needs "--no-edit"
unset git_opts
git_no_edit=$(LC_ALL=C git help pull | grep -m 1 -e "--no-edit" || true)
if [ ! "x${git_no_edit}" = "x" ] ; then
	git_opts="--no-edit"
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

wget_dl="wget -c --directory-prefix=${DIR}/dl/"

dl_gcc_generic () {
	site="https://releases.linaro.org"
	if [ ! -f ${DIR}/dl/${datestamp} ] ; then
		echo "Installing: ${toolchain_name}"
		echo "-----------------------------"
		${wget_dl} ${site}/${version}/${filename}
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
		#https://releases.linaro.org/15.05/components/toolchain/binaries/arm-eabi/gcc-linaro-4.9-2015.05-x86_64_arm-eabi.tar.xz
		#

		gcc_version="4.9"
		release="15.05"
		target="arm-eabi"

		version="${release}/components/toolchain/binaries/${target}"
		filename="gcc-linaro-${gcc_version}-20${release}-x86_64_arm-eabi.tar.xz"
		directory="gcc-linaro-${gcc_version}-20${release}-x86_64_arm-eabi"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/arm-eabi-"

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
		#https://releases.linaro.org/15.05/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.05-x86_64_arm-linux-gnueabihf.tar.xz
		#

		gcc_version="4.9"
		release="15.05"
		target="arm-linux-gnueabihf"

		version="${release}/components/toolchain/binaries/${target}"
		filename="gcc-linaro-${gcc_version}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

git_generic () {
	echo "Starting ${project} build for: ${board}"
	echo "-----------------------------"

	if [ ! -f ${DIR}/git/${project}/.git/config ] ; then
		git clone git://github.com/RobertCNelson/${project}.git ${DIR}/git/${project}/
	fi

	cd ${DIR}/git/${project}/
	git pull ${git_opts} || true
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

	echo "${project} build completed for: ${board}"
	echo "-----------------------------"
}

halt_patching_uboot () {
	pwd
	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config}"
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
	echo "${board}#${MIRROR}/${filename_id}#${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
}

build_at91bootstrap () {
	project="at91bootstrap"
	git_generic
	RELEASE_VER="-r0"

	at91bootstrap_version=$(cat Makefile | grep 'VERSION :=' | awk '{print $3}')
	at91bootstrap_sha=$(git rev-parse --short HEAD)

	make CROSS_COMPILE="${CC}" clean >/dev/null 2>&1
	make CROSS_COMPILE="${CC}" ${at91bootstrap_config} > /dev/null
	echo "Building ${project}: ${board}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
	make CROSS_COMPILE="${CC}" -j${CORES} > /dev/null

	mkdir -p ${DIR}/deploy/${board}/

	if [ -f ${DIR}/scratch/${project}/binaries/at91bootstrap.bin ] ; then
		filename_search="binaries/at91bootstrap.bin"
		filename_id="deploy/${board}/${board}-${at91bootstrap_version}-${at91bootstrap_sha}${RELEASE_VER}.bin"
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

	p_dir="${DIR}/patches/${uboot_old}"
	if [ "${old}" ] ; then
		#r1: initial release
		#r2: am335x_evm: add tftp_dir prefix ${tftp_dir}${bootfile} & ${tftp_dir}dtbs/${fdtfile}
		#r3: am335x_evm: dump reset reason...
		#r4: am335x_evm: support the beaglebone green
		#r5: someone's been using bash too much...
		#r6: am335x_evm: version not name
		#r7: (pending)
		RELEASE_VER="-r6" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
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
		wandboard)
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	p_dir="${DIR}/patches/${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: udoo/wand: enable CONFIG_SPL_EXT_SUPPORT
		#r3: udoo/wand: disable CONFIG_SPL_X_SUPPORT, want to use raw...
		#r4: am335x_evm: fix gpio...
		#r5: omap3, disable thumb2...
		#r6: fix tftp with revert (fixed in master)
		#r7: am335x_evm: we are not yet ready...
		#r8: omap, we arent' ready for partuuid...
		#r9: omap, we arent' ready for partuuid...
		#r10: revert 1fec3c5d832d6e0cac10135179016b0640f1a863
		#r11: omap-netinstall
		#r12: (pending)
		RELEASE_VER="-r11" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
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
			echo "patch -p1 < \"${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap3_beagle)
			echo "patch -p1 < \"${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap4_panda)
			echo "patch -p1 < \"${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			echo "patch -p1 < \"${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d2_xplained_mmc)
#			patch -p1 < "${p_dir}/board/0001-arm-atmel-Add-SAMA5D2-Xplained-board.patch"
#			patch -p1 < "${p_dir}/board/0002-gpio-atmel-Add-the-PIO4-driver-support.patch"
#			patch -p1 < "${p_dir}/board/0003-mmc-atmel-Add-atmel-sdhci-support.patch"
#			patch -p1 < "${p_dir}/board/0004-arm-at91-Change-the-Chip-ID-registers-addresses.patch"
#			patch -p1 < "${p_dir}/board/0005-arm-at91-clock-Add-the-generated-clock-support.patch"
#			git add .
#			git commit -a -m 'sama5d2_xplained fixes' -s
#			git format-patch -1 -o "${p_dir}/"

			echo "patch -p1 < \"${p_dir}/0001-sama5d2_xplained-fixes.patch\""
			${git} "${p_dir}/0001-sama5d2_xplained-fixes.patch"
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
		udoo)
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			echo "patch -p1 < \"${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		wandboard)
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	p_dir="${DIR}/patches/${uboot_testing}"
	if [ "${testing}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			${git} "${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		beagle_x15)
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx23_olinuxino)
			echo "patch -p1 < \"${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx51evk)
			echo "patch -p1 < \"${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx53loco)
			echo "patch -p1 < \"${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx6qsabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap3_beagle)
			echo "patch -p1 < \"${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap4_panda)
			echo "patch -p1 < \"${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			echo "patch -p1 < \"${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d2_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d2_xplained-fixes.patch\""
			${git} "${p_dir}/0001-sama5d2_xplained-fixes.patch"
			;;
		sama5d3xek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d3_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d4ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		udoo)
			echo "patch -p1 < \"${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			echo "patch -p1 < \"${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		wandboard)
			echo "patch -p1 < \"${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	p_dir="${DIR}/patches/next"
	if [ "${next}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			${git} "${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		beagle_x15)
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx23_olinuxino)
			echo "patch -p1 < \"${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx51evk)
			echo "patch -p1 < \"${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx53loco)
			echo "patch -p1 < \"${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
			;;
		mx6qsabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap3_beagle)
			echo "patch -p1 < \"${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap4_panda)
			echo "patch -p1 < \"${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		omap5_uevm)
			echo "patch -p1 < \"${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d2_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d2_xplained-fixes.patch\""
			${git} "${p_dir}/0001-sama5d2_xplained-fixes.patch"
			;;
		sama5d3xek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d3_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"
			;;
		sama5d4ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-sama5d4ek-uEnv.txt-bootz-n-fixes.patch"
			;;
		udoo)
			echo "patch -p1 < \"${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"
			;;
		vf610twr)
			echo "patch -p1 < \"${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
			;;
		wandboard)
			echo "patch -p1 < \"${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch\""
			${git} "${p_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
			;;
		esac
	fi

	if [ "x${board}" = "xbeagle_x15_ti" ] ; then
		git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2015.07
		#r1: ARM: DRA7: Remove Unused pinmux definitions
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=024c903babcb743b5e8803160101bc3e54d2c46c
		#r2: ARM: am43xx_evm: Enable EDMA3 support DMA on qspi
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8dcdcb22f9d06df1ac411b2fe70c06adcd15237b
		#r3: load boot from usb/sata/microSD/eMMC
		#r4: ARM: keystone2: drop unused defines from config file
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=e22bd9012ff5785bb1a595721c39a63c2ae78896
		#r5: ti: qspi: set flash quad bit based on quad support flag
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=c8123f5004f7563085eaa0f122e45d7575e66ad6
		#r6: ARM: DRA7: emif: Fix disabling/enabling of refreshes ti-u-boot-2015.07
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ec018bb44bca64873c934be87c182e5fea0290b
		#r7: ARM: AM33xx: Push all the rtc_only related functions under LOWLEVEL_INIT macro ti
		#r8: ARM: AM335x: Fix usb ether boot support
		#r9: ARM: DRA74/beagle_x15: Remove pin input/output config from WAKEUP pins
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=d49aa5effa20d0b943c74ced84e67defce6d6d1c
		#r10: ARM: DRA7: Fix DDR init sequence during warm reset
		#r11: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=055751e98b7ab9147154a637489c0630af4dc825
		#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3b05302127445f615f22696ac3d4b45a0207aa7d
		#r13: fix beagle-x15
		#r14: fix beagle usb/scsi boot...
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=75d995e87f47902b40065982ccbaae7a466d0913
		#r15: really fix beagle usb/scsi boot...
		#r16: netinstall fixes
		#http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=a843d2b1a1efff638e03289e755674509ce2fa16
		#r17: (pending)
		RELEASE_VER="-r16" #bump on every change...

		p_dir="${DIR}/patches/v2015.07"
		echo "${git} \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
		#halt_patching_uboot
		${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"

	fi

	unset BUILDTARGET
	if [ "x${board}" = "xmx23_olinuxino" ] ; then
		BUILDTARGET="u-boot.sb"
	fi

	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${BUILDTARGET}"
		echo "-----------------------------"
		exit
	fi

	uboot_filename="${board}-${UGIT_VERSION}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${board}

	unset pre_built
	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.imx ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.sb ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/MLO-${uboot_filename} ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.sunxi ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.bin ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/force_rebuild ] ; then
		unset pre_built
	fi

	if [ ! "${pre_built}" ] ; then
		make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config}
		echo "Building ${project}: ${uboot_filename}"
		echo "-----------------------------"
		make ARCH=arm CROSS_COMPILE="${CC}" -j${CORES} ${BUILDTARGET}
		echo "-----------------------------"
		if [ "x${board}" = "xfirefly-rk3288" ] ; then
			./tools/mkimage -T rksd -d ./spl/u-boot-spl-dtb.bin u-boot.rk3288
			echo "-----------------------------"
		fi

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.imx ] ; then
			filename_search="u-boot.imx"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.imx"
			file_save
			UBOOT_DONE=1
		fi

		#Freescale mx23 targets just need u-boot.sb from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.sb ] ; then
			filename_search="u-boot.sb"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.sb"
			file_save
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/MLO ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="MLO"
			filename_id="deploy/${board}/MLO-${uboot_filename}"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#SPL (i.mx6) targets, need SPL and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/SPL ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="SPL"
			filename_id="deploy/${board}/SPL-${uboot_filename}"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: sunxi
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-sunxi-with-spl.bin ] ; then
			filename_search="u-boot-sunxi-with-spl.bin"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.sunxi"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: Atmel
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/boot.bin ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="boot.bin"
			filename_id="deploy/${board}/boot-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: RockChip rk3288
		#./firefly-rk3288/tools/mkimage -T rksd -d firefly-rk3288/spl/u-boot-spl-dtb.bin out
		#sudo dd if=out of=/dev/sdc
		#sudo dd if=firefly-rk3288/u-boot-dtb.img of=/dev/sdc seek=256
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.rk3288 ] ; then
			filename_search="u-boot.rk3288"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.rk3288"
			file_save
			UBOOT_DONE=1
		fi

		#SPL: Samsung (old Atmel)
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/spl/u-boot-spl.bin ] && [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="spl/u-boot-spl.bin"
			filename_id="deploy/${board}/u-boot-spl-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#Just u-boot.bin
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.bin ] ; then
			filename_search="u-boot.bin"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.bin"
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
	uboot_config="${board}_defconfig"
	gcc_arm_embedded_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

build_uboot_gnueabihf () {
	uboot_config="${board}_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

always_mainline () {
	cleanup
	if [ ! "x${uboot_testing}" = "x" ] ; then
		transitioned_to_testing="true"
	fi
	build_uboot_gnueabihf
}

A10_OLinuXino_Lime () {
	board="A10-OLinuXino-Lime" ; always_mainline
}

A20_OLinuXino_Lime () {
	board="A20-OLinuXino-Lime" ; always_mainline
}

A20_OLinuXino_Lime2 () {
	board="A20-OLinuXino-Lime2" ; always_mainline
}

A20_OLinuXino_MICRO () {
	board="A20-OLinuXino_MICRO" ; always_mainline
}

am335x_evm () {
	cleanup
	#transitioned_to_testing="true"

	board="am335x_evm" ; build_uboot_gnueabihf
}

am335x_boneblack_flasher () {
	cleanup
	#transitioned_to_testing="true"

	board="am335x_boneblack"
	uboot_config="am335x_evm_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

am43xx_evm () {
	cleanup
	#transitioned_to_testing="true"

	board="am43xx_evm" ; build_uboot_gnueabihf
}

at91sam9x5ek () {
	cleanup
	#transitioned_to_testing="true"

	board="at91sam9x5ek_mmc"
	build_uboot_eabi

	at91bootstrap_config="at91sam9x5eksd_uboot_defconfig"
	build_at91bootstrap_all
}

Bananapi () {
	board="Bananapi" ; always_mainline
}

Bananapro () {
	board="Bananapro" ; always_mainline
}

beagle_x15 () {
	cleanup
	#transitioned_to_testing="true"

	board="beagle_x15" ; build_uboot_gnueabihf
}

beagle_x15_ti () {
	cleanup

	board="beagle_x15_ti"
	uboot_config="beagle_x15_config"
	gcc_linaro_gnueabihf_4_9
	GIT_SHA="v2015.07"
	build_u_boot
}

cm_fx6 () {
	cleanup
	#transitioned_to_testing="true"

	board="cm_fx6" ; build_uboot_gnueabihf
}

firefly_rk3288 () {
	cleanup
	#transitioned_to_testing="true"

	board="firefly-rk3288" ; build_uboot_gnueabihf
}

mx23_olinuxino () {
	cleanup
	#transitioned_to_testing="true"

	board="mx23_olinuxino" ; build_uboot_eabi
}

mx51evk () {
	cleanup
	#transitioned_to_testing="true"

	board="mx51evk" ; build_uboot_gnueabihf
}

mx53loco () {
	cleanup
	#transitioned_to_testing="true"

	board="mx53loco" ; build_uboot_gnueabihf
}

mx6qsabresd () {
	cleanup
	#transitioned_to_testing="true"

	board="mx6qsabresd" ; build_uboot_gnueabihf
}

omap3_beagle () {
	cleanup
	#transitioned_to_testing="true"

	board="omap3_beagle" ; build_uboot_gnueabihf
}

omap4_panda () {
	cleanup
	#transitioned_to_testing="true"

	board="omap4_panda" ; build_uboot_gnueabihf
}

omap5_uevm () {
	cleanup
	#transitioned_to_testing="true"

	board="omap5_uevm" ; build_uboot_gnueabihf
}

rpi_2 () {
	cleanup
	#transitioned_to_testing="true"

	board="rpi_2" ; build_uboot_gnueabihf
}

sama5d2_xplained () {
	cleanup
	#transitioned_to_testing="true"

	board="sama5d2_xplained_mmc" ; build_uboot_gnueabihf
}

sama5d3xek () {
	cleanup
	#transitioned_to_testing="true"

	board="sama5d3xek_mmc" ; build_uboot_gnueabihf
}

sama5d3_xplained () {
	cleanup
	#transitioned_to_testing="true"

	board="sama5d3_xplained_mmc" ; build_uboot_gnueabihf
}

sama5d4ek () {
	cleanup
	#transitioned_to_testing="true"

	board="sama5d4ek_mmc" ; build_uboot_gnueabihf
}

sama5d4_xplained () {
	cleanup
	#transitioned_to_testing="true"

	board="sama5d4_xplained_mmc" ; build_uboot_gnueabihf
}

udoo () {
	cleanup
	#transitioned_to_testing="true"

	board="udoo" ; build_uboot_gnueabihf
	cleanup
}

vf610twr () {
	cleanup
	#transitioned_to_testing="true"

	board="vf610twr" ; build_uboot_gnueabihf
}

wandboard () {
	cleanup
	#transitioned_to_testing="true"

	board="wandboard" ; build_uboot_gnueabihf
}

A10_OLinuXino_Lime
A20_OLinuXino_Lime
A20_OLinuXino_Lime2
A20_OLinuXino_MICRO
am335x_evm
am335x_boneblack_flasher
am43xx_evm
at91sam9x5ek
Bananapi
Bananapro
#beagle_x15
beagle_x15_ti
cm_fx6
mx23_olinuxino
mx51evk
mx53loco
mx6qsabresd
omap3_beagle
omap4_panda
omap5_uevm
rpi_2
sama5d2_xplained
sama5d3xek
sama5d3_xplained
sama5d4ek
sama5d4_xplained
udoo
vf610twr
wandboard
#
