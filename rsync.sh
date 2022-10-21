#!/bin/sh

exit_err() {
	if [ $1 -ne 0 ]; then
		echo [] $2 1>&2
		exit $1
	fi
}

/tmp/rsync $@
exit_err $? "rsync error $?"

echo "[] rsync finished, running reconfiguration on target" 1>&2

echo -n "[] grub parts to reconfigure: " 1>&2
echo `dpkg --get-selections | grep grub | cut -f1` 1>&2

ROOTDISK=`fdisk -l | head -n 1 | cut -d' ' -f2 | cut -d':' -f1`
echo "[] root disk is $ROOTDISK" 1>&2

cat <<EOL | debconf-set-selections
grub-pc grub-pc/install_devices multiselect $ROOTDISK
grub-pc grub-pc/install_devices_disks_changed multiselect $ROOTDISK
EOL

echo `dpkg --get-selections | grep grub | cut -f1` | xargs dpkg-reconfigure -fnoninteractive
exit_err $? "dpkg-reconfigure error $?"

echo "[] update-grub..." 1>&2
update-grub
exit_err $? "update-grub error $?"

echo "[] update-initramfs..." 1>&2
rm /etc/initramfs-tools/conf.d/resume
update-initramfs -u
exit_err $? "update-initramfs error $?"

echo "[] reconfiguration finished, rebooting" 1>&2

(sleep 3 && reboot) &
