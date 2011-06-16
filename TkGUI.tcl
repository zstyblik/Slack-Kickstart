#!/usr/bin/wish
# Desc: TkGui ~ GUI interface for Slack-Kickstart
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
# Extract TZs: 
# awk '{ if (/^#/) { next; } print $3 }' \
# /usr/share/zoneinfo/zone.tab | sort | less
set DISTRO "Slackware-10.2"

wm geometry . 590x570+150+80
wm minsize . 590 570
wm maxsize . 590 570
wm resizable . 1 1
wm title . "- Slack-Kickstart $DISTRO configuration GUI -"

. configure -background yellow

#----------------------------------
# DEFAULT VALUES
#----------------------------------

set DEVICE "/dev/hda"
set ETH eth0
set ROOT_PART ""
set TIMEZONE "Europe/Rome"
set HWCLOCK "localtime"
set KEYMAP "qwerty/it.map"
set DHCP yes
set AUTOSTART no
set AUTOUPDATE none
set SECURE yes

set DATA [exec date]
set HHOST [exec hostname]
set USER [exec whoami]
set HEADER "#\n#\n# Slack-Kickstart $DISTRO config file\n# Created by TkGUI.tcl \n# On $DATA\n# By $USER@$HHOST\n#\n"
set SLAPTGET "http://software.jaos.org/slackpacks/10.2/slapt-get-0.9.11a-i386-1.tgz"

set EDITING False
set partition_number 1

#
# We need to include combobox.tcl
# by Bryan Oakley
# oakley@bardo.clearlight.com
#
# Thank you Bryan!!
#

source includes/combobox.tcl
package require combobox 2.2
catch {namespace import combobox::*}

#
# Other Functions in a separate file.
#

source includes/functions.tcl
catch {namespace import includes::*}

#-----------------------------------
# LOGO
#-----------------------------------

image create photo header -file "includes/logo.gif"
label .header -image header
place .header -x 0 -y 0

#----------------------------------
# LEFT FRAME
#----------------------------------

frame .left -bd 1 -borderwidth 2 -height 365 -relief groove -width 248

label .left.lhostname -text {Hostname:    }
entry .left.ehostname -width 25 -textvariable HOSTNAME -background lightblue 
	
label .left.linterface -text {Interface:}
combobox .left.cbinterface \
	-width 4 \
	-editable false \
	-textvariable ETH -background lightblue \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

.left.cbinterface list insert end "eth0" \
	"eth1" \
	"eth2" \
	"eth3"

label .left.lrootpw -text {Root password: }
entry .left.erootpw -width 12 -textvariable PASSWD -background lightblue

label .left.lntphost -text {ntp server:}
combobox .left.cbntphost \
	-editable false \
	-width 17 \
	-textvariable NTPHOST \
	-background lightblue

LoadComboTxt .left.cbntphost includes/ntpservers.txt


radiobutton .left.dhcp -variable DHCP -value yes -command InetOnOff  -text {DHCP}
radiobutton .left.stat -variable DHCP -value no  -command InetOnOff -text {Static IP}

label .left.lip -width 10 -text { IP Address: }
entry .left.eip -textvariable INET -width 16 -background lightblue

label .left.lnetmask -text {Netmask: }
combobox .left.cbnetmask \
	-font fixed \
 	-editable false \
	-textvariable MASK \
	-highlightthickness 1 \
	-width 15 \
	-background white \
	-selectforeground black \
	-background lightblue

LoadComboTxt .left.cbnetmask includes/netmasks.txt

label .left.ldefaultgw -text {Default gateway:}
entry .left.edefaultgw -width 16 -textvariable GW -background lightblue

label .left.ldomain -text {Domain: }
entry .left.edomain -width 16 -textvariable DOMAIN -background lightblue

label .left.ldns1 -text {Dns1:}
entry .left.edns1 -width 16 -textvariable NS1 -background lightblue

label .left.ldns2 -text {Dns2:}
entry .left.edns2 -width 16 -textvariable NS2 -background lightblue

#########################
# LEFT FRAME PLACING	#
#########################

place .left.lhostname -x 0 -y 0 -anchor nw
place .left.ehostname -x 0 -y 20 -anchor nw
	
place .left.linterface -x 180 -y 0 -anchor nw
place .left.cbinterface -x 185 -y 20 -anchor nw

place .left.lrootpw -x 0 -y 50 -anchor nw
place .left.erootpw -x 0 -y 70 -anchor nw

place .left.lntphost -x 170 -y 50 -anchor nw
place .left.cbntphost -x 95 -y 70 -anchor nw

place .left.dhcp -x 0 -y 95 -anchor nw
place .left.stat -x 70 -y 95 -anchor nw

place .left.lip -x 0 -y 145 -anchor nw
place .left.eip -x 0 -y 165 -anchor nw

place .left.lnetmask -x 120 -y 145 -anchor nw
place .left.cbnetmask -x 120 -y 165 -anchor nw

place .left.ldefaultgw -x 0 -y 195 -anchor nw
place .left.edefaultgw -x 0 -y 215 -anchor nw

place .left.ldomain -x 120 -y 195 -anchor nw
place .left.edomain -x 120 -y 215 -anchor nw

place .left.ldns1 -x 0 -y 245 -anchor nw
place .left.edns1 -x 0 -y 265 -anchor nw

place .left.ldns2 -x 120 -y 245 -anchor nw
place .left.edns2 -x 120 -y 265 -anchor nw

place .left -x 0 -y 36 -width 248 -height 300 -anchor nw -bordermode ignore	

InetOnOff

#----------------------------------
# RIGHT FRAME
#----------------------------------

frame .right -bd 1 -borderwidth 2 -height 385 -relief groove -width 340
		
label .right.lpackage_server -text {Package repository:}
combobox .right.cbpackage_server \
	-editable false \
	-width 44 \
	-textvariable PACKAGE_SERVER \
	-background lightblue

LoadComboTxt .right.cbpackage_server includes/package_servers.txt

bind .right.cbpackage_server <Button-3> { 
	EditCombo .right.cbpackage_server includes/package_servers.txt 
}

label .right.lkrepository -text {Kernel:}
combobox .right.cbkrepository \
	-editable false \
	-width 44 \
	-textvariable KERNEL \
	-background lightblue

LoadKernel .right.cbkrepository

label .right.lautoupdate -text {Autoupdate:}
	
combobox .right.cbautoupdate \
	-editable false \
	-width 11 \
	-textvariable AUTOUPDATE \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

.right.cbautoupdate list insert end \
	"slackpkg" \
	"slapt-get" \
	"swaret" \
	"none"	

label .right.ltaglist -text {Taglist: }

combobox .right.cbtaglist \
	-editable false \
	-width 29 \
	-textvariable TAG \
	-background lightblue

LoadComboCfg .right.cbtaglist taglists
set TAG "mini-tag"

label .right.lsecure -text {Secure: }

combobox .right.cbsecure \
	-editable false \
	-width 10 \
	-textvariable SECURE \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

.right.cbsecure list insert end \
	"yes" \
	"no"

label .right.ltimezone -text {Timezone:}
combobox .right.cbtimezone \
	-editable false \
	-textvariable TIMEZONE \
	-highlightthickness 1 \
	-width 30 \
	-background white \
	-selectforeground black \
	-background lightblue

LoadComboTxt .right.cbtimezone includes/zone.txt

label .right.lkeymap -text {Keyboard map:}
combobox .right.cbkeymap \
	-state normal \
	-editable false \
	-width 26 \
	-textvariable KEYMAP \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

LoadComboTxt .right.cbkeymap includes/keymaps.txt

label .right.lhwclockzone -text {Hardware clock:}
combobox .right.cbhwclockzone \
	-state normal \
	-editable false \
	-width 14 \
	-textvariable HWCLOCK \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

.right.cbhwclockzone list insert end \
	"localtime" \
	"utc"

label .right.lemailaddress -text {Email address:}
entry .right.eemailaddress -textvariable EMAIL -background lightblue -width 36

label .right.lautostart -text {Autostart:}
combobox .right.cbautostart \
	-state normal \
	-editable false \
	-width 6 \
	-textvariable AUTOSTART \
	-highlightthickness 1 \
	-background white \
	-selectforeground black \
	-background lightblue

.right.cbautostart list insert end \
	"yes" \
	"no"

#########################
# RIGHT FRAME PLACING	#
#########################

place .right.lpackage_server -x 0 -y 0 -anchor nw
place .right.cbpackage_server -x 0 -y 20 -anchor nw

place .right.lkrepository -x 0 -y 45 -anchor nw
place .right.cbkrepository -x 0 -y 70 -anchor nw

place .right.lautoupdate -x 0 -y 95 -anchor nw
place .right.cbautoupdate -x 0 -y 115 -anchor nw

place .right.ltaglist -x 280 -y 95 -anchor nw
place .right.cbtaglist -x 104 -y 115 -anchor nw

place .right.lsecure -x 0 -y 145 -anchor nw
place .right.cbsecure -x 0 -y 165 -anchor nw

place .right.ltimezone -x 265 -y 145 -anchor nw
place .right.cbtimezone -x 98 -y 165 -anchor nw

place .right.lkeymap -x 0 -y 195 -anchor nw
place .right.cbkeymap -x 0 -y 215 -anchor nw

place .right.lhwclockzone -x 230 -y 195 -anchor nw
place .right.cbhwclockzone -x 210 -y 215 -anchor nw

place .right.lemailaddress -x 0 -y 245 -anchor nw
place .right.eemailaddress -x 0 -y 265 -anchor nw

place .right.lautostart -x 265 -y 245 -anchor nw 
place .right.cbautostart -x 265 -y 265 -anchor nw
	
place .right -x 250 -y 36 -width 340 -height 300 -anchor nw -bordermode ignore

#----------------------------------
# BOTTOM FRAME
#----------------------------------

frame .down -bd 1 -borderwidth 2 -height 120 -relief groove -width 300

label .down.lpartitions -text {Device	 	Part Type     Mount Point       FS        Size(Mb)  }	
	  
pack .down.lpartitions \
	-side top -anchor nw 

combobox .down.cbdevice \
	-editable false \
	-width 12 \
	-textvariable DEVICE \
	-selectforeground black \
	-background lightblue

.down.cbdevice list insert end 	"/dev/hda" \
	"/dev/hdb" \
	"/dev/hdc" \
	"/dev/hdd" \
	"/dev/sda" \
	"/dev/sdb" \
	"/dev/sdc" \
	"/dev/sdd" \
	"/dev/cciss/c0d0" \
	"/dev/ida/c0d0"	\
	"/dev/ataraid/d0" \
	"/dev/vda" \
	"/dev/vdb" \
	"/dev/vdc" \
	"/dev/vdd"

entry .down.epart-mount -textvariable PART_MOUNT -background white -width 10
entry .down.epart-fs -textvariable PART_FS -background white -width 5
combobox .down.cbpart-type \
	-editable false \
	-width 8 \
	-textvariable PART_TYPE \
	-selectforeground black \
	-background lightblue

.down.cbpart-type list insert end	 \
	linux \
	swap \
	extended \
	empty

combobox .down.cbpart-fs \
	-editable false \
	-width 6 \
	-textvariable PART_FS \
	-selectforeground black \
	-background lightblue

.down.cbpart-fs list insert end  \
	ext2 \
	ext3 \
	ext4 \
	jfs \
	reiserfs \
	xfs
	
entry .down.epart-size -textvariable PART_SIZE -background white -width 9

listbox .down.lista -width 44 -height 10 -foreground black \
	-background lightblue -font fixed -selectbackground "#00ccff" \
	-selectforeground black

#
# Edit Partition is enabled only when the user selects 
# an entry from partitions list.
#
bind .down.lista <Button-1> { 
	if { [%W get [%W nearest %y]] != "" && $EDITING != "True" } { 
		.down.bedit-part configure -state normal 
	}
}

button .down.bpart-active -width 15 \
	-text {Add partition    } -command { Parser }

button .down.bedit-part -width 15 -state disabled -text {Edit partition    } \
	-command Edit

button .down.bdelete-part -width 15 -state disabled \
	-text {Delete last partition} -command { ClearPartList LAST }

button .down.bclearpartitions -width 15 -state disabled \
	-text {Delete all Partitions} -command { ClearPartList ALL }

pack .down.cbdevice \
	.down.cbpart-type \
	.down.epart-mount \
	.down.cbpart-fs \
	.down.epart-size \
		-side left -anchor n

place .down.lista \
	-x 0 -y 130 -anchor w

place .down.bpart-active -x 277 -y 48
place .down.bedit-part -x 277 -y 78
place .down.bdelete-part -x 277 -y 108
place .down.bclearpartitions -x 277 -y 138

place .down -x 0 -y 338  -width 420 -height 230 -anchor nw -bordermode ignore

#-------------------------------------
# CONFIG BUTTONS FRAME
#-------------------------------------

frame .configcmd -bd 1 -borderwidth 2 -height 100 -relief groove -width 300

label .configcmd.lconfigfile -text {Config File:}

combobox .configcmd.cbconfigfile \
	-editable false \
	-textvariable CONFIGFILE \
	-background lightblue

LoadComboCfg .configcmd.cbconfigfile config-files

button .configcmd.bloadconfig -width 19 -text {Load Config File} \
	-command { LoadConfigFile $CONFIGFILE}
button .configcmd.save -width 19 -text {Test & Save} -command TestConfig
button .configcmd.exit -width 19 -text {Quit} -command exit		
label  .configcmd.lversion -font fixed -text $DISTRO

pack .configcmd.lconfigfile \
	.configcmd.cbconfigfile \
	.configcmd.bloadconfig \
	.configcmd.save \
	.configcmd.exit \
	-side top -anchor w

place .configcmd -x 420 -y 338 -width 260 -height 230 -anchor nw -bordermode ignore
