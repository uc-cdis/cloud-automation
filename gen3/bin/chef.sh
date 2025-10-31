#/bin/sh

gen3_chef_initialize() {  
  curl -L https://omnitruck.chef.io/install.sh > ${GEN3_HOME}/install.sh
  sudo bash ${GEN3_HOME}/install.sh
  sudo apt-get install ruby2.5-dev -y
  sudo gem install chef-zero
  cat << EOF > /home/$user/.chef/client.rb
node_name 'adminvm'
cookbook_path '/home/$user/cloud-automation/Chef/repo/cookbooks'
data_bag_path '/home/$user/cloud-automation/Chef/repo/data_bags'
environment_path '/home/$user/cloud-automation/Chef/repo/environments'
role_path '/home/$user/cloud-automation/Chef/repo/roles'
chef_server_url 'http://127.0.0.1:8889'
log_level :info
log_location '/home/$user/.chef/chef-client.log'
verify_api_cert false
treat_deprecation_warnings_as_errors false
client_key   '/home/$user/.chef/key.pem'
EOF
  cat << EOF > /home/$user/.chef/knife.rb
chef_server_url   'http://127.0.0.1:8889'
node_name         'adminvm'
client_key        '/home/$user/.chef/key.pem'
knife[:supermarket_site] = 'https://supermarket.chef.io'
EOF
  if [ ! -f /home/$user/.chef/key.pem ]; then
    openssl genrsa -out /home/$user/.chef/key.pem 2048
  fi
  status=$(curl -s -o /dev/null -w "%{http_code}" localhost:8889)
  if [[ $status == "000" ]]; then
    chef-zero -d
  fi
}


gen3_chef_role() {
  role=$1
  if [[ -z $(which chef-client) ]]; then
    gen3_chef_initialize
  fi
  knife upload / -c .chef/client.rb
  chef-client -o "role['$role']" -c /home/$user/.chef/client.rb
}

gen3_chef_recipe() {
  recipe=$1
  if [[ -z $(which chef-client) ]]; then
    gen3_chef_initialize
  fi
  knife upload / -c .chef/client.rb
  chef-client -o "$recipe" -c /home/$user/.chef/client.rb
}

gen3_chef() {
  command="$1"
  shift
  case "$command" in
    'role')
      gen3_chef_role "$@"
      ;;
    'recipe')
      gen3_chef_recipe "$@"
      ;;
    'initialize')
      gen3_chef_initialize "$@"
      ;;
    *)
      gen3_chef_help
      ;;
  esac
}

user=$(whoami)

# Let testsuite source file
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_chef "$@"
fi