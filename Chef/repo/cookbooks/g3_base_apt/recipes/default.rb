#
# apt install a bunch of random stuff ...
#

['apt-transport-https', 'curl', 'lsb-release', 'software-properties-common'].each do |name|
  package 'g3-base-'+name do
    package_name name
  end
end
