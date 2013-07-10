#!/bin/sh
# Desc: Creates an image configured by parameters - config, kernel, template
#
# Copyright (C) 2006 Davide Zito
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
#################
# MakeInitrd.sh #
#################
set -e
set -u

CWD=$(pwd)
SCRIPT_NAME=$(basename -- "${0}")
# Ramdisk Constants
RDSIZE=${RDSIZE:-65536}
SLACK_KS_DIR=${SLACK_KS_DIR:-''}
if [ -z "${SLACK_KS_DIR}" ]; then
	# Presumption is $0 is in $SLACK_KS_DIR/scripts/
	SLACK_KS_DIR=$(dirname -- "${0}")
	cd "${SLACK_KS_DIR}"
	cd ../
	SLACK_KS_DIR="$(pwd)"
	cd "${CWD}"
fi

show_help()
{
	printf "Usage: %s <config-file> <bzImage> <template>\n" "${SCRIPT_NAME}" 1>&2
	printf "Example: %s %s %s\n" "${SCRIPT_NAME}" "config-files/sample.cfg" \
		"kernels/huge.s/bzImage" "templates/tmpl-slackware-10.2.gz" 1>&2
	return 0
} # show_help
#########
# MAIN	#
#########
if [ $# -ne 3 ]; then
	printf "Error: not enough parameters given.\n\n" 1>&2
	show_help
	exit 1
fi
#
CFGFILE=${1:-''}
KERNEL=${2:-''}
TMPLFILE=${3:-''}
if [ -z "${CFGFILE}" ] || [ -z "${TMPLFILE}" ] || [ -z "${KERNEL}" ]; then
	printf "Error: One of given parameters is empty.\n\n" 1>&2
	show_help
	exit 1
fi
if [ ! -f "${CFGFILE}" ]; then
	printf "Error: Cannot find config file: '%s'!\n\n" "${CFGFILE}" 1>&2
	exit 1
fi
if [ ! -f "${TMPLFILE}" ]; then
	printf "Error: Cannot find template image '%s'!\n\n" "${TMPLFILE}" 1>&2
	show_help
	exit 1
fi
if [ ! -f "${KERNEL}" ]; then
	printf "Error: Cannot find bzImage '%s'!\n\n" "${KERNEL}" 1>&2
	show_help
	exit 1
fi
# Tool check
if [ $(whoami) != "root" ]; then
	printf "Error: This script must be executed as a root.\n\n" 1>&2
	exit 1
fi
if ! which openssl > /dev/null 2>&1 ; then
	printf "Error: Cannot find openssl binary!\n" 1>&2
	printf "Error: Please install openssl package.\n\n" 1>&2
	exit 1
fi
# Directories check
if [ ! -d "${SLACK_KS_DIR}/rootdisks" ]; then
	mkdir "${SLACK_KS_DIR}/rootdisks"
fi

clear
. "${CFGFILE}"
HOST=$(basename "${CFGFILE}" '.cfg')
MYTMP_DIR=$(mktemp -d)
if [ -z "${MYTMP_DIR}" ]; then
	printf "Error: Failed to create temporary directory.\n\n" 1>&2
	exit 1
fi
printf "Using temp directory '%s'.\n" "${MYTMP_DIR}"
# Info needed for: 
# - Kernel name in rootdisks/$HOST.install
# - root password md5 hash
# - Install info
KNAME=$(basename "${KERNEL}")
ENCRYPTED=$(openssl passwd -1 "${PASSWD}")
INSTALL_TYPE=$(printf -- "%s" ${PACKAGE_SERVER} | awk -F':' '{ print $1 }')
#########################
# Copy from template	#
# and mount in loopback	#
#########################
printf "#########################\n"
printf "# Creating initrd image #\n"
printf "#########################\n\n"

printf "Cloning template image..."
cp "${TMPLFILE}" "${MYTMP_DIR}/${HOST}.gz" \
 && printf "\t[ OK ]\n"

# Unpacking root image
printf "Unpacking initrd image..."
cd "${MYTMP_DIR}"
gunzip "${HOST}.gz" \
 && printf "\t[ OK ]\n"
cd "${CWD}"

sleep 2
# Mounting root image in loopback on mount directory
MOUNT_POINT="${MYTMP_DIR}/mount"
mkdir "${MOUNT_POINT}"
printf "Mounting initrd image..."
if mount -o loop "${MYTMP_DIR}/${HOST}" \
	"${MOUNT_POINT}" > /dev/null 2>&1 ; then
	printf "\t[ OK ]\n"
else
	rm -rf "${MYTMP_DIR}"
	printf "\t[FAILED]\n"
	printf "\nError mounting initrd image - Aborting!\n\n" 1>&2
	exit 1
fi
#################
# Kickstart.cfg #
#################
if [ ! -d "${MOUNT_POINT}/etc" ]; then
	mkdir "${MOUNT_POINT}/etc"
fi
#------------------------------------------
# Creates etc/Kickstart.cfg on root image
#------------------------------------------
sed -e "s@${PASSWD}@\'${ENCRYPTED}\'@" "${CFGFILE}" \
	> "${MOUNT_POINT}/etc/Kickstart.cfg"
#----------------------------------------------------------
# appends Taglist to Kickstart.cfg 
#
# The list of packages to be installed is 'escaped'
# with '#@' to avoid problems when including Kickstart.cfg
# on top of scripts.
#----------------------------------------------------------
TAG=${TAG:-''}
TAGGETTYPE=$(printf "%s" "${TAG}" | cut -d ':' -f 1)
TAGFILE=$(basename "${TAG}")
if [ "$(printf "%s" "${TAG}" | cut -d ':' -f 1)" = 'file' ]; then
	printf "Copying TAG list '%s' ..." "${TAGFILE}"
	if [ -z "${TAGFILE}" ] || [ ! -e "${SLACK_KS_DIR}/taglists/${TAGFILE}" ]; then
		printf "\t[ FAIL ]\n"
		printf "TAG list is either empty or does not exist.\n" 1>&2
	else
		printf "#\n# Taglist: %s\n#" "${TAGFILE}" >> \
			"${MOUNT_POINT}/etc/Kickstart.cfg"
		grep -v -E -e "^#" "${SLACK_KS_DIR}/taglists/${TAGFILE}" | \
			awk '{ printf "#@%s\n", $0 }' >> "${MOUNT_POINT}/etc/Kickstart.cfg"
		printf "# END of Taglist: %s" "${TAGFILE}" >> \
			"${MOUNT_POINT}/etc/Kickstart.cfg"
		printf "\t[ OK ]\n"
	fi # if [ -z "${TAGFILE}" ] || ...
else
	printf "TAG list skipped.\n"
fi # if [ "$(printf ... ]
# SSH keys
printf "Getting SSH keys..."
if [ -e "${SLACK_KS_DIR}/config-files/authorized_keys" ]; then
	mkdir -p "${MOUNT_POINT}/root/.ssh/"
	mkdir -p "${MOUNT_POINT}/etc/dropbear/"
	cp "${SLACK_KS_DIR}/config-files/authorized_keys" \
		"${MOUNT_POINT}/etc/dropbear/"
	cp "${SLACK_KS_DIR}/config-files/authorized_keys" \
		"${MOUNT_POINT}/root/.ssh/"
	chmod 400 "${MOUNT_POINT}/root/.ssh/" "${MOUNT_POINT}/etc/dropbear/"
	printf "\t[ OK ]\n"
else
	printf "\t[ FAIL ]\n"
fi
#--------------------------------------
# Timezone setting
#--------------------------------------
cp "/usr/share/zoneinfo/${TIMEZONE}" "${MOUNT_POINT}/etc/localtime"
##########
# Kernel #
##########
if [ ! -d "${MOUNT_POINT}/kernel" ]; then
	mkdir "${MOUNT_POINT}/kernel"
fi
cp "${KERNEL}" "${MOUNT_POINT}/kernel/"
#------------------------------------------
# Creates the root image
#------------------------------------------
printf "Umounting initrd image..."
umount "${MOUNT_POINT}" \
  && printf "\t[ OK ]\n"

printf "Compressing initrd image..."
cd "${MYTMP_DIR}"
gzip "${HOST}" \
	&& printf "\t[ OK ]\n"
#
# Now we move the root image to
# rootdisks directory
#
mv "${HOST}.gz" "${SLACK_KS_DIR}/rootdisks/"
printf "Removing temp directory '%s'.\n" "${MYTMP_DIR}"
rm -rf "${MYTMP_DIR}"

printf "\nRoot image for '%s' has been created and moved to '%s'!\n\n" \
	"${HOST}" "${SLACK_KS_DIR}/rootdisks/"

if [ "${INSTALL_TYPE}" = "cdrom"  ]; then

	cat << EOP
#
# Create Install CD with:
# [ Expecting Slackware-10.2 CD-Rom in /mnt/cdrom ]
#

./scripts/MakeIso.sh rootdisks/${HOST}.gz ${KERNEL} /mnt/cdrom

EOP

	else
		printf "\nSee 'rootdisks/%s.Install.txt' for install info.\n\n" ${HOST}
		cat << EOF > ./rootdisks/${HOST}.Install.txt

------------- LILO INSTALL  -----------------------
#
# Add to old server's LILO Images section:
#

image = /boot/${KNAME}
  root = /dev/ram0
  label = Kickstart
  initrd = /boot/${HOST}.gz
  ramdisk = ${RDSIZE}
  append = "panic=5"

#
# Remember to upload initrd image and kernel into your 
# old server:
#

scp ${KERNEL} rootdisks/${HOST}.gz root@your_old_server:/boot

------------------- Boot CD -----------------------------
#
# Create a Boot CD with:
#

./scripts/MakeIso.sh rootdisks/${HOST}.gz ${KERNEL}

------------------- PXE INFO ----------------------------
#
# Your PXE config file should be like:
#

default Kickstart
prompt 0
label Kickstart
 kernel ${KNAME}
 append initrd=${HOST}.gz devfs=nomount load_ramdisk=1 prompt_ramdisk=0 ramdisk_size=${RDSIZE} rw root=/dev/ram

# Remember to upload kernel and initrd image into
# your tftp server with something like:

scp ${KERNEL} rootdisks/${HOST}.gz root@your_pxe_server:/tftpboot

-------------------------------------------------------------

EOF
#
# Changes ownership to
# info file
#
	GROUP=$(id -ng)
	chown ${USER}:${GROUP} "${SLACK_KS_DIR}/rootdisks/${HOST}.Install.txt"
fi # if INSTALL_TYPE cdrom
#
# Changes ownership to
# initrd image
#
chown ${USER}:${GROUP} "${SLACK_KS_DIR}/rootdisks/${HOST}.gz"
# EOF
