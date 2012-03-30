#!/bin/sh
# 2012/Mar/29 @ Zdenek Styblik
# Desc: copy kernel modules to initrd
set -e
set -u

get_kmodules()
{
	mkdir -p "${KMODCPTO}/kernel"
	cp -apr ${KMODPATH}/modules.* "${KMODCPTO}/" || true
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
			"${KMODCPTO}/kernel/drivers/input/serio/" || true
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
} # get_modules()

# EOF
