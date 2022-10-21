#!/bin/sh

. ./khimera.config

SRC_IP=demo.khimera.cloud
SRC_USER=scythe
SRC_PASS=retek
SRC_ROOT=a

if [ "$1" = "gc" -o "$1" = "aws" ]; then
	TRGT=$1
else
	echo Usage: $0 \<gc\|aws\>
	exit 1
fi

SSHOPTS="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

exit_err() {
	if [ $1 -ne 0 ]; then
		echo [] $2
		exit $1
	fi
}

if [ ! -e rsync ]; then
	make rsync
fi

#Provision target instance from template first, generating and adding ssh key as needed, the sourrce will need the target key later

#target, rsync bin and shellscript with afterwards commands needed
./provision.sh $TRGT $TRGT-`date +%d%m%y`-`date +%H%M%S`
exit_err $? "target provisioning on $TRGT failed"
TRGT_IP=`cat $TMPL_IP_IDFILE`
#wait a few secs for ssh to start, try 3 times
I=0
while true; do
	I=$((I+1))
	sleep 3
	./install_key.sh $TMPL_USER $TRGT_IP
	if [ $? -eq 0 ]; then
		break
	fi
	if [ $I -eq 3 ]; then
		exit_err 1 "ssh key install to $TRGT_IP (template on $TRGT) failed"
	fi
done

scp $SSHOPTS -i keys/$TRGT_IP.key rsync rsync.sh root@$TRGT_IP:/tmp
exit_err $? "scp to $TRGT_IP failed"
echo [] cloning-process files to $TRGT_IP uploaded

#source, target key and rsync bin needed
./install_key.sh $SRC_USER $SRC_IP $SRC_PASS $SRC_ROOT
exit_err $? "ssh key install to $SRC_IP failed"
scp $SSHOPTS -i keys/$SRC_IP.key rsync keys/$TRGT_IP.key root@$SRC_IP:/tmp
exit_err $? "scp to $SRC_IP failed"
echo [] cloning-process files to $SRC_IP uploaded

echo [] starting cloning...

#ssh to source to start rsync and add key to ssh to target
#exclude fstab because of blkid
ssh $SSHOPTS -i keys/$SRC_IP.key root@$SRC_IP \
/tmp/rsync -aHXxzvh \
--numeric-ids --delete --delete-after --progress \
--exclude /etc/fstab \
--exclude /tmp \
--exclude /run \
--exclude /dev \
--exclude /sys \
--exclude /proc \
--rsync-path=/tmp/rsync.sh \
--rsh=\"ssh $SSHOPTS -i /tmp/$TRGT_IP.key -o Compression=yes -T -x\" \
/ root@$TRGT_IP:/

exit_err $? "rsync failed with code $?"

echo [] cloning finished, swapping ssh keys

cp keys/$SRC_IP.key keys/$TRGT_IP.key
cp keys/$SRC_IP.key.pub keys/$TRGT_IP.key.pub

echo [] done!
