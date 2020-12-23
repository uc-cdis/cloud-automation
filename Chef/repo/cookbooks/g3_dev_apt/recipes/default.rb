#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_base_apt'

#
# https://github.com/nodesource/distributions/blob/master/README.md
#   https://deb.nodesource.com/setup_12.x
#
apt_repository 'nodejs-apt-repo' do
  arch  'amd64'
  uri   'https://deb.nodesource.com/node_12.x'
  key   'https://deb.nodesource.com/gpgkey/nodesource.gpg.key'
  components ['main']
end

['build-essential', 'dnsutils', 'figlet', 'git', 'gpg', 'jq', 'ldap-utils', 'less', 'nano', 'nodejs', 'python-dev', 'python-pip', 'python3-dev', 'python3-pip', 'unzip', 'vim', 'zip'].each do |name|
  package 'g3-dev-'+name do
    package_name name
    action :upgrade
  end
end

execute 'g3-python3-alternatives' do
  command <<-EOF
    if (! which python > /dev/null) || [ "$(python --version 2>&1 | awk '$2 ~ /^3\./ { print "3" }')" != 3 ]; then
      if [ -e /usr/bin/python2 ]; then
        update-alternatives --install /usr/bin/python python /usr/bin/python2 50
      fi
      if [ -e /usr/bin/python3 ]; then
        update-alternatives --install /usr/bin/python python /usr/bin/python3 100
      fi
    fi
    EOF
end

execute 'g3-install-pipstuff' do
  command <<-EOF
    export XDG_CACHE_HOME=/var/cache
    python -m pip install awscli --upgrade
    python -m pip install yq --upgrade
    python -m pip install aws-sam-cli --upgrade
    EOF
end
