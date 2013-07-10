#!/bin/sh
#
# Slack-Kickstart-ng
#
# Origin: 25/05/2006 vonatar(http://www.slack-kickstart.org)
#
# This file contains some common functions.
#
# It is included at top level of each script in /usr/lib/setup
# I hope that with this trick, the scripts are a bit more readable.
#
TMP=${TMP:-"/tmp"}
FH_LOG=${FH_LOG:-"/var/log/kickstart.log"}
ARCH=$(uname -m)
if [ ${ARCH} = 'x86_64' ]; then
	LIBDIRSUFFIX=64
else
	LIBDIRSUFFIX=''
fi

if [ ! -d /var/log/mount ]; then
	mkdir -p /var/log/mount
fi

# Desc: This function is common to all kinds
# of install sources: creates a list
# containing pkg FILENAMES using
# taglist and CHECKSUMS.md5 retrieved
# from pkg repository.
Create_Install_List() {
	local pkg=""
	local directory=""
	local filename=""
	# Checks if /mnt/CHECKSUMS.md5 exists and has a size greater than zero.
	if [ ! -s /mnt/CHECKSUMS.md5 ]; then
		printf "FATAL ERROR downloading CHECKSUMS.md5! - Aborting.\n" |\
			tee -a "${FH_LOG}"
		printf "HINT: Check network configuration.\n" |\
			tee -a "${FH_LOG}"
		exit 1
	fi
	if [ ! -s "${TMP}/taglist" ]; then
		printf "FATAL ERROR: File '%s' doesn't exist or is empty.\n" \
			"${TMP}/taglist" | tee -a "${FH_LOG}" 1>&2
		exit 1
	fi
	# Creates /mnt/PkgList.txt from /mnt/CHECKSUMS.md5
	cat /mnt/CHECKSUMS.md5 | grep -e "./slackware${LIBDIRSUFFIX}/" | \
		grep -E -e "\.t(g|x)z$" | \
		awk -F' ' '{ print $2 }' | \
		awk -F'/' '{ printf "%s/%s\n", $3, $4 }' > /mnt/PkgList.txt
	#
	cat /dev/null > /mnt/usr/Download/install.list
	#
	# Changed on 25/02/2006 to work with Taglist format
	# Taglist is retrieved from Kickstart.cfg grepping '#@' 
	for PACKAGE in $(grep -e "^#@" "${TMP}/taglist" |\
		grep -e 'ADD' | \
		sed -e "s/: ADD//" | sed -e 's/#@//g'); do
		#
		# We need to know package's FILENAME, to retrieve it
		# from repository. It's done grepping package name
		# from filename list.
		#
		pkg=$(printf -- "%s" "${PACKAGE}" |\
			awk -F'/' '{ print $2 }')
		directory=$(printf -- "%s" "${PACKAGE}" |\
			awk -F'/' '{ print $1 }')
		filename=$(cat /mnt/PkgList.txt | \
			grep -E -e "^${directory}/${pkg}-.*\.t(g|x)z$" | \
			head -n 1)

		if [ -z "${filename}" ]; then
			pkg=""
			directory=""
			continue
		fi

		printf -- "%s\n" \
			"${filename}" >> /mnt/usr/Download/install.list

		filename=""
		pkg=""
		directory=""
	done # for PACKAGE
	return 0
} # Create_Install_List
# Desc: mount the nfs share
# $1: eg. nfs:192.168.1.10:/somewhere
NFS_Mount() {
	# Starts rpc portmapper and splits the address.
	/sbin/rpc.portmap >> "${FH_LOG}" 2>&1

	NFS_SERVER=$(printf -- "%s\n" "${1}" | awk -F':' '{ print $2 }')
	NFS_DIR=$(printf -- "%s\n" "${1}" | awk -F':' '{ print $3 }')
	# Mounts NFS PKG Repository
	if ! mount -o ro,rsize=8192,nolock ${NFS_SERVER}:${NFS_DIR} \
		/var/log/mount >> "${FH_LOG}" 2>&1 ; then
		#
		printf "[FAILED]\n" | tee -a "${FH_LOG}"
		printf "\nFATAL ERROR mounting '%s:%s' - Aborting.\n" \
			"${NFS_SERVER}" "${NFS_DIR}" | \
			tee -a "${FH_LOG}"
		printf "HINT: Check network/nfs configuration.\n" |\
			tee -a "${FH_LOG}"
		printf "HINT: Check if your NFS server is alive!\n\n" |\
			tee -a "${FH_LOG}"
		exit 1
	fi
	return 0
} # NFS_Mount
# Desc: download and install packages from an http/ftp repository
HTTP_FTP_Install() {
	# Downloads pkg list from chosen mirror
	printf "\n[ Using: %s ]\n" "${PACKAGE_SERVER}" | \
		tee -a "${FH_LOG}"
	printf "Downloading packages list ..." | tee -a "${FH_LOG}"
	
	wget "${PACKAGE_SERVER}/CHECKSUMS.md5" \
		-O /mnt/CHECKSUMS.md5 2>> "${FH_LOG}"

	if [ $? != 0 ]; then
		printf "[FAILED]\n" | tee -a "${FH_LOG}"
		printf "\nFATAL ERROR downloading PKG list - Aborting.\n" |\
			tee -a "${FH_LOG}"
		printf "HINT: Check network configuration.\n\n" |\
			tee -a "${FH_LOG}"
		exit 1
	fi
	printf "[OK]\n" | tee -a "${FH_LOG}"
	# Converts tagfile to pkg filenames.
	Create_Install_List
	# Here we need to link /var/log/mount to /mnt/usr/Download/slackware
	ln -s /mnt/usr/Download/slackware /var/log/mount/
	cd /var/log/mount/slackware
	# Downloads and installs packages.
	if [ ! -e /mnt/usr/Download/install.list ] \
		|| [ ! -s /mnt/usr/Download/install.list ]; then
		printf "\nFATAL ERROR - Aborting\n" | tee -a "${FH_LOG}"
		printf "File '%s' doesn't exist or has zero length.\n" \
			'/mnt/usr/Download/install.list' | tee -a "${FH_LOG}"
		printf "HINT: Kickstart.cfg has no taglist.\n" |\
			tee -a "${FH_LOG}"
		FireBugInfo
		exit 1
	fi
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		# Creates diskset directory, downloads package and installs it.
		DISKSET=$(printf -- "%s\n" ${PACKAGE} | \
			awk -F'/' '{ print $1 }')
		if [ ! -d $DISKSET ]; then
			mkdir "/var/log/mount/slackware/${DISKSET}"
		fi
		cd "/var/log/mount/slackware/${DISKSET}"

		printf "Downloading package -- '%s'" "${PACKAGE}" |\
			tee -a "${FH_LOG}"
		if wget "${PACKAGE_SERVER}/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
			2>> "${FH_LOG}" ; then
			printf "...[OK]\n" | tee -a "${FH_LOG}"
		else
			printf "...[FAILED]\n" | tee -a "${FH_LOG}"
			continue
		fi
	
		if [ ! -e "/var/log/mount/slackware/${PACKAGE}" ]; then
			printf "Package '%s' doesn't exist? ...[FAILED]\n" \
				"/var/log/mount/slackware/${PACKAGE}" |\
				tee -a "${FH_LOG}"
			continue
		fi

		if [ -d "/var/log/mount/slackware/${PACKAGE}" ]; then
			# this is a serie and we are going to skip it silently
			continue
		fi
		#	installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}" | tee -a "${FH_LOG}"
		if /usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware/${PACKAGE}" \
			>> "${TMP}/installpkg" 2>&1 ; then
			printf "...[OK]\n" | tee -a "${FH_LOG}"
		else
			printf "...[FAILED]\n" | tee -a "${FH_LOG}"
		fi
		rm "/var/log/mount/slackware/${PACKAGE}"
		cd ..
	done # for PACKAGE
	return 0
} # HTTP_FTP_Install
# Desc: Install packages from NFS server/CD-ROM
NFS_CD_Install() {
	# Converts tagfile to pkg filenames.
	cp /var/log/mount/CHECKSUMS.md5 /mnt
	#
	Create_Install_List
	#
	if [ ! -e /mnt/usr/Download/install.list ] \
		|| [ ! -s /mnt/usr/Download/install.list ]; then
		printf "\nFATAL ERROR - Aborting\n" | tee -a "${FH_LOG}"
		printf "File '%s' doesn't exist or has zero length.\n" \
			'/mnt/usr/Download/install.list' | \
			tee -a "${FH_LOG}"
		printf "HINT: Kickstart.cfg has no taglist.\n" |\
			tee -a "${FH_LOG}"
		FireBugInfo
		exit 1
	fi
	# Installs packages on destination dirs.
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		# Installs package from NFS repository
		if [ ! -e "/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" ]; then
			printf "Package '%s' doesn't exist? ...[FAILED]\n" \
				"${PACKAGE}" | tee -a "${FH_LOG}"
			continue
		fi

		if [ -d "/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" ]; then
			# this is a serie and we are going to skip it silently
			continue
		fi
		# installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}" | tee -a "${FH_LOG}"
		if /usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
				>> "${TMP}/installpkg" 2>&1; then
			printf "...[OK]\n" | tee -a "${FH_LOG}"
		else
			printf "...[FAILED]\n" | tee -a "${FH_LOG}"
		fi
	done # for PACKAGE
	# umounts NFS PKG Repository
	umount -f /var/log/mount
	return 0
} # NFS_CD_Install

# EOF
