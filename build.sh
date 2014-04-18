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

stable_at91bootstrap_sha="e95dd87d49ca124ccb57e62e656c6a23900af8f4"

#latest_at91bootstrap_sha=""

uboot_old="v2014.01"
uboot_stable="v2014.04"
#uboot_testing="v2014.04-rc3"

#uboot_latest="1b82491ee6ee1e986e5521b33692a00e1f38fe75"
uboot_latest="3fa1981e243cbe8f4a31139740600eddde5a4da4"

unset GIT_OPTS
unset GIT_NOEDIT
( LC_ALL=C git help pull | grep -m 1 -e "--no-edit" ) >/dev/null 2>&1 && GIT_NOEDIT=1

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
		CC="${DIR}/dl/${directory}/${binary}"
	fi
}

#NOTE: ignore formatting, as this is just: meld build.sh ../stable-kernel/scripts/gcc.sh
gcc_arm_embedded_4_8 () {
		#http://releases.linaro.org/14.03/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.8-2014.03_linux.tar.xz
		gcc_version="4.8"
		release="2014.03"
		toolchain_name="gcc-linaro-arm-none-eabi"
		site="https://releases.linaro.org"
		version="14.03/components/toolchain/binaries"
		directory="${toolchain_name}-${gcc_version}-${release}_linux"
		filename="${directory}.tar.xz"
		datestamp="${release}-${toolchain_name}"

		binary="bin/arm-none-eabi-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_4_8 () {
		#http://releases.linaro.org/14.03/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.8-2014.03_linux.tar.xz
		gcc_version="4.8"
		release="2014.03"
		toolchain_name="gcc-linaro-arm-linux-gnueabihf"
		site="https://releases.linaro.org"
		version="14.03/components/toolchain/binaries"
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

	make CROSS_COMPILE=${CC} clean >/dev/null 2>&1
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

	uboot_patch_dir="${uboot_old}"
	if [ "${old}" ] ; then
		#r1: initial release
		#r2: beagle: loadaddr=0x80300000
		#r3: beagle-xm: drop fixfdt (u-boot wants it done in kernel..)
		#r4: beagle-xm: still need to support the ulcd7 on a v3.7.x based kernel
		#r5: beagle-xm: board files are done... dont revert the usb fix for old crap.. (v3.7.x kernels)
		#r6: am335x_evm: $fdtbase-$cape.dtb
		#r7: beagle-xm: add buddy2 for ulcd7
		#r8: (pending)
		RELEASE_VER="-r7" #bump on every change...

		#Atmel:
		git am "${DIR}/patches/${uboot_patch_dir}/board/0001-at91sam9x5ek-fix-nand-init-for-Linux-2.6.39.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-sama5d3xek-uEnv.txt-bootz-n-fixes.patch"

		#Freescale:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx23_olinuxino-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx51evk-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx53loco-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-mx6qsabre_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-wandboard-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-vf610twr-uEnv.txt-bootz-n-fixes.patch"

		#TI:
		git am "${DIR}/patches/${uboot_patch_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap4_common-uEnv.txt-bootz-n-fixes.patch"
		git am "${DIR}/patches/${uboot_patch_dir}/0001-omap5_common-uEnv.txt-bootz-n-fixes.patch"
	fi

	uboot_patch_dir="${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: am335x_evm: $fdtbase-$cape.dtb
		#r3: am335x_evm: use Tom's Golden values...
		#r4: (pending)
		RELEASE_VER="-r3" #bump on every change...

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
		#r2: am335x_evm: $fdtbase-$cape.dtb
		#r3: am335x_evm: use Tom's Golden values...
		#r4: (pending)
		RELEASE_VER="-r3" #bump on every change...

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
		if [ "x${kbuild}" = "xenable" ] ; then
			echo "-----------------------------"
			time make ARCH=arm CROSS_COMPILE="${CC}" -j${NUMJOBS} ${BUILDTARGET}
			echo "-----------------------------"
		else
			echo "-----------------------------"
			time make ARCH=arm CROSS_COMPILE="${CC}" -j${NUMJOBS} ${BUILDTARGET} > /dev/null
			echo "-----------------------------"
		fi

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

		#SPL: Atmel/Samsung
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/spl/u-boot-spl.bin ] && [ -f ${DIR}/build/${project}/u-boot.img ] ; then
			filename_search="spl/u-boot-spl.bin"
			filename_id="deploy/${BOARD}/u-boot-spl-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
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
	unset transitioned_to_testing
	unset kbuild
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

build_uboot_all () {
	kbuild="enable"
	build_uboot_stable
	kbuild="enable"
	build_uboot_testing
	kbuild="enable"
	build_uboot_latest
}

am335x_evm () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="am335x_evm"
	UBOOT_CONFIG="${BOARD}_config"

	build_uboot_all
}

am335x_boneblack_flasher () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="am335x_boneblack"
	UBOOT_CONFIG="am335x_evm_config"

	build_uboot_all
}

arndale () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="arndale"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

at91sam9x5ek () {
	cleanup
	#transitioned_to_testing="true"
	gcc_arm_embedded_4_8

	BOARD="at91sam9x5ek_mmc"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all

	at91bootstrap_config="at91sam9x5eksd_uboot_defconfig"
	build_at91bootstrap_all
}

mx23_olinuxino () {
	cleanup
	#transitioned_to_testing="true"
	gcc_arm_embedded_4_8

	BOARD="mx23_olinuxino"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

mx51evk () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="mx51evk"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

mx53loco () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="mx53loco"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

mx6qsabresd () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="mx6qsabresd"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

omap3_beagle () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="omap3_beagle"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

omap4_panda () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="omap4_panda"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

omap5_uevm () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="omap5_uevm"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

sama5d3xek () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="sama5d3xek_mmc"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

sama5d3_xplained () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="sama5d3_xplained_mmc"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

vf610twr () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="vf610twr"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

wandboard () {
	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="wandboard_quad"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all

	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="wandboard_dl"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all

	cleanup
	#transitioned_to_testing="true"
	gcc_linaro_gnueabihf_4_8

	BOARD="wandboard_solo"
	UBOOT_CONFIG="${BOARD}_config"
	build_uboot_all
}

am335x_evm
am335x_boneblack_flasher
arndale
at91sam9x5ek
mx23_olinuxino
mx51evk
mx53loco
mx6qsabresd
omap3_beagle
omap4_panda
omap5_uevm
sama5d3xek
sama5d3_xplained
vf610twr
wandboard
#
