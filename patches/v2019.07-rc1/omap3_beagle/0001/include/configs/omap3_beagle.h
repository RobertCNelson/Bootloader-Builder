/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * (C) Copyright 2006-2008
 * Texas Instruments.
 * Richard Woodruff <r-woodruff2@ti.com>
 * Syed Mohammed Khasim <x0khasim@ti.com>
 *
 * Configuration settings for the TI OMAP3530 Beagle board.
 */

#ifndef __CONFIG_H
#define __CONFIG_H

#include <configs/ti_omap3_common.h>

/*
 * We are only ever GP parts and will utilize all of the "downloaded image"
 * area in SRAM which starts at 0x40200000 and ends at 0x4020FFFF (64KB).
 */

#define CONFIG_CMDLINE_TAG
#define CONFIG_SETUP_MEMORY_TAGS
#define CONFIG_INITRD_TAG
#define CONFIG_REVISION_TAG

/* NAND */
#if defined(CONFIG_NAND)
#define CONFIG_SYS_FLASH_BASE		NAND_BASE
#define CONFIG_SYS_MAX_NAND_DEVICE      1
#define CONFIG_SYS_NAND_5_ADDR_CYCLE
#define CONFIG_SYS_NAND_PAGE_COUNT      64
#define CONFIG_SYS_NAND_PAGE_SIZE       2048
#define CONFIG_SYS_NAND_OOBSIZE         64
#define CONFIG_SYS_NAND_BLOCK_SIZE      (128*1024)
#define CONFIG_SYS_NAND_BAD_BLOCK_POS   NAND_LARGE_BADBLOCK_POS
#define CONFIG_SYS_NAND_ECCPOS          {2, 3, 4, 5, 6, 7, 8, 9,\
                                         10, 11, 12, 13}
#define CONFIG_SYS_NAND_ECCSIZE         512
#define CONFIG_SYS_NAND_ECCBYTES        3
#define CONFIG_NAND_OMAP_ECCSCHEME      OMAP_ECC_BCH8_CODE_HW_DETECTION_SW
#define CONFIG_SYS_NAND_U_BOOT_OFFS     0x80000
#define CONFIG_SYS_ENV_SECT_SIZE        SZ_128K
#define CONFIG_ENV_OFFSET               0x260000
#define CONFIG_ENV_ADDR                 0x260000
#define CONFIG_ENV_OVERWRITE
/* NAND: SPL falcon mode configs */
#if defined(CONFIG_SPL_OS_BOOT)
#define CONFIG_SYS_NAND_SPL_KERNEL_OFFS 0x2a0000
#endif /* CONFIG_SPL_OS_BOOT */
#endif /* CONFIG_NAND */

/* USB EHCI */
#define CONFIG_OMAP_EHCI_PHY1_RESET_GPIO	147

/* Enable Multi Bus support for I2C */
#define CONFIG_I2C_MULTI_BUS

/* DSS Support */

/* TWL4030 LED Support */

/* Environment */
#define CONFIG_ENV_SIZE                 SZ_128K

#define CONFIG_PREBOOT                  "usb start"

#define MEM_LAYOUT_ENV_SETTINGS \
	DEFAULT_LINUX_BOOT_ENV

#define BOOTENV_DEV_LEGACY_MMC(devtypeu, devtypel, instance) \
	"bootcmd_" #devtypel #instance "=" \
	"setenv mmcdev " #instance "; " \
	"setenv devtype mmc; " \
	"setenv mmcblk 0; " \
	"setenv mmcdev 0; " \
	"run boot\0"
#define BOOTENV_DEV_NAME_LEGACY_MMC(devtypeu, devtypel, instance) \
	#devtypel #instance " "

#if defined(CONFIG_NAND)

#define BOOTENV_DEV_NAND(devtypeu, devtypel, instance) \
	"bootcmd_" #devtypel #instance "=" \
	"if test ${mtdids} = '' || test ${mtdparts} = '' ; then " \
		"echo NAND boot disabled: No mtdids and/or mtdparts; " \
	"else " \
		"run nandboot; " \
	"fi\0"
#define BOOTENV_DEV_NAME_NAND(devtypeu, devtypel, instance) \
	#devtypel #instance " "

#define BOOT_TARGET_DEVICES(func) \
	func(MMC, mmc, 0) \
	func(LEGACY_MMC, legacy_mmc, 0) \
	func(UBIFS, ubifs, 0) \
	func(NAND, nand, 0)

#else /* !CONFIG_NAND */

#define BOOT_TARGET_DEVICES(func) \
	func(MMC, mmc, 0) \
	func(LEGACY_MMC, legacy_mmc, 0)

#endif /* CONFIG_NAND */

#include <config_distro_bootcmd.h>
#include <environment/ti/mmc.h>

#define CONFIG_EXTRA_ENV_SETTINGS \
	MEM_LAYOUT_ENV_SETTINGS \
	DEFAULT_MMC_TI_ARGS \
	"console=ttyO2,115200n8\0" \
	"fdtfile=undefined\0" \
	"bootpart=0:2\0" \
	"bootdir=/boot\0" \
	"bootfile=zImage\0" \
	"usbtty=cdc_acm\0" \
	"vram=16M\0" \
	"loadbootscript=load ${devtype} ${mmcdev} ${loadaddr} boot.scr\0" \
	"bootscript=echo Running bootscript from mmc${mmcdev} ...; " \
		"source ${loadaddr}\0" \
	"bootenv=uEnv.txt\0" \
	"loadbootenv=load ${devtype} ${bootpart} ${loadaddr} ${bootenv}\0" \
	"importbootenv=echo Importing environment from mmc${mmcdev} ...; " \
		"env import -t ${loadaddr} ${filesize}\0" \
	"loadimage=load ${devtype} ${bootpart} ${loadaddr} ${bootdir}/${bootfile}\0" \
	"loaduimage=load ${devtype} ${mmcdev} ${loadaddr} uImage\0" \
	"mmcboot=echo Booting from mmc${mmcdev} ...; " \
		"run args_mmc; " \
		"bootz ${loadaddr} - ${fdtaddr}\0" \
	"uimageboot=echo Booting from mmc${mmcdev} ...; " \
		"run args_mmc; " \
		"bootm ${loadaddr}\0" \
	"findfdt=" \
		"if test $beaglerev = AxBx; then " \
			"setenv fdtfile omap3-beagle.dtb; fi; " \
		"if test $beaglerev = Cx; then " \
			"setenv fdtfile omap3-beagle.dtb; fi; " \
		"if test $beaglerev = C4; then " \
			"setenv fdtfile omap3-beagle.dtb; fi; " \
		"if test $beaglerev = xMAB; then " \
			"setenv fdtfile omap3-beagle-xm-ab.dtb; fi; " \
		"if test $beaglerev = xMC; then " \
			"setenv fdtfile omap3-beagle-xm.dtb; fi; " \
		"if test $fdtfile = undefined; then " \
			"echo WARNING: Could not determine device tree to use; fi\0" \
	"loadrd=load ${devtype} ${bootpart} ${rdaddr} ${bootdir}/${rdfile}; setenv rdsize ${filesize}\0" \
	"loadfdt=echo loading ${fdtdir}/${fdtfile} ...; load ${devtype} ${bootpart} ${fdtaddr} ${fdtdir}/${fdtfile}\0" \
	EEWIKI_BOOT \
	EEWIKI_UNAME_BOOT \
	BOOTENV

#endif /* __CONFIG_H */
