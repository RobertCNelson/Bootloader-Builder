#!/bin/sh -e
#
# Copyright (c) 2010-2022 Robert Nelson <robertcnelson@gmail.com>
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

ARCH=$(uname -m)
DIR=$PWD
TEMPDIR=$(mktemp -d)

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
	gcc_html_path="https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/${gcc_selected}/"
	gcc_filename_prefix="x86_64-gcc-${gcc_selected}-nolibc-${gcc_prefix}"
	extracted_dir="gcc-${gcc_selected}-nolibc/${gcc_prefix}"
	binary="bin/${gcc_prefix}-"

	WGET="wget -c --directory-prefix=${gcc_dir}/"
	if [ "x${extracted_dir}" = "x" ] ; then
		filename_prefix=${gcc_filename_prefix}
	else
		filename_prefix=${extracted_dir}
	fi

	if [ ! -f "${gcc_dir}/${filename_prefix}/${datestamp}" ] ; then
		echo "Installing Toolchain: ${toolchain}"
		echo "-----------------------------"
		${WGET} "${gcc_html_path}${gcc_filename_prefix}.tar.xz"
		if [ -d "${gcc_dir}/${filename_prefix}" ] ; then
			rm -rf "${gcc_dir}/${filename_prefix}" || true
		fi
		tar -xf "${gcc_dir}/${gcc_filename_prefix}.tar.xz" -C "${gcc_dir}/"
		if [ -f "${gcc_dir}/${filename_prefix}/${binary}gcc" ] ; then
			touch "${gcc_dir}/${filename_prefix}/${datestamp}"
		fi
	else
		echo "Using Existing Toolchain: ${toolchain}"
	fi

	if [ "x${ARCH}" = "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${gcc_dir}/${filename_prefix}/${binary}"
	fi
}

gcc_versions () {
	unset extracted_dir

	#https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/
	gcc6="6.5.0"
	gcc7="7.5.0"
	gcc8="8.5.0"
	gcc9="9.4.0"
	gcc10="10.3.0"
	gcc11="11.1.0"
}

#NOTE: ignore formatting, as this is just: meld build.sh ../stable-kernel/scripts/gcc.sh
gcc_6_arm () {
	gcc_versions
		gcc_selected=${gcc6}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2017.${gcc_selected}-${gcc_prefix}"
	dl_gcc_generic
}

gcc_7_arm () {
	gcc_versions
		gcc_selected=${gcc7}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2017.${gcc_selected}-${gcc_prefix}"
	dl_gcc_generic
}

gcc_8_arm () {
	gcc_versions
		gcc_selected=${gcc8}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2018.${gcc_selected}-${gcc_prefix}"
	dl_gcc_generic
}

gcc_9_arm () {
	gcc_versions
		gcc_selected=${gcc9}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2019.${gcc_selected}-${gcc_prefix}"
	dl_gcc_generic
}

gcc_10_arm () {
	gcc_versions
		gcc_selected=${gcc10}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2020.${gcc_selected}-${gcc_prefix}"
	dl_gcc_generic
}

gcc_11_arm () {
	gcc_versions
		gcc_selected=${gcc11}
		gcc_prefix="arm-linux-gnueabi"
		datestamp="2021.${gcc_selected}-${gcc_prefix}"
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

	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" distclean"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\""
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

		#case "${board}" in
		#socfpga_de0_nano_soc)
		#	;;
		#esac
	fi

	#v2021.10
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
					cp arch/arm/mach-omap2/am33xx/board.c ${base}/arch/arm/mach-omap2/am33xx/
					cp arch/arm/mach-omap2/am33xx/clock_am33xx.c ${base}/arch/arm/mach-omap2/am33xx/
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

					mkdir -p ${base}/include/environment/ti/
					cp include/environment/ti/mmc.h ${base}/include/environment/ti/
					cp ../../patches/artfacts/boot.h  ${base}/include/environment/ti/ || true

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
					cp ../../patches/artfacts/hash-string.h ${base}/board/ti/am335x/ || true

					mkdir -p ${base}/include/configs/
					cp include/configs/ti_armv7_common.h ${base}/include/configs/

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
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\""
		echo "-----------------------------"
		exit
	fi

	uboot_filename="${board}-${UGIT_VERSION}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${board}

	make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config} > /dev/null

	#make ARCH=arm CROSS_COMPILE="${CC}" menuconfig

	echo "Building ${project}: ${uboot_filename}:"
	make ARCH=arm CROSS_COMPILE="${CC}" -j${CORES} > /dev/null

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

	if [ "x${board}" = "xam57xx_evm" ] ; then
		echo "#!/bin/bash" > ${DIR}/deploy/${board}/install.sh
		echo "" >> ${DIR}/deploy/${board}/install.sh
		echo "if ! id | grep -q root; then" >> ${DIR}/deploy/${board}/install.sh
		echo "        echo \"must be run as root\"" >> ${DIR}/deploy/${board}/install.sh
		echo "        exit" >> ${DIR}/deploy/${board}/install.sh
		echo "fi" >> ${DIR}/deploy/${board}/install.sh
		echo "" >> ${DIR}/deploy/${board}/install.sh
		echo "dd if=./MLO of=/dev/sdc count=2 seek=1 bs=128k" >> ${DIR}/deploy/${board}/install.sh
		echo "dd if=./u-boot-dtb.img of=/dev/sdc count=4 seek=1 bs=384k" >> ${DIR}/deploy/${board}/install.sh
		echo "sync" >> ${DIR}/deploy/${board}/install.sh
		chmod +x ${DIR}/deploy/${board}/install.sh
	fi

	echo "-----------------------------"

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

build_uboot_gnueabihf () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_6_arm
	build_uboot_old
	build_uboot_stable
	build_uboot_testing
	build_uboot_wip
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

am335x_evm
am335x_boneblack_flasher
#am57xx_evm
exit

#
