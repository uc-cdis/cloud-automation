FROM quay.io/cdis/golang-build-base:master as base

ARG TARGETOS
ARG TARGETARCH

ENV appname=someapp

ENV CGO_ENABLED=0
ENV GOOS=${TARGETOS}
ENV GOARCH=${TARGETARCH}

FROM base as builder
RUN dnf install -y go \
    && dnf clean all \
    && rm -rf /var/cache/yum/

WORKDIR $GOPATH/src/github.com/uc-cdis/node-affinity-daemonset/

COPY node-affinity-daemonset/* .

RUN go mod download

RUN  go build -o /webhook

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /webhook /webhook
CMD ["/webhook"]