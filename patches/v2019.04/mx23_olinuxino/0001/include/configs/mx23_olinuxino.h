/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) 2013 Marek Vasut <marex@denx.de>
 */
#ifndef __CONFIGS_MX23_OLINUXINO_H__
#define __CONFIGS_MX23_OLINUXINO_H__

/* System configurations */
#define CONFIG_MACH_TYPE	4105

/* U-Boot Commands */

#define CONFIG_SUPPORT_RAW_INITRD

/* Memory configuration */
#define PHYS_SDRAM_1			0x40000000	/* Base address */
#define PHYS_SDRAM_1_SIZE		0x08000000	/* Max 128 MB RAM */
#define CONFIG_SYS_SDRAM_BASE		PHYS_SDRAM_1

/* Environment */
#define CONFIG_ENV_OVERWRITE

/* Environment is in MMC */
#if defined(CONFIG_CMD_MMC) && defined(CONFIG_ENV_IS_IN_MMC)
#define CONFIG_ENV_OFFSET	(256 * 1024)
#define CONFIG_ENV_SIZE		(16 * 1024)
#define CONFIG_SYS_MMC_ENV_DEV	0
#endif

/* Status LED */

/* USB */
#ifdef CONFIG_CMD_USB
#define CONFIG_EHCI_MXS_PORT0
#define CONFIG_USB_MAX_CONTROLLER_COUNT 1
#endif

/* Ethernet */

/* Booting Linux */
#define CONFIG_BOOTFILE		"uImage"
#define CONFIG_LOADADDR		0x42000000
#define CONFIG_SYS_LOAD_ADDR	CONFIG_LOADADDR

/* Extra Environment */
#define CONFIG_EXTRA_ENV_SETTINGS \
	"update_sd_firmware_filename=u-boot.sd\0" \
	"update_sd_firmware="		/* Update the SD firmware partition */ \
		"if mmc rescan ; then "	\
		"if tftp ${update_sd_firmware_filename} ; then " \
		"setexpr fw_sz ${filesize} / 0x200 ; "	/* SD block size */ \
		"setexpr fw_sz ${fw_sz} + 1 ; "	\
		"mmc write ${loadaddr} 0x800 ${fw_sz} ; " \
		"fi ; "	\
		"fi\0" \
	"script=boot.scr\0"	\
	"uimage=uImage\0" \
	"console=ttyAMA0\0" \
	"fdt_file=imx23-olinuxino.dtb\0" \
	"fdt_addr=0x41000000\0" \
	"fdtdir=\0" \
	"bootfile=\0" \
	"bootdir=\0" \
	"boot_fdt=try\0" \
	"ip_dyn=yes\0" \
	"optargs=\0" \
	"cmdline=\0" \
	"mmcdev=0\0" \
	"mmcpart=2\0" \
	"mmcroot=/dev/mmcblk0p2 ro\0" \
	"mmcrootfstype=ext4 rootwait fixrtc\0" \
	"mmcargs=setenv bootargs console=${console},${baudrate} " \
		"${optargs} " \
		"root=${mmcroot} " \
		"rootfstype=${mmcrootfstype} " \
		"${cmdline}\0" \
	"loadbootenv=load mmc ${bootpart} ${loadaddr} /boot/uEnv.txt\0" \
	"importbootenv=echo Importing environment from mmc (uEnv.txt)...; " \
		"env import -t ${loadaddr} ${filesize}\0" \
	"loadbootscript="  \
		"fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${script};\0" \
	"bootscript=echo Running bootscript from mmc ...; "	\
		"source\0" \
	"loadimage=load mmc ${bootpart} ${loadaddr} ${bootdir}/${bootfile}\0" \
	"loadfdt=echo loading ${fdtdir}/${fdt_file} ...;  load mmc ${bootpart} ${fdt_addr} ${fdtdir}/${fdt_file}\0" \
	"mmcboot=mmc dev ${mmcdev}; " \
		"if mmc rescan; then " \
			"echo SD/MMC found on device ${mmcdev};" \
			"echo Checking for: /boot/uEnv.txt ...;" \
			"for i in 2 3 4 5 6 7 ; do " \
				"setenv mmcpart ${i};" \
				"setenv bootpart ${mmcdev}:${mmcpart};" \
				"if test -e mmc ${bootpart} /boot/uEnv.txt; then " \
					"load mmc ${bootpart} ${loadaddr} /boot/uEnv.txt;" \
					"env import -t ${loadaddr} ${filesize};" \
					"echo Loaded environment from /boot/uEnv.txt;" \
					"if test -n ${dtb}; then " \
						"setenv fdt_file ${dtb};" \
						"echo using ${fdt_file} ...;" \
					"fi;" \
					"echo Checking if uname_r is set in /boot/uEnv.txt...;" \
					"if test -n ${uname_r}; then " \
						"setenv mmcroot /dev/mmcblk${mmcdev}p${mmcpart} ro;" \
						"if test -n ${uuid}; then " \
							"setenv mmcroot UUID=${uuid} ro;" \
						"fi;" \
						"run uname_boot;" \
					"fi;" \
				"fi;" \
			"done;" \
		"fi;\0" \
	"mmcboot_old=echo Booting from mmc ...; " \
		"run mmcargs; " \
		"if test ${boot_fdt} = yes || test ${boot_fdt} = try; then " \
			"if run loadfdt; then " \
				"bootm ${loadaddr} - ${fdt_addr}; " \
			"else " \
				"if test ${boot_fdt} = try; then " \
					"bootm; " \
				"else " \
					"echo WARN: Cannot load the DT; " \
				"fi; " \
			"fi; " \
		"else " \
			"bootm; " \
		"fi;\0" \
	"netargs=setenv bootargs console=${console},${baudrate} " \
		"root=/dev/nfs " \
		"ip=dhcp nfsroot=${serverip}:${nfsroot},v3,tcp\0" \
	"netboot=echo Booting from net ...; " \
		"usb start; " \
		"run netargs; "	\
		"if test ${ip_dyn} = yes; then " \
			"setenv get_cmd dhcp; " \
		"else " \
			"setenv get_cmd tftp; " \
		"fi; " \
		"${get_cmd} ${uimage}; " \
		"if test ${boot_fdt} = yes; then " \
			"if ${get_cmd} ${fdt_addr} ${fdt_file}; then " \
				"bootm ${loadaddr} - ${fdt_addr}; " \
			"else " \
				"if test ${boot_fdt} = try; then " \
					"bootm; " \
				"else " \
					"echo WARN: Cannot load the DT; " \
				"fi;" \
			"fi; " \
		"else " \
			"bootm; " \
		"fi;\0" \
	"uname_boot="\
		"setenv bootdir /boot; " \
		"setenv bootfile vmlinuz-${uname_r}; " \
		"if test -e mmc ${bootpart} ${bootdir}/${bootfile}; then " \
			"echo loading ${bootdir}/${bootfile} ...; "\
			"run loadimage;" \
			"setenv fdtdir /boot/dtbs/${uname_r}; " \
			"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
				"run loadfdt;" \
			"else " \
				"setenv fdtdir /usr/lib/linux-image-${uname_r}; " \
				"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
					"run loadfdt;" \
				"else " \
					"setenv fdtdir /lib/firmware/${uname_r}/device-tree; " \
					"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
						"run loadfdt;" \
					"else " \
						"setenv fdtdir /boot/dtb-${uname_r}; " \
						"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
							"run loadfdt;" \
						"else " \
							"setenv fdtdir /boot/dtbs; " \
							"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
								"run loadfdt;" \
							"else " \
								"setenv fdtdir /boot/dtb; " \
								"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
									"run loadfdt;" \
								"else " \
									"setenv fdtdir /boot; " \
									"if test -e mmc ${bootpart} ${fdtdir}/${fdt_file}; then " \
										"run loadfdt;" \
									"else " \
										"echo; echo unable to find ${fdt_file} ...; echo booting legacy ...;"\
										"run mmcargs;" \
										"echo debug: [${bootargs}] ... ;" \
										"echo debug: [bootz ${loadaddr}] ... ;" \
										"bootz ${loadaddr}; " \
									"fi;" \
								"fi;" \
							"fi;" \
						"fi;" \
					"fi;" \
				"fi;" \
			"fi; " \
			"run mmcargs;" \
			"echo debug: [${bootargs}] ... ;" \
			"echo debug: [bootz ${loadaddr} - ${fdt_addr}] ... ;" \
			"bootz ${loadaddr} - ${fdt_addr}; " \
		"fi;\0"

#define CONFIG_BOOTCOMMAND \
	"run mmcboot;"

/* The rest of the configuration is shared */
#include <configs/mxs.h>

#endif /* __CONFIGS_MX23_OLINUXINO_H__ */
