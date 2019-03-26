#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_base_apt'

['dnsutils', 'git', 'gpg', 'jq', 'less', 'nano', 'python-dev', 'python-pip', 'unzip', 'vim'].each do |name|
  package 'g3-dev-'+name do
    package_name name
  end
end


execute 'g3-install-pipstuff' do
  command <<-EOF
    # command for installing Python goes here
    export XDG_CACHE_HOME=/var/cache
    python -m pip install awscli --upgrade
    python -m pip install yq --upgrade
    EOF
end

