# cdis_admin_vm

## What is it

This cookbook is used to setup adminvm's. It has a few recipes that can be used for multiple adminvm maintenance actions. The default recipe is used to setup users and ssh keys. The apt recipe is used to do an apt update. The workvm recipe is meant to replace the kube-setup-workvm script. 

## Prerequisites

To use this cookbook you will need chef/chef-zero installed and configured. To do this you will need to install chef/chef-zero first. You can do this by running,

```bash
curl -L https://omnitruck.chef.io/install.sh | sudo bash
sudo gem install chef-zero
```

You may run into an issue installing chef-zero on an adminvm due to the ruby version. If this happens update ruby through apt.

```bash
sudo apt-get install ruby2.5-dev
```

After this is complete you can create the necessary configuration files. You will need a client.rb file to run chef-client and a knife.rb file to upload/modify files from the local chef-zero server. To do this create a folder in your home directory called .chef and create a client.rb and knife.rb file with contents similar to the templates below.

client.rb

```bash
node_name 'adminvm'
cookbook_path '/home/<username>/cloud-automation/Chef/repo/cookbooks'
data_bag_path '/home/<username>/cloud-automation/Chef/repo/data_bags'
environment_path '/home/<username>/cloud-automation/Chef/repo/environments'
role_path '/home/<username>/cloud-automation/Chef/repo/roles'
chef_server_url 'http://127.0.0.1:8889'
log_level :info
log_location '/home/<username>/.chef/chef-client.log'
verify_api_cert false
treat_deprecation_warnings_as_errors false
client_key   '/home/<username>/.chef/key.pem'
```

knife.rb

```bash
chef_server_url   'http://127.0.0.1:8889'
node_name         'adminvm'
client_key        '/home/<username>/.chef/key.pem'
knife[:supermarket_site] = 'https://supermarket.chef.io'
```

As you may have also noticed there is a private key file referenced. Chef zero requires a private key to work. To create this key you can run the following command,

```bash
openssl genrsa -out /home/<username>/.chef/key.pem 2048
```

After this is setup you can start the chef-zero server.

```bash
sudo chef-zero -d
```

Once it is up and running you should upload the cookbooks/roles/environments/databags to the node using knife. 

```bash
knife upload / -c /home/<username>/.chef/client.rb
```

After this has been completed chef is fully configured and ready to work.

## How to use it

Because we are not using a traditional chef server we will need to run this with chef solo/zero. To do this you will first need to install and configure chef/chef-zero to use the local cookbooks in cloud-automation. Once that is completed you can run this to run a role defined in the chef-repo 

```bash
sudo chef-client -o "role['<role for adminvm>']" -c /home/<username>/.chef/client.rb
```

If you would simply like to run a recipe from a cookbook, such as an apt update recipe, you can run

```bash
sudo chef-client -o "<cookbook name>::<recipe name>" -c /home/<username>/.chef/client.rb
```

## How to test the cookbook

To test the cookbooks we will use kitchen. Kitchen will stand up an environment, run chef client and run a series of defined tests. Kitchen can use a variety of testing suites, vm platforms and os's which can all be defined in the kitchen.yml file. It is currently set to use ubuntu 18.04 images, inspec tests and run on vagrant/virtualbox. To run these tests you will need to install vagrant/virtualbox, go into the root directory of the cookbook and run kitchen test. Kitchen test will provision the vm's run chef client, run the tests and then destroy the vm's. If you run into issues you can run kitchen converge, to run chef, and then kitchen verify to run the tests and play around until you get the expected output. Once you are done though you should run a full kitchen test to ensure that the tests run successfully on the first chef-client run.

## How to setup the roles

The roles contain attributes that can be used by the cookbook to define what the node should look like after chef-client is run. The attributes can be found in the attributes section of the README or the attributes/default.rb file. The role should be a valid json with a name variable, that matches the name of the role file, a default attributes block, which contains attributes that can be used to define the cookbook values, and a runlist that defines the cookbooks/recipes you would like to use.

## How to setup the databags

This cookbooks requires a few databags with lists of ssh keys. There is a dev, qa and admin databag which should contain the list of ssh keys for each group. These will be used by the default recipe to add the correct set of ssh keys to the right users, which will be defined in the roles file. 

## Attributes

The attributes that can be set by the cookbook. They are defined in the attributes/default.rb file.

Attribute      | Description                                                                                                                                                         | Type    
-------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------
devUsers       | The list of users that will have dev ssh access | Array
adminUsers     | The list of users that will have dev ssh access | Array
aptPackages    | The list of packages that need to be installed through apt | Array
pythonPackages | The list of packages that need to be installed through pip | Array
aptRepos       | The list of repos that need to be setup for the apt packages | Hash
remotePackages | A list of executable packages that need to be downloaded, extracted and installed | Hash
