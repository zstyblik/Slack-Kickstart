#!/bin/sh
SYSCTLFILE="/etc/sysctl.conf"
printf "Post-install ~ '/etc/sysctl.conf'\n"
cp ${SYSCTLFILE} ${SYSCTLFILE}.org 2>/dev/null
cat >> ${SYSCTLFILE}.new <<EOF
kernel.panic = 60
EOF

cat ${SYSCTLFILE}.new ${SYSCTLFILE}.org 2>/dev/null | sort | \
	uniq > ${SYSCTLFILE}
