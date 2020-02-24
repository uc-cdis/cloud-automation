FROM ubuntu:18.04

WORKDIR /inspec

MAINTAINER Rodney Bizzell

RUN yum update -y \
    && yum install -y python3 python3-libs python3-devel python3-pip dnf \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN ln -s /usr/bin/pip3 /usr/bin/pip 
RUN unlink /usr/bin/python
# python must be pointing to python3.6
RUN ln -s /usr/bin/python3.6 /usr/bin/python
#RUN dnf install python3-pip
RUN pip install awscli 
RUN curl https://omnitruck.chef.io/install.sh |  bash -s -- -P inspec
RUN inspec plugin install train-aws --chef-license accept


COPY uchi-inspec.sh uchi-inspec.sh

COPY uchi-inspec-policy uchi-inspec-policy

ENTRYPOINT ["/bin/sh","/inspec/uchi-inspec.sh"]
