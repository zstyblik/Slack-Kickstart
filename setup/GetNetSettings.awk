#!/usr/bin/awk -f
# 2012/Dec/05 @ Zdenek Styblik
# Desc: parse Kickstart.cfg and extract network settings, print on STDOUT.
BEGIN { if (ARGC < 2) { exit 1 } }
{
	if ($0 !~ /^NETWORK="/) { next }
	sub("NETWORK=\"", "", $0);
	sub("\"", "", $0);
	split($0, arrRaw, ";");
	for (i in arrRaw) {
		iequal = index(arrRaw[i], "=")
		if (iequal == 0) { continue }
		key = substr(arrRaw[i], 0, iequal-1);
		value = substr(arrRaw[i], iequal+1);
		arrNet[key] = value;
	}
	if (! arrNet["DEVICE"]) { continue }
  inetiface = substr(arrNet["DEVICE"], length(arrNet["DEVICE"]));
	if (arrNet["PROTO"] == "dhcp") { 
		printf("%s,IFNAME%i=%s\n", arrNet["DEVICE"], inetiface, arrNet["DEVICE"]);
		printf("%s,DHCP%i=yes\n", arrNet["DEVICE"], inetiface);
		delete arrNet;
		delete arrRaw;
		next;
	}
	printf("%s,IFNAME%i=%s\n", arrNet["DEVICE"], inetiface, arrNet["DEVICE"]);
	printf("%s,INET%i=%s\n", arrNet["DEVICE"], inetiface, arrNet["IP"]);
	printf("%s,MASK%i=%s\n", arrNet["DEVICE"], inetiface, arrNet["MASK"]);
	if (arrNet["NAMESERVER"]) {
		icomma = index(arrNet["NAMESERVER"], ",");
		if (icomma == 0) {
			printf("NAMESERVER=%s\n", arrNet["NAMESERVER"]);
		} else {
			split(arrNet["NAMESERVER"], arrNs, ",");
			for (ns in arrNs) { printf("NAMESERVER=%s\n", arrNs[ns]) }
			delete arrNs;
		}
	}
	if (arrNet["GATEWAY"]) { printf("GW=%s\n", arrNet["GATEWAY"]); }
	delete arrNet;
	delete arrRaw;
}
