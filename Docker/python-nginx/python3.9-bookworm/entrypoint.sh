#!/usr/bin/env sh
set -e

rate_limit=""
if [ ! -z $NGINX_RATE_LIMIT ]; then
  echo "Found NGINX_RATE_LIMIT environment variable..."
  if [ ! -z $OVERRIDE_NGINX_RATE_LIMIT ]; then
    rate_limit=$OVERRIDE_NGINX_RATE_LIMIT
    echo "Overriding Nginx rate limit with new value ${rate_limit}..."
  else
    rate_limit=$NGINX_RATE_LIMIT
    echo "Applying Nginx rate limit from k8s deployment descriptor..."
  fi

  # Add rate_limit config
  rate_limit_conf="\ \ \ \ limit_req_zone \$binary_remote_addr zone=one:10m rate=${rate_limit}r/s;"
  sed -i "/http\ {/a ${rate_limit_conf}" /etc/nginx/nginx.conf
  if [ -f /etc/nginx/sites-available/uwsgi.conf ]; then
    limit_req_config="\ \ \ \ \ \ \ \ limit_req zone=one;"
    sed -i "/location\ \/\ {/a ${limit_req_config}" /etc/nginx/sites-available/uwsgi.conf
  fi
fi

# Get the maximum upload file size for Nginx, default to 0: unlimited
USE_NGINX_MAX_UPLOAD=${NGINX_MAX_UPLOAD:-0}
# Generate Nginx config for maximum upload file size
echo "client_max_body_size $USE_NGINX_MAX_UPLOAD;" > /etc/nginx/conf.d/upload.conf

# Explicitly add installed Python packages and uWSGI Python packages to PYTHONPATH
# Otherwise uWSGI can't import Flask
export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python3.6/site-packages:/usr/lib/python3.6/site-packages

# Get the number of workers for Nginx, default to 1
USE_NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-1}
# Modify the number of worker processes in Nginx config
sed -i "/worker_processes\s/c\worker_processes ${USE_NGINX_WORKER_PROCESSES};" /etc/nginx/nginx.conf

# Set the max number of connections per worker for Nginx, if requested
# Cannot exceed worker_rlimit_nofile, see NGINX_WORKER_OPEN_FILES below
if [ -n "$NGINX_WORKER_CONNECTIONS" ] ; then
    sed -i "/worker_connections\s/c\    worker_connections ${NGINX_WORKER_CONNECTIONS};" /etc/nginx/nginx.conf
fi

# Set the max number of open file descriptors for Nginx workers, if requested
if [ -n "$NGINX_WORKER_OPEN_FILES" ] ; then
    echo "worker_rlimit_nofile ${NGINX_WORKER_OPEN_FILES};" >> /etc/nginx/nginx.conf
fi

# Get the listen port for Nginx, default to 80
USE_LISTEN_PORT=${LISTEN_PORT:-80}
# Modify Nignx config for listen port
if ! grep -q "listen ${USE_LISTEN_PORT};" /etc/nginx/nginx.conf ; then
    sed -i -e "/server {/a\    listen ${USE_LISTEN_PORT};" /etc/nginx/nginx.conf
fi
exec "$@"
