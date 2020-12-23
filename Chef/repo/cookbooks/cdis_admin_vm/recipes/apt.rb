apt_update 'update' do
  action :update
end

execute "apt-upgrade" do
  command 'DEBIAN_FRONTEND=noninteractive apt-get -fuy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade'
  action :nothing
end
