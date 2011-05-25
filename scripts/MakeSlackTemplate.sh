#!/bin/bash
# Missing features/TODO:
# * chown root:root instead of stybla
# * given passwd in /etc/shadow after an installation
# * more than one HDD, mdadm, LVM ?
# * automagically determine kernel ?
BUSYBOXDIR='/tmp/busybox/busybox-1.18.4'
INITRDMOUNT='/mnt/initrd'
LIBDIRSUFFIX=64
PASSWD="heslo"
PASSWDENC=$(openssl passwd -1 "${PASSWD}")
SLACKPATH='/mnt/floppy/'
TMPDIR='/tmp'

# Ramdisk Constants
RDSIZE=32768
BLKSIZE=1024

# Desc: removes /usr/man, /usr/doc and /usr/share
clean_usr()
{
	rm -rf "${INITRDMOUNT}/usr/doc"
	rm -rf "${INITRDMOUNT}/usr/info"
	rm -rf "${INITRDMOUNT}/usr/lib${LIBDIRSUFFIX}/pkgconfig"
	rm -rf "${INITRDMOUNT}/usr/man"
	rm -rf "${INITRDMOUNT}/usr/share"
	return 0
} # clean_usr

# Note: automagic lib dependency
# TODO: what if dir is anything else but /lib?
getlibs()
{
	BINARY=${1:-''}
	if [ -z "${BINARY}" ]; then
		return 1
	fi
	if [ ! -e "${BINARY}" ]; then
		return 1
	fi
	for LIBLINE in $(ldd "${BINARY}"); do
		echo "${LIBLINE}" | grep -q -e 'linux-vdso' && continue;
		echo "${LIBLINE}" | grep -q -e 'linux-gate' && continue;
		echo "${LIBLINE}" | awk '{ print $1 }' | grep -q -e '^/' && \
			{
				LIBTOCOPY=$(echo "${LIBLINE}" | cut -d ' ' -f 1);
				LIBDIR=$(dirname "${LIBTOCOPY}")
				if [ -z "${LIBTOCOPY}" ]; then
					echo "[FAIL] failed to automagically copy lib dep for '${BINARY}'"
					continue
				fi
				if [ ! -d "${INITRDMOUNT}/${LIBDIR}" ]; then
					mkdir -p "${INITRDMOUNT}/${LIBDIR}"
				fi
				cp -apr "${LIBTOCOPY}" "${INITRDMOUNT}/${LIBDIR}";
				continue;
			}
		echo "${LIBLINE}" | grep -q -e '=>' && \
			{
				LIBREAL=$(echo "${LIBLINE}" | awk '{ print $3 }')
				LIBDIR=$(dirname "${LIBREAL}")
				LIBLINK=$(echo "${LIBLINE}" | awk '{ print $1 }')
				if [ -z "${LIBREAL}" -o -z "${LIBLINK}" ]; then
					echo "[FAIL] failed to to automagically copy lib dep for '${BINARY}'"
					continue
				fi
				if [ ! -d "${INITRDMOUNT}/${LIBDIR}" ]; then
					mkdir -p "${INITRDMOUNT}/${LIBDIR}"
				fi
				cp -apr "${LIBREAL}" "${INITRDMOUNT}/${LIBDIR}";
				LIBREALNAME=$(basename "${LIBREAL}");
				pushd "${INITRDMOUNT}/${LIBDIR}";
				ln -s "${LIBLINK}" "${LIBREALNAME}";
				popd
				continue;
			}
	done
	return 0
}
### MAIN ###
# Housekeeping...
if $(mount | grep -q -e "${INITRDMOUNT}") ; then
	echo "Initrd dir '${INITRDMOUNT}' already mounted."
	exit 1
fi
rm -f "${TMPDIR}/ramdisk.img"
rm -f "${TMPDIR}/ramdisk.img.gz"

# Create an empty ramdisk image
dd if=/dev/zero of="${TMPDIR}/ramdisk.img" bs=${BLKSIZE} count=${RDSIZE}

# Make it an ext2 mountable file system
/sbin/mke2fs -F -m 0 -b ${BLKSIZE} "${TMPDIR}/ramdisk.img" ${RDSIZE}

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
mkdir "${INITRDMOUNT}/lib${LIBDIRSUFFIX}"
mkdir "${INITRDMOUNT}/mnt"
mkdir "${INITRDMOUNT}/root"
mkdir "${INITRDMOUNT}/tmp"
mkdir "${INITRDMOUNT}/var"
mkdir "${INITRDMOUNT}/var/log"
mkdir "${INITRDMOUNT}/var/run"
mkdir "${INITRDMOUNT}/var/tmp"
# TODO ~ this is only temporary and should be fixed within script !!!
mkdir "${INITRDMOUNT}/var/log/mount"
#mkdir "${INITRDMOUNT}/var/log/mount/slackware"
# TODO ~ this is only temporary and should be fixed within script !!!

# Grab busybox and create the symbolic links
# Note: automagic linking to Busybox
pushd "${INITRDMOUNT}"
cp "${BUSYBOXDIR}/busybox" ./bin/
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
cp "${BUSYBOXDIR}/examples/udhcp/simple.script" \
	etc/udhcpc/default.script
chmod +x etc/udhcpc/default.script
# clean up ~ it's hard to say where this came from
rm -f sbin/bin
#rm linuxrc
# Equate sbin with bin
#ln -s bin sbin
popd

# Grab the necessary dev files
cp -a /dev/console "${INITRDMOUNT}/dev"
cp -a /dev/ramdisk "${INITRDMOUNT}/dev" || \
	cp -a /dev/ram0 "${INITRDMOUNT}/dev/ramdisk"
cp -a /dev/ram0 "${INITRDMOUNT}/dev"
cp -a /dev/null "${INITRDMOUNT}/dev"
cp -adpR /dev/tty[0-6] "${INITRDMOUNT}/dev"
cp -adpR /dev/kmem "${INITRDMOUNT}/dev"
cp -adpR /dev/mem "${INITRDMOUNT}/dev"
cp -adpR /dev/null "${INITRDMOUNT}/dev"
mkdir "${INITRDMOUNT}/dev/pts"
mkdir "${INITRDMOUNT}/dev/shm"

# Kernel modules
# TODO: megaTodo - which modules, how-to determine version etc.
# TODO: {...} expansion won't work in Dash
KMODPATH="${TMPDIR}/kernel-modules/lib/modules/2.6.37.6"
KMODCPTO="${INITRDMOUNT}/lib/modules/2.6.37.6"
mkdir -p "${KMODCPTO}/kernel"
cp -apr ${KMODPATH}/modules.* "${KMODCPTO}/"
# Filesystems
mkdir "${KMODCPTO}/kernel/fs/"
cp -apr ${KMODPATH}/kernel/fs/{jfs,ext2,ext3,ext4,reiserfs,xfs} \
	"${KMODCPTO}/kernel/fs/"
# Block devs
mkdir -p "${KMODCPTO}/kernel/drivers/block"
cp -apr "${KMODPATH}/kernel/drivers/block/virtio_blk.ko" \
	"${KMODCPTO}/kernel/drivers/block/"
# Char devs
mkdir -p "${KMODCPTO}/kernel/drivers/char"
cp -apr "${KMODPATH}/kernel/drivers/char/virtio_console.ko" \
	"${KMODCPTO}/kernel/drivers/char/"
# Input devs
mkdir -p "${KMODCPTO}/kernel/drivers/input/serio"
cp -apr ${KMODPATH}/kernel/drivers/input/serio/{serio_raw.ko,serport.ko} \
	"${KMODCPTO}/kernel/drivers/input/serio/"
# Net devs
mkdir -p "${KMODCPTO}/kernel/drivers/net/"
cp -apr \
	${KMODPATH}/kernel/drivers/net/{8139cp.ko,8139too.ko,3c59x.ko,e100.ko,e1000,e1000e,tun.ko,virtio_net.ko} \
	"${KMODCPTO}/kernel/drivers/net/"
# TODO ~ USB modules ?
# VirtiIO acc
cp -apr "${KMODPATH}/kernel/drivers/vhost" "${KMODCPTO}/kernel/drivers/vhost"
cp -apr "${KMODPATH}/kernel/drivers/virtio" "${KMODCPTO}/kernel/drivers/"
#
#
cp "${TMPDIR}/kernel-modules/etc/rc.d/rc.modules-2.6.37.6.new" \
	"${INITRDMOUNT}/etc/rc.d/rc.modules"
pushd "${INITRDMOUNT}"
depmod -v -b ./ 2.6.37.6
popd
# UDev
pushd "${INITRDMOUNT}"
/sbin/explodepkg ${SLACKPATH}/slackware64/a/udev-165-x86_64-2.txz
sh ./install/doinst.sh
rm -rf './install'
getlibs sbin/udevd
getlibs sbin/udevadm
cp ${TMPDIR}/slack-etc/etc/group.new etc/group
cp ${TMPDIR}/slack-etc/etc/passwd.new etc/passwd
cp -avp ${TMPDIR}/rc.scripts/* etc/rc.d/
cp ${TMPDIR}/udev-helpers/nethelper.sh lib/udev/nethelper.sh || exit 254
clean_usr
# etc
/sbin/explodepkg ${SLACKPATH}/slackware64/a/etc-13.013-x86_64-1.txz
sh ./install/doinst.sh
rm -rf ./install/
find ./tmp | xargs rm -rf
cp ${TMPDIR}/slack-etc/etc/nsswitch.conf.new etc/nsswitch.conf
cp -apr /etc/protocols etc/
cp -apr /etc/hosts.* etc/
touch etc/resolv.conf
cp /etc/host.conf etc/
cp /etc/networks etc/
rm -f etc/termcap-BSD
clean_usr
## passwords
cp etc/passwd etc/passwd.org
sed -e 's#bash#sh#g' etc/passwd.org > etc/passwd
rm -f etc/passwd.org
cp etc/shadow etc/shadow.org
sed -r -e "/^root:/c \root:${PASSWDENC}:14466:0:::::" \
	etc/shadow.org > etc/shadow
rm -f etc/shadow.org
# elf libs
cp -apr ${TMPDIR}/slack-elf/* ./
sh ./install/doinst.sh
rm -rf ./install/
# glibc-solibs
cp -apr ${TMPDIR}/slack-glibc-solibs/lib64/incoming/* lib64/
cp -apr ${TMPDIR}/slack-glibc-solibs/lib64/libSegFault.so lib64/
cp ${TMPDIR}/slack-glibc-solibs/install/mydoinst.sh ./
sh mydoinst.sh
rm mydoinst.sh
# modutils
# Note: this is an isurance of module auto-loading; feature you *can* live 
# without.
rm ./sbin/depmod
rm ./sbin/insmod
rm ./sbin/lsmod
rm ./sbin/modinfo
rm ./sbin/modprobe
rm ./sbin/rmmod
explodepkg ${SLACKPATH}/slackware64/a/module-init-tools-3.12-x86_64-2.txz
getlibs sbin/lsmod
getlibs sbin/depmod
getlibs sbin/insmod
getlibs sbin/lsmod
getlibs sbin/rmmod
getlibs sbin/modprobe
getlibs sbin/modinfo
rm -rf ./install
clean_usr
#
#
# Dropbear
cp -apr ${TMPDIR}/install-dropbear/* ./
getlibs ./usr/bin/dbclient
getlibs ./usr/bin/dropbearconvert
getlibs ./usr/bin/dropbearkey
getlibs ./usr/sbin/dropbear
# Installator
mkdir -p ./usr/lib/setup 2>/dev/null
cp -r ${TMPDIR}/Slack-Kickstart-10.2_v06b/Setup/* ./usr/lib/setup/
cp -r ${TMPDIR}/Slack-Kickstart-10.2_v06b/Config-Files/ks-test.cfg \
	etc/Kickstart.cfg
cp ${TMPDIR}/Slack-Kickstart-10.2_v06b/Scripts/makedevs.sh ./usr/sbin/ 
popd
# BTRFS
# btrfs-progs-20110327-x86_64-1.txz
# EXT utils
pushd "${INITRDMOUNT}"
explodepkg ${SLACKPATH}/slackware64/a/e2fsprogs-1.41.14-x86_64-1.txz
sh ./install/doinst.sh
rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
rm -rf ./usr/include
rm -rf ./usr/man
rm -rf ./usr/share
rm -rf ./install
popd
# JFS
rm -rf ${TMPDIR}/slack-jfsutils
mkdir ${TMPDIR}/slack-jfsutils
cd ${TMPDIR}/slack-jfsutils
explodepkg ${SLACKPATH}/slackware64/a/jfsutils-1.1.15-x86_64-1.txz
rm -rf ./usr/doc
rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
rm -rf ./usr/include
rm -rf ./usr/man
rm -rf ./usr/share
rm -rf ./install
cp -apr ./ "${INITRDMOUNT}" 
cd ../
rm -rf ${TMPDIR}/slack-jfsutils
# ReiserFS
rm -rf ${TMPDIR}/slack-jfsutils
mkdir ${TMPDIR}/slack-jfsutils
cd ${TMPDIR}/slack-jfsutils
explodepkg ${SLACKPATH}/slackware64/a/reiserfsprogs-3.6.21-x86_64-1.txz
rm -rf ./usr/doc
rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
rm -rf ./usr/include
rm -rf ./usr/man
rm -rf ./usr/share
rm -rf ./install
cp -apr ./ "${INITRDMOUNT}" 
cd ../
rm -rf ${TMPDIR}/slack-jfsutils
# XFS 
rm -rf ${TMPDIR}/slack-jfsutils
mkdir ${TMPDIR}/slack-jfsutils
cd ${TMPDIR}/slack-jfsutils
explodepkg ${SLACKPATH}/slackware64/a/xfsprogs-3.1.4-x86_64-1.txz
rm -rf ./usr/doc
rm -rf "./usr/lib${LIBDIRSUFFIX}/pkgconfig"
rm -rf ./usr/include
rm -rf ./usr/man
rm -rf ./usr/share
rm -rf ./install
cp -apr ./ "${INITRDMOUNT}" 
cd ../
rm -rf ${TMPDIR}/slack-jfsutils
# util-linux
cd ${TMPDIR}
rm -rf slack-util-linux
mkdir slack-util-linux
cd slack-util-linux
explodepkg ${SLACKPATH}/slackware64/a/util-linux-2.19-x86_64-1.txz
cp ./sbin/sfdisk "${INITRDMOUNT}/sbin/"
cp -apr ./lib64 "${INITRDMOUNT}/"
cp -r ./install "${INITRDMOUNT}/"
pushd "${INITRDMOUNT}"
sh ./install/doinst.sh
rm -f ./install
popd

pushd "${INITRDMOUNT}"
# NFS utils
explodepkg ${SLACKPATH}/slackware64/n/nfs-utils-1.2.3-x86_64-3.txz
sh ./install/doinst.sh
rm -rf ./install
clean_usr
# Portmap/RPC
explodepkg ${SLACKPATH}/slackware64/n/portmap-6.0-x86_64-1.txz
sh ./install/doinst.sh
rm -rf ./install
clean_usr
# dialog
#explodepkg ${SLACKPATH}/slackware64/a/dialog-1.1_20100428-x86_64-2.txz
#rm -rf ./install
#clean_usr
# pkgtools
#explodepkg ${SLACKPATH}/slackware64/a/pkgtools-13.37-noarch-9.tgz
#rm -rf ./install
#clean_usr
# xz
explodepkg ${SLACKPATH}/slackware64/a/xz-5.0.2-x86_64-1.tgz
rm -rf ./usr/include/lzma
sh ./install/doinst.sh
rm -rf ./install
clean_usr
# terminfo
explodepkg ${SLACKPATH}/slackware64/a/aaa_terminfo-5.8-x86_64-1.txz
rm -rf ./install
popd
cp ${TMPDIR}/slack-coreutils/bin/paste "${INITRDMOUNT}/bin/paste"
cp ${TMPDIR}/slack-tar/bin/tar-1.13 "${INITRDMOUNT}/bin/"

# inittab
#::sysinit:/linuxrc
#::sysinit:/etc/rc.d/rc.S start
cat >> "${INITRDMOUNT}/etc/inittab" << EOF
::sysinit:/etc/rc.d/rc.S
::sysinit:/etc/rc.d/rc.M
#
ttyS0::askfirst:/bin/ash --login
tty1::askfirst:/bin/ash --login
tty2:askfirst:/bin/ash --login
tty3::askfirst:/bin/ash --login
#
::ctrlaltdel:/sbin/reboot
#
::shutdown:/sbin/swapoff -a >/dev/null 2>&1 
::shutdown:/bin/umount -a -r >/dev/null 2>&1
EOF

# /etc/fstab
cat >> "${INITRDMOUNT}/etc/fstab" << EOF
#/dev/cdrom      /mnt/cdrom       auto        noauto,owner,ro  0   0
/dev/fd0         /mnt/floppy      auto        noauto,owner     0   0
devpts           /dev/pts         devpts      gid=5,mode=620   0   0
proc             /proc            proc        defaults         0   0
tmpfs            /dev/shm         tmpfs       defaults         0   0
EOF

# Finish up...
umount "${INITRDMOUNT}"
gzip -9 "${TMP}/ramdisk.img"
#cp ${TMPDIR}/ramdisk.img.gz /boot/ramdisk.img.gz
