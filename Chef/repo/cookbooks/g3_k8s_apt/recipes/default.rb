#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_dev_apt'

# Google apt repo
apt_repository 'google-apt-repo' do
  uri   'https://packages.cloud.google.com/apt'
  key   'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
  components ['main']
end

# Gcloud, k8s, etc
[ 'google-cloud-sdk', 'kubectl'].each do |name|
  package 'g3-k8s-'+name do
    package_name name
  end
end

# Download and install heptio authenticator for EKS
execute 'g3-install-heptio-auth' do
  command <<-EOF
  EOF
end

