#!/bin/sh

. ./khimera.config

exit_err() {
	if [ $1 -ne 0 ]; then
		echo [] $2
		exit $1
	fi
}

usage() {
	echo Usage: $0 \<gc\|aws\> \<instance name\>
	exit 1
}

#generate template ssh key before calling install key tcl/expect script, because key pub part needs to be uploaded by hypervisor
if [ ! -e keys/$TMPL_KEY ]; then
	mkdir -p keys
	ssh-keygen -N "" -f keys/$TMPL_KEY -C $TMPL_USER >/dev/null 2>&1
	aws ec2 delete-key-pair --key-name "template-key"
	aws ec2 import-key-pair --key-name "template-key" --public-key-material fileb://keys/$TMPL_KEY.pub
	echo [] template ssh key generated
fi

TMPL_KEY_PUB=`cat keys/$TMPL_KEY.pub`

if [ "$2" = "" ]; then
	usage
else
INST_NAME=$2
fi

if [ "$1" = "gc" ]; then
	gcloud compute instances create $INST_NAME \
	--project=$G_PROJECT \
	--machine-type=e2-micro \
	--metadata=serial-port-enable=true,ssh-keys=$TMPL_USER:"$TMPL_KEY_PUB" \
	--tags=http-server,https-server \
	--create-disk=auto-delete=yes,boot=yes,device-name=$INST_NAME,image=projects/debian-cloud/global/images/debian-11-bullseye-v20220406,mode=rw,size=10,type=projects/$G_PROJECT/zones/$G_ZONE/diskTypes/pd-balanced
	exit_err $? "instance creation failed with error $?"

	echo `gcloud compute instances describe $INST_NAME | grep natIP | cut -d: -f2 | sed 's/ //g'` > $TMPL_IP_IDFILE

elif [ "$1" = "aws" ]; then
	#AMI for community debian 11
	AWS_AMI=ami-0f1793e689f222266
	aws ec2 run-instances --image-id $AWS_AMI --instance-type t3.micro --key-name "template-key" --tag-specifications ResourceType=instance,Tags=[{Key=Name,Value=$INST_NAME}] > $AWS_OUTPUT
	exit_err $? "instance creation failed with error $?"
	head -n 2 $AWS_OUTPUT  | tail -n 1 | cut -f 9 > $AWS_INST_IDFILE
	AWS_INST_ID=`cat $AWS_INST_IDFILE`
	while [ true ]; do
		sleep 3
		aws ec2 describe-instances --instance-ids $AWS_INST_ID > $AWS_OUTPUT
		S=`tail -n 1 $AWS_OUTPUT | rev | cut -f1 | rev`
		case "$S" in
		  pending)
		  ;;
		  *)
		  break
		esac
	done
	sleep 1
	aws ec2 describe-instances --filters Name=instance-id,Values=$AWS_INST_ID --query Reservations[].Instances[].PublicIpAddress > $TMPL_IP_IDFILE 2>&1
else
	usage
fi

cp keys/$TMPL_KEY keys/`cat $TMPL_IP_IDFILE`.key
cp keys/$TMPL_KEY.pub keys/`cat $TMPL_IP_IDFILE`.key.pub

echo [] instance $INST_NAME from template provisioned on $1
