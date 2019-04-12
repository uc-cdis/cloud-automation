#
# Setup custom apt repo, then install
#

include_recipe 'g3_base_apt'

apt_repository 'google-apt-repo' do
  uri   'https://packages.cloud.google.com/apt'
  key   'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
  components ['stable']
end


[ 'google-cloud-sdk', 'kubectl'].each do |name|
  package 'g3-goog-'+name do
    package_name name
  end
end
