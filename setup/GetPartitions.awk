#!/usr/bin/awk -f
# 2011/Dec/06 @ Zdenek Styblik
# Desc: Parse Kickstart.cfg and extract partition info, print on STDOUT.
BEGIN { if (ARGC < 2) { exit 1 } }
{
	if ($0 !~ /^DISK="/) { next }
	sub("DISK=\"", "", $0);
	sub("\"", "", $0);
	iequal = index($0, "=");
	if (iequal == 0) { next }
	device = substr($0, 0, iequal-1);
	ilbr = index(device, "[");
	if (ilbr == 0) { next }
	device = substr(device, ilbr+1, (length(device)-ilbr-1));
	partitions = substr($0, iequal+1);
	split(partitions, arrParts, ";");
	counterParts = 0;
	for (i in arrParts) {
		if (arrParts[i] == "") { continue }
		counterParts++;
		split(arrParts[i], arrPieces, /\]/);
		arrParts[i] = "";
		for (j in arrPieces) {
			if (arrPieces[j] == "") { continue }
			sub(/^,/, "", arrPieces[j]);
			sub(/,$/, "", arrPieces[j]);
			sub(/\[/, "", arrPieces[j]);
			sub(/\],/, "", arrPieces[j]);
			arrParts[i] = sprintf("%s:%s", arrParts[i], arrPieces[j]);
		} # for (j in arrPieces)
		if (arrParts[i] !~ /^:/) { arrParts[i] = sprintf(":%s", arrParts[i]) };
		printf("%s:%i%s\n", device, counterParts, arrParts[i]);
	} # for (i in arrParts)
}
