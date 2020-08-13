FROM nginx/nginx-prometheus-exporter:0.8.0

COPY sleep_infinity.go ./
RUN go build -ldflags "-linkmode external -extldflags -static" -o /usr/bin/sleep_infinity.go

ENTRYPOINT ["/usr/bin/sleep_infinity"]
