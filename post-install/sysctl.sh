#!/bin/sh
SYSCTLFILE="/etc/sysctl.conf"
printf "Post-install ~ '/etc/sysctl.conf'\n"
cp ${SYSCTLFILE} ${SYSCTLFILE}.org
cat >> ${SYSCTLFILE}.new <<EOF
kernel.panic = 60
EOF

cat ${SYSCTLFILE}.new ${SYSCTLFILE}.org | sort | uniq > ${SYSCTLFILE}
