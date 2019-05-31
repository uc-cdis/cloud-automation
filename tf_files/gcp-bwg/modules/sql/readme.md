# Terraform Module - GCP Private IP Cloud SQL

## Known Issues
There's a known issue. First time creation of the resources works but it does not work after deleting and trying to recreate. Error message you may receive is "google_service_networking_connection error: Cannot modify allocated ranges in CreateConnection..."

### Workaround
Manually fixing the VPC peering is the best option. Below are the commands to run from the gcloud console:

```bash
gcloud beta services vpc-peerings update \
    --service=servicenetworking.googleapis.com \
    --ranges=cloudsql-private-ip-address \
    --network=sandbox-net \
    --project=sandbox-XXXXX \
    --force
```


## Inputs

| Name                            | Description                                                                                                                                                    | Type   | Default                     | Required |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|-----------------------------|----------|
| project_id                      | The project ID to manage the Cloud  SQL resources.                                                                                                             | String | -                           | yes      |
| name                            | The name of the Cloud SQL resources.                                                                                                                           | String | ""                          | no       |
| region                          | The region the instance will sit in.                                                                                                                           | String | us-central1                 | yes      |
| database_version                | The database version to use.                                                                                                                                   | String | POSTGRES_9_6                | no       |
| tier                            | The tier for the master instance.Postgres support  only shared-core machine types such as db-f1-micro                                                          | String | db-f1-micro                 | yes      |
| availability_type               | The availability type for the master instance.This is only used to set up high availability for the PostgreSQL  instance. Can be either `ZONAL` or `REGIONAL`. | String | ZONAL                       | no       |
| backup_enabled                  | True if backup configuration is enabled.                                                                                                                       | String | true                        | no       |
| backup_start_time               | HH:MM format time indicating when  backup configuration starts.                                                                                                | String | 02:00                       | no       |
| disk_autoresize                 | Configuration to increase storage size.                                                                                                                        | String | true                        | no       |
| disk_size                       | The disk size for the master instance.                                                                                                                         | String | 10                          | no       |
| disk_type                       | The type of data disk: PD_SSD or PD_HDD.                                                                                                                       | String | PD_SSD                      | no       |
| maintenance_window_day          | The day of week (1-7) for the master instance maintenance.                                                                                                     | String | 7                           | no       |
| maintenance_window_hour         | The hour of day (0-23) maintenance window for the master   instance maintenance.                                                                               | String | 2                           | no       |
| maintenance_window_update_track | The update track of maintenance window for the master  instance maintenance.Can  be either `canary` or `stable`.                                               | String | stable                      | no       |
| user_labels                     | The key/value labels for the master instances.                                                                                                                 | Map    | {}                          | no       |
| ipv4_enabled                    | Whether this Cloud SQL instance should be assigned a public IPV4 address.                                                                                      | String | false                       | no       |
| network                         | Network name inside of the VPC.                                                                                                                                | String | default                     | no       |
| authorized_networks             | Allowed networks to connect to this sql instance.                                                                                                              | List   | []                          | no       |
| activation_policy               | This specifies when the instance should be active. Can be  either ALWAYS, NEVER or ON_DEMAND.                                                                  | String | ALWAYS                      | no       |
| db_name                         | The name of the default database to create.                                                                                                                    | List   | []                          | no       |
| user_name                       | The name of the default user.                                                                                                                                  | String | postgres-user               | no       |
| user_host                       | The host for the default user.This is only supported for  MySQL instances.                                                                                     | String | ""                          | no       |
| user_password                   | The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable.                    | String | ""                          | no       |
| global_address_name             | Name of the global address resource.                                                                                                                           | String | cloudsql-private-ip-address | yes      |
| global_address_purpose          | The purpose of the resource.VPC_PEERING - for peer networks.                                                                                                   | String | VPC_PEERING                 | yes      |
| global_address_type             | The type of the address to reserve. Use External or Internal. Default is Internal.                                                                             | String | INTERNAL                    | yes      |
| global_address_prefix           | The prefix length of the IP range. Not applicable if address type = EXTERNAL."                                                                                 | String | 16                          | yes      |

## Outputs
| Name                            | Description                                                                  |
|---------------------------------|------------------------------------------------------------------------------|
| user_password_url               | The generated id presented in base64,  using the URL-friendly character set. |
| user_password_std               | The generated id presented in base64 without additional transformations.     |
| sql_instance_database_self_link | The URI of the created database resource.                                    |
| sql_instance_self_link          | The URI of the created instance resource.                                    |
| sql_instance_connection_name    |                                                                              |
| service_account_email_address   | The service account email address assigned to the instance.                  |
| ip_address_0_ip_address         | The IPv4 address assigned.                                                   |
| user_name                       |                                                                              |