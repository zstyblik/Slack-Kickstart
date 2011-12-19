# /usr/lib/setup/includes/functions.inc
# Desc: This file contains some common functions and variable definitions.
# 2006 @ vonatar
#
# Set Internal Field Separator
IFS='
'
# Redirect info to tty4
REDIR=/dev/tty4
# Info from config file
. /etc/Kickstart.cfg
# Kickstart.cfg options - defaults
AUTOSTART=${AUTOSTART:-'no'}
AUTOUPDATE=${AUTOUPDATE:-'none'}
BOOTLOADER=${BOOTLOADER:-''}
DISTRO=${DISTRO:-'slackware-default'}
DOMAIN=${DOMAIN:-'example.com'}
HOSTNAME=${HOSTNAME:-'darkstar'}
HWCLOCK=${HWCLOCK:-'utc'}
KERNEL=${KERNEL:-''}
KEYMAP=${KEYMAP:-''}
KS=${KS:-''}
NTPHOST=${NTPHOST:-''}
PACKAGE_SERVER=${PACKAGE_SERVER:-''}
PASSWD=${PASSWD:-''}
POSTINST=${POSTINST:-''}
PREINST=${PREINST:-''}
SECURE=${SECURE:-'no'}
SLAPTGET=${SLAPTGET:-''}
TAG=${TAG:-''}
TIMEZONE=${TIMEZONE:-''}
# Setup options - defaults
BOOTDEV=${BOOTDEV:-''}
ROOTPART=${ROOTPART:-''}
PKG_SRC=$(printf "%s\n" ${PACKAGE_SERVER} | cut -d ":" -f 1)
KERN=$(basename "${KERNEL}")

if [ ! -d /var/log/mount ]; then
	mkdir -p /var/log/mount
fi

#----------------------------- FUNCTIONS ------------------------------------------#

################
# Check CD-Rom #
################
#
# This function does the following tasks
#
# - Checks if we have a CD-Rom device.
# - Checks if we can mount the CD-Rom 
# - Checks if we can access the needed content on CD-Rom
#
Check_CD() {
	# Check if we have a CD-Rom device.
	if [ ! -s /tmp/CDROM ]; then
		printf " [FAILED]\n\n"
		printf "FATAL ERROR: Cannot find a CD-Rom device - Aborting\n"
		printf "HINT: Does this kernel support you CD-Rom device ?\n\n"
		exit 1
	fi
	CDROM=$(cat /tmp/CDROM)
	# Mounts cdrom
	if ! /bin/mount -o ro -t iso9660 "${CDROM}" \
		/var/log/mount > /dev/null 2>&1; then
		printf " [FAILED]\n\n"
		printf "FATAL ERROR: Cannot find media on ${CDROM} - Aborting\n"
		printf "HINT: Check media on %s\n\n" "${CDROM}"
		FireBugInfo
		exit 1
	fi
	# Check CHECKSUMS.md5 if we are testing PACKAGE_SERVER 
	if [ ! -s "/var/log/mount/${1}" ]; then
		printf " [FAILED]\n\n"
		printf "FATAL ERROR: Cannot find %s on %s - Aborting\n" "${1}" "${CDROM}"
		printf "HINT: Check configuration on /etc/Kickstart.cfg\n\n"
		FireBugInfo
		exit 1
	fi
	printf " [OK]\n"
	umount  /var/log/mount
	return 0
} # Check_CD
#####################
# Check Smart Array #
#####################
Check_Smart_Array() {
	DEVICE=${1:-''}
	if [ -z "${DEVICE}" ]; then
		printf ""
		return 1
	fi
	# If we're using Smart Array 2, we need to put a 'p' before 
	# partition number.
	if [ $DEVICE = "/dev/ida/c0d0" ];then
		DEVICE="/dev/ida/c0d0p"
	fi
	# If we're using Smart Array 5 we
	# need to put a 'p' before partition
	# number.
	if [ $DEVICE = "/dev/cciss/c0d0" ];then
		DEVICE="/dev/cciss/c0d0p"
	fi
	# If we're using Promise FastTrack 2TX we
	# need to put a 'p' before partition
	# number.
	if [ $DEVICE = "/dev/ataraid/d0" ];then
		DEVICE="/dev/ataraid/d0p"
	fi
	printf "%s" "${DEVICE}"
	return 0
} # Check_Smart_Array
#################
# Creates fstab #
#################
Create_Fstab() {
	rm -f  /tmp/fstab
	for ROW in $(cat /tmp/Partitions); do
		ROWNO=$(printf "%s\n" "${ROW}" | awk -F':' '{ print $2 }')
		FSYS=$(printf "%s\n" "${ROW}" | awk -F':' '{ print $4 }')
		if [ -z "${FSYS}" ]; then
			continue
		fi
		MOUNTPOINT=$(printf "%s\n" "${ROW}" | awk -F':' '{ print $3 }')
		DEVICE=$(printf "%s\n" "${ROW}" | awk -F':' '{ print $1 }')
		DEVICE=$(Check_Smart_Array "${DEVICE}")
		case "${MOUNTPOINT}" in
		'/')
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults" "1" "1" >> /tmp/fstab
			ROOTPART="${DEVICE}${ROWNO}"
			;;
		'/tmp')
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults,nosuid" "1" "2" >> /tmp/fstab
			;;
		'/var')
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults,nosuid" "1" "2" >> /tmp/fstab
			;;
		'swap')
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults" "0" "0" >> /tmp/fstab
			;;
		*)
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults" "1" "2" >> /tmp/fstab
		esac
	done # for ROW 

	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "/dev/fd0" "/mnt/floppy" \
		"auto" "noauto,owner" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "/dev/cdrom" "/mnt/cdrom" \
		"iso9660" "noauto,owner,ro" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "devpts" "/dev/pts" "devpts" \
		"gid=5,mode=620" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "proc" "/proc" "proc" "defaults" \
		"0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "cgroup" "/dev/cgroup" "cgroup" \
		"devices" "0" "0" >> /tmp/fstab
	return 0
} # Create_Fstab
# Desc: fetch alternative Kickstart.cfg
# $ARG1: string "gettype:source";
# @returns: 0 file fetched, 1 fail;
Get_Kickstart() {
	ARG1=${1:-''}
	if [ -z "${ARG1}" ]; then
		return 1
	fi
	# KS=<[ftp|http|nfs]:[source]>
	GETTYPE=$(printf "%s" "${ARG1}" | cut -d ':' -f 1)
	KSSOURCE=$(printf "%s" "${ARG1}" | cut -d ':' -f 2-)
	if [ -z "${KSSOURCE}" ]; then
		return 1
	fi
	if [ "${GETTYPE}" = 'ftp' ] || [ "${GETTYPE}" = 'http' ]; then
		if wget "${ARG1}/${HOSTNAME}.${DOMAIN}.cfg" \
			-O /tmp/Kickstart.cfg.new &>/dev/null; then
			return 0
		fi
		printf "Failed to get '%s/%s.%s.cfg'.\n" "${ARG1}" "${HOSTNAME}" "${DOMAIN}"
		if wget "${ARG1}/Kickstart.cfg" \
			-O /tmp/Kickstart.cfg.new &>/dev/null; then
			return 0
		fi
		printf "Failed to get '%s/Kickstart.cfg'.\n" "${ARG1}"
		return 1
	elif [ "${GETTYPE}" = 'nfs' ]; then
		if [ ! -d /tmp/nfs-ks ]; then
			mkdir /tmp/nfs-ks
		fi
		NFS_SERVER=$(printf "%s" "${KSSOURCE}" | cut -d ':' -f 1)
		NFS_DIR=$(printf "%s" "${KSSOURCE}" | cut -d ':' -f 2)
		if [ -z "${NFS_SERVER}" ] || [ -z "${NFS_DIR}" ]; then
			printf "NFS Server or NFS Dir not set.\n"
			return 1
		fi
		if ! mount -o ro,rsize=8192,nolock ${NFS_SERVER}:${NFS_DIR} \
			/tmp/nfs-ks ; then
			printf "Failed to do NFS mount in order to get 'Kicstart.cfg'.\n"
			return 1
		fi
		if [ -e "/tmp/nfs-ks/${HOSTNAME}.${DOMAIN}.cfg" ]; then
			cp "/tmp/nfs-ks/${HOSTNAME}.${DOMAIN}.cfg" /tmp/Kickstart.cfg.new
			umount /tmp/nfs-ks
			return 0
		fi
		if [ -e "/tmp/nfs-ks/Kickstart.cfg" ]; then
			cp "/tmp/nfs-ks/Kickstart.cfg" /tmp/Kickstart.cfg.new
			umount /tmp/nfs-ks
			return 0
		fi
		umount /tmp/nfs-ks
		return 1
	elif [ "${GETTYPE}" = 'script' ]; then
		if [ ! -e "${KSSOURCE}" ]; then
			printf "Kickstart source script '%s' doesn't seem to exist.\n" \
				"${KSSOURCE}"
			return 1
		fi
		if ${KSSOURCE} ; then
			return 0
		fi
		return 1
	fi # if [ "${GETTYPE}" ...
	printf "\nMethod '%s' is unsupported to get Kickstart.cfg\n\n" \
		"${GETTYPE}"
	return 1
} # Get_Kickstart
# Desc: try to find root partition and print device name on STDOUT.
# @returns: always 0
Get_Root_Partition() {
	for DEVLINE in $(cat /tmp/Partitions); do
		MOUNTPOINT=$(printf "%s" "${DEVLINE}" | awk -F':' '{ print $3 }')
		if [ "${MOUNTPOINT}" != '/' ]; then
			continue
		fi
		DEVICE=$(printf "%s" "${DEVLINE}" | awk -F':' '{ print $1 }')
		DEVICE=$(Check_Smart_Array "${DEVICE}")
		PARTNUM=$(printf "%s" "${DEVLINE}" | awk -F':' '{ print $2 }')
		ROOTPART="${DEVICE}${PARTNUM}"
	done # for DEVLINE
	printf "%s" "${ROOTPART}"
	return 0
} # Get_Root_Partition
# Desc: retrieve TAG list file and save it as '/tmp/taglist'
# $TAG: string "gettype:source";
# @returns: 0 tag list fetched, 1 error;
Get_Tag_List() {
	TAG=${TAG:-''}
	if [ -z "${TAG}" ]; then
		return 1
	fi # if [ -z "${TAG}" ]
	GETTYPE=$(printf "%s" "${TAG}" | cut -d ':' -f 1)
	TAGSRC=$(printf "%s" "${TAG}" | cut -d ':' -f 2-)
	if [ -z "${TAGSRC}" ]; then
		return 1
	fi # if [ -z "${TAGSRC}" ]
	if [ "${GETTYPE}" = 'http' ] || [ "${GETTYPE}" = 'ftp' ]; then
		if wget "${TAG}" -O /tmp/taglist ; then
			return 0
		fi # if wget
		return 1
	elif [ "${GETTYPE}" = 'nfs' ]; then
		NFS_SERVER=$(printf "%s" "${TAGSRC}" | cut -d ':' -f 1)
		NFS_DIRPART=$(printf "%s" "${TAGSRC}" | cut -d ':' -f 2-)
		NFS_DIR=$(dirname "${NFS_DIRPART}")
		TAGLIST=$(basename "${NFS_DIRPART}")
		if [ -z "${NFS_SERVER}" ] || [ -z "${NFS_DIR}" ] \
			|| [ -z "${TAGLIST}" ]; then
			#
			return 1
		fi # if [ -z ... ]
		if [ ! -d /tmp/nfs-tag ]; then
			mkdir /tmp/nfs-tag
		fi # if [ ! -d /tmp/nfs-tag ]
		if ! mount -o ro,rsize=8192,nolock ${NFS_SERVER}:${NFS_DIR} \
			/tmp/nfs-tag ; then
			#
			return 1
		fi # if ! mount -o ...
		if [ -e "/tmp/nfs-tag/${TAGLIST}" ]; then
			cp "/tmp/nfs-tag/${TAGLIST}" /tmp/taglist
			umount /tmp/nfs-tag
			return 0
		fi # if [ -e "/tmp/nfs-tag/${TAGLIST}" ]
		umount /tmp/nfs-tag
		return 1
	elif [ "${GETTYPE}" = 'file' ]; then
		if [ -e "${TAGSRC}" ]; then
			cp "${TAGSRC}" /tmp/taglist
			return 0
		fi # if [ -e "${TAGSRC}" ]
		return 1
	fi # if [ "${GETTYPE}" ... ]
	return 1
} # Get_Tag_List
# Desc: print contact information
# @returns: always 0;
FireBugInfo() {
	printf "\nHINT: If you think you've found a bug please\n"
	printf "HINT: report it to stybla /at\ turnovfree \dot/ net\n\n"
	return 0
} # FireBugInfo
Extract_Info() {
	ARG=${1:-''}
	if [ -z "${ARG}" ]; then
		return 1
	fi
	#
	COUNTER=1
	CHAR="FOO"
	# Argument value:
	#
	# 2 = Mountpoint list
	# 3 = Filesystem list
	# 4 = sfdisk data
	#
	while [ 0 ]; do
		#get field
		CHAR=$(printf "%s\n" ${PARTITIONS} | cut -d ';' -f "${COUNTER}" | \
			cut -d [ -f "${ARG}" | cut -d ] -f 1)
		if [ "$CHAR" = "" ] ; then
			break
		fi

		case "${ARG}" in
			'3')
				if [ "$CHAR" = "none" ]; then
					CHAR=""
				else
					printf "%s %s\n" ${COUNTER} ${CHAR}
				fi
				;;
			'2')
				if [ "$CHAR" = "empty" ] || [ "$CHAR" = "extended" ]; then
					CHAR=""
				else
					printf "%s %s\n" ${COUNTER} ${CHAR}
				fi
				;;
			'4')
				printf "%s\n" ${CHAR}
		esac
		COUNTER=$(($COUNTER+1))
	done # while [ 0 ]
	return 0
} # Extract_Info
###########
# SCAN-CD #
###########
#
# Scans for an
#
# - IDE
# - SCSI
# - Parallel
# - Old
#
# CD-Rom
#
# [ Code from Slackware standard install ].
#
Scan_CD() {
	printf "\nScanning for CD-Rom/DVD drive ....." 
	sleep 1

	for CDROM in \
		/dev/hdd /dev/hdc /dev/hdb /dev/hda \
		/dev/hde /dev/hdf /dev/hdg /dev/hdh \
		/dev/hdi /dev/hdj /dev/hdk /dev/hdl \
		/dev/hdm /dev/hdn /dev/hdo /dev/hdp \
		/dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3 \
		/dev/pcd0 /dev/pcd1 /dev/pcd2 /dev/pcd3 \
		/dev/sonycd /dev/gscd /dev/optcd /dev/sjcd /dev/mcdx0 /dev/mcdx1 \
		/dev/cdu535 /dev/sbpcd /dev/aztcd /dev/cm205cd /dev/cm206cd \
		/dev/bpcd /dev/mcd \
	; do
		sleep 1
		if /bin/mount -o ro -t iso9660 "${CDROM}" \
			/var/log/mount > /dev/null 2>&1 ; then
		#
			/bin/umount /var/log/mount
			printf " [OK] [CD/DVD is on %s]\n" "${CDROM}"
			sleep 2
			printf "%s\n" "${CDROM}" > /tmp/CDROM
			break
		fi # if /bin/mount ...
	done # for CDROM in

	if [ ! -e /tmp/CDROM ]; then
		printf " [FAILED]\n"
		return 1
	fi
	return 0
} # Scan_CD
# EOF
