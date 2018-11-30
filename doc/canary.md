# TL;DR

Deploy and manage canary services. The reverse proxy [readme](../kube/services/revproxy/README.md) has the more technical details.
When the `service_releases` cookie is included in a request, the revproxy will use the release versions it finds in the cookie.
When the cookie is not included, or for services that aren't in the cookie, revproxy uses the service weights from the manifest to determine which release version to use and sets the client's cookie with that configuration.

## Use

To change the branch a canary service is pointing to, just edit the `<service>-canary` in the manifest. Then `gen3 roll <service>-canary`

To change the probability that a client is directed to the canary service:
* update the service's value in the `canary` section of the manifest (e.g. `.canary.fence: 50`). Provide an integer between 0 and 100, where 0 means 0% of clients are directed to the canary, and 100 means 100% of the clients are directed to the canary service
* deploy the reverse proxy, run `gen3 kube-setup-revproxy`

If the weight is set to `0` for a service, the `service_releases` cookie is ignored and the production release is used.
