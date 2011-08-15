#!/bin/bash
# Desc: Converts tagfiles to taglist
# Copyright (C) 2006 Davide Zito
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 
# Tag2List.sh
#
help()
{
	printf "#\n# Converts Slackware tagfiles in taglist format:\n"
	printf "#\n# Usage: %s tagfiles/tag-file\n#\n" ${0}
	printf "# Example: to convert mini-tag Tagfile\n"
	printf "# %s tagfiles/mini-tag \n#\n" ${0}
	return 0
} # help()

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

printf "#\n" > "taglists/${LISTNAME}"

for DISKSET in $(ls "${FILEIN}/" | grep -v -e 'CVS'); do
	printf "#\n# Diskset %s\n#" "${DISKSET}" >> "./taglists/${LISTNAME}"
	for PACKAGE in $(grep -v -e '^#' "${FILEIN}/${DISKSET}/tagfile"); do
		printf "%s/%s\n" ${DISKSET} ${PACKAGE} >> "./taglists/${LISTNAME}"
	done 
done

printf "\nTaglist '%s' has been created in './taglists/%s'\n" \
	${LISTNAME} ${LISTNAME}
