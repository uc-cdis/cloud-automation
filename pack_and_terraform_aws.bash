#!/bin/bash
# Right now this script guides you through the process
# of running Packer & Terraform

PACKER_VARIABLES="../packer_variables.json"
IMAGES="images"

function random_alphanumeric() {
    # Generate a random string of alphanumeric characters of length $1.
    base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $1
}

function packer_build_image() {
    # Attempt to build the image file $1 using packer. If this runs into errors,
    # print the error output from packer and exit 1. Otherwise, return the ID of
    # the Amazon Machine Image (AMI) built.
    cd $IMAGES
    packer_output="$(../packer build --var-file ../$PACKER_VARIABLES -machine-readable images/$1)"
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
[ -z "$BUILDPACKER" ] && BUILDPACKER="No"
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

    if [ -z "$AWS_INSTANCE_TYPE" ]; then
        read -p "Enter your AWS instance type for creating packer images only (default: m4.xlarge): " AWS_INSTANCE_TYPE
        [ -z "$AWS_INSTANCE_TYPE" ] && AWS_INSTANCE_TYPE="m4.xlarge"
    fi

    read -n 1 -p "Replace CDIS default authorized_keys (yes/append/no)? " REPLACEKEYS
    [ -z "$REPLACEKEYS" ] && REPLACEKEYS="No"
    echo

    if echo "$REPLACEKEYS" | grep -iq "^y"; then
        echo $SSHKEY >images/configs/authorized_keys
    elif echo "$REPLACEKEYS" | grep -iq "^a"; then
        echo $SSHKEY >>images/configs/authorized_keys
    fi

    # SOURCE_AMI is set after building the base image, so leave the variable
    # there for a second envsubst.
    AWS_REGION=$AWS_REGION \
        AWS_INSTANCE_TYPE=$AWS_INSTANCE_TYPE \
        AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
        AWS_SECRET_KEY=$AWS_SECRET_KEY \
        SOURCE_AMI='$SOURCE_AMI' \
        envsubst < $IMAGES/variables.json.template >$PACKER_VARIABLES

    echo "Building packer base image"
    SOURCE_AMI="$(packer_build_image base_image.json)"
    [ $? == 1 ] && exit 1;
    echo "Base ami is $SOURCE_AMI"
    # Fill in the source_ami packer variable. (Note that the packer variables
    # file can't be read from and redirected to in the same step.)
    SOURCE_AMI=$SOURCE_AMI \
        envsubst < $PACKER_VARIABLES >tmp
    mv tmp $PACKER_VARIABLES

    echo "Building packer client image"
    CLIENT_AMI="$(packer_build_image client.json)"
    [ $? == 1 ] && exit 1;
    echo "Client ami is $CLIENT_AMI"

    echo "Building packer squid image"
    PROXY_AMI="$(packer_build_image squid_image.json)"
    [ $? == 1 ] && exit 1;
    echo "Proxy ami is $PROXY_AMI"

fi

read -n 1 -p "Run terraform (y/n)? " RUNTF
[ -z "$RUNTF" ] && RUNTF="No"
echo

if echo "$RUNTF" | grep -iq "^y"; then

    if [ ! -f "terraform" ]; then
        echo "Grabbing terraform executable"
        curl -o terraform.zip https://releases.hashicorp.com/terraform/0.10.4/terraform_0.10.4_darwin_amd64.zip
        unzip terraform.zip
        rm terraform.zip
    fi

    if [ -z "$VPC_NAME" ]; then
        read -p "Enter your VPC name (only alphanumeric characters): " VPC_NAME
    fi

    if [ -z "$VPC_OCTET" ]; then
        read -p "Enter your VPC subnet octet (between 16 to 31) which will make the internal network 172.X (default: 16): " VPC_OCTET
        [ -z "$VPC_OCTET" ] && VPC_OCTET="16"
    fi

    echo "Your configuration for this VPC will be saved to $HOME/.creds/$VPC_NAME"
    creds_dir=$HOME/.creds/$VPC_NAME
    mkdir -p $creds_dir

    if [ -z "$AWS_S3_ACCESS_KEY" ]; then
        read -p "Enter your access key to S3 bucket for saving terraform state: " AWS_S3_ACCESS_KEY
    fi

    if [ -z "$AWS_S3_SECRET_KEY" ]; then
        read -p "Enter your secret key to S3 bucket for saving terraform state: " AWS_S3_SECRET_KEY
    fi

    if [ -z "$AWS_S3_REGION" ]; then
        read -p "Enter your AWS region for S3 bucket that saves terraform state (default: us-east-1): " AWS_S3_REGION
        [ -z "$AWS_S3_REGION" ] && AWS_S3_REGION="us-east-1"
    fi

    if [ -z "$AWS_S3_BUCKET" ]; then
        read -p "Enter your bucket name for S3 bucket that saves terraform state (default: cdis-terraform-states): " AWS_S3_BUCKET
        [ -z "$AWS_S3_BUCKET" ] && AWS_S3_BUCKET="cdis-terraform-states"
    fi

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
    echo "You need to create a certificate in AWS Certificate Manager with imported certs or the admin for the site need to approve aws create it."
    read -p "This needs to be done to make following process working. Done? [y/n] " CONFIGURED_CERT

    if [ -z "$AWS_CERT_NAME" ]; then
        read -p "Enter the domain name for the AWS certificate: " AWS_CERT_NAME
    fi

    if [ "$CONFIGURED_CERT" != "y" ]; then
        exit 1
    fi

    if [ -z "$KUBEBUCKET" ]; then
        read -p "Enter your desired kube bucket name: " KUBEBUCKET
    fi

    ADDSSHKEY=`curl -s https://github.com/philloooo.keys | tail -1`
    echo "Phillis' key is: $ADDSSHKEY"

    if [ -z "$CLIENTID" ]; then
        read -p "Enter your Google OAuth2 Client ID: " CLIENTID
    fi

    if [ -z "$CLIENTSECRET" ]; then
        read -p "Enter your Google OAuth2 Client Secret: " CLIENTSECRET
    fi

    if [ -z "$USERAPISNAPSHOT" ]; then
        read -p "Enter a userapi db snapshot id or leave blank to create: " USERAPISNAPSHOT
    fi

    if [ -z "$GDCAPISNAPSHOT" ]; then
        read -p "Enter a gdcapi db snapshot id or leave blank to create: " GDCAPISNAPSHOT
    fi

    if [ -z "$INDEXDSNAPSHOT" ]; then
        read -p "Enter a indexd db snapshot id or leave blank to create: " INDEXDSNAPSHOT
    fi

    export LC_CTYPE=C
    HMAC="$(random_alphanumeric 32 | base64)"
    echo "Your HMAC encryption key is: $HMAC"
    GDCAPI_SECRET="$(random_alphanumeric 50)"
    echo "Your gdcapi flask secret key is: $GDCAPI_SECRET"
    USERAPIDBPASS="$(random_alphanumeric 32)"
    echo "Your User API DB password is: $USERAPIDBPASS"
    GDCAPIDBPASS="$(random_alphanumeric 32)"
    echo "Your GDC API DB password is: $GDCAPIDBPASS"
    INDEXDDBPASS="$(random_alphanumeric 32)"
    echo "Your IndexD DB password is: $INDEXDDBPASS"
    INDEXD="$(random_alphanumeric 32)"
    echo "Your indexd write password is: $INDEXD"

    AWS_REGION=$AWS_REGION \
        AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
        AWS_SECRET_KEY=$AWS_SECRET_KEY \
        AWS_CERT_NAME=$AWS_CERT_NAME \
        VPC_NAME=$VPC_NAME \
        VPC_OCTET=$VPC_OCTET \
        LOGIN_AMI=$CLIENT_AMI \
        PROXY_AMI=$PROXY_AMI \
        BASE_AMI=$SOURCE_AMI \
        CHOSTNAME=$CHOSTNAME \
        SSHKEY=$SSHKEY \
        ADDSSHKEY=$SSHKEY \
        KUBEBUCKET=$KUBEBUCKET \
        CLIENTSECRET=$CLIENTSECRET \
        CLIENTID=$CLIENTID \
        HMAC=$HMAC \
        GDCAPI_SECRET=$GDCAPI_SECRET \
        USERAPIDBPASS=$USERAPIDBPASS \
        INDEXDDBPASS=$INDEXDDBPASS \
        GDCAPIDBPASS=$GDCAPIDBPASS \
        INDEXD=$INDEXD \
        USERAPISNAPSHOT=$USERAPISNAPSHOT \
        GDCAPISNAPSHOT=$GDCAPISNAPSHOT \
        INDEXDSNAPSHOT=$INDEXDSNAPSHOT \
        envsubst < tf_files/aws/variables.template >$creds_dir/tf_variables
    cd tf_files/aws
    ../../terraform init
    ../../terraform plan -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
    ../../terraform apply -var-file=$creds_dir/tf_variables -state=$creds_dir/terraform.tfstate
fi
