#
# functions for TkGUI.tck
#
# Slack-Kickstart-10.2
# Comments to: vonatar@slack-kickstart.org
#
# Last Revision 25/02/2006 vonatar
#

#-------------------------------------
# ENABLES/DISABLES INET STUFF
#-------------------------------------

proc InetOnOff {} {
#
# This function simply reads the value
# of DHCP; if is set to 'yes' it disables
# the IP address related entryes, else
# enables them.
#

	global DHCP

	if { $DHCP == "yes" } {
		set STATUS disabled
		set COLOR lightgray
	} else {
		set STATUS normal
		set COLOR lightblue
	}

	foreach control { .left.eip .left.cbnetmask .left.edefaultgw .left.edomain \
		.left.edns1 .left.edns2 } {
		$control configure -state $STATUS -background $COLOR
	}
}

#-------------------------------------
# PARTITIONIG INFO EXTRACTION
#-------------------------------------

proc SaveConfig {} {

	global HEADER
	global DEVICE
	global ETH
	global HOSTNAME
	global PASSWD
	global DOMAIN
	global DHCP
	global PACKAGE_SERVER
	global AUTOUPDATE
	global SECURE
	global KERNEL

	global INET
	global MASK
	global GW
	global NS1 NS2
	global NTPHOST

	global TIMEZONE
	global HWCLOCK
	global KEYMAP

	global EMAIL
	global TAG
	global DISTRO
	global AUTOSTART
	global SLAPTGET
	global USER

	set counter 0
#
# Disable Save Config button
#
	.conftest.bsaveconfig configure -state disable
############################	
# Opens fd for config file #	
############################
	set conffd [open "./config-files/$HOSTNAME.cfg" w]

	puts $conffd "$HEADER"

	foreach VALUE { DISTRO HOSTNAME ETH PACKAGE_SERVER TAG PASSWD KERNEL \
		AUTOUPDATE SECURE DHCP AUTOSTART } {
		puts $conffd "$VALUE=[set $VALUE]"
	}

	if { $SLAPTGET != "" } {
		puts $conffd "SLAPTGET=$SLAPTGET"
	}

	if { $EMAIL != "" } {
		puts $conffd "EMAIL=$EMAIL"
	}

	if { $NTPHOST != "" } {
		puts $conffd "NTPHOST=$NTPHOST"
	}

	if { $DHCP == "no" } {
		foreach VALUE { DOMAIN INET MASK GW NS1 } {
			puts $conffd "$VALUE=[set $VALUE]"
		}
		if { $NS2 != "" } {
			puts $conffd "NS2=$NS2"
		}
	}
#
# Converting partitions to 
# Kickstart.cfg format:
#
# DISK="DEVICE[/dev/hda]=[/boot],[ext2],[,50,83];[swap],[swap],[,128,82];\
# 	[extended],[none],[,0,5];[empty],[none],[,0,0];[/],[ext2],[,0,83];"
#

#
# - Adds a comment
# - Adds 'DISK="DEVICE[$DEVICE]
#
	puts $conffd "\n#\n# Partition scheme.\n#\n"
	puts -nonewline $conffd "DISK=\"DEVICE\[$DEVICE\]="
#
# While current partition is not null
#
	while {  [ .down.lista get $counter ] != "" } {
		#
		# - Splits DEVICE and PARTITION_INFO 
		# - Cleans PARTITION_INFO stripping '{' and '}'
		# - Puts the result into config file
		#
		scan [split [ .down.lista get $counter ] = ] "%s %s" foo partition_info

		regsub -all {\{|\}} $partition_info "" partition_info

		puts -nonewline $conffd $partition_info
		puts -nonewline $conffd ";"

		incr counter
	}
#
# Appends the double quotes at the end of line.
#
# DISK="DEVICE[/dev/hda]=[/boot],[ext2],[,50,83];[swap],[swap],[,128,82];\
#		[extended],[none],[,0,5];[empty],[none],[,0,0];[/],[ext2],[,0,83];" <---
#
	puts $conffd "\""

	puts $conffd "\n#\n# Timezone, Keymap & HWClock\n#\n"
	puts $conffd "KEYMAP=$KEYMAP"
	puts $conffd "HWCLOCK=$HWCLOCK"
	puts $conffd "TIMEZONE=$TIMEZONE\n\n## End of Kickstart.cfg ##"

	close $conffd
#
# Clears the Config Check test box,
# enables Quit button.
#
	.conftest.bquit configure -state normal
	.conftest.result delete 1.0 end
#
# Checks user id
#
	if {$USER != "root" } {
		set MESG "\n\nsu -c \"./scripts/MakeInitrd.sh config-files/$HOSTNAME.cfg\"\n\n\n\n"
	} else {
		set MESG "\n\n./scripts/MakeInitrd.sh config-files/$HOSTNAME.cfg\n\n"
	}
	.conftest.result insert end "Config file has been created in\n\n\
config-files/$HOSTNAME.cfg\n\nNow you can create root image with:$MESG\
Click on 'Close' to return to main window.\nClick on 'Quit' to quit TkGui."
	puts "\nYou can create root image with:\n$MESG"
}

#-------------------------------------
# PARTITIONS PARSER
#-------------------------------------

proc Parser {} {

	global DEVICE
	global PART_MOUNT
	global PART_FS
	global PART_SIZE
	global PART_TYPE
	global partition_number
	global EDITING
	global INDEX
	global DEV
	global ROOT_PART

	set counter 0
	.down.cbdevice configure -state disabled

	if {$PART_TYPE == "swap" } {
		set PART_MOUNT "swap"
		set PART_TYPE "82"
		set PART_FS "swap"
	}

	if {$PART_TYPE == "empty" } {
		set PART_MOUNT "empty"
		set PART_SIZE "0"
		set PART_FS "none"
		set PART_TYPE "0"
	}

	if {$PART_TYPE == "linux" } {
		set PART_TYPE 83
	}

	if {$PART_TYPE == "extended" } {
		set PART_MOUNT "extended"
		set PART_SIZE "0"
		set PART_FS "none"
		set PART_TYPE "5"
	}

	if {$PART_SIZE == "" } {
		set PART_SIZE "0"
	}
#
# Checks mountpoint value: if null -> Error.
#
	if { $PART_MOUNT == "" } { 
		ErrorPopup "Error adding partition: Mountpoint cannot be null!" 
		return
	}
#
# We need to check if the mountpoint of new/edited
# partition exists:
#
	while {  [ .down.lista get $counter ] != "" } {

		scan [split [ .down.lista get $counter ] = ] "%s %s" FOO partition_data

		regexp {\[(.+)\]\,\[(.+)\],} $partition_data FOO MNT

		if { $PART_MOUNT == $MNT && $PART_MOUNT != "swap" } { 
			ErrorPopup "Error: mountpoint $PART_MOUNT alredy exists!\n" 
			return
		}

		incr counter
	}
#
# If we're not in EDIT mode, simply adds the new
# partition at the end of the list.
#

	if { $EDITING != "True" } {
	#
	# If partition type is null -> linux (83)
	# If filesystem = null -> ext2
	#
		if { $PART_FS == "" } { set PART_FS ext2}
		if { $PART_TYPE == "" } { set PART_TYPE 83}

		if { $PART_MOUNT == "/" } { set ROOT_PART $PART_MOUNT }

		.down.lista insert end [lindex $DEVICE$partition_number=\[$PART_MOUNT\], \
			\[$PART_FS\],\[,$PART_SIZE,$PART_TYPE\] ]
		incr partition_number
	}
#
# If we are in EDIT mode, we must retrieve:
#
# $INDEX is the partition position in the list
# $DEVICE$INDEX is the device+partnumber (eg: /dev/hda3)
#
# Then, we're ready to insert the modified value in the
# original place.
#
	if { $EDITING == "True" } {
		if { $PART_MOUNT == "/" } { 
			set ROOT_PART $PART_MOUNT 
		}
		.down.lista insert $INDEX [lindex $DEV=\[$PART_MOUNT\],\[$PART_FS\], \
			\[,$PART_SIZE,$PART_TYPE\] ]
		set EDITING False
		.down.bpart-active configure -text { Add Partition }
		.down.bdelete-part configure -state normal
		.down.bclearpartitions configure -state normal
	}
#
# After a successful Add or Edit
# clears textboxes and enables:
#
# - Delete last partition 
# - Delete all partitions 
#
	set PART_MOUNT ""
	set PART_SIZE ""
	set PART_FS ""
	set PART_TYPE ""

	.down.bdelete-part configure -state normal
	.down.bclearpartitions configure -state normal
}

#----------------------------------
# PARTITION EDITING
#----------------------------------

proc Edit {} {
# 
# This function starts the partition
# editing process: retrieves the partition
# to be edited from the list box, saves index
# value, strips the arguments and puts them
# into entryes for editing process.
# 

	.down.bedit-part configure -state disabled
	.down.bdelete-part configure -state disabled
	.down.bclearpartitions configure -state disabled

	global EDITING
	global PART_MOUNT
	global PART_FS
	global PART_SIZE
	global PART_TYPE
	global INDEX
	global DEV

	set EDITING True

	.down.bpart-active configure -text { Update Partition }

	set SELECTED [ .down.lista get active ]

	set INDEX [ .down.lista curselection ]

	.down.lista delete active

	scan [split $SELECTED = ] "%s %s" DEV partition_data

	regsub -all {\[|\]|\{|\}|\[,} $partition_data "" partition_data

	scan [ split $partition_data , ] "%s %s %s %s" PART_MOUNT PART_FS \
		PART_SIZE PART_TYPE

}

#--------------------------------------
# Load Config File
#--------------------------------------

proc LoadConfigFile {FILENAME} {

	global CONFIGFILE
	global partition_number

	global HEADER
	global DEVICE
	global ETH
	global HOSTNAME
	global PASSWD
	global DOMAIN
	global DHCP
	global PACKAGE_SERVER
	global AUTOUPDATE
	global AUTOSTART
	global SECURE
	global KERNEL

	global INET
	global MASK
	global GW
	global NS1 NS2
	global NTPHOST

	global TIMEZONE
	global KEYMAP
	global HWCLOCK

	global EMAIL 
	global TAG
	global DISTRO
	global ROOT_PART
#
# This function loads a config file into GUI,
# converting Kickstart.cfg format to TkGui.
#
	ClearPartList ALL

	set xfd [open "config-files/$CONFIGFILE" r]

	while {[gets $xfd line] > -1} {
		if { [ regexp {^#|^$} $line ] != 1 } {
			if { [ regexp {^DISK} $line ] != 1 } {
				scan [split $line = ] "%s %s" VAR VALUE
				set $VAR "$VALUE"
			} else {
				#
				# we need to catch DEVICE
				# and PARTITIONS list	
				# 
				regexp {"DEVICE\[(/dev/.+)\]\=(.+)"} $line FOO DEVICE PARTITIONS
			}
		}
	}
# 
# If DHCP is set to no, we must
# enable inet textbox
#
	InetOnOff
# Parsing PARTITIONS info 
# 
# Sample:
#
# [/boot],[ext2],[,500,83];[/],[ext2],[,,83];
#
	regsub -all {\;} $PARTITIONS " " PARTITIONS

	set LIMIT [ llength $PARTITIONS ]

	for {set counter 0} {$counter<$LIMIT} {incr counter} {
		set line [ lrange $PARTITIONS $counter $counter ]
		regexp {\[(.+)\]\,\[(.+)\]\,\[\,(.+)\,(.+)\]} $line FOO MNT TYP SIZ ID
		set COUNTERZ [ expr $counter +1 ]
		.down.lista insert end [lindex $DEVICE$COUNTERZ=\[$MNT\],\[$TYP\],\[,$SIZ,$ID\] ]
	}
	set partition_number [ incr COUNTERZ ]
	.down.cbdevice configure -state disabled
	.down.bdelete-part configure -state normal
	.down.bclearpartitions configure -state normal
}

#################
# ClearPartList	#
#################

proc ClearPartList {COMMAND} {

	global partition_number

	if { $COMMAND == "ALL" } { 
		.down.lista delete 0 end
	} else {
		.down.lista delete end
	}
	set partition_number [ .down.lista size ]	
	incr partition_number

	if { $partition_number == 1 } {
#
# No more partitions!
# We need to:
#
# - Enable device combobox
# - Disable Edit partition button
# - Disable Delete Last partition button
# - Disable Clear partitions button
# - Disable Test & Save button
#
		.down.cbdevice configure -state normal
		.down.bedit-part configure -state disabled
		.down.bdelete-part configure -state disabled
		.down.bclearpartitions configure -state disabled
	}
}

#################
# LoadComboCfg	#
#################
#
# Loads .cfg files names found in $PATH
# into $COMBOBOX
#

proc LoadComboCfg {COMBOBOX PATH} {
	
	set u 0
	# Clear combo
	$COMBOBOX list delete 0 end
	# Loads values into comboboxs
	# 
	# Regexp added to match *-tag or *.cfg and avoid
	# to load 'CVS' into combobox
	# vonatar[04/06/03]
	foreach u [ exec ls $PATH ] { 
			if { [ regexp {\-tag|\.cfg} $u ]} { 
				$COMBOBOX list insert end  $u 
			} 
	}
	# Selects the 1st value
	$COMBOBOX select 0
}

################
# LoadComboTxt #
################
#
# Loads text file $FILE 
# into $COMBOBOX
#

proc LoadComboTxt {COMBOBOX FILE} {
	set xfd [open "$FILE" r]
	while {[gets $xfd line] > -1}   {
		if { [ regexp {^[[:alnum:]]} $line ] == 1 } {
			$COMBOBOX list insert end $line
		}
	}
}

#-------------------------------------
# Test Config File
#-------------------------------------

proc TestConfig {} {

	global DISTRO
	global ETH
	global ROOT_PART
	global HOSTNAME
	global PASSWD
	global DOMAIN
	global DHCP
	global PACKAGE_SERVER
	global KERNEL

	global INET
	global MASK
	global GW
	global NS1 NS2
	global NTPHOST
	global TAG

	set error 0
	set counter 0

	toplevel .conftest
	wm geometry .conftest 590x290+275+240
	wm minsize .conftest 590 290
	wm maxsize .conftest 590 290
	wm resizable .conftest 1 1
	wm title .conftest  "- $DISTRO Config test for $HOSTNAME.$DOMAIN "

	text .conftest.result -width 193 -height 19 -background black \
		-foreground green -font fixed
	button .conftest.bsaveconfig -width 20 -text {Save Config File} \
		-state disabled -command SaveConfig
	button .conftest.bexit -width 20 -text {Close} -command { destroy .conftest }
	button .conftest.bquit -width 20 -text {Quit} -state disabled -command { exit }

	place .conftest.result -x 0 -y 0
	place .conftest.bsaveconfig -x 60 -y 255
	place .conftest.bexit -x 230 -y 255
	place .conftest.bquit -x 400 -y 255

#
# Checks partitions
# searching for ROOT_PART
#

	while {  [ .down.lista get $counter ] != "" } {
		scan [split [ .down.lista get $counter ] = ] "%s %s" FOO partition_data
		regexp {\[(.+)\]\,\[(.+)\],} $partition_data FOO mountpoint
		if { $mountpoint == "/" } { set ROOT_PART $mountpoint }
		incr counter
	}

#
# Checks if $KERNEL is in
# kernel directory
#
	set Kernel [ catch { exec file $KERNEL | \
		awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" } ]

	if { $Kernel != 0 } {
		.conftest.result insert end "Tested: KERNEL $KERNEL Not found!! \[FAILED\]\n"
		set error 1
	}
#
# if DHCP option is not set, we
# must check STATIC IP address
# configuration too.
#
	if { $DHCP == "yes" } {
		set PAR "HOSTNAME ETH PASSWD PACKAGE_SERVER KERNEL ROOT_PART"
	} else {
		set PAR "HOSTNAME ETH PASSWD PACKAGE_SERVER KERNEL ROOT_PART INET MASK GW DOMAIN NS1"
	}
#
# Checks for config values and adds
# the result to .conftest.result
#
	foreach VALUE $PAR {
		if { [set $VALUE] == "" } {
			.conftest.result insert end "Tested: $VALUE [set $VALUE] cannot not be null! \[FAILED\]\n"
			set error 1
		} else {
			.conftest.result insert end "Tested: $VALUE [set $VALUE] \[OK\]\n"
		}
	}
#
# Builds the final message and if config file
# is OK, enables 'Save Config' button.
#
	if { $error == 1 } {
		.conftest.result insert end "\nConfig file cannot be saved!\nPlease check your configuration."
		if { $Kernel != 0 } {
			.conftest.result insert end "\n\nHINT: dowload/copy the choosen kernel in 'kernel' subdir."
		}
	} else {
		.conftest.bsaveconfig configure -state normal   
		.conftest.result insert end "\nConfig file is OK! Now you can save it and create your installation root image. "
	}
}

#-------------------------------------
# Error Popup
#-------------------------------------

proc ErrorPopup {ERROR} {

	toplevel .error
	wm geometry .error 380x132+275+240
	wm minsize .error 380 132
	wm maxsize .error 380 132
	wm resizable .error 1 1
	wm title .error  "Error "

	text .error.message -width 62 -height 7 -background black -foreground green -font fixed
	button .error.bexit -width 20 -text {OK} -command { destroy .error }

	place .error.message -x 0 -y 0
	place .error.bexit -x 100 -y 100

	.error.message insert end $ERROR
}

#-----------------------------------------
# SaveRepository
#-----------------------------------------
#
# Saves the content of EditCombo popup
# into repository (Kernel or Packages)
# configuration file.
#

proc SaveRepository {COMBO FILE} {

	set xfd [open "$FILE" w]

	puts $xfd [ .editcombo.content get 1.0 end ]

	close $xfd
	
	$COMBO list delete 0 end
	LoadComboTxt $COMBO $FILE

	destroy .editcombo
}

#-----------------------------------------
# Edit
#-----------------------------------------
#
# Pops up a new window and loads the
# content of Kernel/Package repository
# to be edited.
#

proc EditCombo {COMBO FILE} {

	global DISTRO HOSTNAME DOMAIN

	toplevel .editcombo
	wm geometry .editcombo 590x290+275+240
	wm minsize .editcombo 590 290
	wm maxsize .editcombo 590 290
	wm resizable .editcombo 1 1
	wm title .editcombo  "- $DISTRO Repository Editor"

	text .editcombo.content -width 193 -height 19 -background white -font fixed
	button .editcombo.bsave -width 20 -text {Update } \
		-command "SaveRepository $COMBO $FILE"
	button .editcombo.bexit -width 20 -text {Cancel} -command { destroy .editcombo }

	place .editcombo.content -x 0 -y 0
	place .editcombo.bsave -x 120 -y 255
	place .editcombo.bexit -x 290 -y 255

	set xfd [open $FILE r]

	while {[gets $xfd line] > -1} {
		.editcombo.content insert end "$line\n"
	}
}

############## 
# LoadKernel #
##############
#
# Loads .cfg files names found in $PATH
# into $COMBOBOX
#
 
proc LoadKernel {COMBOBOX } {
 
	set KernelLIst [ catch { exec find kernels -type f | xargs file  | \
		awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" | wc -l } ]
	set u 0
	# Clear combo
	$COMBOBOX list delete 0 end
	# Loads values into comboboxes
	# 
	if { $KernelLIst == 0 } {
		foreach u [ exec find kernels -type f | xargs file  | \
			awk "{ if (/Linux/ && /kernel/ && /x86/) print \$1; }" | \
			cut -d ":" -f 1 ] \
        { $COMBOBOX list insert end  $u }
	} else {
		puts "\n#\n# Cannot find a kernel image in 'kernels' directory!\n#\
Please, upload at least an image.\n#"
		puts "# HINT: You can upload the entire 'kernels' directory \n# of\
Slackware-10.2 CD or any custom one! See README.\n#\n"
		exit 1
	} 
	# Selects the 1st value
	$COMBOBOX select 0
}

##### END of FUNCTIONS ######
