#!/bin/sh
DEVNAME="$1"
COMMAND="$2"

testwrite() 
{
	RC=1
	if $(touch /var/run/checkrw 2>/dev/null) ; then
		rm -rf /var/run/checkrw 
		RC=0
	fi
	return $RC
}

case $DEVNAME in
	eth*|ath*|wlan*|ra*|sta*|ctc*|lcs*|hsi*)
		case $COMMAND in
			'start')

				if [ testwrite ]; then
					if ! $(/sbin/ip link show | /bin/grep -q -e "^${DEVNAME}: ") ; then
						/sbin/ip link set up dev "${DEVNAME}"
						/sbin/udhcpc -i "${DEVNAME}" -p "/var/run/udhcpc.${DEVNAME}.pid" \
							-s /etc/udhcpc/default.script -R -b
					fi
					exit 0
				else
					exit 1
				fi
				;;
			'stop')
				if $(/sbin/ip link show | /bin/grep -q -e "^${DEVNAME}: ") ; then
					if [ -e "/var/run/udhcpc.${DEVNAME}.pid" -o -r "/var/run/udhcpc.${DEVNAME}.pid" ]; then
						kill $(cat "/var/run/udhcpc.${DEVNAME}.pid")
						/sbin/ip link set down dev "${DEVNAME}"
					fi
				fi
				# If the interface is now down, exit with a status of 0:
				if $(/sbin/ip link show | /bin/grep -q -e "${DEVNAME}: " | \
					/bin/grep -q -e "${DEVNAME}") ; then
					exit 0
				fi
				;;
			*)
				echo "usage $0 interface start|stop"
				exit 1
				;;
		esac
	;;
	*)
		echo "Interface $DEVNAME not supported."
		exit 1
	;;
esac
exit 0
