FROM ubuntu:bionic

USER root

# Install required deps
RUN apt update
RUN apt -y install gnupg wget apt-transport-https coreutils java-common

# Import Elasticsearch GPG Key
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

# Add Elasticsearch 6.x APT repository
# setting CPU architecture to be amd64 explicity as in case this is being built from ARM (which it should) it would find the elasticsearch package (elasticsearch 6.x doesn't have ARM binary)  
RUN echo "deb [arch=amd64] https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list

# update after elastic-search repo added
RUN apt-get update

# Install Amazon correto OpenJDK
RUN apt-get install -y --no-install-recommends curl ca-certificates gnupg software-properties-common fontconfig java-common
RUN curl -fL https://apt.corretto.aws/corretto.key | apt-key add -
RUN add-apt-repository 'deb https://apt.corretto.aws stable main'
RUN mkdir -p /usr/share/man/man1 || true
RUN apt-get update
RUN apt-get install -y java-1.8.0-amazon-corretto-jdk
RUN apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false curl gnupg software-properties-common

ENV LANG C.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-amazon-corretto

# Install Elasticsearch 6.x
RUN apt-get -y install elasticsearch

# cleanup
RUN apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false curl gnupg software-properties-common

# run as user elasticsearch
USER elasticsearch

WORKDIR /usr/share/elasticsearch

# push custom conf

RUN echo "#  --------------------------------- CUSTOM -----------------------------------"                                    >> /etc/elasticsearch/elasticsearch.yml
RUN echo ""                                                                                                                   >> /etc/elasticsearch/elasticsearch.yml
RUN echo "#  X-Pack features are not supported in ARM, disable X-Pack"                                                        >> /etc/elasticsearch/elasticsearch.yml
RUN echo "# > org.elasticsearch.bootstrap.StartupException:"                                                                  >> /etc/elasticsearch/elasticsearch.yml
RUN echo "# >   ElasticsearchException[X-Pack is not supported and Machine Learning is not available for [linux-aarch64];"    >> /etc/elasticsearch/elasticsearch.yml
RUN echo "# >   you can use the other X-Pack features (unsupported) by setting xpack.ml.enabled: false in elasticsearch.yml]" >> /etc/elasticsearch/elasticsearch.yml
RUN echo "xpack.ml.enabled: false"                                                                                            >> /etc/elasticsearch/elasticsearch.yml
RUN echo ""                                                                                                                   >> /etc/elasticsearch/elasticsearch.yml
RUN echo "# listen to requests coming from  the network"                                                                      >> /etc/elasticsearch/elasticsearch.yml
RUN echo "network.host: 0.0.0.0"                                                                                              >> /etc/elasticsearch/elasticsearch.yml


ENTRYPOINT [ "./bin/elasticsearch" ]

