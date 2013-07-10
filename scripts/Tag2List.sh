#!/bin/sh
# Desc: Converts tagfiles to taglist
#
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
set -e
set -u
print_help()
{
	printf "Convert Slackware's tag file into tag list.\n" 1>&2
	printf "Usage: %% %s <tag_directory>;\n" $(basename -- "${0}") 1>&2
	printf "Example: %% %s tagfiles/mini-tag > taglists/mini-list;\n" 1>&2
	return 0
} # print_help()

FILEIN=${1:-'None'}

if [ $# -ne 1 ]; then
	printf "Error: Not enough parameters given.\n\n" 1>&2
	print_help
	exit 1
fi
if [ "${FILEIN}" = "None" ] || [ ! -d "${FILEIN}" ]; then
	printf "Error: Tagfile either doesn't exist or is not set.\n\n" 1>&2
	print_help
	exit 1
fi

for DISKSET in $(ls "${FILEIN}/" | grep -v -e 'CVS'); do
	printf "#\n# Diskset %s\n#\n" "${DISKSET}"
	IFS_OLD=$IFS
	IFS="###@@@###"
	for PACKAGE in $(grep -v -e '^#' "${FILEIN}/${DISKSET}/tagfile"); do
		printf -- "%s/%s\n" "${DISKSET}" "${PACKAGE}"
	done 
	IFS=$IFS_OLD
done
printf "Done with conversion of '%s'.\n" "${FILEIN}" 1>&2
