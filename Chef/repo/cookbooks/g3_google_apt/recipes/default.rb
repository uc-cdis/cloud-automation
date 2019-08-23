#
# Setup custom apt repo, then install
#

include_recipe 'g3_base_apt'

apt_repository 'google-apt-repo' do
  arch  'amd64'
  uri   'https://packages.cloud.google.com/apt'
  key   'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
  distribution "cloud-sdk-bionic"
  components ['main']
end

[ 'google-cloud-sdk', 'kubectl'].each do |name|
  package 'g3-goog-'+name do
    package_name name
  end
end

#
# Download and install heptio authenticator for EKS
#    https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
#
execute 'g3-install-heptio-auth' do
  command <<-EOF
curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
curl -o aws-iam-authenticator.sha256 https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator.sha256
openssl sha1 -sha256 aws-iam-authenticator
chmod a+rx ./aws-iam-authenticator
shouldBe="$(awk '{ print $1 }' < ./aws-iam-authenticator.sha256)"
reallyIs="$(openssl sha1 -sha256 ./aws-iam-authenticator | awk '{ print $2 }')"
result=0
if [ "$shouldBe" = "$reallyIs" ]; then
  mv ./aws-iam-authenticator /usr/local/bin/aws-iam-authenticator
else
  echo "ERROR: aws-iam-authenticator fails sha256 hash validation"
  result=1
fi
/bin/rm ./aws-iam-authenticator*
exit $result
    EOF
  cwd Chef::Config[:file_cache_path]
  creates "/usr/local/bin/aws-iam-authenticator"
end
