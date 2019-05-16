# TL;DR

Chef cookbooks, etc for various deployments

## Install Chef

Install chef-client on Debian/Ubuntu:
   https://docs.chef.io/packages.html

```
bash installClient.sh
```

## Chef repo structure

https://docs.chef.io/chef_repo.html
```
chef generate repo little-repo
```

## Run chef-client in "zero" mode

```
sudo /bin/rm -rf nodes && sudo chef-client --local-mode --node-name littlenode --override-runlist 'role[example]' --why-run -l debug
```

or running as root:

```
/bin/rm -rf nodes && chef-client --local-mode --node-name littlenode --override-runlist 'role[example]' --why-run -l debug
```

Running `chef-client` generates a `nodes/` folder owned by `root`, so
we recommend that you install the repo to a folder owned by `root`.

Ex:
```
sudo su # as root
mkdir -p /var/lib/gen3
cd /var/lib/gen3
git clone https://github.com/uc-cdis/cloud-automation.git
cd cloud-automation/Chef/repo

# run chef-client commands here
```

## littleware roles

### dev

ubuntu18 developer machine

* nodejs
* nodejs
* python3
* psql postgres client
* docker
* aws cli
* gcloud sdk

### desktop

ubuntu18 desktop

## Chef and immutable infrastructure

Chef has traditionally been associated with patching long lived virtual and hardware machines, but Chef also lends itself well to building immutable artifacts working with tools like docker files and packer.  For example - a standard docker image build process might simply install a chef role onto a standard base image.
