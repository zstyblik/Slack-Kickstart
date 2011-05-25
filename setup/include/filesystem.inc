# /usr/lib/setup/include/filesystem.inc
#
# Slack-Kickstart 10.2
#
# Last revision: 19/09/2005 vonatar
#
# This file contains some common functions
# and variable definitions.
#
# It is included at top level of each script in /usr/lib/setup
# I hope that with this trick, the scripts are a bit more readable.
#


#----------------------------- FS-RELATED FUNCTIONS ------------------------------------------#

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
	if [ "${3}" = "y" ]; then
		${MKEXT2} -c -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	else
		${MKEXT2} -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	fi
	return 0
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
	# do the format
	if [ "${3}" = "y" ]; then
		${MKEXT3} -c -j -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	else
		${MKEXT3} -j -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	fi
	return 0
} # make_ext3

# make_ext3( dev, nodes, check ) - Create a new ext3 filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext4() {
	MKEXT4=mke2fs
	if [ "${3}" = "y" ]; then
		${MKEXT4} -c -t ext4 -j -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	else
		${MKEXT4} -t ext4 -j -i ${2} ${1} > ${REDIR} 2>&1 && echo "[OK]"
	fi
	return 0
} # make_ext4

make_jfs() {

	# do the format
	mkfs.jfs -q ${1} >$REDIR 2>&1 && echo "[OK]" && echo "[OK]"
	return 0
} # make_jfs

make_reiserfs() {

	# do the format
	mkreiserfs -ff -h r5 ${1} >$REDIR 2>&1 && echo "[OK]" && echo "[OK]"
	return 0
} # make_reiserfs

make_swap() {

	# Creating Swap partition(s)
	/sbin/mkswap -c ${1} >$REDIR 2>&1 && echo "[OK]"
	return 0
} # make_swap 

# make_xfs( dev, nodes, check ) - Create a new xfs filesystem on the named
#                                device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
make_xfs() {

	# do the format
	mkfs.xfs -f ${1} >$REDIR 2>&1 && echo "[OK]" && echo "[OK]"
	return 0
} # make_xfs
#-------------------- END OF FUNCTIONS ---------------------------#
