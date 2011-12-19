#!/bin/bash
# Desc: create template kickstart image for Slack-Kickstart
# Copyright (C) 2011 Zdenek Styblik
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
# Missing features/TODO:
# * more than one HDD -> pkgs for mdadm, LVM ?
# * slackpkg
set -e
set -u

BUSYBOXVER=${BUSYBOXVER:-'1.18.4'}
DROPBEARVER=${DROPBEARVER:-''}
LIBDIRSUFFIX=${LIBDIRSUFFIX:-''}
IMAGEFSDIR=${IMAGEFSDIR:-'./imagefs'}
INITRDMOUNT=${INITRDMOUNT:-'/mnt/initrd'}
SLACKCDPATH=${SLACKCDPATH:-'/mnt/cdrom/'}
TMPDIR=${TMPDIR:-'/tmp'}

# Ramdisk Constants
RDSIZE=${RDSIZE:-65536}
BLKSIZE=1024

SCRIPTNAME=$(basename "${0}")
PREFIX="$(dirname "${SCRIPTNAME}")"

rm -f "${TMPDIR}/${SCRIPTNAME}.stderr.log"
touch "${TMPDIR}/${SCRIPTNAME}.stderr.log"
exec 2>"${TMPDIR}/${SCRIPTNAME}.stderr.log"

# DESC: removes /usr/man, /usr/doc and /usr/share
clean_usr()
{
	rm -rf "${INITRDMOUNT}/usr/doc"
	rm -rf "${INITRDMOUNT}/usr/info"
	rm -rf "${INITRDMOUNT}/usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf "${INITRDMOUNT}/usr/man"
	rm -rf "${INITRDMOUNT}/usr/share"
	return 0
} # clean_usr
# DESC: automagic lib dependency
# Note: this is not ultimate solution and apps with dl_open are going to 
# slip through. It's the same kind of 'idiocy' swaret is using.
getlibs()
{
	BINARY=${1:-''}
	if [ -z "${BINARY}" ]; then
		echo "[FAIL] getlibs ~ parameter unset"
		return 1
	fi
	if [ ! -e "${BINARY}" ]; then
		echo "[FAIL] getlibs ~ binary '${BINARY}' doesn't exist."
		return 1
	fi
	for LIBLINE in $(ldd "${BINARY}" | tr ' ' '#'); do
		printf "%s\n" ${LIBLINE} | grep -q -e 'linux-vdso' && continue;
		printf "%s\n" ${LIBLINE} | grep -q -e 'linux-gate' && continue;
		if printf "${LIBLINE}" | awk -F'#' '{ print $1 }' | grep -q -e '^/' ; then
			LIBTOCOPY=$(printf "%s\n" ${LIBLINE} | awk -F'#' '{ print $1 }');
			LIBDIR=$(dirname "${LIBTOCOPY}")
			if [ -z "${LIBTOCOPY}" ]; then
				echo "[FAIL] failed to automagically copy lib dep for '${BINARY}'"
				continue
			fi
			if [ -e "${INITRDMOUNT}/${LIBTOCOPY}" ]; then
				continue
			fi
			if [ ! -d "${INITRDMOUNT}/${LIBDIR}" ]; then
				mkdir -p "${INITRDMOUNT}/${LIBDIR}"
			fi
			if file "${LIBTOCOPY}" | grep -q -e 'symbolic link' ; then
				LIBREAL=$(file "${LIBTOCOPY}" | cut -d '`' -f 2 | tr -d "'")
				cp -apr "${LIBDIR}/${LIBREAL}" "${INITRDMOUNT}/${LIBDIR}"
				pushd "${INITRDMOUNT}/${LIBDIR}"
				LIBLINK=$(basename "${LIBTOCOPY}")
				ln -s "${LIBREAL}" "${LIBLINK}" || exit
				popd
			else
				cp -apr "${LIBTOCOPY}" "${INITRDMOUNT}/${LIBDIR}"
			fi
			continue
		fi
		if printf "${LIBLINE}" | grep -q -e '=>' ; then
			LIBPOINTER=$(printf "%s\n" ${LIBLINE} | awk -F'#' '{ print $3 }')
			LIBREAL=$(file "${LIBPOINTER}" | cut -d '`' -f 2 | tr -d "'")
			LIBDIR=$(dirname "${LIBPOINTER}")
			LIBLINK=$(printf "%s\n" ${LIBLINE} | awk -F'#' '{ print $1 }')
			if [ -z "${LIBREAL}" -o -z "${LIBLINK}" ]; then
				echo "[FAIL] failed to to automagically copy lib dep for '${BINARY}'"
				continue
			fi
			if [ ! -d "${INITRDMOUNT}/${LIBDIR}" ]; then
				mkdir -p "${INITRDMOUNT}/${LIBDIR}"
			fi
			cp -apr "${LIBDIR}/${LIBREAL}" "${INITRDMOUNT}/${LIBDIR}";
			LIBREALNAME=$(basename "${LIBREAL}");
			pushd "${INITRDMOUNT}/${LIBDIR}";
			if [ ! -e "${LIBLINK}" ]; then
				ln -s "${LIBREALNAME}" "${LIBLINK}" || exit;
			fi
			popd
			continue
		fi
	done
	return 0
} # getlibs
# DESC: automagically searches for PKG by needle in CHECKSUMS.md5 
# and returns PKG path and name in case PKG was found.
parse_package()
{
	PKGNEEDLE=${1:-''}
	if [ -z "${PKGNEEDLE}" ]; then
		return 1
	fi
	if [ ! -e "${SLACKCDPATH}/CHECKSUMS.md5" ]; then
#		echo "File '${SLACKCDPATH}/CHECKSUMS.md5' doesn't seem to exist."
		echo ""
		return 1
	fi
	PKGFOUND=$(grep -e "${PKGNEEDLE}"  "${SLACKCDPATH}/CHECKSUMS.md5" | \
		grep -e "./slackware${LIBDIRSUFFIX}" | grep -E -e '.t?z$' | \
		awk '{ print $2 }')
	if [ -z "${PKGFOUND}" ]; then
#		echo "No PKG found for needle '${PKGNEEDLE}'."
		echo ""
		return 1
	fi
	printf "%s/%s\n" ${SLACKCDPATH} ${PKGFOUND}
	return 0
} # parse_package
# DESC: show help text
show_help() 
{
	echo "Usage: ${0} <CFG> <KERNEL_PKG|BZIMG>"
	echo "Help haven't been written yet."
	return 0
} # show_help

### MAIN ###
CWD=${PWD}
KSCONFIG=${1:-''}
if [ -z "${KSCONFIG}" ]; then
	show_help
	exit 1
fi

if [ ! -e "${KSCONFIG}" ]; then
	echo "File '${KSCONFIG}' doesn't seem to exist or not readable." 1>&2
	exit 1
fi
. "${KSCONFIG}"
TIMEZONE=${TIMEZONE:-'Universal'}
PASSWDENC=$(openssl passwd -1 "${PASSWD}")

BZIMG=${2:-''}
if [ -z "${BZIMG}" ]; then
	show_help
	exit 1
fi

if [ ! -e "${BZIMG}" ]; then
	echo "File '${BZIMG}' doesn't seem to exist or not readable." 1>&2
	exit 1
fi
# If $DROPBEARVER is not set, try figure out the latest from the Web
if [ -z "${DROPBEARVER}" ]; then
	DROPBEARVER=$(wget http://matt.ucc.asn.au/dropbear/ -O - 2>/dev/null | \
	awk -F'>' '{ \
	if ($0 !~ /dropbear-.*\.tar\.bz2/) { next } \
	ibegin = index($0, "href=\"dropbear-"); \
	part = substr($0, ibegin+6); \
	iend = index(part, ".tar.bz2"); \
	if (ibegin == 0 || iend == 0) { next } \
	part = substr(part, 0, iend-1); \
	print part; \
}')
	if [ -z "${DROPBEARVER}" ]; then
		printf "Unable to determine Dropbear version." 1>&2
		exit 1
	fi # if [ -z "${DROPBEARVER}" ]
fi # if [ -z "${DROPBEARVER}" ]
if [ ! -e "${TMPDIR}/${DROPBEARVER}.tar.bz2" ]; then
	wget "http://matt.ucc.asn.au/dropbear/${DROPBEARVER}.tar.bz2" \
		-O "${TMPDIR}/${DROPBEARVER}.tar.bz2"
fi # if [ ! -e "${TMPDIR}/${DROPBEARVER}.tar.bz2" ]

# Housekeeping...
if mount | grep -q -e "${INITRDMOUNT}" ; then
	echo "Initrd dir '${INITRDMOUNT}' already mounted." 1>&2
	exit 1
fi

CWD=$(pwd)
if [ ! -d "${IMAGEFSDIR}" ]; then
	if [ ! -d "../${IMAGEFSDIR}" ]; then
		echo "I couldn't locate './imagefs' neither '../imagefs' dir" 1>&2
		exit 1
	else
		IMAGEFSDIR="../${IMAGEFSDIR}"
	fi
fi

if [ -d "${SLACKCDPATH}/slackware" ]; then
	LIBDIRSUFFIX=""
elif [ -d "${SLACKCDPATH}/slackware64" ]; then
	LIBDIRSUFFIX=64
else
	echo "No '${SLACKCDPATH}/slackware' nor '${SLACKCDPATH}/slackware64' found." \
		1>&2
	exit 1
fi
# Note: hope the following is sufficient for 98% of cases.
BZIMGTYPE=$(file "${BZIMG}")
KERNELVER=""
if printf "%s" "${BZIMGTYPE}" | grep -q -e 'XZ' -e 'gzip' ; then
	rm -rf "${TMPDIR}/slack-kernel"
	mkdir "${TMPDIR}/slack-kernel"
	BZIMGPATH=$(pwd "${BZIMG}")
	BZIMGPATH="${BZIMGPATH}/${BZIMG}"
	pushd "${TMPDIR}/slack-kernel"
	explodepkg "${BZIMGPATH}"
	KERNELVER=$(find ./ -name vmlinuz* | xargs strings | \
		grep -E -e '^(2|3)\.[0-9]+(\.[0-9]+(\.[0-9]+))' | awk '{ print $1 }')
	popd
elif printf "%s" "${BZIMGTYPE}" | grep -q -e 'Linux kernel' ; then
	KERNELVER=$(strings "${BZIMG}" | \
		grep -E -e '^(2|3)\.[0-9]+(\.[0-9]+(\.[0-9]+))' | awk '{ print $1 }')
else
	printf "bzImage '%s' has invalid/unsupported format.\n" "${BZIMG}" 1>&2
	exit 1
fi
if [ -z "${KERNELVER}" ]; then
	printf "Failed to determine kernel version.\n" 1>&2
	exit 1
fi

rm -f "${TMPDIR}/ramdisk.img"
rm -f "${TMPDIR}/ramdisk.img.gz"

# Create an empty ramdisk image
dd if=/dev/zero of="${TMPDIR}/ramdisk.img" bs=${BLKSIZE} count=${RDSIZE}

# Make it an ext2 mountable file system
mke2fs -F -m 0 -b ${BLKSIZE} "${TMPDIR}/ramdisk.img" ${RDSIZE}

# Mount it so that we can populate
mount "${TMPDIR}/ramdisk.img" "${INITRDMOUNT}" -t ext2 -o loop

# Populate the filesystem (subdirectories)
mkdir "${INITRDMOUNT}/bin"
mkdir "${INITRDMOUNT}/sys"
mkdir "${INITRDMOUNT}/dev"
mkdir "${INITRDMOUNT}/proc"
mkdir "${INITRDMOUNT}/etc"
mkdir "${INITRDMOUNT}/etc/rc.d"
mkdir "${INITRDMOUNT}/etc/modprobe.d"
touch "${INITRDMOUNT}/etc/modprobe.conf"
mkdir "${INITRDMOUNT}/lib"
if [ ! -z "${LIBDIRSUFFIX}" ] && [ ${LIBDIRSUFFIX} -eq 64 ]; then
	mkdir "${INITRDMOUNT}/lib${LIBDIRSUFFIX}"
fi
mkdir "${INITRDMOUNT}/mnt"
mkdir "${INITRDMOUNT}/root"
mkdir "${INITRDMOUNT}/tmp"
mkdir "${INITRDMOUNT}/var"
mkdir "${INITRDMOUNT}/var/log"
mkdir "${INITRDMOUNT}/var/run"
mkdir "${INITRDMOUNT}/var/tmp"
mkdir "${INITRDMOUNT}/var/log/mount"

#### BUSYBOX
# Grab busybox and create the symbolic links
pushd "${INITRDMOUNT}"
cp "${TMPDIR}/busybox-${BUSYBOXVER}/busybox" ./bin/
getlibs bin/busybox
for CMD in $(./bin/busybox --list-ful); do
	CMDDIR=$(dirname "${CMD}")
	if [ ! -d "${CMDDIR}" ]; then
		if ! mkdir -p "./${CMDDIR}" ; then
			printf "Unable to create dir '%s'\n" "${CMDDIR}" 1>&2
			exit 253
		fi
	fi
	ln -s /bin/busybox "./${CMD}"
done
# clean up ~ it's hard to say where this came from
rm -f sbin/bin
popd
#### /dev ~ Grab the necessary dev files
cp -a /dev/console "${INITRDMOUNT}/dev"
cp -a /dev/ramdisk "${INITRDMOUNT}/dev" 2>/dev/null || \
	cp -a /dev/ram0 "${INITRDMOUNT}/dev/ramdisk"
cp -a /dev/ram0 "${INITRDMOUNT}/dev"
cp -a /dev/null "${INITRDMOUNT}/dev"
cp -adpR /dev/tty[0-6] "${INITRDMOUNT}/dev"
cp -adpR /dev/kmem "${INITRDMOUNT}/dev"
cp -adpR /dev/mem "${INITRDMOUNT}/dev"
cp -adpR /dev/null "${INITRDMOUNT}/dev"
mkdir "${INITRDMOUNT}/dev/pts"
mkdir "${INITRDMOUNT}/dev/shm"
#### udhcpc
mkdir -p "${INITRDMOUNT}/etc/udhcpc" || true
cp "${IMAGEFSDIR}/etc/udhcpc/default.script" \
	${INITRDMOUNT}/etc/udhcpc/default.script
chmod +x ${INITRDMOUNT}/etc/udhcpc/default.script
#### Kernel modules
KERNELVERNO=$(printf "%s\n" ${KERNELVER} | awk -F'-' '{ print $1 }')
KERNELSUFFIX=$(printf "%s\n" ${KERNELVER} | awk -F'-' '{ print $2 }')
KMODPATH="${TMPDIR}/slack-kmodules/lib/modules/${KERNELVER}"
KMODCPTO="${INITRDMOUNT}/lib/modules/${KERNELVER}"
KMODSPKGSTR="kernel-modules-${KERNELVERNO}"
if [ ! -z "${KERNELSUFFIX}" ]; then
	KMODSPKGSTR="kernel-modules-${KERNELSUFFIX}-${KERNELVERNO}"
fi
BZIMGDIR=$(dirname "${BZIMG}")
KMODULESPKG=$(find "${BZIMGDIR}" -name "${KMODSPKGSTR}")
if [ -z "${KMODULESPKG}" ]; then
	# Try to find kernel-modules package on CD-ROM/wherever
	KMODULESPKG=$(parse_package "${KMODSPKGSTR}")
	if [ -z "${KMODULESPKG}" ]; then
		printf "Failed to locate '%s' package.\n" "${KMODSPKGSTR}" 1>&2
		exit 1
	fi # if [ -z "${KMODULESPKG}" ]
else
	BZIMGPATH=$(pwd "${BZIMG}")
	KMODULESPKG="${BZIMGPATH}/${KMODULESPKG}"
fi # if [ -z "${KMODULESPKG}" ]
# External file with get_kmodules() which does all cp of kernel modules.
if [ -e "${BZIMGDIR}/modules.sh" ]; then
	. "${BZIMGDIR}/modules.sh"
	rm -rf "${TMPDIR}/slack-kmodules"
	mkdir "${TMPDIR}/slack-kmodules/"
	cd "${TMPDIR}/slack-kmodules"
	explodepkg "${KMODULESPKG}" 1>/dev/null
	#
	get_kmodules
	pushd "${INITRDMOUNT}"
	depmod -b ./ "${KERNELVERNO}"
	popd
else
	printf "No kernel modules will be copied to INITRD."
fi # if [ -e "${BZIMGDIR}/modules.sh" ]
#### udev
UDEVPKG=$(parse_package 'udev-')
if [ ! -z "${UDEVPKG}" ]; then
	echo "Installing package '${UDEVPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${UDEVPKG}" 1>/dev/null
	sh ./install/doinst.sh
	rm -rf './install'
	getlibs sbin/udevd
	getlibs sbin/udevadm
	clean_usr
	popd
fi # if $UDEVPKG
#### etc
SLACKETCPKG=$(parse_package 'etc-')
if [ ! -z "${SLACKETCPKG}" ]; then
	echo "Installing package '${SLACKETCPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${SLACKETCPKG}" 1>/dev/null
	sh ./install/doinst.sh
	rm -rf ./install/
	find ./tmp | xargs rm -rf
	cp -apr /etc/protocols etc/
	cp -apr /etc/hosts.* etc/
	touch etc/resolv.conf
	cp /etc/host.conf etc/
	cp /etc/networks etc/
	rm -f etc/termcap-BSD
	clean_usr
	popd
fi # if SLACKETCPKG
#### elf libs
#ELFPKG=$(parse_package 'aaa_elflibs-')
#if [ ! -z "${ELFPKG}" ]; then
#	explodepkg "${ELFPKG}" 1>/dev/null
#	sh ./install/doinst.sh
#	rm -rf ./install/
#fi # if $ELFPKG
#### glibc-solibs
GLIBCSOPKG=$(parse_package 'glibc-solibs-')
if [ ! -z "${GLIBCSOPKG}" ]; then
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-glibc-solibs"
	mkdir "${TMPDIR}/slack-glibc-solibs"
	cd "${TMPDIR}/slack-glibc-solibs"
	explodepkg "${GLIBCSOPKG}" 1>/dev/null
	cp -apr ./lib${LIBDIRSUFFIX}/incoming/* "${INITRDMOUNT}/lib${LIBDIRSUFFIX}/"
	cp -apr ${TMPDIR}/slack-glibc-solibs/lib${LIBDIRSUFFIX}/libSegFault.so \
		"${INITRDMOUNT}/lib${LIBDIRSUFFIX}/"
	# There is no ldconfig; get symlinks from post-install script then
	grep -E -e 'ln -sf' -e 'rm -rf [A-Za-z0-9]+' \
		install/doinst.sh > "${INITRDMOUNT}/mydoinst.sh"
	pushd "${INITRDMOUNT}"
	sh mydoinst.sh
	rm -f mydoinst.sh
	popd
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-glibc-solibs"
fi # if GLIBCSOPKG
#### modutils
# Note: this is an isurance of module auto-loading; feature you *can* live 
# without.
MODULEINITPKG=$(parse_package 'module-init-tools-')
if [ ! -z "${MODULEINITPKG}" ]; then
	pushd "${INITRDMOUNT}"
	rm ./sbin/depmod
	rm ./sbin/insmod
	rm ./sbin/lsmod
	rm ./sbin/modinfo
	rm ./sbin/modprobe
	rm ./sbin/rmmod
	explodepkg "${MODULEINITPKG}" 1>/dev/null
	getlibs sbin/lsmod
	getlibs sbin/depmod
	getlibs sbin/insmod
	getlibs sbin/lsmod
	getlibs sbin/rmmod
	getlibs sbin/modprobe
	getlibs sbin/modinfo
	rm -rf ./install
	clean_usr
	popd
fi # if MODULEINITPKG
#### Dropbear
cd "${TMPDIR}"
rm -rf "${DROPBEARVER}"
tar -jxf "${DROPBEARVER}.tar.bz2"
cd "${DROPBEARVER}"
./configure --prefix=/usr 2>&1 >/dev/null || exit 101
make 2>&1 >/dev/null || exit 102
make install DESTDIR="${INITRDMOUNT}" 2>&1 >/dev/null || exit 103
pushd "${INITRDMOUNT}"
getlibs ./usr/bin/dbclient
getlibs ./usr/bin/dropbearconvert
getlibs ./usr/bin/dropbearkey
getlibs ./usr/sbin/dropbear
popd
#### Setup
pushd "${INITRDMOUNT}"
mkdir -p ./usr/lib/setup 2>/dev/null
cp -r ${CWD}/setup/* ./usr/lib/setup/
cat > ./usr/sbin/setup << EOF
#!/bin/ash
cd /usr/lib/setup
./setup
EOF
chmod +x ./usr/sbin/setup
#### Encrypted password
sed -r -e "s#^PASSWD=.*\$#PASSWD='${PASSWDENC}'#" \
	"${CWD}/${KSCONFIG}" > etc/Kickstart.cfg
# makedevs.sh is being copied from imagefs dir
if [ ! -z "${TAG}" ] && [ -e "${CWD}/taglists/${TAG}" ]; then
	printf "Adding TAG-list '${TAG}' of packages ... "
	printf "#\n# Taglist: %s\n" "${TAG}" >> etc/Kickstart.cfg
	awk '{ printf "#@%s\n", $0 }' "${CWD}/taglists/${TAG}" >> etc/Kickstart.cfg
	printf "# END of Taglist: %s" $TAG >> etc/Kickstart.cfg
	printf "done\n"
fi
popd
#### BTRFS
#BTRFSPKG=$(parse_package 'btrfs-progs-')
#if [ ! -z "${BTRFSPKG}" ]; then
#	echo "Installing package '${BTRFSPKG}'"
#	pushd "${INITRDMOUNT}"
#	explodepkg "${BTRFSPKG}" 1>/dev/null
#	rm -rf ./usr/man
#	rm -rf ./usr/doc
#	popd
#fi # if BTRFSPKG
#### EXT utils
E2FSPKG=$(parse_package 'e2fsprogs-')
if [ ! -z "${E2FSPKG}" ]; then
	echo "Installing package '${E2FSPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${E2FSPKG}" 1>/dev/null
	sh ./install/doinst.sh
	rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf ./usr/include
	rm -rf ./usr/man
	rm -rf ./usr/share
	rm -rf ./install
	popd
fi # if $E2FSPKG
#### JFS
JFSPKG=$(parse_package 'jfsutils-')
if [ ! -z "${JFSPKG}" ]; then
	echo "Installing package '${JFSPKG}'"
	rm -rf "${TMPDIR}/slack-jfsutils"
	mkdir "${TMPDIR}/slack-jfsutils"
	cd "${TMPDIR}/slack-jfsutils"
	explodepkg "${JFSPKG}" 1>/dev/null
	rm -rf ./usr/doc
	rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf ./usr/include
	rm -rf ./usr/man
	rm -rf ./usr/share
	rm -rf ./install
	cp -apr ./ "${INITRDMOUNT}" 
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-jfsutils"
fi # if $JFSPKG
#### ReiserFS
REISERFSPKG=$(parse_package 'reiserfsprogs-')
if [ ! -z "${REISERFSPKG}" ]; then
	echo "Installing package '${REISERFSPKG}'"
	rm -rf "${TMPDIR}/slack-reiserfs"
	mkdir "${TMPDIR}/slack-reiserfs"
	cd "${TMPDIR}/slack-reiserfs"
	explodepkg "${REISERFSPKG}" 1>/dev/null
	rm -rf ./usr/doc
	rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf ./usr/include
	rm -rf ./usr/man
	rm -rf ./usr/share
	rm -rf ./install
	cp -apr ./ "${INITRDMOUNT}" 
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-reiserfs"
fi # if $REISERFSPKG
#### XFS 
XFSPKG=$(parse_package 'xfsprogs-')
if [ ! -z "${XFSPKG}" ]; then
	echo "Installing package '${XFSPKG}'"
	rm -rf "${TMPDIR}/slack-xfs"
	mkdir "${TMPDIR}/slack-xfs"
	cd "${TMPDIR}/slack-xfs"
	explodepkg "${XFSPKG}" 1>/dev/null
	rm -rf ./usr/doc
	rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf ./usr/include
	rm -rf ./usr/man
	rm -rf ./usr/share
	rm -rf ./install
	cp -apr ./ "${INITRDMOUNT}" 
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-xfs"
fi # if $XFSPKG
#### util-linux
UTILLNXPKG=$(parse_package 'util-linux-')
if [ ! -z "${UTILLNXPKG}" ]; then
	echo "Installing package '${UTILLNXPKG}'"
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-util-linux"
	mkdir "${TMPDIR}/slack-util-linux"
	cd "${TMPDIR}/slack-util-linux"
	explodepkg "${UTILLNXPKG}" 1>/dev/null
	cp ./sbin/sfdisk "${INITRDMOUNT}/sbin/"
	cp -apr ./lib${LIBDIRSUFFIX} "${INITRDMOUNT}/"
	cp -r ./install "${INITRDMOUNT}/"
	pushd "${INITRDMOUNT}"
	sh ./install/doinst.sh
	rm -rf ./install
	rm -f clock.8.gz 
	rm -f jaztool.1.gz
	popd
	cd "${TMPDIR}"
	rm -rf slack-util-linux
fi # if $UTILLNXPKG
#### NFS utils
NFSPKG=$(parse_package 'nfs-utils-')
if [ ! -z "${NFSPKG}" ]; then
	echo "Installing package '${NFSPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${NFSPKG}" 1>/dev/null
	sh ./install/doinst.sh
	rm -rf ./install
	clean_usr
	popd
fi # if $NFSPKG
#### Portmap/RPC
PORTMAPPKG=$(parse_package 'portmap-')
if [ ! -z "${PORTMAPPKG}" ]; then
	echo "Installing package '${PORTMAPPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${PORTMAPPKG}" 1>/dev/null
	sh ./install/doinst.sh
	rm -rf ./install
	clean_usr
	popd
fi # if $PORTMAPPKG
#### gzip ~ gzip is shipped with Busybox
#GZIPPKG=$(parse_package 'gzip-')
#if [ ! -z "${GZIPPKG}" ]; then
#	echo "Installing package '${GZIPPKG}'"
#	pushd "${INITRDMOUNT}"
#	explodepkg "${GZIPPKG}" 1>/dev/null
#	sh ./install/doinst.sh
#	rm -rf ./install
#	clean_usr
#	popd
#fi # if $GZIPPKG
#### xz
XZPKG=$(parse_package 'xz-')
if [ ! -z "${XZPKG}" ]; then
	echo "Installing package '${XZPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${XZPKG}" 1>/dev/null
	rm -rf ./usr/include/lzma
	sh ./install/doinst.sh
	rm -rf ./install
	clean_usr
	popd
fi # if $XZPKG
#### terminfo
TERMIPKG=$(parse_package 'aaa_terminfo-')
if [ ! -z "${TERMIPKG}" ]; then
	echo "Installing package '${TERMIPKG}'"
	pushd "${INITRDMOUNT}"
	explodepkg "${TERMIPKG}" 1>/dev/null
	rm -rf ./install
	popd
fi # if $TERMIPKG
#### coreutils
COREUTIPKG=$(parse_package 'coreutils-')
if [ ! -z "${COREUTIPKG}" ]; then
	echo "Installing package '${COREUTIPKG}'"
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-coreutils"
	mkdir "${TMPDIR}/slack-coreutils"
	cd "${TMPDIR}/slack-coreutils"
	explodepkg "${COREUTIPKG}" 1>/dev/null
	cp "${TMPDIR}/slack-coreutils/bin/paste" "${INITRDMOUNT}/bin/paste"
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-coreutils"
fi # if $COREUTILS
#### tar
TARPKG=$(parse_package 'tar-')
if [ ! -z "${TARPKG}" ]; then
	rm -rf "${TMPDIR}/slack-tar"
	mkdir "${TMPDIR}/slack-tar"
	cd "${TMPDIR}/slack-tar"
	explodepkg "${TARPKG}" 1>/dev/null
	echo "Installing 'tar-1.13'"
	cp "${TMPDIR}/slack-tar/bin/tar-1.13" "${INITRDMOUNT}/bin/"
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-tar"
fi
#### ntp
NTPPKG=$(parse_package 'ntp-')
if [ ! -z "${NTPPKG}" ]; then
	rm -rf "${TMPDIR}/slack-ntp"
	mkdir "${TMPDIR}/slack-ntp"
	cd "${TMPDIR}/slack-ntp"
	explodepkg "${NTPPKG}" 1>/dev/null
	echo "Installing 'ntpdate'"
	cp usr/sbin/ntpdate "${INITRDMOUNT}/usr/sbin/"
	pushd "${INITRDMOUNT}"
	getlibs usr/sbin/ntpdate
	popd
	cd ${TMPDIR}
	rm -rf "${TMPDIR}/slack-ntp"
fi # if $NTPPKG
### Finish up...
#### Set TZ
cp -pr ${CWD}/${IMAGEFSDIR}/* "${INITRDMOUNT}/"
if [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
	echo "Configuring TZ settings"
	cat "/usr/share/zoneinfo/${TIMEZONE}" > "${INITRDMOUNT}/etc/localtime"
fi
chmod +x ${INITRDMOUNT}/etc/rc.d/rc.*
#### SSH keys
if [ -e "${CWD}/config-files/authorized_keys" ]; then
	printf "Getting SSH keys\n"
	mkdir -p "${INITRDMOUNT}/root/.ssh/"
	mkdir -p "${INITRDMOUNT}/etc/dropbear/"
	cp "${CWD}/config-files/authorized_keys" "${INITRDMOUNT}/etc/dropbear/"
	cp "${CWD}/config-files/authorized_keys" "${INITRDMOUNT}/root/.ssh/"
	chmod 400 "${INITRDMOUNT}/root/.ssh/" "${INITRDMOUNT}/etc/dropbear/"
fi
#### passwords
printf "Altering passwords.\n"
pushd "${INITRDMOUNT}"
cp etc/passwd etc/passwd.org
sed -e 's#bash#sh#g' etc/passwd.org > etc/passwd
rm -f etc/passwd.org
cp etc/shadow etc/shadow.org
sed -r -e "/^root:/c \root:${PASSWDENC}:14466:0:::::" \
	etc/shadow.org > etc/shadow
rm -f etc/shadow.org
popd
#### pre-installation scripts
if [ -d "${CWD}/pre-install/" ]; then
	printf "Copying pre-installation scripts.\n"
	mkdir -p ${INITRDMOUNT}/etc/pre-install || true
	for PRESCRIPT in $(ls "${CWD}/pre-install/"); do
		cp -r "${CWD}/pre-install/${PRESCRIPT}" "${INITRDMOUNT}/etc/pre-install/"
	done
fi
#### post-installation scripts
if [ -d "${CWD}/post-install/" ]; then
	printf "Copying post-installation scripts.\n"
	mkdir -p ${INITRDMOUNT}/etc/post-install || true
	for POSTSCRIPT in $(ls "${CWD}/post-install/"); do
		cp -r "${CWD}/post-install/${POSTSCRIPT}" "${INITRDMOUNT}/etc/post-install/"
	done
fi
#### chown root:root everything
find "${INITRDMOUNT}" ! -user root ! -group root | xargs chown root:root
#
df -h "${INITRDMOUNT}"
umount "${INITRDMOUNT}"
gzip -9 "${TMPDIR}/ramdisk.img"
RDISKNAME=$(basename "${KSCONFIG}" .cfg)
mv "${TMPDIR}/ramdisk.img.gz" "${CWD}/rootdisks/${RDISKNAME}.gz"
# EOF
