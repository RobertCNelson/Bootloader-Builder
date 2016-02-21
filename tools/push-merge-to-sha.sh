#!/bin/sh -e

DIR=$PWD
repo="https://github.com/RobertCNelson/u-boot/commit"
compare="https://github.com/RobertCNelson/u-boot/compare"

if [ -e ${DIR}/version.sh ]; then
	unset uboot_latest
	. ${DIR}/version.sh

	BRANCH="master"

	git commit -a -m "merge to: ${repo}/${uboot_latest}" -m "${compare}/${uboot_prev}...${uboot_latest}" -s
	git push origin ${BRANCH}
fi

