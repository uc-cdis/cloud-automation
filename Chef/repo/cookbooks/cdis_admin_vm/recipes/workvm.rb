include_recipe 'cdis_admin_vm::apt'

list = ["gpg", "curl", "ca-certificates", "wget"]
list.each do |aptPackage|
  apt_package aptPackage do
    package_name aptPackage
    action :install
  end
end

# Setup apt repo's
node["adminvm"]["aptRepos"].each do | aptDist, aptVariables |
  apt_repository aptDist do
    uri           aptVariables["repo"]
    key           aptVariables["keyserver"]
    distribution  aptDist
    components    ['main']
    trusted       true
  end
end

# Setup nodejs repo

execute 'node setup' do
  command 'curl -sL https://deb.nodesource.com/setup_12.x |  bash'
end

# Install apt packages
node["adminvm"]["aptPackages"].each do | aptPackage |
  apt_package aptPackage do
    package_name aptPackage
    action :install
  end
end

# Set python to python3
python_runtime 'myapp' do
  provider :system
  version '3.6'
end

# Install python packages
node["adminvm"]["pythonPackages"].each do | pythonPackage |
  python_package pythonPackage do
    action :install
  end
end

# Install remote packages
node["adminvm"]["remotePackages"].each do | packageName, packageVariables |
  if ! packageVariables["fileName"]
    remote_file "/usr/local/bin/#{packageName}" do
      source packageVariables["repo"]
      owner 'root'
      group 'root'
      mode '0775'
      action :create
    end
  else
    remote_file "/tmp/#{packageVariables["fileName"]}" do
      source packageVariables["repo"]
      owner 'root'
      group 'root'
      mode '0775'
      action :create
    end
    archive_file packageName do
      path "/tmp/#{packageVariables["fileName"]}"
      destination "/usr/local/bin/#{packageName}"
    end
  end
end

#execute gcloud commands

execute 'gcloud conf1' do
  command "gcloud config set core/disable_usage_reporting true"
end

execute 'gcloud conf2' do
  command "gcloud config set component_manager/disable_update_check true"
end