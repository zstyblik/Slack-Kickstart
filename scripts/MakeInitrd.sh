#!/bin/bash
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

# Ramdisk Constants
RDSIZE=${RDSIZE:-65536}

show_help()
{
	printf "\nUsage: %s <config-file> <bzImage> <template>\n\n" "${0}"
#	echo "Example: ${0} \
#		config-files/sample.cfg \
#		kernels/huge.s/bzImage \
#		templates/tmpl-slackware-10.2.gz"
	return 0
} # show_help
#########
# MAIN	#
#########
if [ $# -ne 3 ]; then
	show_help
	exit 1
fi
#
CFGFILE=${1:-''}
KERNEL=${2:-''}
TMPLFILE=${3:-''}
if [ -z "${CFGFILE}" ] || [ -z "${TMPLFILE}" ] || [ -z "${KERNEL}" ]; then
	show_help
	exit 1
fi
if [ ! -f "${CFGFILE}" ]; then
	printf "\nCannot find config file: '%s'!\n\n" "${CFGFILE}"
	exit 1
fi
if [ ! -f "${TMPLFILE}" ]; then
	printf "\nCannot find template image '%s'!\n" "${TMPLFILE}"
	show_help
	exit 1
fi
if [ ! -f "${KERNEL}" ]; then
	printf "\nCannot find bzImage '%s'!\n" "${KERNEL}"
	show_help
	exit 1
fi
# Tool check
if [ $(whoami) != "root" ]; then
	printf "\nYou must exec %s as root\n\n" "${0}"
	exit 1
fi
if ! which openssl &>/dev/null ; then
	printf "\nCannot find openssl binary!\n"
	printf "\nPlease install openssl package.\n\n"
	exit 1
fi
# Directories check
if [ ! -d './rootdisks' ]; then
	mkdir './rootdisks'
fi
if [ ! -d './mount' ]; then
	mkdir './mount'
fi

clear

HOST=$(basename "${CFGFILE}" '.cfg')
if [ ! -f "./config-files/${HOST}.cfg" ]; then
	printf "Cannot find config file: './config-files/%s.cfg'.\n\n" "${HOST}"
	exit 1
fi
. "./config-files/${HOST}.cfg"
#
# Info needed for: 
#
# - Kernel name in rootdisks/$HOST.install
# - root password md5 hash
# - Install info
#
KNAME=$(basename "${KERNEL}")
ENCRYPTED=$(openssl passwd -1 "${PASSWD}")
INSTALL_TYPE=$(printf "%s\n" ${PACKAGE_SERVER} | awk -F':' '{ print $1 }')
#########################
# Copy from template	#
# and mount in loopback	#
#########################
echo "#########################"
echo "# Creating initrd image #"
echo "#########################"
echo
printf "Cloning template image..."

cp "${TMPLFILE}" "${HOST}.gz" \
 && printf "\t[ OK ]\n"

# Unpacking root image
printf "Unpacking initrd image..."

gunzip "${HOST}.gz" \
 && printf "\t[ OK ]\n"

sleep 2
# Mounting root image in loopback on mount directory
printf "Mounting initrd image..."
if mount -o loop "${HOST}" ./mount > /dev/null 2>&1 ; then
	printf "\t[ OK ]\n"
else
	rm "${HOST}"
	printf "\t[FAILED]\n"
	printf "\nError mounting initrd image - Aborting!\n\n"
	exit 1
fi
#################
# Kickstart.cfg #
#################
#------------------------------------------
# Creates etc/Kickstart.cfg on root image
#------------------------------------------
sed -e "s@${PASSWD}@\'${ENCRYPTED}\'@" "config-files/${HOST}.cfg" \
	> mount/etc/Kickstart.cfg
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
	if [ -z "${TAGFILE}" ] || [ ! -e "./taglists/${TAGFILE}" ]; then
		printf "\t\t[ FAIL ]\n"
		printf "TAG list empty or does not exist.\n"
	else
		printf "#\n# Taglist: %s\n#" "${TAGFILE}" >> mount/etc/Kickstart.cfg
		grep -v -E -e "^#" "./taglists/${TAGFILE}" | \
			awk '{ printf "#@%s\n", $0 }' >> mount/etc/Kickstart.cfg
		printf "# END of Taglist: %s" "${TAGFILE}" >> mount/etc/Kickstart.cfg
		printf "\t\t[ OK ]\n"
	fi # if [ -z "${TAGFILE}" ] || ...
else
	printf "TAG list skipped.\n"
fi # if [ "$(printf ... ]
# SSH keys
printf "Getting SSH keys..."
if [ -e "config-files/authorized_keys" ]; then
	mkdir -p "mount/root/.ssh/"
	mkdir -p "mount/etc/dropbear/"
	cp "config-files/authorized_keys" "mount/etc/dropbear/"
	cp "config-files/authorized_keys" "mount/root/.ssh/"
	chmod 400 "mount/root/.ssh/" "mount/etc/dropbear/"
	printf "\t\t[ OK ]\n"
else
	printf "\t\t[ FAIL ]\n"
fi
#--------------------------------------
# Timezone setting
#--------------------------------------
cp "/usr/share/zoneinfo/${TIMEZONE}" mount/etc/localtime
##########
# Kernel #
##########
if [ ! -d mount/kernel ]; then
	mkdir mount/kernel
fi
cp "${KERNEL}" mount/kernel/
#------------------------------------------
# Creates the root image
#------------------------------------------
printf "Umounting initrd image..."

umount mount \
  && printf "\t[ OK ]\n"

printf "Compressing initrd image..."
gzip "${HOST}" \
	&& printf "\t[ OK ]\n"
#
# Now we move the root image to
# rootdisks directory
#
mv "${HOST}.gz" rootdisks

printf "\nRoot image for '%s' has been created!\n\n" ${HOST}

if [ "${INSTALL_TYPE}" = "cdrom"  ]; then

	cat << EOP
#
# Create Install CD with:
# [ Expecting Slackware-10.2 CD-Rom in /mnt/cdrom ]
#

./scripts/MakeIso.sh rootdisks/${HOST}.gz ${KERNEL} /mnt/cdrom

EOP

	else
		printf "\nSee 'rootdisks/Install.%s.txt' for install info.\n\n" ${HOST}
		cat << EOF > ./rootdisks/Install.${HOST}.txt

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
	chown ${USER}:${GROUP} "./rootdisks/Install.${HOST}.txt"
fi # if INSTALL_TYPE cdrom
#
# Changes ownership to
# initrd image
#
chown ${USER}:${GROUP} "./rootdisks/${HOST}.gz"
# EOF
