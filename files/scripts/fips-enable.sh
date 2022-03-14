source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

key=$1
if [[ -z $key ]];
  gen3_log_err "Please give the key for UA"
  exit 1
fi

# Run an apt update
sudo apt update
# Install Ubuntu Advantage, premium Ubuntu subscription which allows for FIPs
sudo apt install ubuntu-advantage-tools
sudo ua attach $key
sudo ua enable fips-updates
sudo reboot
