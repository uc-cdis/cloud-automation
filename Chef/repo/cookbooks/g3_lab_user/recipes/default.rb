#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_dev_apt'

user 'gen3lab' do
  comment 'lab user'
  shell '/bin/bash'
  manage_home true
end

group 'gen3lab-docker' do
  action :manage
  group_name 'docker'
  members ['gen3lab']
  append true
end


execute 'g3-lab-setup' do
  cwd '/home/gen3lab'
  command <<-EOF
    (
      su gen3lab
      if [ ! -d ./compose-services ]; then
        git clone https://github.com/uc-cdis/compose-services.git
        cd ./compose-services
        bash ./creds_setup.sh "$(hostname).gen3workshop.org"
        sed -i 's/DICTIONARY_URL:/#DICTIONARY_URL:/g' docker-compose.yml
        sed -i 's/#\s*PATH_TO_SCHEMA_DIR:/PATH_TO_SCHEMA_DIR:/g' docker-compose.yml
        if [ -e /var/run/docker.sock ]; then
          docker-compose pull
        fi
      fi
    )
    chown -R gen3lab: /home/gen3lab/
    EOF
end

execute 'g3-lab-keys' do
  cwd '/tmp'
  # TODO - move the list of keys out to an attribute or databag ...
  command <<-EOF
(
  for dir in /home/ubuntu /home/gen3lab; do
    if [ -d "$dir" ]; then
      cd "$dir"
      if [ ! -f .ssh/authorized_keys ]; then
        mkdir -m 0700 -p .ssh
        touch .ssh/authorized_keys
        chown -R $(basename $dir): .ssh
        chmod -R 0700 .ssh
      fi
      (cat - <<EOM
EOM
      ) | while read -r line; do
        key=$(echo $line | awk '{ print $3 }')
        if ! grep "$key" .ssh/authorized_keys > /dev/null 2>&1; then
          echo $line >> .ssh/authorized_keys
        fi
      done
    else
      echo "$dir does not exist"
    fi
  done
)
  EOF
end

log "certbot certonly -a manual -i nginx -d '*.gen3workshop.org'" do
  level :info
end
