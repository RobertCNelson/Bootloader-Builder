#!/bin/bash

SYST=$(uname -n)

if [ "x${SYST}" == "xhera" ] ; then
	#dl:http://rcn-ee.homeip.net:81/dl/bootloader/
	CC=/mnt/sata0/git_repo/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
fi

if [ "x${SYST}" == "xwork-e6400" ] || [ "x${SYST}" == "xhades" ] || [ "x${SYST}" == "xx4-955" ] || [ "x${SYST}" == "xe350" ] ; then
	CC=/opt/github/linaro-tools/cross-gcc/build/sysroot/home/voodoo/opt/gcc-linaro-cross/bin/arm-linux-gnueabi-
fi

