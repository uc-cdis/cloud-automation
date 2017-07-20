#!/bin/bash
# Right now this script guides you through the process
# of running Packer & Terraform

read -p "Enter your AWS ACCESS key: " AWS_ACCESS_KEY
read -p "Enter your AWS SECRET key: " AWS_SECRET_KEY

read -p "Enter your github username: " GITHUB
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

	read -n 1 -p "Replace CDIS default authorized_keys (y/n)? " REPLACEKEYS
	[ -z "$REPLACEKEYS" ] && answer="No"
	echo

	if echo "$REPLACEKEYS" | grep -iq "^y"; then
		echo $SSHKEY >images/configs/authorized_keys
	fi

	cp images/variables.example.json ../packer_variables.json
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

	cp tf_files/variables.template ../tf_variables

	sed -i '' -e "s/aws_access_key=\"\"/aws_access_key=\"$AWS_ACCESS_KEY\"/g" ../tf_variables	
	sed -i '' -e "s/aws_secret_key=\"\"/aws_secret_key=\"$AWS_SECRET_KEY\"/g" ../tf_variables

	read -p "Enter your VPC name (only alphanumeric characters): " VPC_NAME
	sed -i '' -e "s/vpc_name=\"\"/vpc_name=\"$VPC_NAME\"/g" ../tf_variables

	if [ -z "$SOURCE_AMI" ]; then
		read -p "Enter your base ami: " SOURCE_AMI
	fi
	sed -i '' -e "s/base_ami=\"\"/base_ami=\"$SOURCE_AMI\"/g" ../tf_variables

	if [ -z "$CLIENT_AMI" ]; then
                read -p "Enter your client ami: " CLIENT_AMI
        fi
	sed -i '' -e "s/login_ami=\"\"/login_ami=\"$CLIENT_AMI\"/g" ../tf_variables

	if [ -z "$PROXY_AMI" ]; then
                read -p "Enter your proxy ami: " PROXY_AMI
        fi
	sed -i '' -e "s/proxy_ami=\"\"/proxy_ami=\"$PROXY_AMI\"/g" ../tf_variables

	read -p "Enter your hostname name like https://www.example.com: " CHOSTNAME
	sed -i '' -e "s#hostname=\"https://www.example.com\"#hostname=\"$CHOSTNAME\"#g" ../tf_variables

	read -p "Enter your desired kube bucket name: " BUCKET
	sed -i '' -e "s/kube_bucket=\"\"/kube_bucket=\"$BUCKET\"/g" ../tf_variables

	sed -i '' -e "s#kube_ssh_key=\"ssh-rsa XXXX\"#kube_ssh_key=\"$SSHKEY\"#g" ../tf_variables

	ADDSSHKEY=`curl -s https://github.com/philloooo.keys | tail -1`
	echo "Phillis' key is: $ADDSSHKEY"
	sed -i '' -e "s#kube_additional_keys=\"\"#kube_additional_keys=\"- \\\\\"$ADDSSHKEY\\\\\"\\\\n\"#g" ../tf_variables

	read -p "Enter your Google OAuth2 Client ID: " CLIENTID
        sed -i '' -e "s/google_client_id=\"\"/google_client_id=\"$CLIENTID\"/g" ../tf_variables

	read -p "Enter your Google OAuth2 Client Secret: " CLIENTSECRET
        sed -i '' -e "s/google_client_secret=\"\"/google_client_secret=\"$CLIENTSECRET\"/g" ../tf_variables

	export LC_CTYPE=C
	HMAC=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
	echo "Your HMAC encryption key is: $HMAC"
	sed -i '' -e "s/hmac_encryption_key=\"\"/hmac_encryption_key=\"$HMAC\"/g" ../tf_variables

	DBPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your DB password is: $DBPASS"
	sed -i '' -e "s/db_password_userapi=\"\"/db_password_userapi=\"$DBPASS\"/g" ../tf_variables
	sed -i '' -e "s/db_password_gdcapi=\"\"/db_password_gdcapi=\"$DBPASS\"/g" ../tf_variables
	sed -i '' -e "s/db_password_indexd=\"\"/db_password_indexd=\"$DBPASS\"/g" ../tf_variables

	INDEXD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        echo "Your indexd write password is: $INDEXD"
	sed -i '' -e "s/gdcapi_indexd_password=\"\"/gdcapi_indexd_password=\"$INDEXD\"/g" ../tf_variables

	cd tf_files
	../terraform plan -var-file=../../tf_variables
	../terraform apply -var-file=../../tf_variables
	
fi
