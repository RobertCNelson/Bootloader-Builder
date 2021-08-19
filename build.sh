#!/bin/sh -e
#
# Copyright (c) 2010-2020 Robert Nelson <robertcnelson@gmail.com>
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
	WGET="wget -c --directory-prefix=${gcc_dir}/"
	if [ ! -f "${gcc_dir}/${gcc_filename_prefix}/${datestamp}" ] ; then
		echo "Installing Toolchain: ${toolchain}"
		echo "-----------------------------"
		${WGET} "${gcc_html_path}${gcc_filename_prefix}.tar.xz"
		if [ -d "${gcc_dir}/${gcc_filename_prefix}" ] ; then
			rm -rf "${gcc_dir}/${gcc_filename_prefix}" || true
		fi
		tar -xf "${gcc_dir}/${gcc_filename_prefix}.tar.xz" -C "${gcc_dir}/"
		if [ -f "${gcc_dir}/${gcc_filename_prefix}/${binary}gcc" ] ; then
			touch "${gcc_dir}/${gcc_filename_prefix}/${datestamp}"
		fi
	else
		echo "Using Existing Toolchain: ${toolchain}"
	fi

	if [ "x${ARCH}" = "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${gcc_dir}/${gcc_filename_prefix}/${binary}"
	fi
}

#NOTE: ignore formatting, as this is just: meld build.sh ../stable-kernel/scripts/gcc.sh
gcc_arm_embedded_6 () {
		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/arm-eabi/"
		gcc_filename_prefix="gcc-linaro-6.5.0-2018.12-x86_64_arm-eabi"
		gcc_banner="arm-eabi-gcc (Linaro GCC 6.5-2018.12) 6.5.0"
		gcc_copyright="2017"
		datestamp="2018.12-gcc-arm-none-eabi"

		binary="bin/arm-eabi-"

	dl_gcc_generic
}

gcc_arm_embedded_7 () {
		subdir=""
		site="https://releases.linaro.org"
		archive_site="https://releases.linaro.org/archive"

		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/arm-eabi/"
		gcc_filename_prefix="gcc-linaro-7.5.0-2019.12-x86_64_arm-eabi"
		gcc_banner="arm-eabi-gcc (Linaro GCC 7.5-2019.12) 7.5.0"
		gcc_copyright="2017"
		datestamp="2019.12-gcc-arm-none-eabi"

		binary="bin/arm-eabi-"

	dl_gcc_generic
}

gcc_arm_embedded_8 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/"
		gcc_filename_prefix="gcc-arm-8.3-2019.03-x86_64-arm-eabi"
		gcc_banner="arm-eabi-gcc (GNU Toolchain for the A-profile Architecture 8.3-2019.03 (arm-rel-8.36)) 8.3.0"
		gcc_copyright="2018"
		datestamp="2019.03-gcc-arm-none-eabi"

		binary="bin/arm-eabi-"

	dl_gcc_generic
}

gcc_arm_embedded_9 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/"
		gcc_filename_prefix="gcc-arm-9.2-2019.12-x86_64-arm-none-eabi"
		gcc_banner="arm-none-eabi-gcc (GNU Toolchain for the A-profile Architecture 9.2-2019.12 (arm-9.10)) 9.2.1 20191025"
		gcc_copyright="2019"
		datestamp="2019.12-gcc-arm-none-eabi"

		binary="bin/arm-none-eabi-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_4_9 () {
		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabihf/"
		gcc_filename_prefix="gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf"
		gcc_banner="arm-linux-gnueabihf-gcc (Linaro GCC 4.9-2017.01) 4.9.4"
		gcc_copyright="2015"
		datestamp="2017.01-gcc-arm-linux-gnueabihf"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_5 () {
		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/5.5-2017.10/arm-linux-gnueabihf/"
		gcc_filename_prefix="gcc-linaro-5.5.0-2017.10-x86_64_arm-linux-gnueabihf"
		gcc_banner="arm-linux-gnueabihf-gcc (Linaro GCC 5.5-2017.10) 5.5.0"
		gcc_copyright="2015"
		datestamp="2017.10-gcc-arm-linux-gnueabihf"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_6 () {
		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/arm-linux-gnueabihf/"
		gcc_filename_prefix="gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf"
		gcc_banner="arm-linux-gnueabihf-gcc (Linaro GCC 6.5-2018.12) 6.5.0"
		gcc_copyright="2017"
		datestamp="2018.12-gcc-arm-linux-gnueabihf"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_linaro_gnueabihf_7 () {
		gcc_html_path="https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/arm-linux-gnueabihf/"
		gcc_filename_prefix="gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf"
		gcc_banner="arm-linux-gnueabihf-gcc (Linaro GCC 7.5-2019.12) 7.5.0"
		gcc_copyright="2017"
		datestamp="2019.12-gcc-arm-linux-gnueabihf"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_arm_arm_linux_gnueabihf_8 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/"
		gcc_filename_prefix="gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf"
		gcc_banner="arm-linux-gnueabihf-gcc (GNU Toolchain for the A-profile Architecture 8.3-2019.03 (arm-rel-8.36)) 8.3.0"
		gcc_copyright="2018"
		datestamp="2019.03-gcc-arm-linux-gnueabihf"

		binary="bin/arm-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_arm_arm_linux_gnueabihf_9 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/"
		gcc_filename_prefix="gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf"
		gcc_banner="arm-none-linux-gnueabihf-gcc (GNU Toolchain for the A-profile Architecture 9.2-2019.12 (arm-9.10)) 9.2.1 20191025"
		gcc_copyright="2019"
		datestamp="2019.12-gcc-arm-linux-gnueabihf"

		binary="bin/arm-none-linux-gnueabihf-"

	dl_gcc_generic
}

gcc_arm_aarch64_linux_gnu_8 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/"
		gcc_filename_prefix="gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu"
		gcc_banner="aarch64-linux-gnu-gcc (GNU Toolchain for the A-profile Architecture 8.3-2019.03 (arm-rel-8.36)) 8.3.0"
		gcc_copyright="2018"
		datestamp="2019.03-gcc-aarch64-linux-gnu"

		binary="bin/aarch64-linux-gnu-"

	dl_gcc_generic
}

gcc_arm_aarch64_linux_gnu_9 () {
		gcc_html_path="https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/"
		gcc_filename_prefix="gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu"
		gcc_banner="aarch64-none-linux-gnu-gcc (GNU Toolchain for the A-profile Architecture 9.2-2019.12 (arm-9.10)) 9.2.1 20191025"
		gcc_copyright="2019"
		datestamp="2019.12-gcc-aarch64-linux-gnu"

		binary="bin/aarch64-none-linux-gnu-"

	dl_gcc_generic
}

git_generic () {
	echo "Starting ${project} build for: ${board}"
	echo "-----------------------------"

	if [ ! -f ${DIR}/git/${project}/.git/config ] ; then
		git clone git://github.com/RobertCNelson/${project}.git ${DIR}/git/${project}/
	fi

	cd ${DIR}/git/${project}/
	git pull --no-edit || true
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
	cp -v ./${filename_search} ${DIR}/deploy/${board}/
	#md5sum=$(md5sum ${DIR}/${filename_id} | awk '{print $1}')
	check=$(ls "${DIR}/${filename_id}#*" 2>/dev/null | head -n 1)
	if [ "x${check}" != "x" ] ; then
		rm -rf "${DIR}/${filename_id}#*" || true
	fi
	#touch ${DIR}/${filename_id}_${md5sum}
	#echo "${board}#${MIRROR}/${filename_id}#${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
}

cp_git_commit_patch () {
	cp -rv ${base}/* ./
	git add --all
	git commit -a -m "${patch_file}" -s
	git format-patch -1 -o ../../patches/${uboot_ref}/
	unset regenerate
}

refresh_patch () {
	echo "######################################################"
	echo "cd ./scratch/u-boot/"
	echo "patch -p1 < \"${p_dir}/0001-${patch_file}.patch\""
	echo "meld ./ ../../patches/${uboot_ref}/${board}/0001/"
	echo "######################################################"
	halt_patching_uboot
}

cp_git_commit_patch_two () {
	cp -rv ${base}/* ./
	git add --all
	git commit -a -m "${patch_file}" -s
	git format-patch -2 -o ../../patches/${uboot_ref}/
	unset regenerate
}

refresh_patch_two () {
	echo "######################################################"
	echo "cd ./scratch/u-boot/"
	echo "patch -p1 < \"${p_dir}/0002-${patch_file}.patch\""
	echo "meld ./ ../../patches/${uboot_ref}/${board}/0002/"
	echo "######################################################"
	halt_patching_uboot
}

cp_git_commit_patch_three () {
	cp -rv ${base}/* ./
	git add --all
	git commit -a -m "$patch_file" -s
	git format-patch -3 -o ../../patches/${uboot_ref}/
	unset regenerate
}

refresh_patch_three () {
	echo "######################################################"
	echo "cd ./scratch/u-boot/"
	echo "patch -p1 < \"${p_dir}/0003-${patch_file}.patch\""
	echo "meld ./ ../../patches/${uboot_ref}/${board}/0003/"
	echo "######################################################"
	halt_patching_uboot
}

build_u_boot () {
	project="u-boot"
	git_generic
	RELEASE_VER="-r0"

	make ARCH=arm CROSS_COMPILE="${CC}" distclean
	UGIT_VERSION=$(git describe)

	unset BUILDTARGET
	if [ "x${board}" = "xsocfpga_de0_nano_soc" ] ; then
		BUILDTARGET="u-boot-with-spl.sfp"
	fi

	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" distclean"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${BUILDTARGET}"
	echo "-----------------------------"

	#v2019.01
	if [ "${old}" ] ; then
		p_dir="${DIR}/patches/${uboot_old}"
		uboot_ref="${uboot_old}"
		#r1: initial release
		#r2: am335x_evm: revert i2c2_pin_mux state, broke capes...
		#r3: am335x_evm: add BB-BONE-NH10C-01-00A0
		#r4: am335x_evm: add BBORG_DISPLAY70-00A2.dtbo
		#r5: am335x_evm: disable ftd fixup
		#r6: am335x_evm: just use bonegreen eeprom blank (eMMC)
		#r7: am335x_evm: really just use bonegreen eeprom blank (eMMC)
		#r8: (pending)
		RELEASE_VER="-r7" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		socfpga_de0_nano_soc)
			patch_file="de0_nano-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		esac
	fi

	#v2019.04
	if [ "${stable}" ] ; then
		p_dir="${DIR}/patches/${uboot_stable}"
		uboot_ref="${uboot_stable}"
		#r1: initial release
		#r2: omap4-panda: enable btrfs
		#r3: am335x, backport emmc pins, omap5-uevm: enable btrfs
		#r4: am335x add Revolve
		#r5: remove Revolve
		#r6: am335x add BB-BONE-LCD5-01-00A1.dtbo
		#r7: am335x: bbgg might be wl1835 or wl1837...
		#r8: am335x: test u-boot phy fix
		#r9: am335x: bbgg cleanup
		#r10: am335x: move the adc earlier
		#r11: am335x: fix moved the adc earlier
		#r12: am335x: remove old cape universal
		#r13: am335x: rename BeagleBone Black Industrial
		#r14: am335x: new overlay locations
		#r15: am335x: drop /lib/firmware on external reads..
		#r16: am335x: fix capes that use 0xFF as zero/empty/blank...
		#r17: (pending)
		RELEASE_VER="-r16" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am335x_evm)
			patch_file="${board}-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/arch/arm/include/asm/arch-am33xx/
					cp arch/arm/include/asm/arch-am33xx/hardware_am33xx.h ${base}/arch/arm/include/asm/arch-am33xx/
					cp arch/arm/include/asm/arch-am33xx/sys_proto.h ${base}/arch/arm/include/asm/arch-am33xx/

					mkdir -p ${base}/arch/arm/mach-omap2/am33xx/
					cp arch/arm/mach-omap2/am33xx/clock_am33xx.c ${base}/arch/arm/mach-omap2/am33xx/
					cp arch/arm/mach-omap2/am33xx/board.c ${base}/arch/arm/mach-omap2/am33xx/
					cp arch/arm/mach-omap2/hwinit-common.c ${base}/arch/arm/mach-omap2/

					mkdir -p ${base}/board/ti/am335x/
					cp board/ti/am335x/board.c ${base}/board/ti/am335x/
					cp board/ti/am335x/board.h ${base}/board/ti/am335x/
					cp board/ti/am335x/mux.c ${base}/board/ti/am335x/

					mkdir -p ${base}/configs/
					cp configs/am335x_evm_defconfig ${base}/configs/

					mkdir -p ${base}/env/
					cp env/common.c ${base}/env/

					mkdir -p ${base}/include/configs/
					cp include/configs/am335x_evm.h ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_armv7_omap.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					mkdir -p ${base}/scripts/dtc/
					cp scripts/dtc/dtc-lexer.l ${base}/scripts/dtc/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi

			patch_file="U-Boot-BeagleBone-Cape-Manager"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0002"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/board/ti/am335x/
					cp board/ti/am335x/board.c ${base}/board/ti/am335x/
					cp board/ti/am335x/board.h ${base}/board/ti/am335x/
					cp board/ti/am335x/mux.c ${base}/board/ti/am335x/

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_armv7_omap.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch_two
				fi
				cp_git_commit_patch_two
			else
				${git} "${p_dir}/0002-${patch_file}.patch"
			fi
			;;
		am335x_boneblack)
			echo "patch -p1 < \"${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch\""
			echo "patch -p1 < \"${p_dir}/0003-NFM-Production-eeprom-assume-device-is-BeagleBone-Bl.patch\""
			${git} "${p_dir}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch"
			${git} "${p_dir}/0002-U-Boot-BeagleBone-Cape-Manager.patch"

			patch_file="NFM-Production-eeprom-assume-device-is-BeagleBone-Bl"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0003"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/board/ti/am335x/
					cp board/ti/am335x/board.c ${base}/board/ti/am335x/
					cp board/ti/am335x/board.h ${base}/board/ti/am335x/
					cp board/ti/am335x/mux.c ${base}/board/ti/am335x/

					mkdir -p ${base}/board/ti/common/
					cp board/ti/common/board_detect.c ${base}/board/ti/common/

					mkdir -p ${base}/configs/
					cp configs/am335x_evm_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/am335x_evm.h ${base}/include/configs/

					refresh_patch_three
				fi
				cp_git_commit_patch_three
			else
				${git} "${p_dir}/0003-${patch_file}.patch"
			fi
			;;
		mx6ul_14x14_evk)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6ul_14x14_evk.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		mx6ull_14x14_evk)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6ullevk.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		mx6sabresd)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6sabre_common.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap3_beagle)
			patch_file="${board}-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/board/ti/beagle/
					cp board/ti/beagle/beagle.c ${base}/board/ti/beagle/

					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/omap3_beagle.h ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap4_panda)
			patch_file="omap4_common-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap4_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap5_uevm)
			patch_file="omap5_common-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap5_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/boot.h ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		socfpga_de0_nano_soc)
			patch_file="de0_nano-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		wandboard)
			patch_file="${board}-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/wandboard.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		esac
	fi

	#v2020.10-rc2
	if [ "${testing}" ] ; then
		p_dir="${DIR}/patches/${uboot_testing}"
		uboot_ref="${uboot_testing}"
		#r1: initial release
		#r2: am57xx_evm fixes...
		#r3: am57xx_evm/bbai fixes...
		#r4: bbai: cape stuff...
		#r5: bbai: v2020.10-rc2
		#r6: bbai: working eeprom reads..
		#r7: bbai: add a2 eeprom write...
		#r8: (pending)
		RELEASE_VER="-r7" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am57xx_evm)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/arch/arm/dts/
					cp arch/arm/dts/am5729-beagleboneai.dts ${base}/arch/arm/dts/

					mkdir -p ${base}/arch/arm/mach-omap2/omap5/
					cp arch/arm/mach-omap2/omap5/hw_data.c ${base}/arch/arm/mach-omap2/omap5/

					mkdir -p ${base}/include/configs/
					cp include/configs/am57xx_evm.h ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap5_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/boot.h ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					mkdir -p ${base}/board/ti/am57xx/
					cp board/ti/am57xx/board.c ${base}/board/ti/am57xx/
					cp board/ti/am57xx/mux_data.h ${base}/board/ti/am57xx/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		mx6ul_14x14_evk)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6ul_14x14_evk.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		mx6ull_14x14_evk)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6ullevk.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		mx6sabresd)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/mx6sabre_common.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap3_beagle)
			patch_file="${board}-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/board/ti/beagle/
					cp board/ti/beagle/beagle.c ${base}/board/ti/beagle/

					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/omap3_beagle.h ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap4_panda)
			patch_file="omap4_common-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap4_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		omap5_uevm)
			patch_file="omap5_common-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap5_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/boot.h ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		socfpga_de0_nano_soc)
			patch_file="de0_nano-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		wandboard)
			patch_file="${board}-uEnv.txt-bootz-n-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/include/configs/
					cp include/configs/wandboard.h ${base}/include/configs/

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		esac
	fi

	#v2021.04
	if [ "${wip}" ] ; then
		p_dir="${DIR}/patches/${uboot_wip}"
		uboot_ref="${uboot_wip}"
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am57xx_evm)
			patch_file="${board}-fixes"
			#regenerate="enable"
			if [ "x${regenerate}" = "xenable" ] ; then
				base="../../patches/${uboot_ref}/${board}/0001"

				#reset="enable"
				if [ "x${reset}" = "xenable" ] ; then
					mkdir -p ${base}/configs/
					cp configs/${board}_defconfig ${base}/configs/

					mkdir -p ${base}/arch/arm/dts/
					cp arch/arm/dts/am5729-beagleboneai.dts ${base}/arch/arm/dts/

					mkdir -p ${base}/arch/arm/mach-omap2/omap5/
					cp arch/arm/mach-omap2/omap5/hw_data.c ${base}/arch/arm/mach-omap2/omap5/

					mkdir -p ${base}/include/configs/
					cp include/configs/am57xx_evm.h ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/
					cp include/configs/ti_omap5_common.h ${base}/include/configs/

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/boot.h ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/

					mkdir -p ${base}/board/ti/am57xx/
					cp board/ti/am57xx/board.c ${base}/board/ti/am57xx/
					cp board/ti/am57xx/mux_data.h ${base}/board/ti/am57xx/

					mkdir -p ${base}/common/spl/
					cp common/spl/spl_fit.c ${base}/common/spl/spl_fit.c

					refresh_patch
				fi
				cp_git_commit_patch
			else
				${git} "${p_dir}/0001-${patch_file}.patch"
			fi
			;;
		esac
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

	if [ -f ${DIR}/deploy/${board}/MLO-${uboot_filename} ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.bin ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${board}/u-boot-${uboot_filename}.img ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/force_rebuild ] ; then
		unset pre_built
	fi

	if [ ! "${pre_built}" ] ; then
		make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config} > /dev/null

		#make ARCH=arm CROSS_COMPILE="${CC}" menuconfig

		echo "Building ${project}: ${uboot_filename}:"
		make ARCH=arm CROSS_COMPILE="${CC}" -j${CORES} ${BUILDTARGET} > /dev/null

		if [ ! -d ${p_dir}/${board}/ ] ; then
			mkdir -p ${p_dir}/${board}/ || true
		fi
		cp -v ./.config ${p_dir}/${board}/${uboot_config}

		make ARCH=arm CROSS_COMPILE="${CC}" savedefconfig

		if [ ! -d ${p_dir}/${board}/0001/configs/ ] ; then
			mkdir -p ${p_dir}/${board}/0001/configs/ || true
		fi
		cp -v ./defconfig ${p_dir}/${board}/0001/configs/${uboot_config}

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

		#Altera Cyclone V SE
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/u-boot-with-spl.sfp ] ; then
			filename_search="u-boot-with-spl.sfp"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.sfp"
			file_save
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/MLO ] ; then
			filename_search="MLO"
			filename_id="deploy/${board}/MLO-${uboot_filename}"
			file_save

			if [ -f ${DIR}/scratch/${project}/u-boot-dtb.img ] ; then
				filename_search="u-boot-dtb.img"
				filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
				file_save
				UBOOT_DONE=1
			elif [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
				filename_search="u-boot.img"
				filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
				file_save
				UBOOT_DONE=1
			fi
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

		if [ "x${board}" = "xam57xx_evm" ] ; then

			echo "#!/bin/bash" > ${DIR}/deploy/${board}/install.sh
			echo "" >> ${DIR}/deploy/${board}/install.sh
			echo "if ! id | grep -q root; then" >> ${DIR}/deploy/${board}/install.sh
			echo "        echo \"must be run as root\"" >> ${DIR}/deploy/${board}/install.sh
			echo "        exit" >> ${DIR}/deploy/${board}/install.sh
			echo "fi" >> ${DIR}/deploy/${board}/install.sh
			echo "" >> ${DIR}/deploy/${board}/install.sh
			echo "dd if=./MLO of=/dev/sdd count=2 seek=1 bs=128k" >> ${DIR}/deploy/${board}/install.sh
			echo "dd if=./u-boot-dtb.img of=/dev/sdd count=4 seek=1 bs=384k" >> ${DIR}/deploy/${board}/install.sh
			chmod +x ${DIR}/deploy/${board}/install.sh
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
	build_wip="false"
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

build_uboot_wip () {
	if [ "x${build_wip}" = "xtrue" ] ; then
		wip=1
		if [ "${uboot_wip}" ] ; then
			GIT_SHA=${uboot_wip}
			build_u_boot
		fi
		unset wip
		build_wip="false"
	fi
}

build_uboot_eabi () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_arm_embedded_6
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
}

build_uboot_gnueabihf () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_linaro_gnueabihf_6
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
	build_uboot_wip
}

build_uboot_aarch64 () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_arm_aarch64_linux_gnu_8
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
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

ls1021atwr () {
	board="ls1021atwr_sdcard_qspi" ; always_stable_n_testing
}

udoo () {
	board="udoo" ; always_stable_n_testing
}

am335x_evm () {
	cleanup
#	build_old="true"
	build_stable="true"
#	build_testing="true"

	board="am335x_evm" ; build_uboot_gnueabihf
}

am335x_boneblack_flasher () {
	cleanup
#	build_old="true"
	build_stable="true"
#	build_testing="true"

	board="am335x_boneblack"
	uboot_config="am335x_evm_defconfig"
	build_uboot_gnueabihf
}

am57xx_evm () {
	cleanup
#	build_old="true"
#	build_stable="true"
#	build_testing="true"
	build_wip="true"

	board="am57xx_evm" ; build_uboot_gnueabihf
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
#	build_stable="true"
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

omap5_uevm () {
	cleanup
	build_old="true"
	build_stable="true"
	build_testing="true"
	board="omap5_uevm" ; build_uboot_gnueabihf
}

socfpga_de0_nano_soc () {
	cleanup
	build_old="true"
	build_stable="true"
	build_testing="true"
	board="socfpga_de0_nano_soc" ; build_uboot_gnueabihf
}

wandboard () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="wandboard" ; build_uboot_gnueabihf
}

am65x_evm_a53 () {
	cleanup
#	build_old="true"
	build_stable="true"
	build_testing="true"
	board="am65x_evm_a53" ; build_uboot_aarch64
}

am335x_evm
am335x_boneblack_flasher
#am57xx_evm
exit

mx6ul_14x14_evk
mx6ull_14x14_evk
mx6sabresd
omap3_beagle
omap4_panda
omap5_uevm
socfpga_de0_nano_soc
wandboard

#devices with no patches...
ls1021atwr
udoo

#development...
#am65x_evm_a53

#
