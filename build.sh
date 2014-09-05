#!/bin/sh -e
#
# Copyright (c) 2010-2014 Robert Nelson <robertcnelson@gmail.com>
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
if [ $(which nproc) ] ; then
	NUMJOBS=$(nproc)
else
	NUMJOBS=1
fi

. ./version.sh

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
		#https://releases.linaro.org/14.08/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.9-2014.08_linux.tar.xz
		#
		gcc_version="4.9"
		release="2014.08"
		toolchain_name="gcc-linaro-arm-none-eabi"
		version="14.08/components/toolchain/binaries"
		directory="${toolchain_name}-${gcc_version}-${release}_linux"
		filename="${directory}.tar.xz"
		datestamp="${release}-${toolchain_name}"

		binary="bin/arm-none-eabi-"

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
		#https://releases.linaro.org/14.08/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.08_linux.tar.xz
		#
		gcc_version="4.9"
		release="2014.08"
		toolchain_name="gcc-linaro-arm-linux-gnueabihf"
		version="14.08/components/toolchain/binaries"
		directory="${toolchain_name}-${gcc_version}-${release}_linux"
		filename="${directory}.tar.xz"
		datestamp="${release}-${toolchain_name}"

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

	if [ -f ${DIR}/scratch/${project}/binaries/*.bin ] ; then
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

	make ARCH=arm CROSS_COMPILE="${CC}" distclean
	UGIT_VERSION=$(git describe)

	uboot_patch_dir="${uboot_old}"
	if [ "${old}" ] ; then
		#r1: initial release
		#r2: am335x_evm: $fdtbase-$cape.dtb
		#r3: am335x_evm: use Tom's Golden values...
		#r4: am335x_evm: assume boneblack.dtb for eepromless...
		#r5: panda: yet another old board with new memory...
		#r6: am335x_evm: really assume boneblack.dtb for eepromless...
		#r7: udoo: ship working u-boot for dual/quad
		#r8: sama5d3_xplained: validatedtb
		#r9: (pending)
		RELEASE_VER="-r8" #bump on every change...
		#halt_patching_uboot

		#Atmel:
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		if [ "x${BOARD}" = "xam335x_boneblack" ] ; then
			git am "${DIR}/patches/${uboot_patch_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
		fi
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
	fi

	uboot_patch_dir="${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: am335x_evm: $fdtbase-$cape.dtb
		#r3: am335x_evm: use Tom's Golden values...
		#r4: vf610twr: we seem to have a sram limit (230kb fails to load)
		#r5: udoo: fix dtb selection on dl
		#r6: wand: zImage not zimage
		#r7: mx51evk: fix dtb location
		#r8: panda: fix uEnv.txt boot
		#r9: am335x_evm: microSD 2.0
		#r10: am335x_evm: microSD 2.0 + everyone
		#r11: am335x_evm, omap3_beagle, omap4_common, omap5_common: microSD 2.0
		#r12: omap4_common: multi partition search
		#r13: am335x_evm, omap3_beagle, omap4_common, omap5_common: multi partition search
		#r14: am335x_evm: ${cape_disable} ${cape_enable}
		#r15: am335x_evm, omap3_beagle, omap5_common: define #define CONFIG_SUPPORT_RAW_INITRD in each patch
		#r16: am335x_evm: /boot.scr & /boot/boot.scr support for flash-kernel
		#r17: imx: convert all to new partition table setup...
		#r18: am335x_evm: nfs support: http://elinux.org/Beagleboard:U-boot_partitioning_layout_2.0#nfs_support
		#r19: am335x_evm: nfs/tftp of course tftp has a hard coded variable...
		#r20: imx: fdtaddr -> fdt_addr
		#r21: imx: uenvcmd
		#r22: imx: wand/sabresd dual card support
		#r23: imx: mx51evk: fix boot
		#r24: am335x_evm: -r option for env import...
		#r25: omap3_beagle: use Tom's Golden values...
		#r26: (pending)
		RELEASE_VER="-r25" #bump on every change...
		#halt_patching_uboot

		git am "${DIR}/patches/${uboot_patch_dir}/upstream/0001-Add-option-r-to-env-import-to-allow-import-of-text-f.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/upstream/0002-am335x_evm-handle-import-of-environments-in-files-wi.patch"

		#Atmel:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		if [ "x${BOARD}" = "xam335x_boneblack" ] ; then
			git am "${DIR}/patches/${uboot_patch_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
		fi
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
	fi

	uboot_patch_dir="${uboot_testing}"
	if [ "${testing}" ] ; then
		#r1: initial release
		#r2: am335x_evm: fix lockup in eMMC when dd'ed
		#r3: (pending)
		RELEASE_VER="-r2" #bump on every change...
		#halt_patching_uboot

		#Allwinner:
		git am "${DIR}/patches/next/0001-kconfig-remove-redundant-SPL-from-CONFIG_SYS_EXTRA_O.patch"
		git am "${DIR}/patches/next/0002-sunxi-Correct-typo-CONFIG_FTDFILE-CONFIG_FDTFILE.patch"
		git am "${DIR}/patches/next/0003-sun7i-Add-support-for-Olimex-A20-OLinuXino-LIME.patch"

		#Atmel:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		if [ "x${BOARD}" = "xam335x_boneblack" ] ; then
			git am "${DIR}/patches/${uboot_patch_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
		fi
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
	fi

	uboot_patch_dir="next"
	if [ "${next}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		#Allwinner:
		git am "${DIR}/patches/next/0001-kconfig-remove-redundant-SPL-from-CONFIG_SYS_EXTRA_O.patch"
		git am "${DIR}/patches/next/0002-sunxi-Correct-typo-CONFIG_FTDFILE-CONFIG_FDTFILE.patch"
		git am "${DIR}/patches/next/0003-sun7i-Add-support-for-Olimex-A20-OLinuXino-LIME.patch"

		#Atmel:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3_xplained-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-udoo-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		if [ "x${BOARD}" = "xam335x_boneblack" ] ; then
			git am "${DIR}/patches/${uboot_patch_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
		fi
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
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
	UBOOT_CONFIG="${BOARD}_config"
	gcc_arm_embedded_4_8
	build_uboot_stable
	UBOOT_CONFIG="${BOARD}_defconfig"
	gcc_arm_embedded_4_9
	build_uboot_testing
	build_uboot_latest
}

build_uboot_gnueabihf () {
	UBOOT_CONFIG="${BOARD}_config"
	gcc_linaro_gnueabihf_4_8
	build_uboot_stable
	UBOOT_CONFIG="${BOARD}_defconfig"
	gcc_linaro_gnueabihf_4_9
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

am335x_evm () {
	cleanup
	transitioned_to_testing="true"

	BOARD="am335x_evm"
	build_uboot_gnueabihf
}

am335x_boneblack_flasher () {
	cleanup
	transitioned_to_testing="true"

	BOARD="am335x_boneblack"
	UBOOT_CONFIG="am335x_evm_config"
	gcc_linaro_gnueabihf_4_8
	build_uboot_stable
	UBOOT_CONFIG="am335x_evm_defconfig"
	gcc_linaro_gnueabihf_4_9
	build_uboot_testing
	build_uboot_latest
}

am43xx_evm () {
	cleanup
	transitioned_to_testing="true"

	BOARD="am43xx_evm"
	build_uboot_gnueabihf
}

arndale () {
	cleanup
	transitioned_to_testing="true"

	BOARD="arndale"
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

Cubieboard2 () {
	cleanup
	transitioned_to_testing="true"

	BOARD="Cubieboard2"
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
	transitioned_to_testing="true"

	BOARD="omap3_beagle"
	build_uboot_gnueabihf
}

omap4_panda () {
	cleanup
	transitioned_to_testing="true"

	BOARD="omap4_panda"
	build_uboot_gnueabihf
}

omap5_uevm () {
	cleanup
	transitioned_to_testing="true"

	BOARD="omap5_uevm"
	build_uboot_gnueabihf
}

sama5d3xek () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="sama5d3xek_mmc"
	build_uboot_gnueabihf
}

sama5d3_xplained () {
	cleanup
	#transitioned_to_testing="true"

	BOARD="sama5d3_xplained_mmc"
	build_uboot_gnueabihf
}

udoo () {
	cleanup
	transitioned_to_testing="true"

	BOARD="udoo_quad"
	build_uboot_gnueabihf

	cleanup
	transitioned_to_testing="true"

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
	transitioned_to_testing="true"

	BOARD="wandboard_quad"
	build_uboot_gnueabihf

	cleanup
	transitioned_to_testing="true"

	BOARD="wandboard_dl"
	build_uboot_gnueabihf

	cleanup
	transitioned_to_testing="true"

	BOARD="wandboard_solo"
	build_uboot_gnueabihf
}

A10_OLinuXino_Lime
A20_OLinuXino_Lime
am335x_evm
am335x_boneblack_flasher
am43xx_evm
arndale
at91sam9x5ek
Cubieboard2
mx23_olinuxino
mx51evk
mx53loco
mx6qsabresd
omap3_beagle
omap4_panda
omap5_uevm
sama5d3xek
sama5d3_xplained
udoo
#vf610twr
wandboard
#
