#!/bin/sh -e
#
# Copyright (c) 2010-2017 Robert Nelson <robertcnelson@gmail.com>
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

if [ -d $HOME/dl/gcc/ ] ; then
	gcc_dir="$HOME/dl/gcc"
else
	gcc_dir="${DIR}/dl"
fi

wget_dl="wget -c --directory-prefix=${gcc_dir}/"

dl_gcc_generic () {
	site="https://releases.linaro.org"
	archive_site="https://releases.linaro.org/archive"
	non_https_site="http://releases.linaro.org"
	non_https_archive_site="http://releases.linaro.org/archive"
	WGET="wget -c --directory-prefix=${gcc_dir}/"
	if [ ! -f "${gcc_dir}/${directory}/${datestamp}" ] ; then
		echo "Installing: ${toolchain_name}"
		echo "-----------------------------"
		${WGET} "${site}/${version}/${filename}" || ${WGET} "${archive_site}/${version}/${filename}" || ${WGET} "${non_https_site}/${version}/${filename}" || ${WGET} "${non_https_archive_site}/${version}/${filename}"
		if [ -d "${gcc_dir}/${directory}" ] ; then
			rm -rf "${gcc_dir}/${directory}" || true
		fi
		tar -xf "${gcc_dir}/${filename}" -C "${gcc_dir}/"
		if [ -f "${gcc_dir}/${directory}/${binary}gcc" ] ; then
			touch "${gcc_dir}/${directory}/${datestamp}"
		fi
	fi

	if [ "x${ARCH}" = "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		if [ -f /usr/bin/ccache ] ; then
			CC="ccache ${gcc_dir}/${directory}/${binary}"
		else
			CC="${gcc_dir}/${directory}/${binary}"
		fi
	fi
}

#NOTE: ignore formatting, as this is just: meld build.sh ../stable-kernel/scripts/gcc.sh
gcc_arm_embedded_4_9 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/4.9-2016.02/arm-eabi/gcc-linaro-5.3-2016.02-x86_64_arm-eabi.tar.xz
		#

		gcc_version="4.9"
		gcc_minor=".4"
		release="17.01"
		target="arm-eabi"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/arm-eabi-"

	dl_gcc_generic
}

gcc_arm_embedded_6 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-eabi/gcc-linaro-6.3.1-2017.05-x86_64_arm-eabi.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.08/arm-eabi/gcc-linaro-6.4.1-2017.08-x86_64_arm-eabi.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.11/arm-eabi/gcc-linaro-6.4.1-2017.11-x86_64_arm-eabi.tar.xz
		#

		gcc_version="6.4"
		gcc_minor=".1"
		release="17.11"
		target="arm-eabi"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

gcc_arm_embedded_7 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/7.1-2017.05/arm-eabi/gcc-linaro-7.1.1-2017.05-x86_64_arm-eabi.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/7.1-2017.08/arm-eabi/gcc-linaro-7.1.1-2017.08-x86_64_arm-eabi.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/arm-eabi/gcc-linaro-7.2.1-2017.11-x86_64_arm-eabi.tar.xz
		#
		#site="https://snapshots.linaro.org"

		gcc_version="7.2"
		gcc_minor=".1"
		release="17.11"
		target="arm-eabi"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_4_9 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabihf/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf.tar.xz
		#

		gcc_version="4.9"
		gcc_minor=".4"
		release="17.01"
		target="arm-linux-gnueabihf"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_6 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.08/arm-linux-gnueabihf/gcc-linaro-6.4.1-2017.08-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.11/arm-linux-gnueabihf/gcc-linaro-6.4.1-2017.11-x86_64_arm-linux-gnueabihf.tar.xz
		#

		gcc_version="6.4"
		gcc_minor=".1"
		release="17.11"
		target="arm-linux-gnueabihf"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_7 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/7.1-2017.05/arm-linux-gnueabihf/gcc-linaro-7.1.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/7.1-2017.08/arm-linux-gnueabihf/gcc-linaro-7.1.1-2017.08-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/arm-linux-gnueabihf/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabihf.tar.xz
		#
		#site="https://snapshots.linaro.org"

		gcc_version="7.2"
		gcc_minor=".1"
		release="17.11"
		target="arm-linux-gnueabihf"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

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

	unset BUILDTARGET
	if [ "x${board}" = "xmx23_olinuxino" ] ; then
		BUILDTARGET="u-boot.sb"
	fi

	if [ "x${board}" = "xsocfpga_de0_nano_soc" ] ; then
		BUILDTARGET="u-boot-with-spl.sfp"
	fi

	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" distclean"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${BUILDTARGET}"
	echo "-----------------------------"

	#v2017.09
	p_dir="${DIR}/patches/${uboot_old}"
	if [ "${old}" ] ; then
		#r1: initial release
		#r2: am335x_evm: fix BeagleBone Classic
		#r3: am335x_evm: add justboom capes
		#r4: am335x_evm: PocketBeagle
		#r5: am335x_evm: PocketBeagle public release
		#r6: am335x_evm: BeagleLogic
		#r7: am335x_evm: fix BeagleLogic
		#r8: (pending)
		RELEASE_VER="-r7" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch\""
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
		mx6ul_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ul_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ul_14x14_evk-fixes.patch"
			;;
		mx6ull_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ull_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ull_14x14_evk-fixes.patch"
			;;
		mx6sabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6sabresd-fixes.patch\""
			${git} "${p_dir}/0001-mx6sabresd-fixes.patch"
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
		sama5d2_xplained_mmc|sama5d3xek_mmc|sama5d3_xplained_mmc|sama5d4ek_mmc|sama5d4_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5dX-fixes.patch\""
			${git} "${p_dir}/0001-sama5dX-fixes.patch"
			;;
		socfpga_de0_nano_soc)
			pfile="0001-de0_nano-fixes.patch" ; echo "patch -p1 < \"${p_dir}/${pfile}\"" ; ${git} "${p_dir}/${pfile}"
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

	#v2017.11
	p_dir="${DIR}/patches/${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: am335x_evm: fix efi regression...
		#r3: am335x_evm: add initial Octavo Systems OSD3358-SM-RED:
		#r4: am335x_evm: Green and DLP fixes
		#r5: wandboard: fix memory issues
		#r6: (pending)
		RELEASE_VER="-r5" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch\""
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
		mx6ul_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ul_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ul_14x14_evk-fixes.patch"
			;;
		mx6ull_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ull_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ull_14x14_evk-fixes.patch"
			;;
		mx6sabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6sabresd-fixes.patch\""
			${git} "${p_dir}/0001-mx6sabresd-fixes.patch"
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
		sama5d2_xplained_mmc|sama5d3xek_mmc|sama5d3_xplained_mmc|sama5d4ek_mmc|sama5d4_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5dX-fixes.patch\""
			${git} "${p_dir}/0001-sama5dX-fixes.patch"
			;;
		socfpga_de0_nano_soc)
			pfile="0001-de0_nano-fixes.patch" ; echo "patch -p1 < \"${p_dir}/${pfile}\"" ; ${git} "${p_dir}/${pfile}"
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

	#v2018.01
	p_dir="${DIR}/patches/${uboot_testing}"
	if [ "${testing}" ] ; then
		#r1: initial release
		#r2: am335x_evm: fix BLANK...
		#r3: am335x_evm: enable btrfs by default
		#r4: am335x_evm: enable btrfs_cmds by default
		#r5: (pending)
		RELEASE_VER="-r4" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch\""
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
		mx6ul_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ul_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ul_14x14_evk-fixes.patch"
			;;
		mx6ull_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ull_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ull_14x14_evk-fixes.patch"
			;;
		mx6sabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6sabresd-fixes.patch\""
			${git} "${p_dir}/0001-mx6sabresd-fixes.patch"
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
		sama5d2_xplained_mmc|sama5d3xek_mmc|sama5d3_xplained_mmc|sama5d4ek_mmc|sama5d4_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5dX-fixes.patch\""
			${git} "${p_dir}/0001-sama5dX-fixes.patch"
			;;
		socfpga_de0_nano_soc)
			pfile="0001-de0_nano-fixes.patch" ; echo "patch -p1 < \"${p_dir}/${pfile}\"" ; ${git} "${p_dir}/${pfile}"
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
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"
			${git} "${p_dir}/0002-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch"
			;;
		at91sam9x5ek_mmc)
			echo "patch -p1 < \"${p_dir}/0001-at91sam9x5ek-uEnv.txt-bootz-n-fixes.patch\""
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
		mx6ul_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ul_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ul_14x14_evk-fixes.patch"
			;;
		mx6ull_14x14_evk)
			echo "patch -p1 < \"${p_dir}/0001-mx6ull_14x14_evk-fixes.patch\""
			${git} "${p_dir}/0001-mx6ull_14x14_evk-fixes.patch"
			;;
		mx6sabresd)
			echo "patch -p1 < \"${p_dir}/0001-mx6sabresd-fixes.patch\""
			${git} "${p_dir}/0001-mx6sabresd-fixes.patch"
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
		sama5d2_xplained_mmc|sama5d3xek_mmc|sama5d3_xplained_mmc|sama5d4ek_mmc|sama5d4_xplained_mmc)
			echo "patch -p1 < \"${p_dir}/0001-sama5dX-fixes.patch\""
			${git} "${p_dir}/0001-sama5dX-fixes.patch"
			;;
		socfpga_de0_nano_soc)
			pfile="0001-de0_nano-fixes.patch" ; echo "patch -p1 < \"${p_dir}/${pfile}\"" ; ${git} "${p_dir}/${pfile}"
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

	if [ "x${board}" = "xam57xx_evm_ti" ] ; then
		if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
			git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2017.01
			#r1: initial build
			#r2: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=acfdcab5ce406c8cfb607bd0731b7a6d41757679
			#r3: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=438d0991e5a913323f6e38293a3d103d82284d9d
			#r4: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ca4ec25c8a6a3586601e8926bac4f5861ccaa2d
			#r5: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8369eec4f36f4eb8c30e769b3b0ad35d5148f636
			#r6: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=2127a54b2aca99cc0290ff79cba0fe9e2adfd794
			#r7: blank eeprom
			#r8: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=9fd60700db4562ffac00317a9a44761b8c3255f1
			#r9: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=40e76546f34e77cf12454137a3f16322b9610d4c
			#r10: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=5861b3bd349184df97ea26a93fc9b06c65e0ff5e
			#r11: fix new board
			#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=b79c87e6f7e2d24f262754845c6fc5f45b71bf15
			#r13: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=590c7d7fe15d06a4d708403d3234bcd01cd039e1
			#r14: (pending)
			RELEASE_VER="-r13" #bump on every change...

			p_dir="${DIR}/patches/ti-2017.01"
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			#halt_patching_uboot
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
		fi
	fi

	if [ "x${board}" = "xam57xx_evm_ti_flasher" ] ; then
		if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
			git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2017.01
			#r1: initial build
			#r2: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=acfdcab5ce406c8cfb607bd0731b7a6d41757679
			#r3: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=438d0991e5a913323f6e38293a3d103d82284d9d
			#r4: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ca4ec25c8a6a3586601e8926bac4f5861ccaa2d
			#r5: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8369eec4f36f4eb8c30e769b3b0ad35d5148f636
			#r6: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=2127a54b2aca99cc0290ff79cba0fe9e2adfd794
			#r7: blank eeprom
			#r8: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=9fd60700db4562ffac00317a9a44761b8c3255f1
			#r9: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=40e76546f34e77cf12454137a3f16322b9610d4c
			#r10: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=5861b3bd349184df97ea26a93fc9b06c65e0ff5e
			#r11: fix new board
			#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=b79c87e6f7e2d24f262754845c6fc5f45b71bf15
			#r13: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=590c7d7fe15d06a4d708403d3234bcd01cd039e1
			#r14: (pending)
			RELEASE_VER="-r13" #bump on every change...

			p_dir="${DIR}/patches/ti-2017.01"
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-board_is_x15_revb1_blank.patch\""
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			#halt_patching_uboot
			${git} "${p_dir}/0002-NFM-board_is_x15_revb1_blank.patch"
		fi
	fi

	if [ "x${board}" = "xam57xx_beagle_revc_ti_flasher" ] ; then
		if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
			git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2017.01
			#r1: initial build
			#r2: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=acfdcab5ce406c8cfb607bd0731b7a6d41757679
			#r3: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=438d0991e5a913323f6e38293a3d103d82284d9d
			#r4: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ca4ec25c8a6a3586601e8926bac4f5861ccaa2d
			#r5: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8369eec4f36f4eb8c30e769b3b0ad35d5148f636
			#r6: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=2127a54b2aca99cc0290ff79cba0fe9e2adfd794
			#r7: blank eeprom
			#r8: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=9fd60700db4562ffac00317a9a44761b8c3255f1
			#r9: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=40e76546f34e77cf12454137a3f16322b9610d4c
			#r10: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=5861b3bd349184df97ea26a93fc9b06c65e0ff5e
			#r11: fix new board
			#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=b79c87e6f7e2d24f262754845c6fc5f45b71bf15
			#r13: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=590c7d7fe15d06a4d708403d3234bcd01cd039e1
			#r14: (pending)
			RELEASE_VER="-r13" #bump on every change...

			p_dir="${DIR}/patches/ti-2017.01"
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-board_is_x15_revc_blank.patch\""
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			#halt_patching_uboot
			${git} "${p_dir}/0002-NFM-board_is_x15_revc_blank.patch"
		fi
	fi

	if [ "x${board}" = "xam571x_sndrblock_flasher" ] ; then
		if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
			git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2017.01
			#r1: initial build
			#r2: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=acfdcab5ce406c8cfb607bd0731b7a6d41757679
			#r3: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=438d0991e5a913323f6e38293a3d103d82284d9d
			#r4: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ca4ec25c8a6a3586601e8926bac4f5861ccaa2d
			#r5: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8369eec4f36f4eb8c30e769b3b0ad35d5148f636
			#r6: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=2127a54b2aca99cc0290ff79cba0fe9e2adfd794
			#r7: blank eeprom
			#r8: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=9fd60700db4562ffac00317a9a44761b8c3255f1
			#r9: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=40e76546f34e77cf12454137a3f16322b9610d4c
			#r10: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=5861b3bd349184df97ea26a93fc9b06c65e0ff5e
			#r11: fix new board
			#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=b79c87e6f7e2d24f262754845c6fc5f45b71bf15
			#r13: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=590c7d7fe15d06a4d708403d3234bcd01cd039e1
			#r14: (pending)
			RELEASE_VER="-r13" #bump on every change...

			p_dir="${DIR}/patches/ti-2017.01"
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-NFM-board_is_am571x_blank.patch\""
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			#halt_patching_uboot
			${git} "${p_dir}/0002-NFM-board_is_am571x_blank.patch"
		fi
	fi

	if [ "x${board}" = "xomap5_igep0050" ] ; then
		git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2015.07
		#r1: first pass
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...

		p_dir="${DIR}/patches/ti-2015.07"

		${git} "${p_dir}/0001-IGEPv5-Added-IGEPv5-board-support.patch"
	fi

	if [ "x${board}" = "xartik5" ] || [ "x${board}" = "xartik10" ] ; then
		git pull ${git_opts} https://github.com/SamsungARTIK/u-boot-artik artik-exynos/v2012.07
		#r1: first pass
		#r2: artik5: disable log level
		#r3: artik5: mmc1
		#r4: (pending)
		RELEASE_VER="-r3" #bump on every change...

		p_dir="${DIR}/patches/artik-2012.07"

		if [ "x${board}" = "xartik5" ] ; then
			echo "patch -p1 < \"${p_dir}/0001-artik5-fixes.patch\""
			#halt_patching_uboot
			${git} "${p_dir}/0001-artik5-fixes.patch"
		fi

		if [ "x${board}" = "xartik10" ] ; then
			echo "patch -p1 < \"${p_dir}/0001-artik10-fixes.patch\""
			#halt_patching_uboot
			${git} "${p_dir}/0001-artik10-fixes.patch"
		fi
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
		make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config} > /dev/null
		echo "Building ${project}: ${uboot_filename}:"
		make ARCH=arm CROSS_COMPILE="${CC}" -j${CORES} ${BUILDTARGET} > /dev/null
		if [ "x${board}" = "xfirefly-rk3288" ] ; then
			./tools/mkimage -n rk3288 -T rksd -d ./spl/u-boot-spl-nodtb.bin u-boot-spl.rk3288
		fi

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot.imx ] ; then
			filename_search="u-boot.imx"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.imx"
			file_save
			UBOOT_DONE=1
		fi

		#Freescale targets just need u-boot-dtb.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-dtb.imx ] ; then
			filename_search="u-boot-dtb.imx"
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

		#Altera Cyclone V SE
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-with-spl.sfp ] ; then
			filename_search="u-boot-with-spl.sfp"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.sfp"
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
		#./tools/mkimage -n rk3288 -T rksd -d ./spl/u-boot-spl-dtb.bin u-boot-spl.rk3288
		#sudo dd if=u-boot-spl.rk3288 of=/dev/sdc seek=64
		#sudo dd if=u-boot-dtb.img of=/dev/sdc seek=256
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-spl.rk3288 ] ; then
			filename_search="u-boot-spl.rk3288"
			filename_id="deploy/${board}/SPL-${uboot_filename}.rk3288"
			file_save

			filename_search="u-boot-dtb.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.rk3288"
			file_save
			UBOOT_DONE=1
		fi

		#ls1021a targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-with-spl-pbl.bin ] ; then
			filename_search="u-boot-with-spl-pbl.bin"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.ls1021a"
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
		echo "-----------------------------"
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
	unset uboot_config
	build_old="false"
	build_stable="false"
	build_testing="false"
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
	if [ "x${build_old}" = "xtrue" ] ; then
		old=1
		if [ "${uboot_old}" ] ; then
			GIT_SHA=${uboot_old}
			build_u_boot
		fi
		unset old
		build_old="false"
	fi
}

build_uboot_stable () {
	if [ "x${build_stable}" = "xtrue" ] ; then
		stable=1
		if [ "${uboot_stable}" ] ; then
			GIT_SHA=${uboot_stable}
			build_u_boot
		fi
		unset stable
		build_stable="false"
	fi
}

build_uboot_testing () {
	if [ "x${build_testing}" = "xtrue" ] ; then
		testing=1
		if [ "${uboot_testing}" ] ; then
			GIT_SHA=${uboot_testing}
			build_u_boot
		fi
		unset testing
		build_testing="false"
	fi

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
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_arm_embedded_6
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

build_uboot_gnueabihf () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_linaro_gnueabihf_6
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

build_uboot_gnueabihf_only_old () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_linaro_gnueabihf_6
	build_uboot_old
}

build_uboot_gnueabihf_only_stable () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_linaro_gnueabihf_6
	build_uboot_stable
}

always_stable_n_testing () {
	cleanup
	if [ ! "x${build_stable}" = "x" ] ; then
		build_stable="true"
	fi
	if [ ! "x${uboot_testing}" = "x" ] ; then
		build_testing="true"
	fi
	build_uboot_gnueabihf
}

always_testing () {
	cleanup
	if [ ! "x${uboot_testing}" = "x" ] ; then
		build_testing="true"
	fi
	build_uboot_gnueabihf
}

artik5 () {
	board="artik5"
	uboot_config="artik5_config"
	gcc_linaro_gnueabihf_4_9
	GIT_SHA="v2012.07"
	build_u_boot
}

artik10 () {
	board="artik10"
	uboot_config="artik10_config"
	gcc_linaro_gnueabihf_4_9
	GIT_SHA="v2012.07"
	build_u_boot
}

A10_OLinuXino_Lime () {
	board="A10-OLinuXino-Lime" ; always_stable_n_testing
}

A20_OLinuXino_Lime () {
	board="A20-OLinuXino-Lime" ; always_stable_n_testing
}

A20_OLinuXino_Lime2 () {
	board="A20-OLinuXino-Lime2" ; always_stable_n_testing
}

A20_OLinuXino_MICRO () {
	board="A20-OLinuXino_MICRO" ; always_stable_n_testing
}

A33_OLinuXino () {
	board="A33-OLinuXino" ; always_stable_n_testing
}

am335x_evm () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"

	board="am335x_evm" ; build_uboot_gnueabihf
}

am335x_boneblack_flasher () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"

	board="am335x_boneblack"
	uboot_config="am335x_evm_defconfig"
	build_uboot_gnueabihf
}

am43xx_evm () {
	board="am43xx_evm" ; always_stable_n_testing
}

am57xx_evm () {
	board="am57xx_evm" ; always_stable_n_testing
}

am57xx_evm_ti () {
	cleanup

	board="am57xx_evm_ti"
	uboot_config="am57xx_evm_defconfig"
	gcc_linaro_gnueabihf_6
	GIT_SHA="v2017.01"
	build_u_boot
}

am57xx_evm_ti_flasher () {
	cleanup

	board="am57xx_evm_ti_flasher"
	uboot_config="am57xx_evm_defconfig"
	gcc_linaro_gnueabihf_6
	GIT_SHA="v2017.01"
	build_u_boot
}

am57xx_beagle_revc_ti_flasher () {
	cleanup

	board="am57xx_beagle_revc_ti_flasher"
	uboot_config="am57xx_evm_defconfig"
	gcc_linaro_gnueabihf_6
	GIT_SHA="v2017.01"
	build_u_boot
}

am571x_sndrblock_flasher () {
	cleanup

	board="am571x_sndrblock_flasher"
	uboot_config="am57xx_evm_defconfig"
	gcc_linaro_gnueabihf_6
	GIT_SHA="v2017.01"
	build_u_boot
}

at91sam9x5ek () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="at91sam9x5ek_mmc" ; build_uboot_eabi
}

Bananapi () {
	board="Bananapi" ; always_stable_n_testing
}

Bananapro () {
	board="Bananapro" ; always_stable_n_testing
}

cm_fx6 () {
	board="cm_fx6" ; always_stable_n_testing
}

Cubieboard4 () {
	board="Cubieboard4" ; always_testing
}

Cubietruck_plus () {
	board="Cubietruck_plus" ; always_testing
}

firefly_rk3288 () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="firefly-rk3288" ; build_uboot_gnueabihf
}

ls1021atwr () {
	board="ls1021atwr_sdcard_qspi" ; always_stable_n_testing
}

mx23_olinuxino () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx23_olinuxino" ; build_uboot_eabi
}

mx51evk () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx51evk" ; build_uboot_gnueabihf
}

mx53loco () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx53loco" ; build_uboot_gnueabihf
}

mx6ul_14x14_evk () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx6ul_14x14_evk" ; build_uboot_gnueabihf
}

mx6ull_14x14_evk () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx6ull_14x14_evk" ; build_uboot_gnueabihf
}

mx6sabresd () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="mx6sabresd" ; build_uboot_gnueabihf
}

omap3_beagle () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="omap3_beagle" ; build_uboot_gnueabihf
}

omap4_panda () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="omap4_panda" ; build_uboot_gnueabihf
}

omap5_igep0050 () {
	cleanup

	board="omap5_igep0050"
	uboot_config="omap5_igep0050_config"
	gcc_linaro_gnueabihf_4_9
	GIT_SHA="v2015.07"
	build_u_boot
}

omap5_uevm () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="omap5_uevm" ; build_uboot_gnueabihf
}

orangepi_pc () {
	board="orangepi_pc" ; always_stable_n_testing
}

sama5d2_xplained () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="sama5d2_xplained_mmc" ; build_uboot_gnueabihf
}

sama5d3xek () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="sama5d3xek_mmc" ; build_uboot_gnueabihf
}

sama5d3_xplained () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="sama5d3_xplained_mmc" ; build_uboot_gnueabihf
}

sama5d4ek () {
	cleanup
#	build_old="true"
#	build_stable="true"
#	build_testing="true"
	board="sama5d4ek_mmc" ; build_uboot_gnueabihf
}

sama5d4_xplained () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="sama5d4_xplained_mmc" ; build_uboot_gnueabihf
}

socfpga_de0_nano_soc () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="socfpga_de0_nano_soc" ; build_uboot_gnueabihf
}

Sinovoip_BPI_M2 () {
	board="Sinovoip_BPI_M2" ; always_stable_n_testing
}

Sinovoip_BPI_M3 () {
	board="Sinovoip_BPI_M3" ; always_stable_n_testing
}

udoo () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="udoo" ; build_uboot_gnueabihf
}

vf610twr () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="vf610twr" ; build_uboot_gnueabihf
}

wandboard () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="wandboard" ; build_uboot_gnueabihf
}

#exit

###artik5
###artik10

am335x_evm
am335x_boneblack_flasher
am43xx_evm
am57xx_evm
###am57xx_evm_ti
###am57xx_evm_ti_flasher
###am57xx_beagle_revc_ti_flasher
###am571x_sndrblock_flasher
at91sam9x5ek
mx23_olinuxino
mx51evk
mx53loco
mx6ul_14x14_evk
mx6ull_14x14_evk
mx6sabresd
omap3_beagle
omap4_panda
###omap5_igep0050
omap5_uevm
sama5d2_xplained
###(these are a shared patch...)
###sama5d3xek
###sama5d3_xplained
###sama5d4ek
###sama5d4_xplained
###(these are a shared patch...)
socfpga_de0_nano_soc
#udoo
###vf610twr
#wandboard

#devices with no patches...
A10_OLinuXino_Lime
A20_OLinuXino_Lime
A20_OLinuXino_Lime2
A20_OLinuXino_MICRO
A33_OLinuXino
Bananapi
Bananapro
Cubieboard4
Cubietruck_plus
firefly_rk3288
ls1021atwr
orangepi_pc
Sinovoip_BPI_M2
Sinovoip_BPI_M3

#
