#
# Cookbook:: cdis_admin_vm
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

# Load keys from ssh keys databag
adminUserKeys = data_bag_item("users", "admin")
devUserKeys = data_bag_item("users", "dev")
qaUserKeys = data_bag_item("users", "qa")

# Setup users that dev's should have access to and set ssh authorized keys to the dev authorized keys databag
node["adminvm"]["devUsers"].each do |devUser|
  user "#{devUser}" do
    home "/home/#{devUser}"
    shell "/bin/bash"
    action :create
  end
  directory "/home/#{devUser}/.ssh" do
    owner devUser
    group devUser
    mode "0755"
    recursive true
    action :create
  end
  file "/home/#{devUser}/.ssh/authorized_keys" do
    content devUserKeys["keys"]
    mode "0600"
    owner devUser
    group devUser
  end
  directory "/home/#{devUser}/.config" do
    owner devUser
    group devUser
    mode "0775"
    recursive true
    action :create
  end
  template "/home/#{devUser}/.bashrc" do
    source 'bashrc.erb'
    mode '0655'
    owner devUser
    group devUser
    variables(userName: devUser)
  end
end


node["adminvm"]["qaUsers"].each do |qaUser|
  user "#{qaUser}" do
    home "/home/#{qaUser}"
    shell "/bin/bash"
    action :create
  end
  directory "/home/#{qaUser}/.ssh" do
    owner adminUser
    group adminUser
    mode "0755"
    recursive true
    action :create
  end
  file "/home/#{qaUser}/.ssh/authorized_keys" do
    content qaUserKeys["keys"]
    mode "0600"
    owner adminUser
    group adminUser
  end
  directory "/home/#{qaUser}/.config" do
    owner adminUser
    group adminUser
    mode "0775"
    recursive true
    action :create
  end
  template "/home/#{qaUser}/.bashrc" do
    source 'bashrc.erb'
    mode '0655'
    owner adminUser
    group adminUser
    variables(userName: qaUser)
  end
end

# Setup users that admin's should have access to and set ssh authorized keys to the admin authorized keys databag
# Setup after to ensure any users in both groups only give access to admin users
node["adminvm"]["adminUsers"].each do |adminUser|
  user "#{adminUser}" do
    home "/home/#{adminUser}"
    shell "/bin/bash"
    action :create
  end
  directory "/home/#{adminUser}/.ssh" do
    owner adminUser
    group adminUser
    mode "0755"
    recursive true
    action :create
  end
  file "/home/#{adminUser}/.ssh/authorized_keys" do
    content adminUserKeys["keys"]
    mode "0600"
    owner adminUser
    group adminUser
  end
  directory "/home/#{adminUser}/.config" do
    owner adminUser
    group adminUser
    mode "0775"
    recursive true
    action :create
  end
  template "/home/#{adminUser}/.bashrc" do
    source 'bashrc.erb'
    mode '0655'
    owner adminUser
    group adminUser
    variables(userName: adminUser)
  end
end