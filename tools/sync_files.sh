#!/bin/bash -e
#
# Copyright (c) 2010-2012 Robert Nelson <robertcnelson@gmail.com>
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

DIR=$PWD

build_server="http://httphost/jenkins/bootloader/deploy"
file="latest-bootloader.log"

file_dl=0
md5sum_off=0
md5sum_match=0

dl_latest () {
	if [ -f ${DIR}/${file} ] ; then
		rm -rf ${DIR}/${file} || true
	fi

	wget --no-verbose ${build_server}/${file}

	if [ ! -f ${DIR}/${file} ] ; then
		echo "Error: failed to download from ${build_server}"
		exit
	fi
}

dl_file () {
	if [ ! -f ${DIR}/${board}/${file} ] ; then
		echo "dl: ${file}"
		wget -c --directory-prefix=${DIR}/${board}/ ${http_file}

		if [ ! -f ${DIR}/${board}/${file} ] ; then
			echo "Error: failed to download ${file} from ${build_server}"
			exit
		fi

		temp=$(md5sum ${DIR}/${board}/${file} | awk '{print $1}')
		if [ "x${temp}" != "x${md5sum}" ] ; then
			rm -rf ${DIR}/${board}/${file} || true
			echo "Error: md5sum verification failed on ${file} from ${build_server}"
			exit
		else
			echo ${temp} > ${DIR}/${board}/${file}.md5sum
		fi

		let file_dl=$file_dl+1
	fi
}

verify_file () {
	if [ ! -d ${DIR}/${board} ] ; then
		mkdir -p ${DIR}/${board} || true
	fi

	dl_file

	if [ -f ${DIR}/${board}/${file} ] ; then
		test_md5sum=$(md5sum ${DIR}/${board}/${file} | awk '{print $1}')

		#Sometimes there can be manual uploads
		if [ ! -f ${DIR}/${board}/${file}.md5sum ] ; then
			echo ${test_md5sum} > ${DIR}/${board}/${file}.md5sum
		fi

		saved_md5sum=$(cat ${DIR}/${board}/${file}.md5sum)
		if [ "x${test_md5sum}" != "x${saved_md5sum}" ] ; then
			rm -rf ${DIR}/${board}/${file} || true
			rm -rf ${DIR}/${board}/${file}.md5sum || true
			let md5sum_off=$md5sum_off+1
			dl_file
		else
			let md5sum_match=$md5sum_match+1
		fi
	fi
}

process_latest () {
	while read line
	do
		board=$(echo ${line} | awk -F'#' '{ print $1 }')
		http_file=$(echo ${line} | awk -F'#' '{ print $2 }')
		file=$(echo ${http_file} | awk -F'/' '{ print $(NF) }')
		md5sum=$(echo ${line} | awk -F'#' '{ print $3 }')
		verify_file
	done < "${file}"
}

dl_latest
process_latest

if [ -f ${DIR}/${file} ] ; then
	rm -rf ${DIR}/${file} || true
fi

echo "Report: verfied files: ${md5sum_match}"
echo "Report: corrupted files: ${md5sum_off}"
echo "Report: files downloaded: ${file_dl}"
