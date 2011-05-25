#!/bin/sh
#
# MakeIso by Bruno Barberi Gnecco
# brunobg@users.sourceforge.net
#
# Last Revision: 25/05/2006 vonatar
#

#
# Work Dir
# we need to set a working directory
# for iso image creation; WORKDIR
# must be lanrge enough if you need
# to create an install image.
#

WORKDIR='/tmp/'
BSDIR="${WORKDIR}/Kickstart"
ISODIR="${WORKDIR}/Kickstart/tmp"
RDSIZE=32768

if [ ! -f $(which mkisofs) ]; then
	echo
	echo "Fatal error: cannot find 'mkisofs'"
	echo 
	echo "HINT: Check if package 'cdrtools' is installed"
	echo
	exit 1
fi

if [ ! -d "${WORKDIR}/Kickstart/tmp" ]; then
	mkdir -p "${WORKDIR}/Kickstart/tmp" > /dev/null 2>&1 || \
		{
			MYSELF=$(whoami)
			echo
			echo "Error creating work directory '${BSDIR}' !"  
			echo "create '${BSDIR}' with root, and change  "
			echo "permissions to 'Kickstart' subdirectory: "
			echo
			echo " chown ${MYSELF}:users '${BSDIR}'"
			echo
			exit 1
		}
fi

#
# FUNCTIONS
#
#
# Find utils that we need
#
MKISOFS=$(which mkisofs)
if [ ! -x "${MKISOFS}" ]; then
	echo "You need to have mkisofs in your path."
	exit 1
fi

ISOLINUXBIN="/usr/share/syslinux/isolinux.bin"
if [ ! -e "${ISOLINUXBIN}" ]; then
	#try to find it...
	ISOLINUXBIN=$(locate isolinux.bin | head -n 1)
fi

while [ ! -e "${ISOLINUXBIN}" ]; do
	# TODO: ask user.
	echo "Required file '${ISOLINUXBIN}' couldn't be found."
	exit 1
done

#
# Get the kernel
#

if [ $# -lt 2 ]; then
	echo
	echo "usage: ${0} initrd_image kernel [Slackware CD]"
	echo
	exit 1
fi

INITRDIMG=${1:-''}

if [ ! -e "${INITRDIMG}" ]; then
	echo
	echo "Error: Cannot find initrd image '${INITRDIMG}'"
	echo
	exit 1
fi

file "${INITRDIMG}" | grep -q -e "gzip compressed data" || \
	{
		echo
		echo "Error: Not an initrd image '${INITRDIMG}' !"
		echo
		exit 1
	}
KERNEL=${2:-''}
if [ ! -e "${KERNEL}" ]; then
	echo
	echo "Error: Cannot find kernel '${KERNEL}'"
	echo
	exit 1
fi
file "${KERNEL}" | awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" | \
	grep -q -E -e '^.+$' || \
	{
		echo
		echo "Error: Not a Slackware kernel '${KERNEL}' !"
		echo
		exit 1
	}


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
# mount Slackware CD-Rom, parse the
# tagfile, and copy the needed stuff.
#

if [ $# -eq 3 ]; then
	PACKAGE_SERVER=$(grep -e 'PACKAGE_SERVER' "Config-Files/${HOST}.cfg" | \
		sed -e 's/PACKAGE_SERVER=//g')
	PKG_REP=$(echo "${PACKAGE_SERVER}" | cut -d ":" -f 1)

	if [ "${PKG_REP}" = "cdrom" ]; then
		SLACKCD=${3:-''}
		TAG=$(grep -e 'TAG' "Config-Files/${HOST}.cfg" | -e sed 's/TAG=//g')
		if [ ! -e "${SLACKCD}/CHECKSUMS.md5" ]; then
			echo
			echo "Cannot find Slackware-10.2 CD on '${SLACKCD}' - Aborting"
			echo
			exit 1
		fi
		#
		# Packages
		#
		mkdir "${ISODIR}/slackware"
		cp "${SLACKCD}/CHECKSUMS.md5" "${ISODIR}"
	
		for PACKAGE in $(grep -v -e '^#' "./taglists/${TAG}" | cut -d ":" -f 1); do
			DISKSET=$(echo "${PACKAGE}" | cut -d "/" -f 1)
			if [ ! -d "${ISODIR}/slackware/${DISKSET}" ]; then
				mkdir "${ISODIR}/slackware/${DISKSET}"
				echo
				printf "Copying packages for diskset [ %s ] " "${DISKSET}"
			fi
			printf "."
			cp ${SLACKCD}/slackware/${PACKAGE}*.t?z \
				"${ISODIR}/slackware/${DISKSET}/"
			chmod 750 ${ISODIR}/slackware/${PACKAGE}*.t?z
		done
	else
		echo
		echo "- Package repository is not on CD-Rom: packages will not be copied."
	fi
fi

echo
echo
echo "-------------- Creating ISO image: -------------"
mkisofs -R -J -l -o "${BSDIR}/${CD_IMAGE}" -b isolinux/isolinux.bin -c isolinux/boot.cat \
	-sort "${ISODIR}/isolinux/iso.sort" -no-emul-boot -boot-load-size 4 \
	-boot-info-table -V "Slack-Kickstart" -A "Slack-Kickstart" "${ISODIR}"
echo "------------------------------------------------"

#
# Cleans $ISODIR
#

rm -rf "${ISODIR}"

echo
echo "ISO image '${BSDIR}/${CD_IMAGE}' created with success: now burn it with your favorite tool!"
echo
