#!/bin/sh
# 2011/Sep/04 @ Zdenek Styblik
# Desc: sysctl post-install script
SYSCTLFILE="/etc/sysctl.conf"

printf "Post-install ~ '%s'\n" ${SYSCTLFILE}

cp ${SYSCTLFILE} ${SYSCTLFILE}.org 2>/dev/null
cat >> ${SYSCTLFILE}.new <<EOF
kernel.panic = 60
EOF

cat ${SYSCTLFILE}.new ${SYSCTLFILE}.org 2>/dev/null | sort | \
	uniq > ${SYSCTLFILE}

rm -f /etc/sysctl.new /etc/sysctl.org
# EOF
