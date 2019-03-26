#
# apt install a bunch of random stuff ...
#

#include_recipe 'g3_dev_apt'

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
      # command for installing Python goes here
      if [ ! -d ./compose-services ]; then
        git clone https://github.com/uc-cdis/compose-services.git
        cd ./compose-services
        bash ./creds_setup.sh
      fi
    )
    EOF
end

