#!/bin/sh
#
# /etc/rc.d/rc.S:  System initialization script.
#
# Mostly written by:  Patrick J. Volkerding, <volkerdi@slackware.com>
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin

mkdir /dev/pts
mkdir /dev/shm

# Try to mount /proc:
/bin/mount -v proc /proc -n -t proc 2> /dev/null

if [ -x /sbin/ldconfig ]; then
	/sbin/ldconfig >/dev/null
fi

# Mount sysfs next, if the kernel supports it:
if [ -d /sys ]; then
  if $(/bin/grep -w -q -e sysfs /proc/filesystems) ; then
    if $(/bin/grep -v -w -q -e sysfs /proc/mounts) ; then
      /bin/mount -v sysfs /sys -n -t sysfs
    fi
  fi
fi

# Initialize udev to manage /dev entries and hotplugging for 2.6.x kernels.
# You may turn off udev by making the /etc/rc.d/rc.udev file non-executable
# or giving the "nohotplug" option at boot, but in the 2.6.x+ kernels udev
# has taken over the job of hotplug (finding hardware and loading the kernel
# modules for it, as well as creating device nodes in /dev).  Realize that
# if you turn off udev that you will have to load all the kernel modules
# that you need yourself (possibly in /etc/rc.d/rc.modules, which does not
# promise to list all of them), and make any additional device nodes that you
# need in the /dev directory.  Even USB and IEEE1394 devices will need to have
# the modules loaded by hand if udev is not used with a 2.6 kernel.  So use it.  :-)
if $(/bin/grep -w -q -e sysfs /proc/mounts) && \
	$(/bin/grep -q -e tmpfs /proc/filesystems) ; then
  if $(/bin/grep -v -w -q -e nohotplug /proc/cmdline) ; then
    if [ -x /etc/rc.d/rc.udev ]; then
      /bin/sh /etc/rc.d/rc.udev start
    fi
  fi
fi

# Initialize the Logical Volume Manager.
# This won't start unless we find /etc/lvmtab (LVM1) or
# /etc/lvm/backup/ (LVM2).  This is created by /sbin/vgscan, so to
# use LVM you must run /sbin/vgscan yourself the first time (and
# create some VGs and LVs).
if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
  echo "Initializing LVM (Logical Volume Manager):"
  # Check for device-mapper support.
  if $(/bin/grep -v -w -q -e device-mapper /proc/devices) ; then
    # Try to load a device-mapper kernel module:
    /sbin/modprobe -q dm-mod
  fi
  # Scan for new volume groups:
  /sbin/vgscan --mknodes --ignorelockingfailure 2> /dev/null
  if [ $? = 0 ]; then
    # Make volume groups available to the kernel.
    # This should also make logical volumes available.
    /sbin/vgchange -ay --ignorelockingfailure
  fi
fi

# Enable swapping:
#/sbin/swapon -a 2> /dev/null

# Start FUSE, if requested:
if [ -x /etc/rc.d/rc.fuse ]; then
  sh /etc/rc.d/rc.fuse start
fi

# Note: commented out due to problems and RTC is missing
# Set the system time from the hardware clock using hwclock --hctosys.
#if [ -x /sbin/hwclock ]; then
#  # Check for a broken motherboard RTC clock (where ioports for rtc are
#  # unknown) to prevent hwclock causing a hang:
#	# Note: doesn't work with Busybox
#  if ! $(/bin/grep -q -w -e 'rtc' /proc/ioports) ; then
#    CLOCK_OPT="--directisa"
#  fi
#  if $(/bin/grep -w -q -e "^UTC" /etc/hardwareclock) ; then
#    echo "Setting system time from the hardware clock (UTC)."
#    /sbin/hwclock $CLOCK_OPT --utc --hctosys
#  else
#    echo "Setting system time from the hardware clock (localtime)."
#    /sbin/hwclock $CLOCK_OPT --localtime --hctosys
#  fi
#fi

# Test to see if the root partition is read-only, like it ought to be.
READWRITE=no
if $(touch /fsrwtestfile 2>/dev/null) ; then
  rm -f /fsrwtestfile
  READWRITE=yes
else
  echo "Testing root filesystem status:  read-only filesystem"
fi


# Any /etc/mtab that exists here is old, so we delete it to start over:
/bin/rm -f /etc/mtab*
# Remounting the / partition will initialize the new /etc/mtab:
/bin/mount -w -o remount /

# Read in the correct / filesystem complete with arguments so mount will
# show them correctly. This does not stop those arguments from functioning
# but does prevent a small bug with /etc/mtab.
/bin/grep -e ' / ' /proc/mounts | /bin/grep -v -e "^rootfs" > /etc/mtab

# Fix /etc/mtab to list sys and proc if they were not yet entered in
# /etc/mtab because / was still mounted read-only:
if [ -d /proc/sys ]; then
  /bin/mount -f proc /proc -t proc
fi
if [ -d /sys/bus ]; then
  /bin/mount -f sysfs /sys -t sysfs
fi

# Configure ISA Plug-and-Play devices:
if [ -r /etc/isapnp.conf ]; then
  if [ -x /sbin/isapnp ]; then
    /sbin/isapnp /etc/isapnp.conf
  fi
fi

# This loads any kernel modules that are needed.  These might be required to
# use your ethernet card, sound card, or other optional hardware.
# Priority is given first to a script named "rc.modules.local", then
# to "rc.modules-$FULL_KERNEL_VERSION", and finally to the plain "rc.modules".
# Note that if /etc/rc.d/rc.modules.local is found, then that will be the ONLY
# rc.modules script the machine will run, so make sure it has everything in
# it that you need.
if [ -x /etc/rc.d/rc.modules.local -a -r /proc/modules ]; then
  echo "Running /etc/rc.d/rc.modules.local:"
  /bin/sh /etc/rc.d/rc.modules.local
elif [ -x /etc/rc.d/rc.modules-$(uname -r) -a -r /proc/modules ]; then
  echo "Running /etc/rc.d/rc.modules-$(uname -r):"
  /etc/rc.d/rc.modules-$(uname -r)
elif [ -x /etc/rc.d/rc.modules -a -r /proc/modules -a -L /etc/rc.d/rc.modules ]; then
  echo "Running /etc/rc.d/rc.modules -> $(readlink /etc/rc.d/rc.modules):"
  /etc/rc.d/rc.modules
elif [ -x /etc/rc.d/rc.modules -a -r /proc/modules ]; then
  echo "Running /etc/rc.d/rc.modules:"
  /etc/rc.d/rc.modules
fi

# Configure runtime kernel parameters:
if [ -x /sbin/sysctl -a -r /etc/sysctl.conf ]; then
  /sbin/sysctl -e -p /etc/sysctl.conf
fi

# Check all the non-root filesystems:
if [ ! -r /etc/fastboot ]; then
  echo "Checking non-root filesystems:"
  /sbin/fsck $FORCEFSCK -C -R -A -a
fi

# Mount usbfs only if it is found in /etc/fstab:
if $(/bin/grep -w -q -e usbfs /proc/filesystems) ; then
  if $(/bin/grep -v -w -q -e usbfs /proc/mounts) ; then
    if $(/bin/grep -w -q -e usbfs /etc/fstab) ; then
      /bin/mount -v /proc/bus/usb
    fi
  fi
fi

# Mount non-root file systems in fstab, but not NFS or SMB 
# because TCP/IP is not yet configured, and not proc or sysfs
# because those have already been mounted.  Also check that
# devpts is not already mounted before attempting to mount
# it.  With a 2.6.x or newer kernel udev mounts devpts.
# We also need to wait a little bit to let USB and other
# hotplugged devices settle (sorry to slow down the boot):
echo "Mounting non-root local filesystems:"
sleep 3
if $(/bin/grep -w -q -e devpts /proc/mounts) ; then
  /bin/mount -a -v -t nonfs,nosmbfs,nocifs,noproc,nosysfs,nodevpts
else
  /bin/mount -a -v -t nonfs,nosmbfs,nocifs,noproc,nosysfs
fi

# Enable swapping again.  This is needed in case a swapfile is used,
# as it can't be enabled until the filesystem it resides on has been
# mounted read-write.
/sbin/swapon -a 2> /dev/null

# Clean up some temporary files:
#rm -f /var/run/* /var/run/*/* /var/run/*/*/* /etc/nologin \
#  /etc/dhcpc/*.pid /etc/forcefsck /etc/fastboot \
#  /var/state/saslauthd/saslauthd.pid \
#  /tmp/.Xauth* 1> /dev/null 2> /dev/null
#  ( cd /var/log/setup/tmp && rm -rf * )
#  ( cd /tmp && rm -rf kde-[a-zA-Z]* ksocket-[a-zA-Z]* hsperfdata_[a-zA-Z]* plugtmp* )

# Create /tmp/{.ICE-unix,.X11-unix} if they are not present:
if [ ! -e /tmp/.ICE-unix ]; then
  mkdir -p /tmp/.ICE-unix
  chmod 1777 /tmp/.ICE-unix
fi
if [ ! -e /tmp/.X11-unix ]; then
  mkdir -p /tmp/.X11-unix
  chmod 1777 /tmp/.X11-unix
fi

# Create a fresh utmp file:
#touch /var/run/utmp
#chown root:utmp /var/run/utmp
#chmod 664 /var/run/utmp

# Update the current kernel level in the /etc/motd (Message Of The Day) file,
# if the first line of that file begins with the word 'Linux'.
# You are free to modify the rest of the file as you see fit.

#if [ -x /bin/sed ]; then
#  /bin/sed -i "{1s/^Linux.*/$(/bin/uname -sr)\./}" /etc/motd
#fi

# If there are SystemV init scripts for this runlevel, run them.
if [ -x /etc/rc.d/rc.sysvinit ]; then
  /etc/rc.d/rc.sysvinit
fi

# Run serial port setup script:
# CAREFUL!  This can make some systems hang if the rc.serial script isn't
# set up correctly.  If this happens, you may have to edit the file from a
# boot disk, and/or set it as non-executable:
if [ -x /etc/rc.d/rc.serial ]; then
  sh /etc/rc.d/rc.serial start
fi

# Carry an entropy pool between reboots to improve randomness.
if [ -f /etc/random-seed ]; then
  echo "Using /etc/random-seed to initialize /dev/urandom."
  cat /etc/random-seed > /dev/urandom
fi
# Use the pool size from /proc, or 512 bytes:
if [ -r /proc/sys/kernel/random/poolsize ]; then
  dd if=/dev/urandom of=/etc/random-seed count=1 bs=$(cat /proc/sys/kernel/random/poolsize) 2> /dev/null
else
  dd if=/dev/urandom of=/etc/random-seed count=1 bs=512 2> /dev/null
fi
chmod 600 /etc/random-seed

