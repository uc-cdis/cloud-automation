### Inputs
| Name                | Description                                                                                                                                                  | Type   | Default                                              | Required |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|------------------------------------------------------|----------|
| project             | The   ID   of   the   project   in   which   the   resource   belongs.                                                                                       | String |                                                      |    yes   |
| count_compute       | The   total   number   of   instances   to   create.                                                                                                         | String |                           1                          |    yes   |
| environment         | Select   envrironment   type   of   prod   or   dev   to   change   instance   types.   Prod  =  n1-standard-1 ,  dev  =  g1-small                           | String |                          dev                         |    yes   |
| image_name          | The   name   of   a   specific   image   or   a   family.                                                                                                    | String |                    ubuntu-1604-lts                   |    yes   |
| instance_name       | A   unique   name   for   the   resource ,  required   by   GCE.   Changing   this   forces   a   new   resource   to   be   created.                        | String |                        adminvm                       |    yes   |
| compute_tags        | A   list   of   tags   to   attach   to   the   instance.                                                                                                    |  list  |                                                      |    no    |
| compute_labels      | A list of labels to attach to the instance                                                                                                                   |   map  |                                                      |    no    |
| size                | The   size   of   the   image   in   gigabytes.                                                                                                              | string |                          10                          |    no    |
| type                | The   GCE   disk   type.                                                                                                                                     | String |                        pd-ssd                        |    no    |
| auto_delete         | Whether   the   disk   will   be   auto-deleted   when   the   instance   is   deleted.   Defaults   to   true                                               | String |                         true                         |    no    |
| subnetwork_name     | Name   of   the   subnetwork   in   the   VPC.                                                                                                               | String |                                                      |    yes   |
| scopes              | A   list   of   service   scopes.                                                                                                                            |  List  | [ "userinfo-email" ,  "compute-ro" ,  "storage-ro" ] |    yes   |
| automatic_restart   | Specifies   if   the   instance   should   be   restarted   if   it   was   terminated   by   Compute   Engine  ( not   a   user ) .   Defaults   to   true. | String |                         true                         |    no    |
| on_host_maintenance | Describes   maintenance   behavior   for   the   instance.   Can   be   MIGRATE   or   TERMINATE                                                             | String |                        MIGRATE                       |    no    |
| region | Region the project resides in. | String | us-central1 | yes|                                                                                                                                                       

### Outputs

| Name       | Description                  |
|------------|------------------------------|
| private_ip | Instance private IP address. |