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

snap_package 'g3-desktop-code' do
  package_name "code"
  options ["--classic" ]
end
