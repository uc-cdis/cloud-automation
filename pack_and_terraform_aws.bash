#!/bin/bash
# Right now this script guides you through the process
# of running Packer & Terraform

packer_variables="../packer_variables.json"
images="images"

function random_alphanumeric() {
    # Generate a random string of alphanumeric characters of length $1.
    base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $1
}

function packer_build_image() {
    # Attempt to build the image file $1 using packer. If this runs into errors,
    # print the error output from packer and exit 1. Otherwise, return the ID of
    # the Amazon Machine Image (AMI) built.
    cd $images
    packer_output="$(../packer build --var-file ../$packer_variables -machine-readable images/$1)"
    packer_errors="$(echo "$packer_output" | egrep '^.*,.*,.*,error' | cut -d ',' -f 5-)"
    if [[ -n $packer_errors ]]; then
        echo "packer failed to build image: $1" >&2
        echo -e "$packer_errors" >&2
        exit 1
    fi
    cd ..
    echo "$packer_output" | egrep 'artifact,0,id' | rev | cut -d ',' -f 1 | rev | cut -d ':' -f 2
}

unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
    export PATH=${PATH}:/usr/local/opt/gettext/bin
    if [[ ! -x "$(command -v envsubst)" ]]; then
        echo "need envsubst to run this script, please install gettext"
        exit 1
    fi
fi

read -n 1 -p "create vpc with inherited vars from old vpc (y/n)? " migrate_vpc
[ -z "$migrate_vpc" ] && migrate_vpc="no"
echo

if echo "$migrate_vpc" | grep -iq "^y"; then
  . ./migrate_vpc.bash
fi
if [ -z "$aws_region" ]; then
    read -p "Enter your AWS region (default: us-east-1): " aws_region
    [ -z "$aws_region" ] && aws_region="us-east-1"
fi
if [ -z "$aws_access_key" ]; then
    read -p "Enter your AWS ACCESS key: " aws_access_key
fi

if [ -z "$aws_secret_key" ]; then
    read -p "Enter your AWS SECRET key: " aws_secret_key
fi

if [ -z "$kube_ssh_key" ]; then
    if [ -z "$github" ]; then
        read -p "enter your github username: " github
    fi
    kube_ssh_key=`curl -s https://github.com/$github.keys | tail -1`
    echo "got key for $github: $kube_ssh_key"
fi

#
# Terraform now copies new public ubuntu16 images for the VPC -
# building the old ubuntu14 images is no longer necessary ...
#
buildpacker=no

#read -n 1 -p "build packer images (y/n)? " buildpacker
#[ -z "$buildpacker" ] && buildpacker="no"
echo

if echo "$buildpacker" | grep -iq "^y"; then

    # get the info to create amis
    if [ ! -d "images" ]; then
        echo "cloning ami base configurations"
        git clone https://github.com/uc-cdis/images.git
    fi

    # get packer to create amis
    if [ ! -f "packer" ]; then
        echo "grabbing packer executable"
        curl -o packer.zip https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_darwin_amd64.zip
        unzip packer.zip
        rm packer.zip
    fi

    if [ -z "$aws_instance_type" ]; then
        read -p "enter your aws instance type for creating packer images only (default: m4.xlarge): " aws_instance_type
        [ -z "$aws_instance_type" ] && aws_instance_type="m4.xlarge"
    fi

    read -n 1 -p "replace cdis default authorized_keys (yes/append/no)? " replacekeys
    [ -z "$replacekeys" ] && replacekeys="no"
    echo

    if echo "$replacekeys" | grep -iq "^y"; then
        echo $kube_ssh_key >images/configs/authorized_keys
    elif echo "$replacekeys" | grep -iq "^a"; then
        echo $kube_ssh_key >>images/configs/authorized_keys
    fi

    # source_ami is set after building the base image, so leave the variable
    # there for a second envsubst.
    AWS_REGION=$aws_region \
        AWS_INSTANCE_TYPE=$aws_instance_type \
        AWS_ACCESS_KEY=$aws_access_key \
        AWS_SECRET_KEY=$aws_secret_key \
        SOURCE_AMI='$source_ami' \
        envsubst < $images/variables.json.template >$packer_variables

    echo "building packer base image"
    source_ami="$(packer_build_image base_image.json)"
    [ $? == 1 ] && exit 1;
    echo "base ami is $source_ami"
    # fill in the source_ami packer variable. (note that the packer variables
    # file can't be read from and redirected to in the same step.)
    source_ami=$source_ami \
        envsubst < $packer_variables >tmp


    mv tmp $packer_variables

    echo "building packer client image"
    client_ami="$(packer_build_image client.json)"
    [ $? == 1 ] && exit 1;
    echo "client ami is $client_ami"

    echo "building packer squid image"
    proxy_ami="$(packer_build_image squid_image.json)"
    [ $? == 1 ] && exit 1;
    echo "proxy ami is $proxy_ami"


    base_ami=$source_ami
    login_ami=$client_ami

fi

read -n 1 -p "run terraform (y/n)? " runtf
[ -z "$runtf" ] && runtf="no"
echo

if echo "$runtf" | grep -iq "^y"; then

    if [ ! -f "terraform" ]; then
        tfUrl=https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip
        if [ "linux-gnu" != "$OSTYPE" ]; then
          tfUrl=https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_darwin_amd64.zip
        fi
        echo "grabbing terraform executable from $tfUrl"
        curl -o terraform.zip $tfUrl
        unzip terraform.zip
        rm terraform.zip
    fi

    if [ -z "$vpc_name" ]; then
        read -p "enter your vpc name (only alphanumeric characters): " vpc_name
    fi

    if [ -z "$vpc_octet" ]; then
        read -p "enter your vpc subnet octet (between 16 to 31) which will make the internal network 172.x (default: 16): " vpc_octet
        [ -z "$vpc_octet" ] && vpc_octet="16"
    fi

    echo "your configuration for this vpc will be saved to $HOME/.creds/$vpc_name"
    creds_dir=$HOME/.creds/$vpc_name
    mkdir -p $creds_dir

    if [ -z "$aws_s3_access_key" ]; then
        read -p "enter your access key to s3 bucket for saving terraform state: " aws_s3_access_key
    fi

    if [ -z "$aws_s3_secret_key" ]; then
        read -p "enter your secret key to s3 bucket for saving terraform state: " aws_s3_secret_key
    fi

    if [ -z "$aws_s3_region" ]; then
        read -p "enter your aws region for s3 bucket that saves terraform state (default: us-east-1): " aws_s3_region
        [ -z "$aws_s3_region" ] && aws_s3_region="us-east-1"
    fi

    if [ -z "$aws_s3_bucket" ]; then
        read -p "enter your bucket name for s3 bucket that saves terraform state (default: cdis-terraform-states): " aws_s3_bucket
        [ -z "$aws_s3_bucket" ] && aws_s3_bucket="cdis-terraform-states"
    fi

    if [ -z "$base_ami" ]; then
        read -p "enter your base ami: " base_ami
    fi

    if [ -z "$login_ami" ]; then
        read -p "enter your client ami: " login_ami
    fi

    if [ -z "$proxy_ami" ]; then
        read -p "enter your proxy ami: " proxy_ami
    fi

    if [ -z "$hostname" ]; then
        read -p "enter your hostname name like www.example.com: " hostname
    fi
    echo "you need to create a certificate in aws certificate manager with imported certs or the admin for the site need to approve aws create it."
    read -p "this needs to be done to make following process working. done? [y/n] " configured_cert

    if [ "$configured_cert" != "y" ]; then
        exit 1
    fi

    if [ -z "$aws_cert_name" ]; then
        read -p "enter the domain name for the aws certificate: " aws_cert_name
    fi

    if [ -z "$kube_bucket" ]; then
        read -p "enter your desired kube bucket name: " kube_bucket
    fi

    if [ -z "$addsshkey" ]; then
        addsshkey=`curl -s https://github.com/philloooo.keys | tail -1`
        echo "phillis' key is: $addsshkey"
    fi

    if [ -z "$google_client_id" ]; then
        read -p "enter your google oauth2 client id: " google_client_id
    fi

    if [ -z "$google_client_secret" ]; then
        read -p "enter your google oauth2 client secret: " google_client_secret
    fi

    if [ -z "$fence_snapshot" ]; then
        read -p "enter a fence db snapshot id or leave blank to create: " fence_snapshot
    fi

    if [ -z "$userapi_snapshot" ]; then
        read -p "enter a userapi db snapshot id or leave blank to create: " userapi_snapshot
    fi

    if [ -z "$gdcapi_snapshot" ]; then
        read -p "enter a gdcapi db snapshot id or leave blank to create: " gdcapi_snapshot
    fi

    if [ -z "$indexd_snapshot" ]; then
        read -p "enter a indexd db snapshot id or leave blank to create: " indexd_snapshot
    fi

    export LC_CTYPE=C

    if [ -z "$hmac_encryption_key" ]; then
        hmac_encryption_key="$(random_alphanumeric 32 | base64)"
        echo "your hmac encryption key is: $hmac_encryption_key"
    fi
    if [ -z "$gdcapi_secret_key" ]; then
        gdcapi_secret_key="$(random_alphanumeric 50)"
        echo "your gdcapi flask secret key is: $gdcapi_secret_key"
    fi
    if [ -z "$db_password_fence" ]; then
        db_password_fence="$(random_alphanumeric 32)"
        echo "your user api db password is: $db_password_fence"
    fi
    if [ -z "$db_password_userapi" ]; then
        db_password_userapi="$(random_alphanumeric 32)"
        echo "your user api db password is: $db_password_userapi"
    fi
    if [ -z "$db_password_gdcapi" ]; then
        db_password_gdcapi="$(random_alphanumeric 32)"
        echo "your gdc api db password is: $db_password_gdcapi"
    fi
    if [ -z "$db_password_indexd" ]; then
        db_password_indexd="$(random_alphanumeric 32)"
        echo "your indexd db password is: $db_password_indexd"
    fi
    if [ -z "$gdcapi_indexd_password" ]; then
        gdcapi_indexd_password="$(random_alphanumeric 32)"
        echo "your indexd write password is: $gdcapi_indexd_password"
    fi

    pwd
    cd tf_files/aws
    aws_region=$aws_region \
        aws_access_key=$aws_access_key \
        aws_secret_key=$aws_secret_key \
        aws_cert_name=$aws_cert_name \
        vpc_name=$vpc_name \
        vpc_octet=$vpc_octet \
        login_ami=$login_ami \
        proxy_ami=$proxy_ami \
        base_ami=$base_ami \
        hostname=$hostname \
        kube_ssh_key=$kube_ssh_key \
        addsshkey=$addsshkey \
        kube_bucket=$kube_bucket \
        google_client_secret=$google_client_secret \
        google_client_id=$google_client_id \
        hmac_encryption_key=$hmac_encryption_key \
        gdcapi_secret_key=$gdcapi_secret_key \
        db_password_fence=$db_password_fence \
        db_password_userapi=$db_password_userapi \
        db_password_indexd=$db_password_indexd \
        db_password_gdcapi=$db_password_gdcapi \
        gdcapi_indexd_password=$gdcapi_indexd_password \
        fence_snapshot=$fence_snapshot \
        userapi_snapshot=$userapi_snapshot \
        gdcapi_snapshot=$gdcapi_snapshot \
        indexd_snapshot=$indexd_snapshot \
        aws_s3_access_key=$aws_s3_access_key \
    	aws_s3_secret_key=$aws_s3_secret_key \
		aws_s3_region=$aws_s3_region \
        aws_s3_bucket=$aws_s3_bucket \
        key_to_state=cdis-terraform-$vpc_name/terraform.tfstate \
        gdcapi_oauth2_client_secret=$gdcapi_oauth2_client_secret \
        gdcapi_oauth2_client_id=$gdcapi_oauth2_client_id \
        envsubst < variables.template >$creds_dir/tf_variables
    aws_s3_access_key=$aws_s3_access_key \
    	aws_s3_secret_key=$aws_s3_secret_key \
		aws_s3_region=$aws_s3_region \
        aws_s3_bucket=$aws_s3_bucket \
        key_to_state=cdis-terraform-$vpc_name/terraform.tfstate \
        envsubst < terraform.tfvars >$creds_dir/terraform.tfvars
	../../terraform init -backend-config=$creds_dir/terraform.tfvars
    ../../terraform plan -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
    ../../terraform apply -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
fi
