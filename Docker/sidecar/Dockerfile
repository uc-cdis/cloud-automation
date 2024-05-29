FROM nginx:1-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY uwsgi.conf.template /etc/nginx/gen3.conf.d/uwsgi.conf.template
COPY dockerrun.sh /usr/local/gen3/dockerrun.sh
#
# Just a placeholder self-signed cert for testing
# Mount a proper cert in production
#
COPY service.key /mnt/ssl/service.key
COPY service.crt /mnt/ssl/service.crt

WORKDIR /usr/local/gen3

EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/bin/sh", "/usr/local/gen3/dockerrun.sh"]
CMD []
