# /usr/lib/setup/include/filesystem.inc
#
# Slack-Kickstart-ng
#
# Last revision: 19/09/2005 vonatar(http://www.slack-kickstart.org)
#
# This file contains some common functions
# and variable definitions.
#
# It is included at top level of each script in /usr/lib/setup
# I hope that with this trick, the scripts are a bit more readable.
#

FH_LOG=${FH_LOG:-"/var/log/kickstart.log"}

#### STANDARD FUNCTIONS

# make_ext2( dev, nodes, check ) - Create a new ext2 filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext2() {

	MKEXT2=mke2fs
	#
	# do the format
	#
	RC=1
	if [ "${3}" = "y" ]; then
		${MKEXT2} -c -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	else
		${MKEXT2} -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	fi
	return $RC
} # make_ext2

# make_ext3( dev, nodes, check ) - Create a new ext3 filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext3() {
#
# Here we must know what version of Slackware we are going to install:
# Slackware 9.0 mke2fs is different from the old one (Slack 8.1) so,
# if we're installing 8.1 we must use the old binary.
#
	MKEXT3=mke2fs
	RC=1
	# do the format
	if [ "${3}" = "y" ]; then
		${MKEXT3} -c -j -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	else
		${MKEXT3} -j -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	fi
	return $RC
} # make_ext3

# make_ext3( dev, nodes, check ) - Create a new ext3 filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext4() {
	MKEXT4=mke2fs
	RC=1
	if [ "${3}" = "y" ]; then
		${MKEXT4} -c -t ext4 -j -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	else
		${MKEXT4} -t ext4 -j -i ${2} ${1} >> "${FH_LOG}" 2>&1 \
			&& RC=0 || RC=1
	fi
	return $RC
} # make_ext4

make_jfs() {
	# do the format
	RC=1
	mkfs.jfs -q ${1} >> "${FH_LOG}" 2>&1 \
		&& RC=0 || RC=1
	return $RC
} # make_jfs

make_reiserfs() {
	RC=1
	# do the format
	mkreiserfs -ff -h r5 ${1} >> "${FH_LOG}" 2>&1 && RC=0 || RC=1
	return $RC
} # make_reiserfs

make_swap() {
	# Creating Swap partition(s)
	RC=1
	/sbin/mkswap ${1} >> "${FH_LOG}" 2>&1 && RC=0 || RC=1
	return $RC
} # make_swap 

# make_xfs( dev, nodes, check ) - Create a new xfs filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
make_xfs() {
	# do the format
	RC=1
	mkfs.xfs -f ${1} >> "${FH_LOG}" 2>&1 && RC=0 || RC=1
	return $RC
} # make_xfs
