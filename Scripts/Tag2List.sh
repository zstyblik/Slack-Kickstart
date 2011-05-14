#!/bin/bash
#
# Tag2List.sh
#
# Created: 25/02/2006
# Last Revision: -
#
# Converts tagfiles to taglist
#

LISTNAME=`basename $1`

echo "#" > Taglists/$LISTNAME

if [ $# -ne 1 ]; then
   echo -e "#\n# Converts Slackware tagfiles in taglist format:"
   echo -e "#\n# Usage: $0 Tagfiles/tag-file\n#"
   echo -e "# Example: to convert mini-tag Tagfile\n#"
   echo -e "# $0 Tagfiles/mini-tag \n#"
   
   exit 1
fi


for DISKSET in `ls $1/ | grep -v CVS`
do
   echo -e "#\n# Diskset $DISKSET\n#" >> Taglists/$LISTNAME
   for PACKAGE in  `cat $1/$DISKSET/tagfile | grep -v "#"`
   do
   	echo -e "$DISKSET/$PACKAGE" >> Taglists/$LISTNAME
   done 
done

echo -e "\nTaglist $LISTNAME has been created in Taglists/$LISTNAME\n"
