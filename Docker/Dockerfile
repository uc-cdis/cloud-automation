FROM     centos:centos7

WORKDIR /inspec


MAINTAINER Rodney Bizzell

RUN yum update -y \
    && yum install -y https://centos7.iuscommunity.org/ius-release.rpm \
    && yum install -y python36u python36u-libs python36u-devel python36u-pip \ yum install -y dnf \
    && yum clean all && \
    rm -rf /var/cache/yum



RUN pip3.6 install  --upgrade
RUN ln -s /usr/bin/pip3.6 /bin/pip
RUN rm /usr/bin/python
# python must be pointing to python3.6
RUN ln -s /usr/bin/python3.6 /usr/bin/python
RUN dnf install python3-pip
RUN pip3 install awscli  --upgrade
RUN curl https://omnitruck.chef.io/install.sh |  bash -s -- -P inspec
RUN inspec plugin install train-aws --chef-license accept


COPY uchi-inspec.sh uchi-inspec.sh

COPY uchi-inspec-policy uchi-inspec-policy

ENTRYPOINT ["/bin/sh","/inspec/uchi-inspec.sh"]

