#!/sbin/sh

######## BootMenu Script
######## Execute [Stable Recovery] Menu

source /system/bootmenu/script/_config.sh

export PATH=/sbin:/system/xbin:/system/bin

export LD_LIBRARY_PATH=.:/sbin

######## Main Script

PART_DATA=/dev/block/mmcblk1p26
PART_SYSTEM=/dev/block/mmcblk1p21

## /tmp folder can be a link to /data/tmp, bad thing !
[ -L /tmp ] && rm /tmp
mkdir -p /tmp
mkdir -p /res

rm -f /etc
mkdir /etc

# hijack mke2fs & tune2fs CWM3
rm -f /sbin/mke2fs
rm -f /sbin/tune2fs
rm -f /sbin/e2fsck

rm -f /sdcard
mkdir /sdcard

chmod 755 /sbin
chmod 755 /res

cp -r -f /system/bootmenu/recovery/res/* /res/
cp -p -f /system/bootmenu/recovery/sbin/* /sbin/

# recovery prebuilt
cp -f /sbin/recovery_stable /sbin/recovery

chmod +rx /sbin/*

rm -f /sbin/postrecoveryboot.sh

if [ ! -e /etc/recovery.fstab ]; then
    cp /system/bootmenu/recovery/recovery.fstab /etc/recovery.fstab
fi

# for ext3 format
cp /system/etc/mke2fs.conf /etc/

mkdir -p /cache/recovery
touch /cache/recovery/command
touch /cache/recovery/log
touch /cache/recovery/last_log
touch /tmp/recovery.log

killall -6 adbd

# mount fake image of pds, for backup purpose (4MB)
[ ! -d /data/data ] && mount -t ext3 -o rw,noatime,nodiratime,errors=continue $PART_DATA /data
if [ ! -f /data/pdsdata.img ]; then
    /system/bootmenu/script/pdsbackup.sh
    umount /pds
    losetup -d /dev/block/loop7
fi
cp /data/pdsdata.img /tmp/pdsdata.img
if [ -f /tmp/pdsdata.img ] ; then
    mkdir -p /pds
    umount /pds 2>/dev/null
    losetup -d /dev/block/loop7 2>/dev/null
    losetup /dev/block/loop7 /tmp/pdsdata.img
    busybox mount -o rw,nosuid,nodev,noatime,nodiratime,barrier=1 /dev/block/loop7 /pds
fi

ps | grep -v grep | grep adbd
ret=$?

if [ ! $ret -eq 0 ]; then
   # chmod 755 /system/bootmenu/script/adbd.sh
   # /system/bootmenu/script/adbd.sh

   # don't use adbd here, will load many android process which locks /system
   killall -6 adbd
fi

#############################
# mount in /sbin/postrecoveryboot.sh
umount /system

usleep 50000
mount -t ext3 -o rw,noatime,nodiratime $PART_SYSTEM /system

# retry without type & options if not mounted
[ ! -f /system/build.prop ] && mount -o rw $PART_SYSTEM /system

# set red led if problem with system
echo 0 > /sys/class/leds/red/brightness
echo 0 > /sys/class/leds/green/brightness
echo 0 > /sys/class/leds/blue/brightness
[ ! -f /system/build.prop ] && echo 1 > /sys/class/leds/red/brightness

#############################

# turn on button backlight (back button is used in CWM Recovery 3.x)
# echo 1 > /sys/class/leds/button-backlight/brightness

# to allow "eat"
ln -s /sdcard /mnt/sdcard
cd /sbin && ln -s adbd adbd.root

/sbin/recovery

# Post Recovery (back to bootmenu)

# bootmenu support buttons too
# echo 0 > /sys/class/leds/button-backlight/brightness

# remount system & data if unmounted
[ ! -d /data/data ] &&         mount -t ext3 -o rw,noatime,nodiratime,errors=continue $PART_DATA /data
[ ! -f /system/build.prop ] && mount -t ext3 -o rw,noatime,nodiratime,errors=continue $PART_SYSTEM /system

if [ -f /system/build.prop ] ; then
	echo 0 > /sys/class/leds/red/brightness
	echo 0 > /sys/class/leds/green/brightness
	echo 1 > /sys/class/leds/blue/brightness
else
	echo 1 > /sys/class/leds/red/brightness
	echo 0 > /sys/class/leds/green/brightness
	echo 0 > /sys/class/leds/blue/brightness
fi


exit
