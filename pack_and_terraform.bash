#!/bin/bash
# Right now this script guides you through the process
# of running Packer & Terraform
unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
    export PATH=${PATH}:/usr/local/opt/gettext/bin
    if [[ ! -x "$(command -v envsubst)" ]]; then
	echo "need envsubst to run this script, please install gettext"
	exit 1
    fi
fi
if [ -z "$AWS_REGION" ]; then
        read -p "Enter your AWS region (default: us-east-1): " AWS_REGION
	[ -z "$AWS_REGION" ] && AWS_REGION="us-east-1"
fi
if [ -z "$AWS_ACCESS_KEY" ]; then
	read -p "Enter your AWS ACCESS key: " AWS_ACCESS_KEY
fi

if [ -z "$AWS_SECRET_KEY" ]; then
	read -p "Enter your AWS SECRET key: " AWS_SECRET_KEY
fi

if [ -z "$GITHUB" ]; then
	read -p "Enter your github username: " GITHUB
fi
SSHKEY=`curl -s https://github.com/$GITHUB.keys | tail -1`
echo "Got key for $GITHUB: $SSHKEY"

read -n 1 -p "Build packer images (y/n)? " BUILDPACKER
[ -z "$BUILDPACKER" ] && answer="No"
echo

if echo "$BUILDPACKER" | grep -iq "^y"; then

	# Get the info to create AMIs
	if [ ! -d "images" ]; then
		echo "Cloning AMI base configurations"
		git clone https://github.com/uc-cdis/images.git
	fi

	# Get packer to create AMIs
	if [ ! -f "packer" ]; then
		echo "Grabbing packer executable"
		curl -o packer.zip https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_darwin_amd64.zip
		unzip packer.zip
		rm packer.zip
	fi

	read -n 1 -p "Replace CDIS default authorized_keys (yes/append/no)? " REPLACEKEYS
	[ -z "$REPLACEKEYS" ] && answer="No"
	echo

	if echo "$REPLACEKEYS" | grep -iq "^y"; then
		echo $SSHKEY >images/configs/authorized_keys
	elif echo "$REPLACEKEYS" | grep -iq "^a"; then
		echo $SSHKEY >>images/configs/authorized_keys
	fi

	cp images/variables.example.json ../packer_variables.json
	sed -i '' -e "s/\"aws_region\": \"\"/\"aws_region\": \"$AWS_REGION\"/g" ../packer_variables.json
	sed -i '' -e "s/\"aws_access_key\": \"\"/\"aws_access_key\": \"$AWS_ACCESS_KEY\"/g" ../packer_variables.json
	sed -i '' -e "s/\"aws_secret_key\": \"\"/\"aws_secret_key\": \"$AWS_SECRET_KEY\"/g" ../packer_variables.json


	cd images
	echo "Building packer base image"
	SOURCE_AMI=`../packer build --var-file ../../packer_variables.json -machine-readable images/base_image.json | egrep 'artifact,0,id' | rev | cut -f1 -d, | rev | cut -d: -f 2`
	echo "Base ami is $SOURCE_AMI"
	sed -i '' -e "s/\"source_ami\": \"\"/\"source_ami\": \"$SOURCE_AMI\"/g" ../../packer_variables.json

	echo "Building packer client image"
	CLIENT_AMI=`../packer build --var-file ../../packer_variables.json -machine-readable images/client.json | egrep 'artifact,0,id' | rev | cut -f1 -d, | rev | cut -d: -f 2`
	echo "Client ami is $CLIENT_AMI"
	echo "Building packer squid image"
	PROXY_AMI=`../packer build --var-file ../../packer_variables.json -machine-readable images/squid_image.json | egrep 'artifact,0,id' | rev | cut -f1 -d, | rev | cut -d: -f 2`
	echo "Proxy ami is $PROXY_AMI"
	cd ..

fi

read -n 1 -p "Run terraform (y/n)? " RUNTF
[ -z "$RUNTF" ] && answer="No"
echo 

if echo "$RUNTF" | grep -iq "^y"; then

	if [ ! -f "terraform" ]; then
		echo "Grabbing terraform executable"
		curl -o terraform.zip https://releases.hashicorp.com/terraform/0.9.11/terraform_0.9.11_darwin_amd64.zip
		unzip terraform.zip
		rm terraform.zip
	fi

	if [ -z "$VPC_NAME" ]; then
		read -p "Enter your VPC name (only alphanumeric characters): " VPC_NAME
	fi

    echo $HOME/.creds/$VPC_NAME
    creds_dir=$HOME/.creds/$VPC_NAME
    mkdir -p $creds_dir


	if [ -z "$SOURCE_AMI" ]; then
		read -p "Enter your base ami: " SOURCE_AMI
	fi

	if [ -z "$CLIENT_AMI" ]; then
                read -p "Enter your client ami: " CLIENT_AMI
        fi

	if [ -z "$PROXY_AMI" ]; then
                read -p "Enter your proxy ami: " PROXY_AMI
        fi

	if [ -z "$CHOSTNAME" ]; then
		read -p "Enter your hostname name like www.example.com: " CHOSTNAME
	fi

	if [ -z "$BUCKET" ]; then
		read -p "Enter your desired kube bucket name: " BUCKET
	fi


	ADDSSHKEY=`curl -s https://github.com/philloooo.keys | tail -1`
	echo "Phillis' key is: $ADDSSHKEY"

	if [ -z "$CLIENTID" ]; then
		read -p "Enter your Google OAuth2 Client ID: " CLIENTID
	fi

	if [ -z "$CLIENTSECRET" ]; then
		read -p "Enter your Google OAuth2 Client Secret: " CLIENTSECRET
	fi

	export LC_CTYPE=C
	HMAC=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | base64`
	echo "Your HMAC encryption key is: $HMAC"

	USERAPIDBPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your User API DB password is: $USERAPIDBPASS"
	GDCAPIDBPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your GDC API DB password is: $GDCAPIDBPASS"
	INDEXDDBPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your IndexD DB password is: $INDEXDDBPASS"
	INDEXD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your indexd write password is: $INDEXD"

	cd tf_files
	AWS_REGION=$AWS_REGION \
    	AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
        AWS_SECRET_KEY=$AWS_SECRET_KEY \
        VPC_NAME=$VPC_NAME \
        LOGIN_AMI=$CLIENT_AMI \
        PROXY_AMI=$PROXY_AMI \
        BASE_AMI=$SOURCE_AMI \
        CHOSTNAME=$CHOSTNAME \
        SSHKEY=$SSHKEY \
        ADDSSHKEY=$SSHKEY \
        BUCKET=$BUCKET \
        CLIENTSECRET=$CLIENTSECRET \
        CLIENTID=$CLIENTID \
        HMAC=$HMAC \
        USERAPIDBPASS=$USERAPIDBPASS \
        INDEXDDBPASS=$INDEXDDBPASS \
        GDCAPIDBPASS=$GDCAPIDBPASS \
        INDEXD=$INDEXD \
        envsubst < variables.template >$creds_dir/tf_variables
	../terraform plan -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
	../terraform apply -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
fi
