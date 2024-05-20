FROM golang:1.21.8-alpine as build-deps

RUN apk update && apk add --no-cache git gcc curl bash

# get nginxinc/nginx-prometheus-exporter and pull latest release/tag
RUN git clone https://github.com/nginxinc/nginx-prometheus-exporter.git \
    && cd nginx-prometheus-exporter \
    && git pull origin master \
    && git fetch --tags \
    && tag=$(git describe --tags `git rev-list --max-count=1 --tags`) \
    && git checkout $tag -b latest

RUN cd nginx-prometheus-exporter \
    && GO111MODULE=on CGO_ENABLED=0 GOOS=linux go build -mod=vendor -a -installsuffix cgo -o /usr/bin/exporter .

USER 1001:1001

ENTRYPOINT ["/usr/bin/exporter"]
