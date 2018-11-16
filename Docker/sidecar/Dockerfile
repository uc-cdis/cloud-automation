FROM nginx:1.15.6-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY uwsgi.conf /etc/nginx/conf.d/default.conf.template

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
