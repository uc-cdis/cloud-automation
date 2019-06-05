#
# Setup custom apt repo, then install
#  * https://docs.docker.com/install/linux/docker-ce/debian/#install-docker-ce-1
#  * https://docs.docker.com/compose/install/#install-compose
#

include_recipe 'g3_dev_apt'

apt_repository 'docker-apt-repo' do
  uri   'https://download.docker.com/linux/ubuntu'
  key   'https://download.docker.com/linux/ubuntu/gpg'
  components ['stable']
end


[ 'docker-ce', 'docker-ce-cli', 'containerd.io'].each do |name|
  package 'g3-docker-'+name do
    package_name name
  end
end


#curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
execute 'g3-install-compose' do
  command <<-EOF
    # command for installing Python goes here
    export XDG_CACHE_HOME=/var/cache
    python -m pip install docker-compose --upgrade
    EOF
end