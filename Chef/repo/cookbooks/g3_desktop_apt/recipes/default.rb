#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_dev_apt'

['libsecret-tools'].each do |name|
  package 'g3-desktop-'+name do
    package_name name
    action :upgrade
  end
end

execute 'g3-desktop-code' do
  command <<-EOF
snap install code --classic
    EOF
  creates "/snap/bin/code"
end
