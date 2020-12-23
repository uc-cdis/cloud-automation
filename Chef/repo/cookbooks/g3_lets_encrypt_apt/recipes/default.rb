#
# apt install lets encrypt certbot ...
#

include_recipe 'g3_dev_apt'

apt_repository 'apt-lets-encrypt' do
  arch  'amd64'
  uri   'ppa:certbot/certbot'
end


[ 'certbot', 'python3-certbot-nginx', 'python3-certbot-dns-route53' ].each do |name|
  package 'g3-apt-'+name do
    package_name name
    action :upgrade
  end
end

#
# Prefer apt based installation
#
#execute 'g3-pip-certbot' do
#  command <<-EOF
#    export XDG_CACHE_HOME=/var/cache
#    python -m pip install certbot-nginx --upgrade
#    python -m pip install certbot-dns-route53 --upgrade
#    EOF
#end


