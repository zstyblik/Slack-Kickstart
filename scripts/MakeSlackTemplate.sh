#!/bin/bash
# 2011/May @ Zdenek Styblik
# Desc: create template kickstart image for Slack-Kickstart
# Missing features/TODO:
# * chown root:root instead of stybla
# * more than one HDD, mdadm, LVM ?
set -e
set -u

BUSYBOXVER='1.18.4'
DROPBEARVER='0.53.1'
LIBDIRSUFFIX=64
IMAGEFSDIR="./imagefs"
INITRDMOUNT='/mnt/initrd'
SLACKCDPATH='/mnt/cdrom/'
TMPDIR='/tmp'

# Ramdisk Constants
#RDSIZE=32768
RDSIZE=65536
BLKSIZE=1024

SCRIPTNAME=$(basename "${0}")
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
		echo "${LIBLINE}" | grep -q -e 'linux-vdso' && continue;
		echo "${LIBLINE}" | grep -q -e 'linux-gate' && continue;
		if $(echo "${LIBLINE}" | awk -F'#' '{ print $1 }' | grep -q -e '^/') ; then
			LIBTOCOPY=$(echo "${LIBLINE}" | awk -F'#' '{ print $1 }');
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
			if $(file "${LIBTOCOPY}" | grep -q -e 'symbolic link') ; then
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
		if $(echo "${LIBLINE}" | grep -q -e '=>') ; then
			LIBPOINTER=$(echo "${LIBLINE}" | awk -F'#' '{ print $3 }')
			LIBREAL=$(file "${LIBPOINTER}" | cut -d '`' -f 2 | tr -d "'")
			LIBDIR=$(dirname "${LIBPOINTER}")
			LIBLINK=$(echo "${LIBLINE}" | awk -F'#' '{ print $1 }')
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
	echo "${SLACKCDPATH}/${PKGFOUND}"
} # parse_package
# DESC: show help text
show_help() 
{
	echo "Usage: ${0} <CFG> <bzImage>"
	echo "Help haven't been written yet."
	return 0
} # show_help

### MAIN ###
KSCONFIG=${1:-''}
if [ -z "${KSCONFIG}" ]; then
	show_help
	exit 1
fi

if [ ! -e "${KSCONFIG}" ]; then
	echo "File '${KSCONFIG}' doesn't seem to exist or not readable."
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
	echo "File '${BZIMG}' doesn't seem to exist or not readable."
	exit 1
fi

# Housekeeping...
if $(mount | grep -q -e "${INITRDMOUNT}") ; then
	echo "Initrd dir '${INITRDMOUNT}' already mounted."
	exit 1
fi

CWD=$(pwd)
if [ ! -d "${IMAGEFSDIR}" ]; then
	if [ ! -d "../${IMAGEFSDIR}" ]; then
		echo "I couldn't locate './imagefs' neither '../imagefs' dir"
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
	echo "No '${SLACKCDPATH}/slackware' nor '${SLACKCDPATH}/slackware64' found."
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

#### BUSYBOX ####
# Grab busybox and create the symbolic links
pushd "${INITRDMOUNT}"
cp "${TMPDIR}/busybox-${BUSYBOXVER}/busybox" ./bin/
getlibs bin/busybox
for CMD in $(./bin/busybox --list-ful); do
	CMDDIR=$(dirname "${CMD}")
	if [ ! -d "${CMDDIR}" ]; then
		mkdir -p "./${CMDDIR}" || \
			{
				echo "Unable to create dir '${CMDDIR}'"
				exit 253
			}
	fi
	ln -s /bin/busybox "./${CMD}"
done
mkdir -p etc/udhcpc
cp "${TMPDIR}/busybox-${BUSYBOXVER}/examples/udhcp/simple.script" \
	etc/udhcpc/default.script
chmod +x etc/udhcpc/default.script
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

#### Kernel modules
# TODO: megaTodo - which modules, how-to determine version etc.
# A: external file as a list of modules to copy including "paths"
KERNELVER=$(strings "${BZIMG}" | \
	grep -E -e '^(2|3)\.[0-9]+(\.[0-9]+(\.[0-9]+))' | awk '{ print $1 }')
KERNELVERNO=$(echo "${KERNELVER}" | awk -F'-' '{ print $1 }')
KERNELSUFFIX=$(echo "${KERNELVER}" | awk -F'-' '{ print $2 }')
KMODPATH="${TMPDIR}/slack-kmodules/lib/modules/2.6.37.6"
KMODCPTO="${INITRDMOUNT}/lib/modules/${KERNELVER}"
KMODSPKGSTR="kernel-modules-${KERNELVERNO}"
if [ ! -z "${KERNELSUFFIX}" ]; then
	KMODSPKGSTR="kernel-modules-${KERNELSUFFIX}-${KERNELVERNO}"
fi
KMODULESPKG=$(parse_package "${KMODSPKGSTR}")
rm -rf "${TMPDIR}/slack-kmodules"
mkdir "${TMPDIR}/slack-kmodules/"
cd "${TMPDIR}/slack-kmodules"
explodepkg "${KMODULESPKG}" 1>/dev/null
#
mkdir -p "${KMODCPTO}/kernel"
cp -apr ${KMODPATH}/modules.* "${KMODCPTO}/"
# Filesystems
mkdir "${KMODCPTO}/kernel/fs/"
for FS in btrfs jfs ext2 ext3 ext4 reiserfs xfs; do
	cp -apr "${KMODPATH}/kernel/fs/${FS}" "${KMODCPTO}/kernel/fs/" || true
done # for FS
# Block devs
mkdir -p "${KMODCPTO}/kernel/drivers/block"
cp -apr "${KMODPATH}/kernel/drivers/block/virtio_blk.ko" \
	"${KMODCPTO}/kernel/drivers/block/" || true
# Char devs
mkdir -p "${KMODCPTO}/kernel/drivers/char"
cp -apr "${KMODPATH}/kernel/drivers/char/virtio_console.ko" \
	"${KMODCPTO}/kernel/drivers/char/" || true
# Input devs
mkdir -p "${KMODCPTO}/kernel/drivers/input/serio"
for SER in serio_raw.ko serport.ko; do
	cp -apr "${KMODPATH}/kernel/drivers/input/serio/${SER}" \
		"${KMODCPTO}/kernel/drivers/input/serio/"
done # for SER
# Net devs
mkdir -p "${KMODCPTO}/kernel/drivers/net/"
for NETMOD in 8139cp.ko 8139too.ko 3c59x.ko e100.ko e1000 e1000e tun.ko \
	virtio_net.ko; do
	cp -apr "${KMODPATH}/kernel/drivers/net/${NETMOD}" \
		"${KMODCPTO}/kernel/drivers/net/" || true
done # for NETMOD
# TODO ~ USB modules ?
# VirtiIO acc
cp -apr "${KMODPATH}/kernel/drivers/vhost" \
	"${KMODCPTO}/kernel/drivers/vhost" || true
cp -apr "${KMODPATH}/kernel/drivers/virtio" \
	"${KMODCPTO}/kernel/drivers/" || true
#
cp "etc/rc.d/rc.modules-${KERNELVERNO}.new" \
	"${INITRDMOUNT}/etc/rc.d/rc.modules" || true
pushd "${INITRDMOUNT}"
depmod -b ./ "${KERNELVERNO}"
popd

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
#explodepkg "${ELFPKG}" 1>/dev/null
#sh ./install/doinst.sh
#rm -rf ./install/
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
	cat > "${INITRDMOUNT}/mydoinst.sh" <<EOF
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_nis.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_nis-2.13.so libnss_nis.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libm.so.6 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libm-2.13.so libm.so.6 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_files.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_files-2.13.so libnss_files.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libresolv.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libresolv-2.13.so libresolv.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnsl.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnsl-2.13.so libnsl.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libutil.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libutil-2.13.so libutil.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_compat.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_compat-2.13.so libnss_compat.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libthread_db.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libthread_db-1.0.so libthread_db.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_hesiod.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_hesiod-2.13.so libnss_hesiod.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libanl.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libanl-2.13.so libanl.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libcrypt.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libcrypt-2.13.so libcrypt.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libBrokenLocale.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libBrokenLocale-2.13.so libBrokenLocale.so.1 )
( cd lib${LIBDIRSUFFIX} ; rm -rf ld-linux-x86-64.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf ld-2.13.so ld-linux-x86-64.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libdl.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libdl-2.13.so libdl.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_dns.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_dns-2.13.so libnss_dns.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libpthread.so.0 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libpthread-2.13.so libpthread.so.0 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libnss_nisplus.so.2 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libnss_nisplus-2.13.so libnss_nisplus.so.2 )
( cd lib${LIBDIRSUFFIX} ; rm -rf libc.so.6 )
( cd lib${LIBDIRSUFFIX} ; ln -sf libc-2.13.so libc.so.6 )
( cd lib${LIBDIRSUFFIX} ; rm -rf librt.so.1 )
( cd lib${LIBDIRSUFFIX} ; ln -sf librt-2.13.so librt.so.1 )
EOF
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
if [ ! -e "dropbear-${DROPBEARVER}.tar.bz2" ]; then
	wget "http://matt.ucc.asn.au/dropbear/dropbear-${DROPBEARVER}.tar.bz2"
fi
rm -rf "dropbear-${DROPBEARVER}"
tar -jxf "dropbear-${DROPBEARVER}.tar.bz2"
cd "dropbear-${DROPBEARVER}"
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
#
sed -r -e "s#^PASSWD=.*\$#PASSWD='${PASSWDENC}'#" \
	"${CWD}/${KSCONFIG}" > etc/Kickstart.cfg
# makedevs.sh is being copied from imagefs dir
popd
#### BTRFS
# TODO ~ btrfs-progs-20110327-x86_64-1.txz
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
	cp "${TMPDIR}/slack-tar/bin/tar-1.13" "${INITRDMOUNT}/bin/"
	cd "${TMPDIR}"
	rm -rf "${TMPDIR}/slack-coreutils"
fi # if $COREUTILS
#### Finish up...
cp -pr ${CWD}/${IMAGEFSDIR}/* "${INITRDMOUNT}/"
if [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
	echo "Configuring TZ settings"
	cp "/usr/share/zoneinfo/${TIMEZONE}" "${INITRDMOUNT}/etc/localtime"
fi
#### passwords
cp etc/passwd etc/passwd.org
sed -e 's#bash#sh#g' etc/passwd.org > etc/passwd
rm -f etc/passwd.org
cp etc/shadow etc/shadow.org
sed -r -e "/^root:/c \root:${PASSWDENC}:14466:0:::::" \
	etc/shadow.org > etc/shadow
rm -f etc/shadow.org
#
df -h "${INITRDMOUNT}"
umount "${INITRDMOUNT}"
gzip -9 "${TMPDIR}/ramdisk.img"
RDISKNAME=$(basename "${KSCONFIG}" .cfg)
mv "${TMPDIR}/ramdisk.img.gz" "${CWD}/rootdisks/${RDISKNAME}.gz"
