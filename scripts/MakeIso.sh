#!/bin/sh
#
# MakeIso by Bruno Barberi Gnecco
# brunobg@users.sourceforge.net
#
# Last Revision: 25/05/2006 vonatar
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
	if $(mkdir -p "${WORKDIR}/Kickstart/tmp" > /dev/null 2>&1) ; then
		printf "\t[ OK ]\n"
	else
		printf "\t[ FAIL ]\n"
		MYSELF=$(whoami)
		echo
		echo "Error creating work directory '${BSDIR}' !"  
		echo "Create '${BSDIR}' with root, and change  "
		echo "permissions to 'Kickstart' subdirectory: "
		echo
		echo " chown ${MYSELF}:users '${BSDIR}'"
		echo
		exit 1
	fi
fi
######################################
# Utilities ~ Find utils that we need
######################################
if [ ! -f $(which mkisofs) ]; then
	echo
	echo "Fatal error: cannot find 'mkisofs'"
	echo 
	echo "HINT: Check if package 'cdrtools' is installed"
	echo
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
	echo
	echo "usage: ${0} <initrd_image> <kernel> [Slackware_CD]"
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

if $(file "${INITRDIMG}" | grep -q -e "gzip compressed data") ; then
	# OK
	true
else
	echo
	echo "Error: Not an initrd image '${INITRDIMG}'!"
	echo
	exit 1
fi
KERNEL=${2:-''}
if [ ! -e "${KERNEL}" ]; then
	echo
	echo "Error: Cannot find kernel '${KERNEL}'"
	echo
	exit 1
fi
if $(file "${KERNEL}" | \
	awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" | \
	grep -q -E -e '^.+$') ; then
	# dummy
	true
else
	echo
	echo "Error: Not a Slackware kernel '${KERNEL}' !"
	echo
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
	PKG_REP=$(echo "${PACKAGE_SERVER}" | awk -F ':' '{ print $1 }')

	if [ "${PKG_REP}" = "cdrom" ]; then
		SLACKCD=${3:-''}
		TAG=$(grep -e 'TAG' "./config-files/${HOST}.cfg" | -e sed 's/TAG=//g')
		if [ ! -e "${SLACKCD}/CHECKSUMS.md5" ]; then
			echo
			echo "Cannot find Slackware CD on '${SLACKCD}' - Aborting"
			echo
			exit 1
		fi
		if [ -d "${SLACKCD}/slackware" ]; then
			LIBDIRSUFFIX=""
		elif [ -d "${SLACKCD}/slackware64" ]; then
			LIBDIRSUFFIX=64
		else
			echo
			echo "Directory '${SLACKCD}/slackware' nor '${SLACKCD}/slackware64' found."
			echo
			exit 1
		fi
		#
		# Packages
		#
		mkdir "${ISODIR}/slackware${LIBDIRSUFFIX}"
		cp "${SLACKCD}/CHECKSUMS.md5" "${ISODIR}"
	
		for PACKAGE in $(grep -v -e '^#' "./taglists/${TAG}" | cut -d ":" -f 1); do
			DISKSET=$(echo "${PACKAGE}" | cut -d "/" -f 1)
			if [ ! -d "${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}" ]; then
				mkdir "${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}"
				echo
				printf "Copying packages for diskset [ %s ] " "${DISKSET}"
			fi
			printf "."
			cp ${SLACKCD}/slackware${LIBDIRSUFFIX}/${PACKAGE}*.t?z \
				"${ISODIR}/slackware${LIBDIRSUFFIX}/${DISKSET}/"
			chmod 750 ${ISODIR}/slackware${LIBDIRSUFFIX}/${PACKAGE}*.t?z
		done
	else
		echo
		echo "- Package repository is not on CD-ROM: packages will not be copied."
	fi
fi

echo
echo
echo "-------------- Creating ISO image: -------------"
mkisofs -R -J -l -o "${BSDIR}/${CD_IMAGE}" -b isolinux/isolinux.bin \
	-c isolinux/boot.cat \
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
