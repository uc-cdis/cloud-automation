echo "local workspaces under $XDG_DATA_HOME/gen3"
#cd $XDG_DATA_HOME
for i in "$XDG_DATA_HOME/gen3/"*; do
  profileName=$(basename "$i")
  #echo "Scanning $profileName"
  for j in "$XDG_DATA_HOME/gen3/$profileName/"*; do
    commonsName=$(basename "$j")
    #echo "Scanning $commonsName"
    if [[ -d "$XDG_DATA_HOME/gen3/$profileName/$commonsName" ]]; then
      echo "$profileName    $commonsName"
    fi
  done
done
