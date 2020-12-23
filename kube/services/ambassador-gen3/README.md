# TL;DR

Ambassador proxy for gen3 services.
The other ambassador deployment manages user notebooks.

## Gen3 Customization

### CSRF and Cookie to JWT

The lua scripts handle the following:
* copy the auth cookie to the Authorization header
* require CSRF header and cookie to match for POST, DELETE, PUT requests authenticated via a cookie

See `gen3 testsuite --filter lua`

### Authz

### Logging

### Monitoring

`ambassador-gen3-deploy.yaml` points ambassador at our internal `statsd-exporter` service that is in turn scraped by prometheus.

## References

* global configuration customiztion: https://www.getambassador.io/reference/core/ambassador/#lua-scripts-lua_scripts
* statsd integration: https://www.getambassador.io/reference/statistics/
* running multiple ambassador instances in same namespace: https://www.getambassador.io/reference/running/
* ambassador mappings: https://www.getambassador.io/reference/mappings/

