FROM quay.io/cdis/golang:1.20-bullseye as build-deps

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

WORKDIR $GOPATH/src/github.com/uc-cdis/node-affinity-daemonset/

COPY node-affinity-daemonset/* .

RUN go mod download

RUN  go build -o /webhook

FROM scratch
COPY --from=build-deps /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build-deps /webhook /webhook
CMD ["/webhook"]