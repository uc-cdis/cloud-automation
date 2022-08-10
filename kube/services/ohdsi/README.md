# Deploying Atlas

## `ConfigMap`s

### `webapi.conf` file as `ohdsi-atlas-nginx-webapi`

```
kubectl create configmap ohdsi-atlas-nginx-webapi --from-file=webapi.conf
```

```
    resolver kube-dns.kube-system.svc.cluster.local ipv6=off;

    location /WebAPI/ {
        set $proxy_service  "ohdsi-webapi";
        # upstream is written to logs
        set $upstream http://ohdsi-webapi-service.qa-mickey.svc.cluster.local;
        # rewrite ^/ohdsi-webapi/(.*) /$1 break;
        proxy_pass $upstream;
        proxy_set_header Host atlas-qa-mickey.planx-pla.net;
        proxy_redirect http://atlas-qa-mickey.planx-pla.net/ https://atlas-qa-mickey.planx-pla.net/;
        client_max_body_size 0;
    }
```

### store `config-local.js` file as `ohdsi-atlas-config-local` configmap

See `./config-local.js` in this folder. Add it as a configmap using:

```
kubectl create configmap ohdsi-atlas-config-local --from-file=config-local.js
```


### `ohdsi-webapi-config.yaml`

```
kubectl apply -f ohdsi-webapi-config.yaml
```

```
apiVersion: v1
kind: Secret
metadata:
  name: ohdsi-webapi-config
type: Opaque
stringData:
  datasource_driverClassName: org.postgresql.Driver
  datasource_url: jdbc:postgresql://<db_hostname>:5432/<db_name>
  datasource_ohdsi_schema: ohdsi
  datasource_username: <db_username>
  datasource_password: <db_password>
  spring_jpa_properties_hibernate_default_schema: ohdsi
  spring_jpa_properties_hibernate_dialect: org.hibernate.dialect.PostgreSQLDialect
  spring_batch_repository_tableprefix: ohdsi.BATCH_
  flyway_datasource_driverClassName: org.postgresql.Driver
  flyway_datasource_url: jdbc:postgresql://<db_hostname>:5432/<db_name>
  flyway_schemas: ohdsi
  flyway_placeholders_ohdsiSchema: ohdsi
  flyway_datasource_username: <db_username>
  flyway_datasource_password: <db_password>
  flyway_locations: classpath:db/migration/postgresql
  # Zoe testing Atlas-Fence
  security_cors_enabled: "true"
  security_origin: "*"
  security_token_expiration: "43200"
  security_ssl_enabled: "false"

#  security_provider: DisabledSecurity
  security_provider: AtlasRegularSecurity

  security_auth_windows_enabled: "false"
  security_auth_kerberos_enabled: "false"
  security_auth_openid_enabled: "true"
  security_auth_facebook_enabled: "false"
  security_auth_github_enabled: "false"
  security_auth_google_enabled: "false"
  security_auth_jdbc_enabled: "false"
  security_auth_ldap_enabled: "false"
  security_auth_ad_enabled: "false"
  security_auth_cas_enabled: "false"

  security_db_datasource_schema: security
  security_db_datasource_url: jdbc:postgresql://<db_hostname>:5432/<db_name>
  security_db_datasource_driverClassName: org.postgresql.Driver
  security_db_datasource_username: <db_username>
  security_db_datasource_password: <db_password>

  security_oid_clientId: <oid_clientid>
  security_oid_apiSecret: <oid_secret>
  security_oid_url: https://<url>/.well-known/openid-configuration
  security_oid_redirectUrl: https://<atlas_url>/atlas/#/welcome
  security_oid_logoutUrl: https://<atlas_url>/atlas/#/home

  security_oauth_callback_ui: https://<atlas_url>/atlas/#/welcome
  security_oauth_callback_api: https://<atlas_url>/WebAPI/user/oauth/callback
  security_oauth_callback_urlResolver: query

  logging_level_root: info
  logging_level_org_ohdsi: info
  logging_level_org_apache_shiro: info
```

## Making changes and redeploying to QA

Example: we have some changes in `kube/services/ohdsi-atlas/config-local.js`.

To redeploy to QA, follow these steps:
- delete old configmap `kubectl delete configmap ohdsi-atlas-config-local`
- get a copy of `config-local.js` into the current folder
- run the `kubectl create configmap ohdsi-atlas-config-local --from-file=config-local.js` on QA server
- assess results with `kubectl describe configmap ohdsi-atlas-config-local`
- and then restart Atlas with `gen3 roll ohdsi-atlas`
- watch pod status with `kubectl get pods -l app=ohdsi-atlas`

To clear the browser cache (when making .js changes):
- go to https://atlas-qa-mickey.planx-pla.net/atlas/js/config-local.js and force-reload it to clear old code from browser cache
