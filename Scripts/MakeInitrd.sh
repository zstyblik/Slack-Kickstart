#!/bin/bash
#
#################
# MakeInitrd.sh #
#################
#
# Slack-Kickstart 10.2
#
# Last Revision: 24/07/2006 vonatar
#
# comments to: vonatar@slack-kickstart.org
# http://www.slack-kickstart.org
#

#########
# MAIN	#
#########

IFS='
'

if [[ $# -ne 1 ]]; then
	echo
	echo "Usage: $0 Config-Files/HOSTNAME.cfg"
	echo
	exit 1
fi

if [[ (`whoami` != "root") ]]; then
	echo
	echo "You must exec $0 as root"
	echo
	exit 1
fi

if [[ !(-f template102.gz) ]]; then
	echo
	echo "Cannot find template image!"
	echo
	exit 1
fi

if [[ !(-f $1) ]]; then
	echo
	echo "Cannot find config file: '$1'"
	echo
	exit 1
fi

if [[ !(-d rootdisks) ]]; then

	mkdir rootdisks
fi

if [[ !(-d mount ) ]]; then

	mkdir mount
fi

if [[ !(`which openssl` ) ]]; then
        echo
        echo "Cannot find openssl binary!"
        echo "Please install openssl package."
        echo
        exit 1
fi


clear

HOST=`basename $1|sed s/.cfg//`

. Config-Files/$HOST.cfg

#
# Info needed for: 
#
# - Kernel name in rootdisks/$HOST.install
# - root password md5 hash
# - Install info
#

KNAME=`basename $KERNEL`
ENCRIPTED=`openssl passwd -1 $PASSWD`
INSTALL_TYPE=`echo $PACKAGE_SERVER | cut -d ":" -f 1`

#########################
# Copy from template	#
# and mount in loopback	#
#########################

echo "#########################"
echo "# Creating initrd image #"
echo "#########################"
echo
echo -n "Cloning template image    "

cp template102.gz $HOST.gz \
 && echo  -e "\t[ OK ]"

# Unpacking root image

echo -n "Unpacking initrd image     "

gunzip $HOST.gz \
 && echo -e "\t[ OK ]"

sleep 2

# Mounting root image in loopback on mount directory

echo -n "Mounting initrd image       "
mount -o loop $HOST mount > /dev/null 2>&1 \

if [ $? = 0 ];then

    echo -e "\t[ OK ]"

else
     rm $HOST
     echo  -e "\t[FAILED]"
     echo
     echo "Error mounting initrd image - Aborting!"
     echo
     exit 1
fi

#################
# Kickstart.cfg #
#################

#------------------------------------------
# Creates etc/Kickstart.cfg on root image
#------------------------------------------

cat Config-Files/$HOST.cfg |sed s@$PASSWD@\'$ENCRIPTED\'@ > mount/etc/Kickstart.cfg

#----------------------------------------------------------
# appends Taglist to Kickstart.cfg 
#
# The list of packages to be installed is 'escaped'
# with '#@' to avoid problems when including Kickstart.cfg
# on top of scripts.
#----------------------------------------------------------

echo -e "#\n# Taglist: $TAG\n#" >> mount/etc/Kickstart.cfg

for PACKAGE in `cat Taglists/$TAG | grep -v "#"`
do
    echo "#@$PACKAGE" >> mount/etc/Kickstart.cfg
done

echo -e "# END of Taglist: $TAG" >> mount/etc/Kickstart.cfg

#--------------------------------------
# Timezone setting
#--------------------------------------

cp /usr/share/zoneinfo/$TIMEZONE mount/etc/localtime

##########
# Kernel #
##########

cp $KERNEL mount/kernel/

#------------------------------------------
# Creates the root image
#------------------------------------------

echo -n "Umounting initrd image       "

umount mount \
  && echo -e "\t[ OK ]"

echo -n "Compressing initrd image     "
gzip $HOST \
 && echo -e "\t[ OK ]"

#
# Now we move the root image to
# rootdisks directory
#

mv $HOST.gz rootdisks

echo
echo "Root image for $HOST has been created!"
echo 

if [ $INSTALL_TYPE = "cdrom"  ];then

cat << EOP
#
# Create Install CD with:
# [ Expecting Slackware-10.2 CD-Rom in /mnt/cdrom ]
#

./Scripts/MakeIso.sh rootdisks/$HOST.gz $KERNEL /mnt/cdrom



EOP

else

echo "See rootdisks/Install.$HOST.txt for install info."
echo

cat << EOF > rootdisks/Install.$HOST.txt

------------- LILO INSTALL  -----------------------
#
# Add to old server's LILO Images section:
#

image = /boot/$KNAME
  root = /dev/ram0
  label = Kickstart
  initrd = /boot/$HOST.gz
  ramdisk = 49152
  append = "panic=5"

#
# Remember to upload initrd image and kernel into your 
# old server:
#

scp $KERNEL rootdisks/$HOST.gz root@your_old_server:/boot

------------------- Boot CD -----------------------------
#
# Create a Boot CD with:
#

./Scripts/MakeIso.sh rootdisks/$HOST.gz $KERNEL

------------------- PXE INFO ----------------------------
#
# Your PXE config file should be like:
#

default Kickstart
prompt 0
label Kickstart
 kernel $KNAME
 append initrd=$HOST.gz devfs=nomount load_ramdisk=1 prompt_ramdisk=0 ramdisk_size=16384 rw root=/dev/ram

# Remember to upload kernel and initrd image into
# your tftp server with something like:

scp $KERNEL rootdisks/$HOST.gz root@your_pxe_server:/tftpboot

-------------------------------------------------------------

EOF

#
# Changes ownership to
# info file
#

chown $USER:users rootdisks/Install.$HOST.txt

fi

#
# Changes ownership to
# initrd image
#

chown $USER:users rootdisks/$HOST.gz
