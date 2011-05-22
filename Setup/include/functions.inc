# /usr/lib/setup/includes/functions.inc
#
# Slack-Kickstart 10.2
#
# Last revision: 05/08/2006 vonatar
#
# This file contains some common functions
# and variable definitions.
#
# It is included at top level of each script in /usr/lib/setup
# I hope that with this trick, the scripts are a bit more readable.
#

#################################
# Set internal Field Separator	#
#################################

IFS='
'
#########################
# Redirect info to tty4 #
#########################

REDIR=/dev/tty4

#########################
# Info from config file	#
#########################

. /etc/Kickstart.cfg

DEVICE=$(echo "${DISK}" | cut -d '[' -f 2 | cut -d ']' -f 1)
BOOTDEV="${DEVICE}"
PARTITIONS=$(echo "${DISK}" | cut -d '=' -f 2 | sed -e 's/,0,/,,/g')
PKG_SRC=$(echo "${PACKAGE_SERVER}" | cut -d ":" -f 1)
KERN=$(basename "${KERNEL}")

#----------------------------- FUNCTIONS ------------------------------------------#
FireBugInfo() {
	echo
	echo "HINT: If you think you've found a bug please"
	echo "HINT: report it to bugs@slack-kickstart.org "
	echo
	return 0
} # FireBugInfo
# MARK
Extract_Info() {
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
 		CHAR=$(echo "${PARTITIONS}" | cut -d ';' -f "${COUNTER}" | \
			cut -d [ -f	"${1}" | cut -d ] -f 1)
		if [ "$CHAR" = "" ] ; then
			break
		fi

		case "${1}" in
			'3')
				if [ "$CHAR" = "none" ]; then
					CHAR=""
				else
					echo "${COUNTER} ${CHAR}"
				fi
        ;;
			'2')
				if [ "$CHAR" = "empty" ] || [ "$CHAR" = "extended" ]; then
					CHAR=""
				else
					echo "${COUNTER} ${CHAR}"
				fi
				;;
			'4')
				echo "${CHAR}"
		esac
		COUNTER=$(($COUNTER+1))
	done
	return 0
} # Extract_Info

#################
# Creates fstab #
#################
Create_Fstab() {
	rm -f  /tmp/fstab
	for ROW in $(cat /tmp/MountpointsList | grep -v -e 'none'); do
		ROWNO=$(echo "${ROW}" | awk '{ print $1 }')
		FSYS=$(grep -e "^${ROWNO}" /tmp/FilesystemsList | grep -v -e 'none' | \
			awk '{ print $2 }')
		if [ -z "${FSYS}" ]; then
			continue
		fi
		MOUNTPOINT=$(echo "${ROW}" | cut -d " " -f 2)
		case "${MOUNTPOINT}" in
		'/')
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "${DEVICE}${ROWNO}" \
				"${MOUNTPOINT}" "${FSYS}"  "defaults" "1" "1" >> /tmp/fstab
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
	done

	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "/dev/fd0" "/mnt/floppy" \
		"auto" "noauto,owner" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "/dev/cdrom" "/mnt/cdrom" \
		"iso9660" "noauto,owner,ro" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "devpts" "/dev/pts" "devpts" \
		"gid=5,mode=620" "0" "0" >> /tmp/fstab
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "proc" "/proc" "proc" "defaults" \
		"0" "0" >> /tmp/fstab
	return 0
}

#####################
# Check Smart Array #
#####################
Check_Smart_Array(){
#
# If we're using Smart Array 2, we
# need to put a 'p' before partition
# number.
#
	if [ $DEVICE = "/dev/ida/c0d0" ];then
		DEVICE="/dev/ida/c0d0p"
	fi
#
# If we're using Smart Array 5 we
# need to put a 'p' before partition
# number.
#
	if [ $DEVICE = "/dev/cciss/c0d0" ];then
		DEVICE="/dev/cciss/c0d0p"
	fi
#
# If we're using Promise FastTrack 2TX we
# need to put a 'p' before partition
# number.
#
	if [ $DEVICE = "/dev/ataraid/d0" ];then
		DEVICE="/dev/ataraid/d0p"
	fi
##################
# Root partition #
##################
	MOUNTSPARSED=$(cat /tmp/MountpointsList | grep -e "/$"| cut -d " " -f 1)
	ROOTPART="${DEVICE}${MOUNTSPARSED}"
	return 0
}
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
	echo
	printf "Scanning for CD-Rom/DVD drive ....." 
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
		/bin/mount -o ro -t iso9660 "${CDROM}" /var/log/mount > /dev/null 2>&1
		if [ $? = 0 ]; then
			/bin/umount /var/log/mount
			echo " [OK] [CD/DVD is on ${CDROM}]"
			sleep 2
			echo "${CDROM}" > /tmp/CDROM
			break
		fi
	done

	if [ ! -e /tmp/CDROM ]; then
		echo " [FAILED]"
		return 1
	fi
	return 0
} # Scan_CD

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
#
# Check if we have a CD-Rom device.
#
	if [ ! -s /tmp/CDROM ]; then
		echo " [FAILED]"
		echo
		echo "FATAL ERROR: Cannot find a CD-Rom device - Aborting"
		echo "HINT: Does this kernel support you CD-Rom device ?"
		echo
		exit 1
	fi

	CDROM=$(cat /tmp/CDROM)
	#
	# Mounts cdrom
	#
	/bin/mount -o ro -t iso9660 "${CDROM}" /var/log/mount > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo " [FAILED]"
		echo
		echo "FATAL ERROR: Cannot find media on ${CDROM}  - Aborting"
		echo "HINT: Check media on ${CDROM}"
		echo
		FireBugInfo
		exit 1
	fi
#
# Check CHECKSUMS.md5 if we are testing PACKAGE_SERVER 
#
	if [ ! -s "/var/log/mount/${1}" ]; then
		echo " [FAILED]"
		echo
		echo "FATAL ERROR: Cannot find ${1} on ${CDROM}  - Aborting"
		echo "HINT: Check configuration on /etc/Kickstart.cfg"
		echo
		FireBugInfo
 		exit 1
	fi
	echo " [OK]"
	umount  /var/log/mount
	return 0
} # Check_CD

