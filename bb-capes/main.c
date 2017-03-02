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

	strlcpy(cape_overlay, "/lib/firmware/NL-AB-BBCL-00B0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x4b0c13f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-GREEN-HDMI-00A0.dtbo", 40 + 1);
	strlcpy(original_hash, "0x93b574f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-LCD7-01-00A3.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfc93c8f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	strlcpy(cape_overlay, "/lib/firmware/BB-BONE-LCD4-01-00A1.dtbo", 40 + 1);
	strlcpy(original_hash, "0xfe93c1f", 9 + 1);
	cape_overlay_hash = hash_string(cape_overlay);
	printf("[0x%lx]=[%s],[%s]\n", cape_overlay_hash, original_hash, cape_overlay);

	return 0;
}
