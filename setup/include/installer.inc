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
#
# Checks if /mnt/CHECKSUMS.md5 exists
# and has a size greater than zero.
#
	if [ ! -s /mnt/CHECKSUMS.md5 ]; then
		echo "FATAL ERROR downloading PKG list! - Aborting."
		echo "HINT: Check network configuration."
		exit 1
	fi
#
# Creates /mnt/PkgList.txt from /mnt/CHECKSUMS.md5
#
	cat /mnt/CHECKSUMS.md5 | grep -e "./slackware${LIBDIRSUFFIX}/" | \
		grep -E -e "\.t(g|x)z$" | \
		cut -d " " -f 3 | cut -d "/" -f 4 > /mnt/PkgList.txt

#
# Changed on 25/02/2006 to work with Taglist format
# Taglist is retrieved from Kickstart.cfg grepping '#@' 
#
	for PACKAGE in $(cat /etc/Kickstart.cfg | grep -e "^#@" | grep -e 'ADD' | \
		sed -e "s/: ADD//" | sed -e 's/#@//g'); do
		#
		# We need to know package's FILENAME, to retrieve it
		# from repository. It's done grepping package name
		# from filename list.
		#
		PKG=$(echo "${PACKAGE}" | cut -d "/" -f 2)
		DIRECTORY=$(echo "${PACKAGE}" | cut -d "/" -f 1)
		FILENAME=$(cat /mnt/PkgList.txt | grep -e "^${PKG}-[[:digit:]]")
		echo "${DIRECTORY}/${FILENAME}" >> /mnt/usr/Download/install.list
	done
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
	#
	# Starts rpc portmapper
	# and splits the address.
	#
	/sbin/rpc.portmap > $REDIR 2>&1

	NFS_SERVER=$(echo "${1}" | cut -d ":" -f 2)
	NFS_DIR=$(echo "${1}" | cut -d ":" -f 3)
	#
	# Mounts NFS PKG Repository
	#
	mount -o ro,rsize=8192,nolock ${NFS_SERVER}:${NFS_DIR} /var/log/mount \
		> $REDIR 2>&1

	if [ $? != 0 ];then
		echo "[FAILED]"
		echo 
		echo "FATAL ERROR mounting '$NFS_SERVER:$NFS_DIR' - Aborting."
		echo "HINT: Check network/nfs configuration."
		echo "HINT: Check if your NFS server is alive!"
		echo
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
	#
	# Downloads pkg list
	# from choosen mirror
	#
	echo
	echo "[ Using: ${PACKAGE_SERVER} ]"
	printf "Downloading packages list ..... "
	
	wget "${PACKAGE_SERVER}/CHECKSUMS.md5" -O /mnt/CHECKSUMS.md5 2> ${REDIR} 

	if [ $? != 0 ]; then
		echo "[FAILED]"
		echo
		echo "FATAL ERROR downloading PKG list - Aborting."
		echo "HINT: Check network configuration."
		echo
		exit 1
	else
		echo "[OK]"
	fi
	#
	# Converts tagfile to pkg filenames.
	#
	Create_Install_List
	#
	# Here we need to link /var/log/mount to
	# /mnt/usr/Download/slackware
	#
	ln -s /mnt/usr/Download/slackware /var/log/mount/
	cd /var/log/mount/slackware
	#
	# Downloads and installs packages.
	#
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		#
		# Creates diskset directory, downloads package
		# and installs it.
		#
		DISKSET=$(echo "${PACKAGE}" | cut -d "/" -f 1)
		if [ ! -d $DISKSET ]; then
			mkdir "/var/log/mount/slackware/${DISKSET}"
		fi
		cd "/var/log/mount/slackware/${DISKSET}"

		#		dialog --title "Downloading package" --infobox "Downloading: \n\
		#${PACKAGE_SERVER}/slackware${LIBDIRSUFFIX}/${PACKAGE} \n\
		#\n\
		#" 10 60
		printf "Downloading package -- '%s'" "${PACKAGE}"
		if $(wget "${PACKAGE_SERVER}/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
			2> ${REDIR}) ; then
			echo "...[OK]"
		else
			echo "...[FAILED]"
			continue
		fi
	
		#		if [ $? != 0 ];then
			#			dialog --title "Downloading package" --infobox \
			#				"Error Downloading: \n\ ${PACKAGE_SERVER}/slackware${LIBDIRSUFFIX}/${PACKAGE} \n\
			#Skipping package!\n\
			#\n\
			#" 10 60
			#			continue
			#		fi
		
		if [ ! -e "/var/log/mount/slackware/${PACKAGE}" ]; then
			echo "Package doesn't exist??? FAILED!!!"
			continue
		fi

		#		installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}"
		if $(/usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware/${PACKAGE}" >>/tmp/installpkg) ; then
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
	#
	# Converts tagfile to pkg filenames.
	#
	cp /var/log/mount/CHECKSUMS.md5 /mnt

	Create_Install_List
	#
	# Installs packages on
	# destination  dirs.
	#
	for PACKAGE in $(cat /mnt/usr/Download/install.list); do
		#
		# Installs package from NFS repository
		#
		#		installpkg -infobox -root /mnt "/var/log/mount/slackware/${PACKAGE}"
		printf "Installing -- '%s'" "${PACKAGE}"
		if $(/usr/lib/setup/installpkg --root /mnt \
			"/var/log/mount/slackware${LIBDIRSUFFIX}/${PACKAGE}" \
      >>/tmp/installpkg); then
			echo "...[OK]"
		else
			echo "...[FAILED]"
		fi
	done
	#
	# umounts NFS PKG Repository
	#
	umount -f /var/log/mount
	return 0
} # NFS_CD_Install
