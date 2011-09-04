#!/bin/sh
# 2011/Sep/04 @ Zdenek Styblik
# Desc: SSH daemon post-install script.
SSHDCONF="/etc/ssh/sshd_config"

printf "Post-install ~ '%s'.\n" ${SSHDCONF}

if [ ! -e ${SSHDCONF} ]; then
	printf "* '%s' doesn't seem to exist.\n" ${SSHDCONF}
	exit 0
fi

sed -r \
	-e '/^[#]?PasswordAuthentication/c \PasswordAuthentication no' \
	-e '/^[#]?Protocol/c \Protocol 2' \
	-e '/^[#]?PubkeyAuthentication/c \PubkeyAuthentication yes' \
	${SSHDCONF} > ${SSHDCONF}.new

mv ${SSHDCONF}.new ${SSHDCONF}
# EOF
