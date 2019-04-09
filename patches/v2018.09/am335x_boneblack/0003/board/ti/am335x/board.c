// SPDX-License-Identifier: GPL-2.0+
/*
 * board.c
 *
 * Board functions for TI AM335X based boards
 *
 * Copyright (C) 2011, Texas Instruments, Incorporated - http://www.ti.com/
 */

#include <common.h>
#include <dm.h>
#include <errno.h>
#include <spl.h>
#include <serial.h>
#include <asm/arch/cpu.h>
#include <asm/arch/hardware.h>
#include <asm/arch/omap.h>
#include <asm/arch/ddr_defs.h>
#include <asm/arch/clock.h>
#include <asm/arch/clk_synthesizer.h>
#include <asm/arch/gpio.h>
#include <asm/arch/mmc_host_def.h>
#include <asm/arch/sys_proto.h>
#include <asm/arch/mem.h>
#include <asm/io.h>
#include <asm/emif.h>
#include <asm/gpio.h>
#include <asm/omap_common.h>
#include <asm/omap_sec_common.h>
#include <asm/omap_mmc.h>
#include <asm/davinci_rtc.h>
#include <i2c.h>
#include <miiphy.h>
#include <cpsw.h>
#include <power/tps65217.h>
#include <power/tps65910.h>
#include <environment.h>
#include <watchdog.h>
#include <environment.h>
#include "../common/board_detect.h"
#include "board.h"
#include "hash-string.h"

DECLARE_GLOBAL_DATA_PTR;

/* GPIO that controls power to DDR on EVM-SK */
#define GPIO_TO_PIN(bank, gpio)		(32 * (bank) + (gpio))
#define GPIO_DDR_VTT_EN		GPIO_TO_PIN(0, 7)
#define ICE_GPIO_DDR_VTT_EN	GPIO_TO_PIN(0, 18)
#define GPIO_PR1_MII_CTRL	GPIO_TO_PIN(3, 4)
#define GPIO_MUX_MII_CTRL	GPIO_TO_PIN(3, 10)
#define GPIO_FET_SWITCH_CTRL	GPIO_TO_PIN(0, 7)
#define GPIO_PHY_RESET		GPIO_TO_PIN(2, 5)
#define GPIO_ETH0_MODE		GPIO_TO_PIN(0, 11)
#define GPIO_ETH1_MODE		GPIO_TO_PIN(1, 26)

static struct ctrl_dev *cdev = (struct ctrl_dev *)CTRL_DEVICE_BASE;

#define GPIO0_RISINGDETECT	(AM33XX_GPIO0_BASE + OMAP_GPIO_RISINGDETECT)
#define GPIO1_RISINGDETECT	(AM33XX_GPIO1_BASE + OMAP_GPIO_RISINGDETECT)

#define GPIO0_IRQSTATUS1	(AM33XX_GPIO0_BASE + OMAP_GPIO_IRQSTATUS1)
#define GPIO1_IRQSTATUS1	(AM33XX_GPIO1_BASE + OMAP_GPIO_IRQSTATUS1)

#define GPIO0_IRQSTATUSRAW	(AM33XX_GPIO0_BASE + 0x024)
#define GPIO1_IRQSTATUSRAW	(AM33XX_GPIO1_BASE + 0x024)

/*
 * Read header information from EEPROM into global structure.
 */
#ifdef CONFIG_TI_I2C_BOARD_DETECT
void do_board_detect(void)
{
	enable_i2c0_pin_mux();
	i2c_init(CONFIG_SYS_OMAP24_I2C_SPEED, CONFIG_SYS_OMAP24_I2C_SLAVE);

	if (ti_i2c_eeprom_am_get(CONFIG_EEPROM_BUS_ADDRESS,
				 CONFIG_EEPROM_CHIP_ADDRESS))
		printf("ti_i2c_eeprom_init failed\n");

	//hack-ish, needs to mux'ed early, in do_cape_detect was too late...
	enable_i2c2_pin_mux();
	i2c_init(CONFIG_SYS_OMAP24_I2C_SPEED2, CONFIG_SYS_OMAP24_I2C_SLAVE2);
}
#endif

#define CAPE_EEPROM_ADDR0	0x54
#define CAPE_EEPROM_ADDR1	0x55
#define CAPE_EEPROM_ADDR2	0x56
#define CAPE_EEPROM_ADDR3	0x57

#define NOT_POP		0x0
#define PINS_TAKEN	0x0

#define UNK_BASE_DTB	0x0
#define BB_BASE_DTB	0x1
#define BBB_BASE_DTB	0x2
#define BBGW_BASE_DTB	0x3
#define BBBL_BASE_DTB	0x4
#define BBE_BASE_DTB	0x5

#define BBB_EMMC	0x1

#define BBB_TDA998X_AUDIO	0x1
#define BBB_TDA998X_NAUDIO	0x2
#define BBB_ADV7511_AUDIO	0x3
#define BBB_ADV7511_NAUDIO	0x4

#define BBB_ADC		0x1

#define BBBW_WL1835	0x1
#define BBGW_WL1835	0x2

#define CAPE_UNIVERSAL	0x0
#define CAPE_UNIVERSAL_BBB	0x01
#define CAPE_UNIVERSAL_BBG	0x02
#define CAPE_UNIVERSAL_BBGW	0x03

#define M_BBG1	0x01
#define M_OS00	0x02

static int probe_cape_eeprom(struct am335x_cape_eeprom_id *cape_header)
{
	unsigned char addr;
	/* /lib/firmware/BB-CAPE-DISP-CT4-00A0.dtbo */
	/* 14 + 16 + 1 + 4 + 5 = 40 */
	char cape_overlay[40];
	char process_cape_part_number[16];
	char end_part_number;
	char cape_overlay_pass_to_kernel[18];

	//Don't forget about the BeagleBone Classic (White)
	char base_dtb=UNK_BASE_DTB;
	char virtual_emmc=NOT_POP;
	char virtual_video=NOT_POP;
	char virtual_audio=NOT_POP;
	char virtual_wireless=NOT_POP;
	char cape_universal=CAPE_UNIVERSAL;
	char virtual_adc=NOT_POP;
	char model=NOT_POP;

	char *name = NULL;

	if (board_is_bone_lt()) {
		puts("BeagleBone Black:\n");
		base_dtb=BBB_BASE_DTB;
		virtual_emmc=BBB_EMMC;
		virtual_video=BBB_TDA998X_AUDIO;
		virtual_audio=BBB_TDA998X_AUDIO;
		virtual_wireless=NOT_POP;
		virtual_adc=BBB_ADC;
		cape_universal=CAPE_UNIVERSAL_BBB;
		name = "A335BNLT";

		if (!strncmp(board_ti_get_rev(), "BLA", 3)) {
			puts("Model: BeagleBoard.org BeagleBone Blue:\n");
			/* Special case */
			base_dtb=BBBL_BASE_DTB;
			virtual_emmc=NOT_POP;
			virtual_video=NOT_POP;
			virtual_audio=NOT_POP;
			virtual_wireless=NOT_POP;
			virtual_adc=BBB_ADC;
			cape_universal=CAPE_UNIVERSAL;
			name = "BBBL";
		}
		if (!strncmp(board_ti_get_rev(), "BW", 2)) {
			puts("Model: BeagleBoard.org BeagleBone Black Wireless:\n");
			virtual_wireless=BBBW_WL1835;
			name = "BBBW";
		}
		if (!strncmp(board_ti_get_rev(), "BBG", 3)) {
			/* catches again in board_is_bbg1() */
			//puts("Model: SeeedStudio BeagleBone Green:\n");
			virtual_video=NOT_POP;
			virtual_audio=NOT_POP;
			cape_universal=CAPE_UNIVERSAL_BBG;
			name = "BBG1";
			model=M_BBG1;
		}
		if (!strncmp(board_ti_get_rev(), "GW1", 3)) {
			puts("Model: SeeedStudio BeagleBone Green Wireless:\n");
			base_dtb=BBGW_BASE_DTB;
			virtual_video=NOT_POP;
			virtual_audio=NOT_POP;
			virtual_wireless=BBGW_WL1835;
			cape_universal=CAPE_UNIVERSAL_BBGW;
		}
		if (!strncmp(board_ti_get_rev(), "AIA", 3)) {
			puts("Model: Arrow BeagleBone Black Industrial:\n");
			virtual_video=BBB_ADV7511_AUDIO;
			virtual_audio=BBB_ADV7511_AUDIO;
			cape_universal=CAPE_UNIVERSAL;
		}
		if (!strncmp(board_ti_get_rev(), "EIA", 3)) {
			puts("Model: Element14 BeagleBone Black Industrial:\n");
		}
		if (!strncmp(board_ti_get_rev(), "SE", 2)) {
			puts("Model: SanCloud BeagleBone Enhanced:\n");
			base_dtb=BBE_BASE_DTB;
			cape_universal=CAPE_UNIVERSAL_BBB;
			name = "BBEN";
		}
		if (!strncmp(board_ti_get_rev(), "ME0", 3)) {
			puts("Model: MENTOREL BeagleBone uSomIQ:\n");
			virtual_video=NOT_POP;
			virtual_audio=NOT_POP;
			cape_universal=CAPE_UNIVERSAL_BBG;
		}
		if (!strncmp(board_ti_get_rev(), "NAD", 3)) {
			puts("Model: Neuromeka BeagleBone Air:\n");
			cape_universal=CAPE_UNIVERSAL;
		}
		if (!strncmp(board_ti_get_rev(), "OS0", 3)) {
			puts("Model: Octavo Systems OSD3358-SM-RED:\n");
			name = "OS00";
			cape_universal=NOT_POP;
			model=M_OS00;
		}
	}

	if (board_is_bone()) {
		puts("Model: BeagleBone:\n");
		base_dtb=BB_BASE_DTB;
		virtual_emmc=NOT_POP;
		virtual_video=NOT_POP;
		virtual_audio=NOT_POP;
		virtual_wireless=NOT_POP;
		virtual_adc=BBB_ADC;
		cape_universal=CAPE_UNIVERSAL_BBB;
		name = "A335BONE";
	}

	if (board_is_bbg1()) {
		puts("Model: SeeedStudio BeagleBone Green:\n");
		base_dtb=BBB_BASE_DTB;
		virtual_emmc=BBB_EMMC;
		virtual_video=NOT_POP;
		virtual_audio=NOT_POP;
		virtual_wireless=NOT_POP;
		virtual_adc=BBB_ADC;
		cape_universal=CAPE_UNIVERSAL_BBG;
		name = "BBG1";
		model=M_BBG1;
	}

	set_board_info_env(name);

	i2c_set_bus_num(2);
	strlcpy(cape_overlay_pass_to_kernel, "", 1);

	for ( addr = CAPE_EEPROM_ADDR0; addr <= CAPE_EEPROM_ADDR3; addr++ ) {
		if (i2c_probe(addr)) {
			printf("BeagleBone: cape eeprom: i2c_probe: 0x%x:\n", addr);
		} else {
			/* read the eeprom using i2c */
			if (i2c_read(addr, 0, 2, (uchar *)cape_header,
				     sizeof(struct am335x_cape_eeprom_id))) {
				puts("BeagleBone: cape eeprom: Could not read the EEPROM; something fundamentally"
					" wrong on the I2C bus.\n");
				return -EIO;
			}

			if (cape_header->header == 0xEE3355AA) {
				strlcpy(cape_overlay, "/lib/firmware/", 14 + 1);
				strlcpy(cape_overlay_pass_to_kernel, "", 2);
				strlcpy(process_cape_part_number, "...............", 16 + 1);

				strlcpy(process_cape_part_number, cape_header->part_number, 16 + 1);
				printf("debug: process_cape_part_number:[%s]\n", process_cape_part_number);

				//FIXME: some capes end with '.'
				if ( process_cape_part_number[15] == 0x2E ) {
					puts("debug: fixup, extra . in eeprom field\n");
					process_cape_part_number[15] = 0x00;
					if ( process_cape_part_number[14] == 0x2E ) {
						process_cape_part_number[14] = 0x00;
					}
				}

				//Find ending 0x00
				puts("debug: process_cape_part_number:[");
				end_part_number=16;
				for ( int i=0; i <= 16; i++ ) {
					if ( process_cape_part_number[i] == 0x00 ) {
						end_part_number=i;
						i=17;
					} else {
						printf("%x", process_cape_part_number[i]);
					}
				}
				puts("]\n");

				strncat(cape_overlay, process_cape_part_number, end_part_number);
				//printf("debug: %s\n", cape_overlay);

				strncat(cape_overlay, "-", 1);
				//printf("debug: %s\n", cape_overlay);

				strncat(cape_overlay, cape_header->version, 4);
				//printf("debug: %s\n", cape_overlay);

				strncat(cape_overlay, ".dtbo", 5);
				//printf("debug: %s\n", cape_overlay);

				unsigned long cape_overlay_hash = hash_string(cape_overlay);

				printf("BeagleBone: cape eeprom: i2c_probe: 0x%x: %s [0x%lx]\n", addr, cape_overlay, cape_overlay_hash);

				strncat(cape_overlay_pass_to_kernel, process_cape_part_number, end_part_number);
				strncat(cape_overlay_pass_to_kernel, ",", 1);

				switch(cape_overlay_hash) {
					case 0x3c766f: /* /lib/firmware/BB-CAPE-DISP-CT4-00A0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0x24f51cf: /* /lib/firmware/BB-BONE-CAM-VVDN-00A0.dtbo */
						virtual_emmc=PINS_TAKEN;
						break;
					case 0x4b0c13f: /* /lib/firmware/NL-AB-BBCL-00B0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0x74e7bbf: /* /lib/firmware/bb-justboom-dac-00A0.dtbo */
						virtual_audio=PINS_TAKEN;
						break;
					case 0x93b574f: /* /lib/firmware/BB-GREEN-HDMI-00A0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0x9dcd73f: /* /lib/firmware/BB-BONE-NH10C-01-00A0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xb1b7bbf: /* /lib/firmware/bb-justboom-amp-00A0.dtbo */
						virtual_audio=PINS_TAKEN;
						break;
					//d15bb
					case 0xd15b80f: /* /lib/firmware/DLPDLCR2000-00A0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xd4c9eff: /* /lib/firmware/bb-justboom-digi-00A0.dtbo */
						virtual_audio=PINS_TAKEN;
						break;
					case 0xe05061f: /* /lib/firmware/BBORG_DISPLAY70-00A2.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xe3f55df: /* /lib/firmware/BB-BONE-NH7C-01-A0.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfc93c8f: /* /lib/firmware/BB-BONE-LCD7-01-00A3.dtbo */
						virtual_video=PINS_TAKEN;
						virtual_adc=PINS_TAKEN;
						break;
					//fe131
					case 0xfe1313f: /* /lib/firmware/BB-BONE-4D5R-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					//fe132
					case 0xfe1323f: /* /lib/firmware/BB-BONE-4D4R-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfe1327f: /* /lib/firmware/BB-BONE-4D4N-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfe132cf: /* /lib/firmware/BB-BONE-4D4C-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					//fe133
					case 0xfe1337f: /* /lib/firmware/BB-BONE-4D7N-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfe133cf: /* /lib/firmware/BB-BONE-4D7C-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					//fe135
					case 0xfe1357f: /* /lib/firmware/BB-BONE-4D5N-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfe135cf: /* /lib/firmware/BB-BONE-4D5C-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					//fe137
					case 0xfe1373f: /* /lib/firmware/BB-BONE-4D7R-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						break;
					case 0xfe93c1f: /* /lib/firmware/BB-BONE-LCD4-01-00A1.dtbo */
						virtual_video=PINS_TAKEN;
						virtual_adc=PINS_TAKEN;
						break;
				}

				switch(addr) {
					case CAPE_EEPROM_ADDR0:
						env_set("uboot_overlay_addr0", cape_overlay);
						env_set("uboot_detected_capes_addr0", cape_overlay_pass_to_kernel);
						break;
					case CAPE_EEPROM_ADDR1:
						env_set("uboot_overlay_addr1", cape_overlay);
						env_set("uboot_detected_capes_addr1", cape_overlay_pass_to_kernel);
						break;
					case CAPE_EEPROM_ADDR2:
						env_set("uboot_overlay_addr2", cape_overlay);
						env_set("uboot_detected_capes_addr2", cape_overlay_pass_to_kernel);
						break;
					case CAPE_EEPROM_ADDR3:
						env_set("uboot_overlay_addr3", cape_overlay);
						env_set("uboot_detected_capes_addr3", cape_overlay_pass_to_kernel);
						break;
				}
				env_set("uboot_detected_capes", "1");
			} else {
				printf("BeagleBone: found invalid cape eeprom: i2c_probe: 0x%x:\n", addr);
			}
		}
	}//for

	switch(base_dtb) {
		case BB_BASE_DTB:
			env_set("uboot_base_dtb_univ", "am335x-bone-uboot-univ.dtb");
			env_set("uboot_base_dtb", "am335x-bone.dtb");
			env_set("uboot_try_cape_universal", "1");
			break;
		case BBB_BASE_DTB:
			env_set("uboot_base_dtb_univ", "am335x-boneblack-uboot-univ.dtb");
			env_set("uboot_base_dtb", "am335x-boneblack-uboot.dtb");
			env_set("uboot_try_cape_universal", "1");
			break;
		case BBGW_BASE_DTB:
			//gpio-hogs and cape-universal dont mesh very well on bootup...
			env_set("uboot_base_dtb_univ", "am335x-bonegreen-wireless-uboot-univ.dtb");
			env_set("uboot_base_dtb", "am335x-boneblack-uboot.dtb");
			env_set("uboot_try_cape_universal", "1");
			break;
		case BBE_BASE_DTB:
			env_set("uboot_base_dtb_univ", "am335x-sancloud-bbe-uboot-univ.dtb");
			env_set("uboot_base_dtb", "am335x-sancloud-bbe-uboot.dtb");
			env_set("uboot_try_cape_universal", "1");
			break;
		case BBBL_BASE_DTB:
			env_set("uboot_base_dtb_univ", "am335x-boneblue.dtb");
			break;
	}

	if (virtual_emmc == BBB_EMMC) {
		env_set("uboot_emmc", "/lib/firmware/BB-BONE-eMMC1-01-00A0.dtbo");
	}

	switch(virtual_video) {
		case BBB_TDA998X_AUDIO:
			if (virtual_audio == PINS_TAKEN) {
				env_set("uboot_video", "/lib/firmware/BB-NHDMI-TDA998x-00A0.dtbo");
				env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-TDA998x-00A0.dtbo");
			} else {
				env_set("uboot_video", "/lib/firmware/BB-HDMI-TDA998x-00A0.dtbo");
				env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-TDA998x-00A0.dtbo");
			}
			break;
		case BBB_TDA998X_NAUDIO:
			env_set("uboot_video", "/lib/firmware/BB-NHDMI-TDA998x-00A0.dtbo");
			env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-TDA998x-00A0.dtbo");
			break;
		case BBB_ADV7511_AUDIO:
			if (virtual_audio == PINS_TAKEN) {
				env_set("uboot_video", "/lib/firmware/BB-NHDMI-ADV7511-00A0.dtbo");
				env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-ADV7511-00A0.dtbo");
			} else {
				env_set("uboot_video", "/lib/firmware/BB-HDMI-ADV7511-00A0.dtbo");
				env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-ADV7511-00A0.dtbo");
			}
			break;
		case BBB_ADV7511_NAUDIO:
			env_set("uboot_video", "/lib/firmware/BB-NHDMI-ADV7511-00A0.dtbo");
			env_set("uboot_video_naudio", "/lib/firmware/BB-NHDMI-ADV7511-00A0.dtbo");
			break;
	}

	switch(virtual_wireless) {
		case BBBW_WL1835:
			env_set("uboot_wireless", "/lib/firmware/BB-BBBW-WL1835-00A0.dtbo");
			break;
		case BBGW_WL1835:
			env_set("uboot_wireless", "/lib/firmware/BB-BBGW-WL1835-00A0.dtbo");
			break;
	}

	switch(virtual_adc) {
		case BBB_ADC:
			env_set("uboot_adc", "/lib/firmware/BB-ADC-00A0.dtbo");
			break;
	}

	switch(model) {
		case M_BBG1:
			env_set("uboot_model", "/lib/firmware/M-BB-BBG-00A0.dtbo");
			break;
		case M_OS00:
			env_set("uboot_model", "/lib/firmware/M-BB-OSD3358-SM-RED-00A0.dtbo");
			break;
	}

	switch(cape_universal) {
		case CAPE_UNIVERSAL_BBB:
			env_set("uboot_cape_universal_bbb", "1");
			break;
		case CAPE_UNIVERSAL_BBG:
			env_set("uboot_cape_universal_bbg", "1");
			break;
		case CAPE_UNIVERSAL_BBGW:
			env_set("uboot_cape_universal_bbgw", "1");
			break;
	}

	i2c_set_bus_num(0);
	return 0;
}

void do_cape_detect(void)
{
	struct am335x_cape_eeprom_id cape_header;

	i2c_init(CONFIG_SYS_OMAP24_I2C_SPEED2, CONFIG_SYS_OMAP24_I2C_SLAVE2);
	probe_cape_eeprom(&cape_header);
}

#ifndef CONFIG_DM_SERIAL
struct serial_device *default_serial_console(void)
{
	if (board_is_icev2())
		return &eserial4_device;
	else if (board_is_beaglelogic())
		return &eserial5_device;
	else
		return &eserial1_device;
}
#endif

#ifndef CONFIG_SKIP_LOWLEVEL_INIT
static const struct ddr_data ddr2_data = {
	.datardsratio0 = MT47H128M16RT25E_RD_DQS,
	.datafwsratio0 = MT47H128M16RT25E_PHY_FIFO_WE,
	.datawrsratio0 = MT47H128M16RT25E_PHY_WR_DATA,
};

static const struct cmd_control ddr2_cmd_ctrl_data = {
	.cmd0csratio = MT47H128M16RT25E_RATIO,

	.cmd1csratio = MT47H128M16RT25E_RATIO,

	.cmd2csratio = MT47H128M16RT25E_RATIO,
};

static const struct emif_regs ddr2_emif_reg_data = {
	.sdram_config = MT47H128M16RT25E_EMIF_SDCFG,
	.ref_ctrl = MT47H128M16RT25E_EMIF_SDREF,
	.sdram_tim1 = MT47H128M16RT25E_EMIF_TIM1,
	.sdram_tim2 = MT47H128M16RT25E_EMIF_TIM2,
	.sdram_tim3 = MT47H128M16RT25E_EMIF_TIM3,
	.emif_ddr_phy_ctlr_1 = MT47H128M16RT25E_EMIF_READ_LATENCY,
};

static const struct emif_regs ddr2_evm_emif_reg_data = {
	.sdram_config = MT47H128M16RT25E_EMIF_SDCFG,
	.ref_ctrl = MT47H128M16RT25E_EMIF_SDREF,
	.sdram_tim1 = MT47H128M16RT25E_EMIF_TIM1,
	.sdram_tim2 = MT47H128M16RT25E_EMIF_TIM2,
	.sdram_tim3 = MT47H128M16RT25E_EMIF_TIM3,
	.ocp_config = EMIF_OCP_CONFIG_AM335X_EVM,
	.emif_ddr_phy_ctlr_1 = MT47H128M16RT25E_EMIF_READ_LATENCY,
};

static const struct ddr_data ddr3_data = {
	.datardsratio0 = MT41J128MJT125_RD_DQS,
	.datawdsratio0 = MT41J128MJT125_WR_DQS,
	.datafwsratio0 = MT41J128MJT125_PHY_FIFO_WE,
	.datawrsratio0 = MT41J128MJT125_PHY_WR_DATA,
};

static const struct ddr_data ddr3_beagleblack_data = {
	.datardsratio0 = MT41K256M16HA125E_RD_DQS,
	.datawdsratio0 = MT41K256M16HA125E_WR_DQS,
	.datafwsratio0 = MT41K256M16HA125E_PHY_FIFO_WE,
	.datawrsratio0 = MT41K256M16HA125E_PHY_WR_DATA,
};

static const struct ddr_data ddr3_evm_data = {
	.datardsratio0 = MT41J512M8RH125_RD_DQS,
	.datawdsratio0 = MT41J512M8RH125_WR_DQS,
	.datafwsratio0 = MT41J512M8RH125_PHY_FIFO_WE,
	.datawrsratio0 = MT41J512M8RH125_PHY_WR_DATA,
};

static const struct ddr_data ddr3_icev2_data = {
	.datardsratio0 = MT41J128MJT125_RD_DQS_400MHz,
	.datawdsratio0 = MT41J128MJT125_WR_DQS_400MHz,
	.datafwsratio0 = MT41J128MJT125_PHY_FIFO_WE_400MHz,
	.datawrsratio0 = MT41J128MJT125_PHY_WR_DATA_400MHz,
};

static const struct cmd_control ddr3_cmd_ctrl_data = {
	.cmd0csratio = MT41J128MJT125_RATIO,
	.cmd0iclkout = MT41J128MJT125_INVERT_CLKOUT,

	.cmd1csratio = MT41J128MJT125_RATIO,
	.cmd1iclkout = MT41J128MJT125_INVERT_CLKOUT,

	.cmd2csratio = MT41J128MJT125_RATIO,
	.cmd2iclkout = MT41J128MJT125_INVERT_CLKOUT,
};

static const struct cmd_control ddr3_beagleblack_cmd_ctrl_data = {
	.cmd0csratio = MT41K256M16HA125E_RATIO,
	.cmd0iclkout = MT41K256M16HA125E_INVERT_CLKOUT,

	.cmd1csratio = MT41K256M16HA125E_RATIO,
	.cmd1iclkout = MT41K256M16HA125E_INVERT_CLKOUT,

	.cmd2csratio = MT41K256M16HA125E_RATIO,
	.cmd2iclkout = MT41K256M16HA125E_INVERT_CLKOUT,
};

static const struct cmd_control ddr3_evm_cmd_ctrl_data = {
	.cmd0csratio = MT41J512M8RH125_RATIO,
	.cmd0iclkout = MT41J512M8RH125_INVERT_CLKOUT,

	.cmd1csratio = MT41J512M8RH125_RATIO,
	.cmd1iclkout = MT41J512M8RH125_INVERT_CLKOUT,

	.cmd2csratio = MT41J512M8RH125_RATIO,
	.cmd2iclkout = MT41J512M8RH125_INVERT_CLKOUT,
};

static const struct cmd_control ddr3_icev2_cmd_ctrl_data = {
	.cmd0csratio = MT41J128MJT125_RATIO_400MHz,
	.cmd0iclkout = MT41J128MJT125_INVERT_CLKOUT_400MHz,

	.cmd1csratio = MT41J128MJT125_RATIO_400MHz,
	.cmd1iclkout = MT41J128MJT125_INVERT_CLKOUT_400MHz,

	.cmd2csratio = MT41J128MJT125_RATIO_400MHz,
	.cmd2iclkout = MT41J128MJT125_INVERT_CLKOUT_400MHz,
};

static struct emif_regs ddr3_emif_reg_data = {
	.sdram_config = MT41J128MJT125_EMIF_SDCFG,
	.ref_ctrl = MT41J128MJT125_EMIF_SDREF,
	.sdram_tim1 = MT41J128MJT125_EMIF_TIM1,
	.sdram_tim2 = MT41J128MJT125_EMIF_TIM2,
	.sdram_tim3 = MT41J128MJT125_EMIF_TIM3,
	.zq_config = MT41J128MJT125_ZQ_CFG,
	.emif_ddr_phy_ctlr_1 = MT41J128MJT125_EMIF_READ_LATENCY |
				PHY_EN_DYN_PWRDN,
};

static struct emif_regs ddr3_beagleblack_emif_reg_data = {
	.sdram_config = MT41K256M16HA125E_EMIF_SDCFG,
	.ref_ctrl = MT41K256M16HA125E_EMIF_SDREF,
	.sdram_tim1 = MT41K256M16HA125E_EMIF_TIM1,
	.sdram_tim2 = MT41K256M16HA125E_EMIF_TIM2,
	.sdram_tim3 = MT41K256M16HA125E_EMIF_TIM3,
	.ocp_config = EMIF_OCP_CONFIG_BEAGLEBONE_BLACK,
	.zq_config = MT41K256M16HA125E_ZQ_CFG,
	.emif_ddr_phy_ctlr_1 = MT41K256M16HA125E_EMIF_READ_LATENCY,
};

static struct emif_regs ddr3_evm_emif_reg_data = {
	.sdram_config = MT41J512M8RH125_EMIF_SDCFG,
	.ref_ctrl = MT41J512M8RH125_EMIF_SDREF,
	.sdram_tim1 = MT41J512M8RH125_EMIF_TIM1,
	.sdram_tim2 = MT41J512M8RH125_EMIF_TIM2,
	.sdram_tim3 = MT41J512M8RH125_EMIF_TIM3,
	.ocp_config = EMIF_OCP_CONFIG_AM335X_EVM,
	.zq_config = MT41J512M8RH125_ZQ_CFG,
	.emif_ddr_phy_ctlr_1 = MT41J512M8RH125_EMIF_READ_LATENCY |
				PHY_EN_DYN_PWRDN,
};

static struct emif_regs ddr3_icev2_emif_reg_data = {
	.sdram_config = MT41J128MJT125_EMIF_SDCFG_400MHz,
	.ref_ctrl = MT41J128MJT125_EMIF_SDREF_400MHz,
	.sdram_tim1 = MT41J128MJT125_EMIF_TIM1_400MHz,
	.sdram_tim2 = MT41J128MJT125_EMIF_TIM2_400MHz,
	.sdram_tim3 = MT41J128MJT125_EMIF_TIM3_400MHz,
	.zq_config = MT41J128MJT125_ZQ_CFG_400MHz,
	.emif_ddr_phy_ctlr_1 = MT41J128MJT125_EMIF_READ_LATENCY_400MHz |
				PHY_EN_DYN_PWRDN,
};

#ifdef CONFIG_SPL_OS_BOOT
int spl_start_uboot(void)
{
#ifdef CONFIG_SPL_SERIAL_SUPPORT
	/* break into full u-boot on 'c' */
	if (serial_tstc() && serial_getc() == 'c')
		return 1;
#endif

#ifdef CONFIG_SPL_ENV_SUPPORT
	env_init();
	env_load();
	if (env_get_yesno("boot_os") != 1)
		return 1;
#endif

	return 0;
}
#endif

const struct dpll_params *get_dpll_ddr_params(void)
{
	int ind = get_sys_clk_index();

	if (board_is_evm_sk())
		return &dpll_ddr3_303MHz[ind];
	else if (board_is_pb() || board_is_bone_lt() || board_is_icev2() || board_is_beaglelogic() || board_is_blank_bone_lt())
		return &dpll_ddr3_400MHz[ind];
	else if (board_is_evm_15_or_later())
		return &dpll_ddr3_303MHz[ind];
	else
		return &dpll_ddr2_266MHz[ind];
}

static u8 bone_not_connected_to_ac_power(void)
{
	if (board_is_bone()) {
		uchar pmic_status_reg;
		if (tps65217_reg_read(TPS65217_STATUS,
				      &pmic_status_reg))
			return 1;
		if (!(pmic_status_reg & TPS65217_PWR_SRC_AC_BITMASK)) {
			puts("No AC power, switching to default OPP\n");
			return 1;
		}
	}
	return 0;
}

const struct dpll_params *get_dpll_mpu_params(void)
{
	int ind = get_sys_clk_index();
	int freq = am335x_get_efuse_mpu_max_freq(cdev);

	if (bone_not_connected_to_ac_power())
		freq = MPUPLL_M_600;

	if (board_is_pb() || board_is_bone_lt() || board_is_beaglelogic())
		freq = MPUPLL_M_1000;

	switch (freq) {
	case MPUPLL_M_1000:
		return &dpll_mpu_opp[ind][5];
	case MPUPLL_M_800:
		return &dpll_mpu_opp[ind][4];
	case MPUPLL_M_720:
		return &dpll_mpu_opp[ind][3];
	case MPUPLL_M_600:
		return &dpll_mpu_opp[ind][2];
	case MPUPLL_M_500:
		return &dpll_mpu_opp100;
	case MPUPLL_M_300:
		return &dpll_mpu_opp[ind][0];
	}

	return &dpll_mpu_opp[ind][0];
}

static void scale_vcores_bone(int freq)
{
	int usb_cur_lim, mpu_vdd;

	/*
	 * Only perform PMIC configurations if board rev > A1
	 * on Beaglebone White
	 */
	if (board_is_bone() && !strncmp(board_ti_get_rev(), "00A1", 4))
		return;

	if (i2c_probe(TPS65217_CHIP_PM))
		return;

	/*
	 * On Beaglebone White we need to ensure we have AC power
	 * before increasing the frequency.
	 */
	if (bone_not_connected_to_ac_power())
		freq = MPUPLL_M_600;

	/*
	 * Override what we have detected since we know if we have
	 * a Beaglebone Black it supports 1GHz.
	 */
	if (board_is_pb() || board_is_bone_lt() || board_is_beaglelogic())
		freq = MPUPLL_M_1000;

	switch (freq) {
	case MPUPLL_M_1000:
		mpu_vdd = TPS65217_DCDC_VOLT_SEL_1325MV;
		usb_cur_lim = TPS65217_USB_INPUT_CUR_LIMIT_1800MA;
		break;
	case MPUPLL_M_800:
		mpu_vdd = TPS65217_DCDC_VOLT_SEL_1275MV;
		usb_cur_lim = TPS65217_USB_INPUT_CUR_LIMIT_1300MA;
		break;
	case MPUPLL_M_720:
		mpu_vdd = TPS65217_DCDC_VOLT_SEL_1200MV;
		usb_cur_lim = TPS65217_USB_INPUT_CUR_LIMIT_1300MA;
		break;
	case MPUPLL_M_600:
	case MPUPLL_M_500:
	case MPUPLL_M_300:
	default:
		mpu_vdd = TPS65217_DCDC_VOLT_SEL_1100MV;
		usb_cur_lim = TPS65217_USB_INPUT_CUR_LIMIT_1300MA;
		break;
	}

	if (tps65217_reg_write(TPS65217_PROT_LEVEL_NONE,
			       TPS65217_POWER_PATH,
			       usb_cur_lim,
			       TPS65217_USB_INPUT_CUR_LIMIT_MASK))
		puts("tps65217_reg_write failure\n");

	/* Set DCDC3 (CORE) voltage to 1.10V */
	if (tps65217_voltage_update(TPS65217_DEFDCDC3,
				    TPS65217_DCDC_VOLT_SEL_1100MV)) {
		puts("tps65217_voltage_update failure\n");
		return;
	}

	/* Set DCDC2 (MPU) voltage */
	if (tps65217_voltage_update(TPS65217_DEFDCDC2, mpu_vdd)) {
		puts("tps65217_voltage_update failure\n");
		return;
	}

	/*
	 * Set LDO3, LDO4 output voltage to 3.3V for Beaglebone.
	 * Set LDO3 to 1.8V and LDO4 to 3.3V for Beaglebone Black.
	 */
	if (board_is_bone()) {
		if (tps65217_reg_write(TPS65217_PROT_LEVEL_2,
				       TPS65217_DEFLS1,
				       TPS65217_LDO_VOLTAGE_OUT_3_3,
				       TPS65217_LDO_MASK))
			puts("tps65217_reg_write failure\n");
	} else {
		if (tps65217_reg_write(TPS65217_PROT_LEVEL_2,
				       TPS65217_DEFLS1,
				       TPS65217_LDO_VOLTAGE_OUT_1_8,
				       TPS65217_LDO_MASK))
			puts("tps65217_reg_write failure\n");
	}

	if (tps65217_reg_write(TPS65217_PROT_LEVEL_2,
			       TPS65217_DEFLS2,
			       TPS65217_LDO_VOLTAGE_OUT_3_3,
			       TPS65217_LDO_MASK))
		puts("tps65217_reg_write failure\n");
}

void scale_vcores_generic(int freq)
{
	int sil_rev, mpu_vdd;

	/*
	 * The GP EVM, IDK and EVM SK use a TPS65910 PMIC.  For all
	 * MPU frequencies we support we use a CORE voltage of
	 * 1.10V.  For MPU voltage we need to switch based on
	 * the frequency we are running at.
	 */
	if (i2c_probe(TPS65910_CTRL_I2C_ADDR))
		return;

	/*
	 * Depending on MPU clock and PG we will need a different
	 * VDD to drive at that speed.
	 */
	sil_rev = readl(&cdev->deviceid) >> 28;
	mpu_vdd = am335x_get_tps65910_mpu_vdd(sil_rev, freq);

	/* Tell the TPS65910 to use i2c */
	tps65910_set_i2c_control();

	/* First update MPU voltage. */
	if (tps65910_voltage_update(MPU, mpu_vdd))
		return;

	/* Second, update the CORE voltage. */
	if (tps65910_voltage_update(CORE, TPS65910_OP_REG_SEL_1_1_0))
		return;

}

void gpi2c_init(void)
{
	/* When needed to be invoked prior to BSS initialization */
	static bool first_time = true;

	if (first_time) {
		enable_i2c0_pin_mux();
		i2c_init(CONFIG_SYS_OMAP24_I2C_SPEED,
			 CONFIG_SYS_OMAP24_I2C_SLAVE);
		first_time = false;
	}
}

void scale_vcores(void)
{
	int freq;

	gpi2c_init();
	freq = am335x_get_efuse_mpu_max_freq(cdev);

	if (board_is_beaglebonex())
		scale_vcores_bone(freq);
	else
		scale_vcores_generic(freq);
}

void set_uart_mux_conf(void)
{
#if CONFIG_CONS_INDEX == 1
	if (board_is_beaglelogic())
		enable_uart4_pin_mux();
	else
		enable_uart0_pin_mux();

#elif CONFIG_CONS_INDEX == 2
	enable_uart1_pin_mux();
#elif CONFIG_CONS_INDEX == 3
	enable_uart2_pin_mux();
#elif CONFIG_CONS_INDEX == 4
	enable_uart3_pin_mux();
#elif CONFIG_CONS_INDEX == 5
	enable_uart4_pin_mux();
#elif CONFIG_CONS_INDEX == 6
	enable_uart5_pin_mux();
#endif
}

void set_mux_conf_regs(void)
{
	enable_board_pin_mux();
}

const struct ctrl_ioregs ioregs_evmsk = {
	.cm0ioctl		= MT41J128MJT125_IOCTRL_VALUE,
	.cm1ioctl		= MT41J128MJT125_IOCTRL_VALUE,
	.cm2ioctl		= MT41J128MJT125_IOCTRL_VALUE,
	.dt0ioctl		= MT41J128MJT125_IOCTRL_VALUE,
	.dt1ioctl		= MT41J128MJT125_IOCTRL_VALUE,
};

const struct ctrl_ioregs ioregs_bonelt = {
	.cm0ioctl		= MT41K256M16HA125E_IOCTRL_VALUE,
	.cm1ioctl		= MT41K256M16HA125E_IOCTRL_VALUE,
	.cm2ioctl		= MT41K256M16HA125E_IOCTRL_VALUE,
	.dt0ioctl		= MT41K256M16HA125E_IOCTRL_VALUE,
	.dt1ioctl		= MT41K256M16HA125E_IOCTRL_VALUE,
};

const struct ctrl_ioregs ioregs_evm15 = {
	.cm0ioctl		= MT41J512M8RH125_IOCTRL_VALUE,
	.cm1ioctl		= MT41J512M8RH125_IOCTRL_VALUE,
	.cm2ioctl		= MT41J512M8RH125_IOCTRL_VALUE,
	.dt0ioctl		= MT41J512M8RH125_IOCTRL_VALUE,
	.dt1ioctl		= MT41J512M8RH125_IOCTRL_VALUE,
};

const struct ctrl_ioregs ioregs = {
	.cm0ioctl		= MT47H128M16RT25E_IOCTRL_VALUE,
	.cm1ioctl		= MT47H128M16RT25E_IOCTRL_VALUE,
	.cm2ioctl		= MT47H128M16RT25E_IOCTRL_VALUE,
	.dt0ioctl		= MT47H128M16RT25E_IOCTRL_VALUE,
	.dt1ioctl		= MT47H128M16RT25E_IOCTRL_VALUE,
};

void sdram_init(void)
{
	if (board_is_evm_sk()) {
		/*
		 * EVM SK 1.2A and later use gpio0_7 to enable DDR3.
		 * This is safe enough to do on older revs.
		 */
		gpio_request(GPIO_DDR_VTT_EN, "ddr_vtt_en");
		gpio_direction_output(GPIO_DDR_VTT_EN, 1);
	}

	if (board_is_icev2()) {
		gpio_request(ICE_GPIO_DDR_VTT_EN, "ddr_vtt_en");
		gpio_direction_output(ICE_GPIO_DDR_VTT_EN, 1);
	}

	if (board_is_evm_sk())
		config_ddr(303, &ioregs_evmsk, &ddr3_data,
			   &ddr3_cmd_ctrl_data, &ddr3_emif_reg_data, 0);
	else if (board_is_pb() || board_is_bone_lt() || board_is_beaglelogic() || board_is_blank_bone_lt())
		config_ddr(400, &ioregs_bonelt,
			   &ddr3_beagleblack_data,
			   &ddr3_beagleblack_cmd_ctrl_data,
			   &ddr3_beagleblack_emif_reg_data, 0);
	else if (board_is_evm_15_or_later())
		config_ddr(303, &ioregs_evm15, &ddr3_evm_data,
			   &ddr3_evm_cmd_ctrl_data, &ddr3_evm_emif_reg_data, 0);
	else if (board_is_icev2())
		config_ddr(400, &ioregs_evmsk, &ddr3_icev2_data,
			   &ddr3_icev2_cmd_ctrl_data, &ddr3_icev2_emif_reg_data,
			   0);
	else if (board_is_gp_evm())
		config_ddr(266, &ioregs, &ddr2_data,
			   &ddr2_cmd_ctrl_data, &ddr2_evm_emif_reg_data, 0);
	else
		config_ddr(266, &ioregs, &ddr2_data,
			   &ddr2_cmd_ctrl_data, &ddr2_emif_reg_data, 0);
}
#endif

#if defined(CONFIG_CLOCK_SYNTHESIZER) && (!defined(CONFIG_SPL_BUILD) || \
	(defined(CONFIG_SPL_ETH_SUPPORT) && defined(CONFIG_SPL_BUILD)))
static void request_and_set_gpio(int gpio, char *name, int val)
{
	int ret;

	ret = gpio_request(gpio, name);
	if (ret < 0) {
		printf("%s: Unable to request %s\n", __func__, name);
		return;
	}

	ret = gpio_direction_output(gpio, 0);
	if (ret < 0) {
		printf("%s: Unable to set %s  as output\n", __func__, name);
		goto err_free_gpio;
	}

	gpio_set_value(gpio, val);

	return;

err_free_gpio:
	gpio_free(gpio);
}

#define REQUEST_AND_SET_GPIO(N)	request_and_set_gpio(N, #N, 1);
#define REQUEST_AND_CLR_GPIO(N)	request_and_set_gpio(N, #N, 0);

/**
 * RMII mode on ICEv2 board needs 50MHz clock. Given the clock
 * synthesizer With a capacitor of 18pF, and 25MHz input clock cycle
 * PLL1 gives an output of 100MHz. So, configuring the div2/3 as 2 to
 * give 50MHz output for Eth0 and 1.
 */
static struct clk_synth cdce913_data = {
	.id = 0x81,
	.capacitor = 0x90,
	.mux = 0x6d,
	.pdiv2 = 0x2,
	.pdiv3 = 0x2,
};
#endif

#if defined(CONFIG_SPL_AM33XX_ENABLE_RTC32K_OSC)
void rtc32k_enable(void)
{
	struct davinci_rtc *rtc = (struct davinci_rtc *)RTC_BASE;

	/*
	 * Unlock the RTC's registers.  For more details please see the
	 * RTC_SS section of the TRM.  In order to unlock we need to
	 * write these specific values (keys) in this order.
	 */
	writel(RTC_KICK0R_WE, &rtc->kick0r);
	writel(RTC_KICK1R_WE, &rtc->kick1r);

	if (board_is_pb() || board_is_blue()) {
		/* 6: EN_32KCLK */
		/* 3: SEL_32KCLK_SRC 0: internal, 1: external */
		writel((0 << 3) | (1 << 6), &rtc->osc);
	} else {
		/* Enable the RTC 32K OSC by setting bits 3 and 6. */
		writel((1 << 3) | (1 << 6), &rtc->osc);
	}
}
#endif

/*
 * Basic board specific setup.  Pinmux has been handled already.
 */
int board_init(void)
{
	u32 sys_reboot, sys_rtc_osc;

	sys_reboot = readl(PRM_RSTST);
	if (sys_reboot & (1 << 9))
		puts("Reset Source: IcePick reset has occurred.\n");

	if (sys_reboot & (1 << 5))
		puts("Reset Source: Global external warm reset has occurred.\n");

	if (sys_reboot & (1 << 4))
		puts("Reset Source: watchdog reset has occurred.\n");

	if (sys_reboot & (1 << 1))
		puts("Reset Source: Global warm SW reset has occurred.\n");

	if (sys_reboot & (1 << 0))
		puts("Reset Source: Power-on reset has occurred.\n");

	sys_rtc_osc = readl(RTC_OSC);
	if (sys_rtc_osc & (1 << 3)) {
		puts("RTC 32KCLK Source: External.\n");
	} else {
		puts("RTC 32KCLK Source: Internal.\n");
	}

#if defined(CONFIG_HW_WATCHDOG)
	hw_watchdog_init();
#endif

	gd->bd->bi_boot_params = CONFIG_SYS_SDRAM_BASE + 0x100;
#if defined(CONFIG_NOR) || defined(CONFIG_NAND)
	gpmc_init();
#endif

#if defined(CONFIG_CLOCK_SYNTHESIZER) && (!defined(CONFIG_SPL_BUILD) || \
	(defined(CONFIG_SPL_ETH_SUPPORT) && defined(CONFIG_SPL_BUILD)))
	if (board_is_icev2()) {
		int rv;
		u32 reg;

		REQUEST_AND_SET_GPIO(GPIO_PR1_MII_CTRL);
		/* Make J19 status available on GPIO1_26 */
		REQUEST_AND_CLR_GPIO(GPIO_MUX_MII_CTRL);

		REQUEST_AND_SET_GPIO(GPIO_FET_SWITCH_CTRL);
		/*
		 * Both ports can be set as RMII-CPSW or MII-PRU-ETH using
		 * jumpers near the port. Read the jumper value and set
		 * the pinmux, external mux and PHY clock accordingly.
		 * As jumper line is overridden by PHY RX_DV pin immediately
		 * after bootstrap (power-up/reset), we need to sample
		 * it during PHY reset using GPIO rising edge detection.
		 */
		REQUEST_AND_SET_GPIO(GPIO_PHY_RESET);
		/* Enable rising edge IRQ on GPIO0_11 and GPIO 1_26 */
		reg = readl(GPIO0_RISINGDETECT) | BIT(11);
		writel(reg, GPIO0_RISINGDETECT);
		reg = readl(GPIO1_RISINGDETECT) | BIT(26);
		writel(reg, GPIO1_RISINGDETECT);
		/* Reset PHYs to capture the Jumper setting */
		gpio_set_value(GPIO_PHY_RESET, 0);
		udelay(2);	/* PHY datasheet states 1uS min. */
		gpio_set_value(GPIO_PHY_RESET, 1);

		reg = readl(GPIO0_IRQSTATUSRAW) & BIT(11);
		if (reg) {
			writel(reg, GPIO0_IRQSTATUS1); /* clear irq */
			/* RMII mode */
			printf("ETH0, CPSW\n");
		} else {
			/* MII mode */
			printf("ETH0, PRU\n");
			cdce913_data.pdiv3 = 4;	/* 25MHz PHY clk */
		}

		reg = readl(GPIO1_IRQSTATUSRAW) & BIT(26);
		if (reg) {
			writel(reg, GPIO1_IRQSTATUS1); /* clear irq */
			/* RMII mode */
			printf("ETH1, CPSW\n");
			gpio_set_value(GPIO_MUX_MII_CTRL, 1);
		} else {
			/* MII mode */
			printf("ETH1, PRU\n");
			cdce913_data.pdiv2 = 4;	/* 25MHz PHY clk */
		}

		/* disable rising edge IRQs */
		reg = readl(GPIO0_RISINGDETECT) & ~BIT(11);
		writel(reg, GPIO0_RISINGDETECT);
		reg = readl(GPIO1_RISINGDETECT) & ~BIT(26);
		writel(reg, GPIO1_RISINGDETECT);

		rv = setup_clock_synthesizer(&cdce913_data);
		if (rv) {
			printf("Clock synthesizer setup failed %d\n", rv);
			return rv;
		}

		/* reset PHYs */
		gpio_set_value(GPIO_PHY_RESET, 0);
		udelay(2);	/* PHY datasheet states 1uS min. */
		gpio_set_value(GPIO_PHY_RESET, 1);
	}
#endif

	return 0;
}

#ifdef CONFIG_BOARD_LATE_INIT
int board_late_init(void)
{
#if !defined(CONFIG_SPL_BUILD)
	uint8_t mac_addr[6];
	uint32_t mac_hi, mac_lo;
#endif

#ifdef CONFIG_ENV_VARS_UBOOT_RUNTIME_CONFIG
	char *name = NULL;

	if (board_is_bone_lt()) {
		puts("Board: BeagleBone Black\n");
		name = "A335BNLT";
		/* BeagleBoard.org BeagleBone Black Wireless: */
		if (!strncmp(board_ti_get_rev(), "BWA", 3)) {
			name = "BBBW";
		}
		/* SeeedStudio BeagleBone Green Wireless */
		if (!strncmp(board_ti_get_rev(), "GW1", 3)) {
			name = "BBGW";
		}
		/* BeagleBoard.org BeagleBone Blue */
		if (!strncmp(board_ti_get_rev(), "BLA", 3)) {
			name = "BBBL";
		}
		/* Octavo Systems OSD3358-SM-RED */
		if (!strncmp(board_ti_get_rev(), "OS00", 4)) {
			puts("Model: Octavo Systems OSD3358-SM-RED\n");
			name = "OS00";
		}
	}

	if (board_is_bbg1())
		name = "BBG1";
	if (board_is_bben()) {
		puts("Model: SanCloud BeagleBone Enhanced\n");
		name = "BBEN";
		//Was: name = "SBBE";
	}

	if (board_is_pb()) {
		puts("Model: BeagleBoard.org PocketBeagle\n");
	}

	if (board_is_beaglelogic()) {
		puts("Model: BeagleLogic\n");
	}

	set_board_info_env(name);

	/*
	 * Default FIT boot on HS devices. Non FIT images are not allowed
	 * on HS devices.
	 */
	if (get_device_type() == HS_DEVICE)
		env_set("boot_fit", "1");
#endif

#if !defined(CONFIG_SPL_BUILD)
	/* try reading mac address from efuse */
	mac_lo = readl(&cdev->macid0l);
	mac_hi = readl(&cdev->macid0h);
	mac_addr[0] = mac_hi & 0xFF;
	mac_addr[1] = (mac_hi & 0xFF00) >> 8;
	mac_addr[2] = (mac_hi & 0xFF0000) >> 16;
	mac_addr[3] = (mac_hi & 0xFF000000) >> 24;
	mac_addr[4] = mac_lo & 0xFF;
	mac_addr[5] = (mac_lo & 0xFF00) >> 8;

	if (!env_get("ethaddr")) {
		printf("<ethaddr> not set. Validating first E-fuse MAC\n");

		if (is_valid_ethaddr(mac_addr))
			eth_env_set_enetaddr("ethaddr", mac_addr);
	}

	mac_lo = readl(&cdev->macid1l);
	mac_hi = readl(&cdev->macid1h);
	mac_addr[0] = mac_hi & 0xFF;
	mac_addr[1] = (mac_hi & 0xFF00) >> 8;
	mac_addr[2] = (mac_hi & 0xFF0000) >> 16;
	mac_addr[3] = (mac_hi & 0xFF000000) >> 24;
	mac_addr[4] = mac_lo & 0xFF;
	mac_addr[5] = (mac_lo & 0xFF00) >> 8;

	if (!env_get("eth1addr")) {
		if (is_valid_ethaddr(mac_addr))
			eth_env_set_enetaddr("eth1addr", mac_addr);
	}
#endif

	if (!env_get("serial#")) {
		char *board_serial = env_get("board_serial");
		char *ethaddr = env_get("ethaddr");

		if (!board_serial || !strncmp(board_serial, "unknown", 7))
			env_set("serial#", ethaddr);
		else
			env_set("serial#", board_serial);
	}

#ifdef CONFIG_ENV_VARS_UBOOT_RUNTIME_CONFIG
#ifdef CONFIG_TI_I2C_BOARD_DETECT
	if (!board_is_pb() && !board_is_beaglelogic()) {
		do_cape_detect();
	}
#endif
#endif

	return 0;
}
#endif

#ifndef CONFIG_DM_ETH

#if (defined(CONFIG_DRIVER_TI_CPSW) && !defined(CONFIG_SPL_BUILD)) || \
	(defined(CONFIG_SPL_ETH_SUPPORT) && defined(CONFIG_SPL_BUILD))
static void cpsw_control(int enabled)
{
	/* VTP can be added here */

	return;
}

static struct cpsw_slave_data cpsw_slaves[] = {
	{
		.slave_reg_ofs	= 0x208,
		.sliver_reg_ofs	= 0xd80,
		.phy_addr	= 0,
	},
	{
		.slave_reg_ofs	= 0x308,
		.sliver_reg_ofs	= 0xdc0,
		.phy_addr	= 1,
	},
};

static struct cpsw_platform_data cpsw_data = {
	.mdio_base		= CPSW_MDIO_BASE,
	.cpsw_base		= CPSW_BASE,
	.mdio_div		= 0xff,
	.channels		= 8,
	.cpdma_reg_ofs		= 0x800,
	.slaves			= 1,
	.slave_data		= cpsw_slaves,
	.ale_reg_ofs		= 0xd00,
	.ale_entries		= 1024,
	.host_port_reg_ofs	= 0x108,
	.hw_stats_reg_ofs	= 0x900,
	.bd_ram_ofs		= 0x2000,
	.mac_control		= (1 << 5),
	.control		= cpsw_control,
	.host_port_num		= 0,
	.version		= CPSW_CTRL_VERSION_2,
};
#endif

#if ((defined(CONFIG_SPL_ETH_SUPPORT) || defined(CONFIG_SPL_USB_ETHER)) &&\
	defined(CONFIG_SPL_BUILD)) || \
	((defined(CONFIG_DRIVER_TI_CPSW) || \
	  defined(CONFIG_USB_ETHER) && defined(CONFIG_MUSB_GADGET)) && \
	 !defined(CONFIG_SPL_BUILD))

/*
 * This function will:
 * Read the eFuse for MAC addresses, and set ethaddr/eth1addr/usbnet_devaddr
 * in the environment
 * Perform fixups to the PHY present on certain boards.  We only need this
 * function in:
 * - SPL with either CPSW or USB ethernet support
 * - Full U-Boot, with either CPSW or USB ethernet
 * Build in only these cases to avoid warnings about unused variables
 * when we build an SPL that has neither option but full U-Boot will.
 */
int board_eth_init(bd_t *bis)
{
	int rv, n = 0;
#if defined(CONFIG_USB_ETHER) && \
	(!defined(CONFIG_SPL_BUILD) || defined(CONFIG_SPL_USB_ETHER))
	uint8_t mac_addr[6];
	uint32_t mac_hi, mac_lo;

	/*
	 * use efuse mac address for USB ethernet as we know that
	 * both CPSW and USB ethernet will never be active at the same time
	 */
	mac_lo = readl(&cdev->macid0l);
	mac_hi = readl(&cdev->macid0h);
	mac_addr[0] = mac_hi & 0xFF;
	mac_addr[1] = (mac_hi & 0xFF00) >> 8;
	mac_addr[2] = (mac_hi & 0xFF0000) >> 16;
	mac_addr[3] = (mac_hi & 0xFF000000) >> 24;
	mac_addr[4] = mac_lo & 0xFF;
	mac_addr[5] = (mac_lo & 0xFF00) >> 8;
#endif


#if (defined(CONFIG_DRIVER_TI_CPSW) && !defined(CONFIG_SPL_BUILD)) || \
	(defined(CONFIG_SPL_ETH_SUPPORT) && defined(CONFIG_SPL_BUILD))

#ifdef CONFIG_DRIVER_TI_CPSW
if (!board_is_blank_bone_lt()) {
if (!board_is_pb()) {
	if (board_is_bone() || (board_is_bone_lt() && !board_is_m10a() && !board_is_bben()) ||
	    board_is_idk() || board_is_beaglelogic()) {
		puts("eth0: MII MODE\n");
		writel(MII_MODE_ENABLE, &cdev->miisel);
		cpsw_slaves[0].phy_if = cpsw_slaves[1].phy_if =
				PHY_INTERFACE_MODE_MII;
	} else if (board_is_icev2()) {
		puts("eth0: icev2: RGMII MODE\n");
		writel(RMII_MODE_ENABLE | RMII_CHIPCKL_ENABLE, &cdev->miisel);
		cpsw_slaves[0].phy_if = PHY_INTERFACE_MODE_RMII;
		cpsw_slaves[1].phy_if = PHY_INTERFACE_MODE_RMII;
		cpsw_slaves[0].phy_addr = 1;
		cpsw_slaves[1].phy_addr = 3;
	} else {
		puts("eth0: RGMII MODE\n");
		writel((RGMII_MODE_ENABLE | RGMII_INT_DELAY), &cdev->miisel);
		cpsw_slaves[0].phy_if = cpsw_slaves[1].phy_if =
				PHY_INTERFACE_MODE_RGMII;
	}

	rv = cpsw_register(&cpsw_data);
	if (rv < 0)
		printf("Error %d registering CPSW switch\n", rv);
	else
		n += rv;
}
}
#endif

	/*
	 *
	 * CPSW RGMII Internal Delay Mode is not supported in all PVT
	 * operating points.  So we must set the TX clock delay feature
	 * in the AR8051 PHY.  Since we only support a single ethernet
	 * device in U-Boot, we only do this for the first instance.
	 */
#define AR8051_PHY_DEBUG_ADDR_REG	0x1d
#define AR8051_PHY_DEBUG_DATA_REG	0x1e
#define AR8051_DEBUG_RGMII_CLK_DLY_REG	0x5
#define AR8051_RGMII_TX_CLK_DLY		0x100

	if (board_is_evm_sk() || board_is_gp_evm() || board_is_bben() || board_is_m10a()) {
		const char *devname;
		devname = miiphy_get_current_dev();

		miiphy_write(devname, 0x0, AR8051_PHY_DEBUG_ADDR_REG,
				AR8051_DEBUG_RGMII_CLK_DLY_REG);
		miiphy_write(devname, 0x0, AR8051_PHY_DEBUG_DATA_REG,
				AR8051_RGMII_TX_CLK_DLY);
	}
#endif
#if defined(CONFIG_USB_ETHER) && \
	(!defined(CONFIG_SPL_BUILD) || defined(CONFIG_SPL_USB_ETHER))
	if (is_valid_ethaddr(mac_addr))
		eth_env_set_enetaddr("usbnet_devaddr", mac_addr);

	rv = usb_eth_initialize(bis);
	if (rv < 0)
		printf("Error %d registering USB_ETHER\n", rv);
	else
		n += rv;
#endif
	return n;
}
#endif

#endif /* CONFIG_DM_ETH */

#ifdef CONFIG_SPL_LOAD_FIT
int board_fit_config_name_match(const char *name)
{
	//FIME: we currently dont use this, yet...
	if (board_is_gp_evm() && !strcmp(name, "am335x-evm"))
		return 0;
	else if (board_is_bone() && !strcmp(name, "am335x-bone"))
		return 0;
	else if (board_is_bone_lt() && !strcmp(name, "am335x-boneblack"))
		return 0;
	else if (board_is_pb() && !strcmp(name, "am335x-pocketbeagle"))
		return 0;
	else if (board_is_evm_sk() && !strcmp(name, "am335x-evmsk"))
		return 0;
	else if (board_is_bbg1() && !strcmp(name, "am335x-bonegreen"))
		return 0;
	else if (board_is_icev2() && !strcmp(name, "am335x-icev2"))
		return 0;
	else
		return -1;
}
#endif

#ifdef CONFIG_TI_SECURE_DEVICE
void board_fit_image_post_process(void **p_image, size_t *p_size)
{
	secure_boot_verify_image(p_image, p_size);
}
#endif

#if !CONFIG_IS_ENABLED(OF_CONTROL)
static const struct omap_hsmmc_plat am335x_mmc0_platdata = {
	.base_addr = (struct hsmmc *)OMAP_HSMMC1_BASE,
	.cfg.host_caps = MMC_MODE_HS_52MHz | MMC_MODE_HS | MMC_MODE_4BIT,
	.cfg.f_min = 400000,
	.cfg.f_max = 52000000,
	.cfg.voltages = MMC_VDD_32_33 | MMC_VDD_33_34 | MMC_VDD_165_195,
	.cfg.b_max = CONFIG_SYS_MMC_MAX_BLK_COUNT,
};

U_BOOT_DEVICE(am335x_mmc0) = {
	.name = "omap_hsmmc",
	.platdata = &am335x_mmc0_platdata,
};

static const struct omap_hsmmc_plat am335x_mmc1_platdata = {
	.base_addr = (struct hsmmc *)OMAP_HSMMC2_BASE,
	.cfg.host_caps = MMC_MODE_HS_52MHz | MMC_MODE_HS | MMC_MODE_8BIT,
	.cfg.f_min = 400000,
	.cfg.f_max = 52000000,
	.cfg.voltages = MMC_VDD_32_33 | MMC_VDD_33_34 | MMC_VDD_165_195,
	.cfg.b_max = CONFIG_SYS_MMC_MAX_BLK_COUNT,
};

U_BOOT_DEVICE(am335x_mmc1) = {
	.name = "omap_hsmmc",
	.platdata = &am335x_mmc1_platdata,
};
#endif
