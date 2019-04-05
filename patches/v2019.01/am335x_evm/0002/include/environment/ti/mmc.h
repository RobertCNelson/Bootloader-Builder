/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) 2017 Texas Instruments Incorporated - http://www.ti.com
 *
 * Environment variable definitions for MMC/SD on TI boards.
 */

#ifndef __TI_MMC_H
#define __TI_MMC_H

#define DEFAULT_MMC_TI_ARGS \
	"mmcdev=0\0" \
	"mmcrootfstype=ext4 rootwait\0" \
	"finduuid=part uuid ${devtype} ${bootpart} uuid\0" \
	"args_mmc=run finduuid;setenv bootargs console=${console} " \
		"${cape_disable} " \
		"${cape_enable} " \
		"${cape_uboot} " \
		"root=PARTUUID=${uuid} ro " \
		"rootfstype=${mmcrootfstype} " \
		"${uboot_detected_capes} " \
		"${cmdline}\0" \
	"args_mmc_old=setenv bootargs console=${console} " \
		"${optargs} " \
		"${cape_disable} " \
		"${cape_enable} " \
		"${cape_uboot} " \
		"root=${oldroot} ro " \
		"rootfstype=${mmcrootfstype} " \
		"${uboot_detected_capes} " \
		"${cmdline}\0" \
	"args_mmc_uuid=setenv bootargs console=${console} " \
		"${optargs} " \
		"${cape_disable} " \
		"${cape_enable} " \
		"${cape_uboot} " \
		"root=UUID=${uuid} ro " \
		"rootfstype=${mmcrootfstype} " \
		"${uboot_detected_capes} " \
		"${cmdline}\0" \
	"args_uenv_root=setenv bootargs console=${console} " \
		"${optargs} " \
		"${cape_disable} " \
		"${cape_enable} " \
		"${cape_uboot} " \
		"root=${uenv_root} ro " \
		"rootfstype=${mmcrootfstype} " \
		"${uboot_detected_capes} " \
		"${cmdline}\0" \
	"args_netinstall=setenv bootargs ${netinstall_bootargs} " \
		"${optargs} " \
		"${cape_disable} " \
		"${cape_enable} " \
		"${cape_uboot} " \
		"root=/dev/ram rw " \
		"${uboot_detected_capes} " \
		"${cmdline}\0" \
	"script=boot.scr\0" \
	"scriptfile=${script}\0" \
	"loadbootscript=load ${devtype} ${bootpart} ${loadaddr} ${scriptfile};\0" \
	"bootscript=echo Running bootscript from mmc${bootpart} ...; " \
		"source ${loadaddr}\0" \
	"bootenvfile=uEnv.txt\0" \
	"bootenv=uEnv.txt\0" \
	"importbootenv=echo Importing environment from ${devtype} ...; " \
		"env import -t ${loadaddr} ${filesize}\0" \
	"loadbootenv=load ${devtype} ${bootpart} ${loadaddr} ${bootenvfile}\0" \
	"loadimage=load ${devtype} ${bootpart} ${loadaddr} ${bootdir}/${bootfile}\0" \
	"loadrd=load ${devtype} ${bootpart} ${rdaddr} ${bootdir}/${rdfile}; setenv rdsize ${filesize}\0" \
	"loadfdt=echo loading ${fdtdir}/${fdtfile} ...; load ${devtype} ${bootpart} ${fdtaddr} ${fdtdir}/${fdtfile}\0" \
	"loadoverlay=echo uboot_overlays: loading ${uboot_overlay} ...; " \
		"load ${devtype} ${bootpart} ${rdaddr} ${uboot_overlay}; " \
		"fdt addr ${fdtaddr}; fdt resize ${fdt_buffer}; " \
		"fdt apply ${rdaddr}; fdt resize ${fdt_buffer};\0" \
	"virtualloadoverlay=if test -e ${devtype} ${bootpart} ${uboot_overlay}; then " \
				"run loadoverlay;" \
			"else " \
				"echo uboot_overlays: unable to find [${devtype} ${bootpart} ${uboot_overlay}]...;" \
			"fi;\0" \
	"capeloadoverlay=if test -e ${devtype} ${bootpart} ${uboot_overlay}; then " \
				"run loadoverlay;" \
				"setenv cape_uboot bone_capemgr.uboot_capemgr_enabled=1; " \
			"else " \
				"echo uboot_overlays: unable to find [${devtype} ${bootpart} ${uboot_overlay}]...;" \
			"fi;\0" \
	"failumsboot=echo; echo FAILSAFE: U-Boot UMS (USB Mass Storage) enabled, media now available over the usb slave port ...; " \
		"ums 0 ${devtype} 1;\0" \
	"envboot=mmc dev ${mmcdev}; " \
		"if mmc rescan; then " \
			"echo SD/MMC found on device ${mmcdev};" \
			"if run loadbootscript; then " \
				"run bootscript;" \
			"else " \
				"if run loadbootenv; then " \
					"echo Loaded env from ${bootenvfile};" \
					"run importbootenv;" \
				"fi;" \
				"if test -n $uenvcmd; then " \
					"echo Running uenvcmd ...;" \
					"run uenvcmd;" \
				"fi;" \
			"fi;" \
		"fi;\0" \
	"mmcloados=run args_mmc; " \
		"if test ${boot_fdt} = yes || test ${boot_fdt} = try; then " \
			"if run loadfdt; then " \
				"if test -n ${uname_r}; then " \
					"bootz ${loadaddr} ${rdaddr}:${rdsize} ${fdtaddr}; " \
				"else " \
					"bootz ${loadaddr} - ${fdtaddr}; " \
				"fi; " \
			"else " \
				"if test ${boot_fdt} = try; then " \
					"bootz; " \
				"else " \
					"echo WARN: Cannot load the DT; " \
				"fi; " \
			"fi; " \
		"else " \
			"bootz; " \
		"fi;\0" \
	"mmcboot=mmc dev ${mmcdev}; " \
		"setenv devnum ${mmcdev}; " \
		"setenv devtype mmc; " \
		"if mmc rescan; then " \
			"echo SD/MMC found on device ${mmcdev};" \
			"if run loadimage; then " \
				"if test ${boot_fit} -eq 1; then " \
					"run loadfit; " \
				"else " \
					"run mmcloados;" \
				"fi;" \
			"fi;" \
		"fi;\0"

#endif /* __TI_MMC_H */
