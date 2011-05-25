#!/bin/bash
#
# Tag2List.sh
#
# Created: 25/02/2006
# Last Revision: -
#
# Converts tagfiles to taglist
#

help()
{
	printf "#\n# Converts Slackware tagfiles in taglist format:\n"
	printf "#\n# Usage: %s Tagfiles/tag-file\n#\n" ${0}
	printf "# Example: to convert mini-tag Tagfile\n"
	printf "# %s Tagfiles/mini-tag \n#\n" ${0}
	return 0
}

FILEIN=${1:-'None'}

if [ $# -ne 1 ]; then
	help
	exit 1
fi

if [ "${FILEIN}" = "None" ] || [ ! -f "${FILEIN}" ]; then
	printf "#\n# Tagfile either doesn't exist or is not set.\n"
	help
	exit 1
fi

LISTNAME=$(basename "${FILEIN}")

echo "#" > "taglists/${LISTNAME}"

for DISKSET in $(ls "${FILEIN}/" | grep -v -e 'CVS'); do
	printf "#\n# Diskset %s\n#" "${DISKSET}" >> "./taglists/${LISTNAME}"
	for PACKAGE in $(grep -v -e '^#' "${FILEIN}/${DISKSET}/tagfile"); do
		echo -e "${DISKSET}/${PACKAGE}" >> "./taglists/${LISTNAME}"
	done 
done

echo -e "\nTaglist '${LISTNAME}' has been created in './taglists/${LISTNAME}'\n"
