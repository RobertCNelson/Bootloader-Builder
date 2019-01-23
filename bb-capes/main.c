#include <stdio.h>
#include <bsd/string.h>
#include "hash-string.h"

int main (void)
{
	/* /lib/firmware/BB-CAPE-DISP-CT4-00A0.dtbo */
	/* 14 + 16 + 1 + 4 + 5 = 40 */
	char cape_overlay[41];
	char original_hash[10];
	unsigned long cape_overlay_hash = 0;

	strlcpy(cape_overlay, "/lib/firmware/BB-CAPE-DISP-CT4-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x3c766f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-CAM-VVDN-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x24f51cf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/NL-AB-BBCL-00B0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x4b0c13f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/bb-justboom-dac-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x74e7bbf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-GREEN-HDMI-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x93b574f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//9dc
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-NH10C-01-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x9dcd73f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/bb-justboom-amp-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0xb1b7bbf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//d15bb
	strlcpy(cape_overlay, "/lib/firmware/DLPDLCR2000-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0xd15b80f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/bb-justboom-digi-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0xd4c9eff", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//e3
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-NH7C-01-A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0xe3f55df", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fc
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-LCD7-01-00A3.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfc93c8f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fe131
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D5R-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1313f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fe132
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D4R-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1323f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D4N-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1327f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D4C-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe132cf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fe133
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D7N-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1337f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D7C-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe133cf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fe135
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D5N-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1357f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D5C-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe135cf", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	//fe137
	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-4D7R-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe1373f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-LCD4-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe93c1f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	return 0;
}
