#!/bin/bash

#add: bc bison flex libssl-dev u-boot-tools python3-pycryptodome python3-pyelftools
#binutils-arm-linux-gnueabihf
#gcc-arm-linux-gnueabihf

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- distclean
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig

make ARCH=arm -j4 CROSS_COMPILE=arm-linux-gnueabihf-
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- savedefconfig
cp -v defconfig ./configs/am335x_evm_defconfig
