#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_base_apt'

['dnsutils', 'git', 'gpg', 'jq', 'less', 'nano', 'python3-dev', 'python3-pip', 'unzip', 'vim'].each do |name|
  package 'g3-dev-'+name do
    package_name name
    action :upgrade
  end
end

execute 'g3-python3-alternatives' do
  command <<-EOF
    if (! which python) || [ "$(python --version 2>&1 | awk '$2 ~ /^3\./ { print "3" }')" = 2 ]; then
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
    EOF
end

