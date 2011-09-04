#!/bin/sh
# 2011/Sep/04 @ Zdenek Styblik
# Desc: modify /etc/inetd.conf and disable things which aren't needed.
# One small flaw is it doesn't cover case when new services are added.
INETDCONF="/etc/inetd.conf"

printf "Post-install ~ '%s'\n" ${INETDCONF}

if [ ! -e ${INETDCONF} ]; then
	printf "* '%s' doesn't seem to exist.\n" ${INETDCONF}
	exit 0
fi # if ! -e $INETDCONF

sed -r \
	-e 's/^time/# time/g' \
	-e 's/^auth/# auth/' \
	${INETDCONF} > ${INETDCONF}.new

mv ${INETDCONF}.new ${INETDCONF}
# EOF
