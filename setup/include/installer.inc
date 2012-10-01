# /usr/lib/setup/include/installer.inc
#
# Slack-Kickstart 10.2
#
# Last revision: 25/05/2006 vonatar
#
# This file contains some common functions.
#
# It is included at top level of each script in /usr/lib/setup
# I hope that with this trick, the scripts are a bit more readable.
#

REDIR=/dev/tty4
ARCH=$(uname -m)
if [ ${ARCH} = 'x86_64' ]; then
	LIBDIRSUFFIX=64
else
	LIBDIRSUFFIX=''
fi

if [ ! -d /var/log/mount ]; then
	mkdir -p /var/log/mount
fi

#######################
# Create install list #
#######################
#
# This function is common to all kinds
# of install sources: creates a list
# containing pkg FILENAMES using
# taglist and CHECKSUMS.md5 retrieved
# from pkg repository.
#
Create_Install_List() {
	# Checks if /mnt/CHECKSUMS.md5 exists and has a size greater than zero.
	if [ ! -s /mnt/CHECKSUMS.md5 ]; then
		printf "FATAL ERROR downloading CHECKSUMS.md5! - Aborting.\n"
		printf "HINT: Check network configuration.\n"
		exit 1
	fi
	if [ ! -s /tmp/taglist ]; then
		printf "FATAL ERROR: File '/tmp/taglist' doesn't exist or is empty.\n"
		exit 1
	fi
	# Creates /mnt/PkgList.txt from /mnt/CHECKSUMS.md5
	cat /mnt/CHECKSUMS.md5 | grep -e "./slackware${LIBDIRSUFFIX}/" | \
		grep -E -e "\.t(g|x)z$" | \
		cut -d " " -f 3 | cut -d "/" -f 4 > /mnt/PkgList.txt
	#
	cat /dev/null > /mnt/usr/Download/install.list
	#
	# Changed on 25/02/2006 to work with Taglist format
	# Taglist is retrieved from Kickstart.cfg grepping '#@' 
	for PACKAGE in $(cat /tmp/taglist | grep -e "^#@" | grep -e 'ADD' | \
		sed -e "s/: ADD//" | sed -e 's/#@//g'); do
		#
		# We need to know package's FILENAME, to retrieve it
		# from repository. It's done grepping package name
		# from filename list.
		#
		PKG=$(printf "%s\n" ${PACKAGE} | cut -d "/" -f 2)
		DIRECTORY=$(printf "%s\n" ${PACKAGE} | cut -d "/" -f 1)
		FILENAME=$(cat /mnt/PkgList.txt | grep -E -e "^${PKG}-.*\.t(g|x)z$" | \
			head -n 1)

		if [ -z "${FILENAME}" ]; then
			continue
		fi

		printf -- "%s/%s\n" "${DIRECTORY}" \
			"${FILENAME}" >> /mnt/usr/Download/install.list
	done # for PACKAGE
	return 0
} # Create_Install_List
#############
# NFS Mount #
#############
#
# This function mount the nfs share $1
# $1 is something like:
#
# nfs:192.168.1.10:/somewhere
#
NFS_Mount() {
	# Starts rpc portmapper and splits the address.
	/sbin/rpc.portmap > $REDIR 2>&1

	NFS_SERVER=$(printf "%s\n" ${1} | cut -d ":" -f 2)
	NFS_DIR=$(printf "%s\n" ${1} | cut -d ":" -f 3)
	# Mounts NFS PKG Repository
	if ! mount -o ro,rsize=8192,nolock ${NFS_SERVER}:${NFS_DIR} \
		/var/log/mount > $REDIR 2>&1 ; then
		#
		echo "[FAILED]"
		printf "\nFATAL ERROR mounting '$NFS_SERVER:$NFS_DIR' - Aborting.\n"
		printf "HINT: Check network/nfs configuration.\n"
		printf "HINT: Check if your NFS server is alive!\n\n"
		exit 1
	fi
	return 0
} # NFS_Mount
####################
# HTTP/FTP Install #
####################
#
# This function downloads and installs
# packages from an http/ftp repository
#
HTTP_FTP_Install() {
	# Downloads pkg list from chosen mirror
	printf "\n[ Using: %s ]\n" ${PACKAGE_SERVER}
	printf "Downloading packages list ..... "
	
	wget "${PACKAGE_SERVER}/CHECKSUMS.md5" -O /mnt/CHECKSUMS.md5 2> ${REDIR} 

	if [ $? != 0 ]; then
		printf "[FAILED]\n"
		printf "\nFATAL ERROR downloading PKG list - Aborting.\n"
		printf "HINT: Check network configuration.\n\n"
		exit 1
	else
		echo "[OK]"
	fi
	# Converts tagfile to pkg filenames.
	Create_Install_List
	# Here we need to link /var/log/mount to /mnt/usr/Download/slackware
	ln -s /mnt/usr/Download/slackware /var/log/mount/
	cd /var/log/mount/slackware
	# Downloads and installs packages.
	if [ ! -e /mnt/usr/Download/install.list ] \
		|| [ ! -s /mnt/usr/Download/install.list ]; then
		printf "\nFATAL ERROR - Aborting\n"
		printf "File '%s' doesn't exist or has zero length.\n" \
			'/mnt/usr/Download/install.list'
		printf "HINT: Kickstart.cfg has no taglist.\n"
		FireBugInfo
		exit 1
	fi
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		# Creates diskset directory, downloads package and installs it.
		DISKSET=$(printf "%s\n" ${PACKAGE} | cut -d "/" -f 1)
		if [ ! -d $DISKSET ]; then
			mkdir "/var/log/mount/slackware/${DISKSET}"
		fi
		cd "/var/log/mount/slackware/${DISKSET}"

		printf "Downloading package -- '%s'" "${PACKAGE}"
		if wget "${PACKAGE_SERVER}/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
			2> ${REDIR} ; then
			echo "...[OK]"
		else
			echo "...[FAILED]"
			continue
		fi
	
		if [ ! -e "/var/log/mount/slackware/${PACKAGE}" ]; then
			echo "Package doesn't exist??? FAILED!!!"
			continue
		fi

		if [ -d "/var/log/mount/slackware/${PACKAGE}" ]; then
			# this is a serie and we are going to skip it silently
			continue
		fi
		#	installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}"
		if /usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware/${PACKAGE}" >>/tmp/installpkg ; then
			echo "...[OK]"
		else
			echo "...[FAILED]"
		fi
		rm "/var/log/mount/slackware/${PACKAGE}"
		cd ..
	done # for PACKAGE
	return 0
} # HTTP_FTP_Install
##################
# NFS/CD Install #
##################
#
# This function installs packages
# from NFS server or CD-Rom.
#
NFS_CD_Install() {
	# Converts tagfile to pkg filenames.
	cp /var/log/mount/CHECKSUMS.md5 /mnt
	#
	Create_Install_List
	#
	if [ ! -e /mnt/usr/Download/install.list ] \
		|| [ ! -s /mnt/usr/Download/install.list ]; then
		printf "\nFATAL ERROR - Aborting\n"
		printf "File '%s' doesn't exist or has zero length.\n" \
			'/mnt/usr/Download/install.list'
		printf "HINT: Kickstart.cfg has no taglist.\n"
		FireBugInfo
		exit 1
	fi
	# Installs packages on destination dirs.
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		# Installs package from NFS repository
		if [ ! -e "/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" ]; then
			printf "Package '%s' doesn't exist? FAILED!!!\n" ${PACKAGE}
			continue
		fi

		if [ -d "/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" ]; then
			# this is a serie and we are going to skip it silently
			continue
		fi
		# installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}"
		if /usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
      >>/tmp/installpkg; then
			echo "...[OK]"
		else
			echo "...[FAILED]"
		fi
	done # for PACKAGE
	# umounts NFS PKG Repository
	umount -f /var/log/mount
	return 0
} # NFS_CD_Install
