if [[ "$1" =~ ^-*help ]]; then
  cat - <<EOM
   gen3 ls [PROFILE]
     profile is optional
   Lists local workspaces, 
   and workspaces saved to S3 under the given PROFILE if given.
EOM
  exit 0
fi
if [[ -n "$GEN3_S3_BUCKET" && -n "$GEN3_PROFILE" ]]; then
  echo "$GEN3_PROFILE profile workspaces under s3://$GEN3_S3_BUCKET"
  gen3_aws_run aws s3 ls "s3://${GEN3_S3_BUCKET}" 2> /dev/null || true
  OLD_S3_BUCKET="cdis-terraform-state.account-${AWS_ACCOUNT_ID}.gen3"
  echo ""
  echo "$GEN3_PROFILE profile workspaces under legacy path s3://$OLD_S3_BUCKET"
  gen3_aws_run aws s3 ls "s3://${OLD_S3_BUCKET}" 2> /dev/null || true
  echo ""
fi
echo "local workspaces under $XDG_DATA_HOME/gen3"
#cd $XDG_DATA_HOME
for i in "$XDG_DATA_HOME/gen3/"*; do
  profileName=$(basename "$i")
  #echo "Scanning $profileName"
  if [[ "$profileName" != "etc" && "$profileName" != "cache" ]]; then
    for j in "$XDG_DATA_HOME/gen3/$profileName/"*; do
      commonsName=$(basename "$j")
      #echo "Scanning $commonsName"
      if [[ -d "$XDG_DATA_HOME/gen3/$profileName/$commonsName" ]]; then
        echo "$profileName    $commonsName"
      fi
    done
  fi
done
