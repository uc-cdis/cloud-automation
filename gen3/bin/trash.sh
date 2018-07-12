help() {
  cat - <<EOM
  gen3 trash [--apply]:
    Move the local folder of the current workspace to the gen3 trash folder.
    This is just a local cleanup - it does not affect cloud resources or
    the configs backed up in S3.
    
    --apply must be passed - otherwise the help is given.
    dryrun with: gen3 --dryrun trash --apply
    
EOM
  return 0
}

source "$GEN3_HOME/gen3/lib/utils.sh"

GEN3_TRASH="$XDG_DATA_HOME/gen3/.trash"
mkdir -p -m 0700 "$GEN3_TRASH"

if [[ ! "$1" =~ ^-*apply ]]; then
  help
  exit 1
fi

if [[ ! -d "$GEN3_WORKDIR" ]]; then
  echo "ERROR: $GEN3_WORKDIR does not exist"
  exit 1
fi

destFolder="${GEN3_TRASH}/${GEN3_PROFILE}-${GEN3_WORKSPACE}.$(date +%s)"
echo "$DRY_RUN_STR mv $GEN3_WORKDIR $destFolder"
if ! $GEN3_DRY_RUN; then
  mv "$GEN3_WORKDIR" "$destFolder"
fi
