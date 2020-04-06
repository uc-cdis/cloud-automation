# Potential Useful SQL Queries

## Fence Database

### Get All User Access by Username and Project.auth_id
```sql
select "User".username, project.auth_id from access_privilege INNER JOIN "User" on access_privilege.user_id="User".id INNER JOIN project on access_privilege.project_id=project.id ORDER BY "User".username;
```

Example output:
```console
             username             |  auth_id
----------------------------------+-----------
 USER_A                           | test1
 USER_A                           | test2
 USER_B                           | test1
 USER_B                           | test2
 USER_B                           | test3
 USER_C                           | test2

```

### Get Bucket Name(s) and Google Bucket Access Groups associated with Project.auth_id
Particularly useful with commons that have buckets in Google.

```sql
select bucket.name, project.auth_id, google_bucket_access_group.email from project_to_bucket INNER JOIN project ON project.id=project_to_bucket.project_id INNER JOIN bucket ON bucket.id=project_to_bucket.bucket_id INNER JOIN google_bucket_access_group ON bucket.id=google_bucket_access_group.bucket_id ORDER BY project.auth_id;
```

Example output:
```console
                 name                    |  auth_id  |                                 email                            
-----------------------------------------+-----------+-------------------------------------------------------------------
 test-bucket-with-data                   | test      | test-bucket-with-data_read_gbag@test.datacommons.io
 test-bucket-with-data                   | test      | test-bucket-with-data_write_gbag@test.datacommons.io
```

### Get Registered Google Service Account(s) Project Access and Expiration
To determine which user service accounts currently have access to controlled data (and their associated Google Project).

```sql
SELECT DISTINCT user_service_account.google_project_id, user_service_account.email, project.auth_id, service_account_to_google_bucket_access_group.expires from service_account_to_google_bucket_access_group
INNER JOIN user_service_account ON service_account_to_google_bucket_access_group.service_account_id=user_service_account.id
INNER JOIN service_account_access_privilege ON user_service_account.id=service_account_access_privilege.service_account_id
INNER JOIN project ON service_account_access_privilege.project_id=project.id ORDER BY user_service_account.google_project_id;
```

Example output:
```console
  google_project_id   |                               email                               |  auth_id  |  expires   
----------------------+-------------------------------------------------------------------+-----------+------------
 tmp-test             | 1234567890-compute@developer.gserviceaccount.com                  | test1     | 1543254638
 tmp-test             | test-service-account@tmp-test.iam.gserviceaccount.com             | test2     | 1543254614
 tmp-test             | test-service-account@tmp-test.iam.gserviceaccount.com             | test1     | 1543254614
 foobar               | blahblahblahb@foobar.iam.gserviceaccount.com                      | test1     | 1543254897

 
```

## Arborist Database 

### Get access by username and resource paths

```sql
SELECT policies.name, path FROM (SELECT * FROM usr INNER JOIN usr_policy ON usr_policy.usr_id = usr.id WHERE usr.name = 'test@gmail.com') AS policies JOIN policy_resource ON policy_resource.policy_id = policies.policy_id JOIN resource ON resource.id = policy_resource.resource_id;
```

Replace `test@gmail.com` with whatever, or just remove the WHERE to get everything. This will *not* include policies granted by a user's group membership.

Example output: 
```
          name           |               path
-------------------------+----------------------------------
 test@gmail.com          | workspace
 test@gmail.com          | prometheus
 test@gmail.com          | data_file
 test@gmail.com          | programs.jnkns
 test@gmail.com          | programs.jnkns.projects.jenkins
```
