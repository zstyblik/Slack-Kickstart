#!/usr/bin/awk -f
# 2011/Dec/12 @ Zdenek Styblik
# Desc: parse given file for BOOTLOADER settings and print on STDOUT.
BEGIN { if (ARGC < 2) { exit 1 } }
{
	if ($0 !~ /^BOOTLOADER=/) { next }
	sub("BOOTLOADER=\"", "", $0);
	sub(/"$/, "", $0);
	split($0, arrParts, /;/);
	for (i in arrParts) {
		if (arrParts[i] == "") { continue }
		printf("%s\n", arrParts[i]);
	}
}
