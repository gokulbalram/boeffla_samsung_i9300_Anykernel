#!/system/bin/sh

# *****************************
# i9300 Cyanogenmod 12 NG version
#
# V0.2
# *****************************

# define basic kernel configuration
	# path to internal sd memory
	SD_PATH="/data/media/0"

	# block devices
	SYSTEM_DEVICE="/dev/block/mmcblk0p9"
	CACHE_DEVICE="/dev/block/mmcblk0p8"
	DATA_DEVICE="/dev/block/mmcblk0p12"

# define file paths
	BOEFFLA_DATA_PATH="$SD_PATH/boeffla-kernel-data"
	BOEFFLA_LOGFILE="$BOEFFLA_DATA_PATH/boeffla-kernel.log"
	BOEFFLA_STARTCONFIG="/data/.boeffla/startconfig"
	BOEFFLA_STARTCONFIG_DONE="/data/.boeffla/startconfig_done"
	CWM_RESET_ZIP="boeffla-config-reset-v4.zip"
	INITD_ENABLER="/data/.boeffla/enable-initd"
	BUSYBOX_ENABLER="/data/.boeffla/enable-busybox"
	FRANDOM_ENABLER="/data/.boeffla/enable-frandom"
	PERMISSIVE_ENABLER="/data/.boeffla/enable-permissive"
	
# If not yet existing, create a boeffla-kernel-data folder on sdcard 
# which is used for many purposes,
# always set permissions and owners correctly for pathes and files
	if [ ! -d "$BOEFFLA_DATA_PATH" ] ; then
		/sbin/busybox mkdir $BOEFFLA_DATA_PATH
	fi

	/sbin/busybox chmod 775 $SD_PATH
	/sbin/busybox chown 1023:1023 $SD_PATH

	/sbin/busybox chmod -R 775 $BOEFFLA_DATA_PATH
	/sbin/busybox chown -R 1023:1023 $BOEFFLA_DATA_PATH

# maintain log file history
	rm $BOEFFLA_LOGFILE.3
	mv $BOEFFLA_LOGFILE.2 $BOEFFLA_LOGFILE.3
	mv $BOEFFLA_LOGFILE.1 $BOEFFLA_LOGFILE.2
	mv $BOEFFLA_LOGFILE $BOEFFLA_LOGFILE.1

# Initialize the log file (chmod to make it readable also via /sdcard link)
	echo $(date) Boeffla-Kernel initialisation started > $BOEFFLA_LOGFILE
	/sbin/busybox chmod 666 $BOEFFLA_LOGFILE
	/sbin/busybox cat /proc/version >> $BOEFFLA_LOGFILE
	echo "=========================" >> $BOEFFLA_LOGFILE
	/sbin/busybox grep ro.build.version /system/build.prop >> $BOEFFLA_LOGFILE
	echo "=========================" >> $BOEFFLA_LOGFILE

# Correct /sbin and /res directory and file permissions
	mount -o remount,rw rootfs /

	# change permissions of /sbin folder and scripts in /res/bc
	/sbin/busybox chmod -R 755 /sbin
	/sbin/busybox chmod 755 /res/bc/*

	/sbin/busybox sync
	mount -o remount,ro rootfs /

# remove any obsolete Boeffla-Config V2 startconfig done file
	/sbin/busybox rm -f $BOEFFLA_STARTCONFIG_DONE

# remove not used configuration files for frandom and busybox
	/sbin/busybox rm -f $BUSYBOX_ENABLER
	/sbin/busybox rm -f $FRANDOM_ENABLER
	
# Apply Boeffla-Kernel default settings

	# Set AC charging rate default
	echo "1100" > /sys/kernel/charge_levels/charge_level_ac

	# Ext4 tweaks default to on
	/sbin/busybox sync
	mount -o remount,commit=20,noatime $CACHE_DEVICE /cache
	/sbin/busybox sync
	mount -o remount,commit=20,noatime $DATA_DEVICE /data
	/sbin/busybox sync

	# Sdcard buffer tweaks default to 256 kb
	echo 256 > /sys/block/mmcblk0/bdi/read_ahead_kb
	echo 256 > /sys/block/mmcblk1/bdi/read_ahead_kb

	echo $(date) Boeffla-Kernel default settings applied >> $BOEFFLA_LOGFILE

# init.d support (enabler only to be considered for CM based roms)
# (zipalign scripts will not be executed as only exception)
	if [ -f $INITD_ENABLER ] ; then
		echo $(date) Execute init.d scripts start >> $BOEFFLA_LOGFILE
		if cd /system/etc/init.d >/dev/null 2>&1 ; then
			for file in * ; do
				if ! cat "$file" >/dev/null 2>&1 ; then continue ; fi
				if [[ "$file" == *zipalign* ]]; then continue ; fi
				echo $(date) init.d file $file started >> $BOEFFLA_LOGFILE
				/system/bin/sh "$file"
				echo $(date) init.d file $file executed >> $BOEFFLA_LOGFILE
			done
		fi
		echo $(date) Finished executing init.d scripts >> $BOEFFLA_LOGFILE
	else
		echo $(date) init.d script handling by kernel disabled >> $BOEFFLA_LOGFILE
	fi

# Now wait for the rom to finish booting up
# (by checking for the android acore process)
	echo $(date) Checking for Rom boot trigger... >> $BOEFFLA_LOGFILE
	while ! /sbin/busybox pgrep com.android.systemui ; do
	  /sbin/busybox sleep 1
	done
	echo $(date) Rom boot trigger detected, waiting a few more seconds... >> $BOEFFLA_LOGFILE
	/sbin/busybox sleep 10

# Play sound for Boeffla-Sound compatibility
	echo $(date) Initialize sound system... >> $BOEFFLA_LOGFILE
	/sbin/tinyplay /res/misc/silence.wav -D 0 -d 0 -p 880

# Interaction with Boeffla-Config app V2
	# save original stock values for selected parameters
	cat /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table > /dev/bk_orig_cpu_voltage
	cat /sys/class/misc/gpu_clock_control/gpu_control > /dev/bk_orig_gpu_clock
	cat /sys/class/misc/gpu_voltage_control/gpu_control > /dev/bk_orig_gpu_voltage
	cat /sys/kernel/charge_levels/charge_level_ac > /dev/bk_orig_charge_level_ac
	cat /sys/kernel/charge_levels/charge_level_usb > /dev/bk_orig_charge_level_usb
	cat /sys/kernel/charge_levels/charge_level_wireless > /dev/bk_orig_charge_level_wireless
	cat /sys/module/lowmemorykiller/parameters/minfree > /dev/bk_orig_minfree
	/sbin/busybox lsmod > /dev/bk_orig_modules

	# if there is a startconfig placed by Boeffla-Config V2 app, execute it;
	if [ -f $BOEFFLA_STARTCONFIG ]; then
		echo $(date) "Startup configuration found:"  >> $BOEFFLA_LOGFILE
		cat $BOEFFLA_STARTCONFIG >> $BOEFFLA_LOGFILE
		. $BOEFFLA_STARTCONFIG
		echo $(date) Startup configuration applied  >> $BOEFFLA_LOGFILE
	else
		echo $(date) "No startup configuration found"  >> $BOEFFLA_LOGFILE
	fi
	
# Turn off debugging for certain modules
	echo 0 > /sys/module/ump/parameters/ump_debug_level
	echo 0 > /sys/module/mali/parameters/mali_debug_level
	echo 0 > /sys/module/kernel/parameters/initcall_debug
	echo 0 > /sys/module/lowmemorykiller/parameters/debug_level
	echo 0 > /sys/module/earlysuspend/parameters/debug_mask
	echo 0 > /sys/module/alarm/parameters/debug_mask
	echo 0 > /sys/module/alarm_dev/parameters/debug_mask
	echo 0 > /sys/module/binder/parameters/debug_mask
	echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask

# Auto root support
	if [ -f $SD_PATH/autoroot ]; then

		echo $(date) Auto root is enabled >> $BOEFFLA_LOGFILE

		mount -o remount,rw -t ext4 $SYSTEM_DEVICE /system

		/sbin/busybox mkdir /system/bin/.ext
		/sbin/busybox cp /res/misc/su /system/xbin/su
		/sbin/busybox cp /res/misc/su /system/xbin/daemonsu
		/sbin/busybox cp /res/misc/su /system/bin/.ext/.su
		/sbin/busybox cp /res/misc/install-recovery.sh /system/etc/install-recovery.sh
		/sbin/busybox echo /system/etc/.installed_su_daemon
		
		/sbin/busybox chown 0.0 /system/bin/.ext
		/sbin/busybox chmod 0777 /system/bin/.ext
		/sbin/busybox chown 0.0 /system/xbin/su
		/sbin/busybox chmod 6755 /system/xbin/su
		/sbin/busybox chown 0.0 /system/xbin/daemonsu
		/sbin/busybox chmod 6755 /system/xbin/daemonsu
		/sbin/busybox chown 0.0 /system/bin/.ext/.su
		/sbin/busybox chmod 6755 /system/bin/.ext/.su
		/sbin/busybox chown 0.0 /system/etc/install-recovery.sh
		/sbin/busybox chmod 0755 /system/etc/install-recovery.sh
		/sbin/busybox chown 0.0 /system/etc/.installed_su_daemon
		/sbin/busybox chmod 0644 /system/etc/.installed_su_daemon

		/system/bin/sh /system/etc/install-recovery.sh

		/sbin/busybox sync
		
		mount -o remount,ro -t ext4 $SYSTEM_DEVICE /system
		echo $(date) Auto root: su installed >> $BOEFFLA_LOGFILE

		rm $SD_PATH/autoroot
	fi

# EFS backup
	EFS_BACKUP_INT="$BOEFFLA_DATA_PATH/efs.tar.gz"
	EFS_BACKUP_EXT="/storage/extSdCard/efs.tar.gz"

	if [ ! -f $EFS_BACKUP_INT ]; then

		cd /efs
		/sbin/busybox tar cvz -f $EFS_BACKUP_INT .
		/sbin/busybox chmod 666 $EFS_BACKUP_INT

		/sbin/busybox cp $EFS_BACKUP_INT $EFS_BACKUP_EXT
		
		echo $(date) EFS Backup: Not found, now created one >> $BOEFFLA_LOGFILE
	fi

# Copy reset recovery zip in boeffla-kernel-data folder, delete older versions first
	CWM_RESET_ZIP_SOURCE="/res/misc/$CWM_RESET_ZIP"
	CWM_RESET_ZIP_TARGET="$BOEFFLA_DATA_PATH/$CWM_RESET_ZIP"

	if [ ! -f $CWM_RESET_ZIP_TARGET ]; then

		/sbin/busybox rm $BOEFFLA_DATA_PATH/boeffla-config-reset*
		/sbin/busybox cp $CWM_RESET_ZIP_SOURCE $CWM_RESET_ZIP_TARGET
		/sbin/busybox chmod 666 $CWM_RESET_ZIP_TARGET

		echo $(date) Recovery reset zip copied >> $BOEFFLA_LOGFILE
	fi

# TEMPORARY switch kernel to permissive mode by default when freshly installed
	if [ ! -f /data/.boeffla/installed_40a1 ]; then
		echo "autocreated" > /data/.boeffla/installed_40a1
		echo "autocreated" > $PERMISSIVE_ENABLER
		echo $(date) "First time installation detected, creating selinux permissive setting" >> $BOEFFLA_LOGFILE
	fi

# Remove SELinux enforce lock to allow SELinux mode changes from now on
	echo "0" > /sys/fs/selinux/bk_locked

# If not explicitely configured to permissive, set SELinux to enforcing
	if [ ! -f $PERMISSIVE_ENABLER ]; then
		echo "1" > /sys/fs/selinux/enforce
		echo $(date) "SELinux: enforcing" >> $BOEFFLA_LOGFILE
	else
		echo $(date) "SELinux: permissive" >> $BOEFFLA_LOGFILE
	fi
	
# Finished
	echo $(date) Boeffla-Kernel initialisation completed >> $BOEFFLA_LOGFILE
