#!/bin/sh
# Desc: creates a bootable Slackware ISO image
#
# Author: Bruno Barberi Gnecco <brunobg@users.sourceforge.net>
# Contributors:
# * 2006/05/25 ~ Davide Zito <dave@slack-kickstart.org>
# * 2011/06/01 ~ Zdenek Styblik <stybla@turnovfree.net>
#
# Copyright (C) 2011
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#
# Work Dir
# we need to set a working directory
# for iso image creation; WORKDIR
# must be large enough if you need
# to create an install image.
#
WORKDIR='/tmp/'
BSDIR="${WORKDIR}/Kickstart"
ISODIR="${WORKDIR}/Kickstart/tmp"
RDSIZE=${RDSIZE:-65536}

if [ ! -d "${WORKDIR}/Kickstart/tmp" ]; then
	printf "Creating workdir '${WORKDIR}'..."
	if mkdir -p "${WORKDIR}/Kickstart/tmp" > /dev/null 2>&1 ; then
		printf "\t[ OK ]\n"
	else
		printf "\t[ FAIL ]\n"
		MYSELF=$(whoami)
		printf "\nError creating work directory '%s' !\n\n" ${BSDIR}
		printf "Create '%s' with root, and change \n" ${BSDIR}
		printf "permissions to 'Kickstart' subdirectory: \n\n"
		printf " chown %s:users '%s'\n\n" ${MYSELF} ${BSDIR}
		exit 1
	fi
fi
######################################
# Utilities ~ Find utils that we need
######################################
if [ ! -f $(which mkisofs) ]; then
	printf "\nFatal error: cannot find 'mkisofs'\n"
	printf "\nHINT: Check if package 'cdrtools' is installed\n\n"
	exit 1
fi
MKISOFS=$(which mkisofs)
if [ ! -x "${MKISOFS}" ]; then
	echo "You need to have mkisofs in your path."
	exit 1
fi

ISOLINUXBIN=${ISOLINUXBIN:-"/usr/share/syslinux/isolinux.bin"}
if [ ! -e "${ISOLINUXBIN}" ]; then
	#try to find it...
	ISOLINUXBIN=$(locate isolinux.bin | head -n 1)
fi
while [ ! -e "${ISOLINUXBIN}" ]; do
	echo "Required file '${ISOLINUXBIN}' couldn't be found."
	echo "If it's not located in '/usr/share/syslinux/' then "
	echo "export path to isolinux.bin in variable 'ISOLINUXBIN'."
	exit 1
done
#
# Get the kernel
#
if [ $# -lt 2 ]; then
	printf "Usage: %s <initrd_image> <kernel> [Slackware_CD]\n" ${0}
	exit 1
fi

INITRDIMG=${1:-''}
if [ ! -e "${INITRDIMG}" ]; then
	printf "\nError: Cannot find initrd image '%s'.\n\n" ${INITRDIMG}
	exit 1
fi

if file "${INITRDIMG}" | grep -q -e "gzip compressed data" ; then
	# OK
	true
else
	printf "\nError: Not an initrd image '%s'!\n\n" ${INITRDIMG}
	exit 1
fi
KERNEL=${2:-''}
if [ ! -e "${KERNEL}" ]; then
	printf "\nError: Cannot find kernel '%s'\n\n" ${KERNEL}
	exit 1
fi
if file "${KERNEL}" | \
	awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" | \
	grep -q -E -e '^.+$' ; then
	# dummy
	true
else
	printf "\nError: Not a Slackware kernel '%s'!\n\n" ${KERNEL}
	exit 1
fi

HOST=$(basename "${INITRDIMG}" | sed -e "s#.gz##g")
#todo: get from kickslack
CD_IMAGE="${HOST}.iso"

mkdir -p "${ISODIR}/isolinux"
mkdir -p "${ISODIR}/img"
cp "${ISOLINUXBIN}" "${ISODIR}/isolinux"
cp "${INITRDIMG}" "${ISODIR}/initrd.img"
cat << EOP > ${ISODIR}/isolinux/isolinux.cfg
default linux
prompt 0
label linux
  kernel /kernels/vmlinuz
  append initrd=/initrd.img devfs=nomount load_ramdisk=1 prompt_ramdisk=0 ramdisk_size=${RDSIZE} rw root=/dev/ram0
EOP

cat << EOF > ${ISODIR}/isolinux/iso.sort
isolinux 100
isolinux/isolinux.bin 200
kernels 50
EOF

mkdir "${ISODIR}/kernels"
cp "${KERNEL}" "${ISODIR}/kernels/vmlinuz"
#
# If #3 is not null, the user needs to
# create an install cd, so we need to
# mount Slackware CD-ROM, parse the
# tagfile, and copy the needed stuff.
#
if [ $# -eq 3 ]; then
	PACKAGE_SERVER=$(grep -e 'PACKAGE_SERVER' "./config-files/${HOST}.cfg" | \
		sed -e 's/PACKAGE_SERVER=//g')
	PKG_REP=$(printf "%s\n" ${PACKAGE_SERVER} | awk -F ':' '{ print $1 }')

	if [ "${PKG_REP}" = "cdrom" ]; then
		SLACKCD=${3:-''}
		if [ ! -e "${SLACKCD}/CHECKSUMS.md5" ]; then
			printf "\nCannot find Slackware CD on '%s' - Aborting\n\n" ${SLACKCD}
			exit 1
		fi
		if [ -d "${SLACKCD}/slackware" ]; then
			LIBDIRSUFFIX=""
		elif [ -d "${SLACKCD}/slackware64" ]; then
			LIBDIRSUFFIX=64
		else
			printf "\nDirectory '%s/slackware' nor '%s/slackware64' found.\n\n" \
				${SLACKCD} ${SLACKCD}
			exit 1
		fi
		#
		# Packages
		#
		mkdir "${ISODIR}/slackware${LIBDIRSUFFIX}"
		cp "${SLACKCD}/CHECKSUMS.md5" "${ISODIR}"
	
		TAG=$(grep -e 'TAG' "./config-files/${HOST}.cfg" | -e sed 's/TAG=//g')
		TAGGET=$(printf "%s" "${TAG}" | cut -d ':' -f 1)
		TAGSRC=$(printf "%s" "${TAG}" | cut -d ':' -f 2-)
		TAGFILE=$(basename "${TAGSRC}")
		if [ "${TAGGET}" != 'file' ]; then
			printf "WARNING - TAG list get method should be 'file', not '%s'.\n" \
				"${TAGGET}"
		fi
		if [ ! -s "./taglists/${TAGFILE}" ]; then
			printf "FATAL ERROR - File './taglists/%s' doesn't seem to exist.\n" \
				"${TAGFILE}"
			exit 1
		fi
		for PACKAGE in $(grep -v -e '^#' "./taglists/${TAGFILE}" | \
			cut -d ":" -f 1); do
			DISKSET=$(printf "%s\n" ${PACKAGE} | cut -d "/" -f 1)
			if [ ! -d "${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}" ]; then
				mkdir "${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}"
				printf "\nCopying packages for diskset [ %s ] " "${DISKSET}"
			fi
			printf "."
			cp ${SLACKCD}/slackware${LIBDIRSUFFIX}/${PACKAGE}*.t?z \
				"${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}/"
			chmod 750 ${ISODIR}/slackware${LIBDIRSUFFIX}/${PACKAGE}*.t?z
		done
	else
		printf "- Package repository is not on CD-ROM: packages will not be copied.\n"
	fi
fi

printf "\n\n-------------- Creating ISO image: -------------\n"
mkisofs -R -J -l -o "${BSDIR}/${CD_IMAGE}" -b isolinux/isolinux.bin \
	-c isolinux/boot.cat \
	-sort "${ISODIR}/isolinux/iso.sort" -no-emul-boot -boot-load-size 4 \
	-boot-info-table -V "Slack-Kickstart" -A "Slack-Kickstart" "${ISODIR}"
printf "------------------------------------------------\n"
#
# Cleans $ISODIR
#
rm -rf "${ISODIR}"

printf "\nISO image '%s/%s' created with success: now burn it with your \
favorite tool!\n\n" ${BSDIR} ${CD_IMAGE}
