# VPC name is also used in DB name, so only alphanumeric characters
vpc_name="GENERATE FROM $GEN3_WORKSPACE"
#
# for vpc_octet see https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md
#  CIDR becomes 172.{vpc_octet2}.{vpc_octet3}.0/20
#
vpc_octet2=GET_A_UNIQUE_VPC_172_OCTET2
vpc_octet3=GET_A_UNIQUE_VPC_172_OCTET3

cluster_name="$GEN3_WORKSPACE"
k8s_master_password       = "$(gen3 random 32)"
k8s_node_service_account  = PUT-SERVICE-ACCOUNT-EMAIL-HERE
admin_box_service_account = PUT-SERVICE-ACCOUNT-EMAIL-HERE

dictionary_url="https://s3.amazonaws.com/dictionary-artifacts/YOUR/DICTIONARY/schema.json"
portal_app="dev"

hostname="YOUR.API.HOSTNAME"
#
# Bucket in bionimbus account hosts user.yaml
# config for all commons:
#   s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml
#
config_folder="PUT-SOMETHING-HERE"

google_client_secret="YOUR.GOOGLE.SECRET"
google_client_id="YOUR.GOOGLE.CLIENT"

# Following variables can be randomly generated passwords
# don't use ( ) " ' { } < > @ in password
db_fence_password="GENERATE WITH $(gen3 random 32)"
db_sheepdog_password="GENERATE WITH $(gen3 random 32)"
db_peregrine_password="GENERATE WITH $(gen3 random 32)"
db_indexd_password="GENERATE WITH $(gen3 random 32)"

# password for write access to indexd
gdcapi_indexd_password="GENERATE WITH $(gen3 random 32)"
gdcapi_secret_key="GENERATE WITH $(gen3 random 32)"
