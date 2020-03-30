# How to set up dev env to get pre-signed URLs from AWS and Google


## Set up URLs and ACLs in relevant Indexd record:
 - Whatever Indexd record it is for whose file you are trying to generate a signed URL, it needs to have URLs and ACLs set up
 - Can check Indexd record using `/index/index/{GUID}`; here are the [Indexd Swagger docs](http://petstore.swagger.io/?url=https://raw.githubusercontent.com/uc-cdis/indexd/master/openapis/swagger.yaml). Use `PUT` `/index/{GUID}` to edit  a record or `POST` `/index/index` to make a new record.
 - You can also look at/edit `index_record_ace` and `index_record_url` in the Indexd db (`gen3 psql indexd`), but editing the database directly is generally a bad idea, and you should prefer using the Indexd endpoints.
 - Make sure that the `acl` field includes `DEV`, `test`, or some other Project.auth_id that you have access to (based on the user yaml)
 - Then, URLs field should have URLs for each of the relevant protocols--in the DCF case, s3 and gs
   - Example gs url: `gs://dcf-integration-test/file.txt`
   - Example s3 url: `s3://cdis-presigned-url-test/testdata`
   - (You kind of just have to know about these urls; there's not really a way to "discover" them)
 - Fun exercise: Try to access above file as though it were public: 
   https://storage.googleapis.com/dcf-integration-test/file.txt
   Should get access denied.

## Link a Google bucket to Fence:
- Can reuse an existing bucket that's set up for the DCF integration tests (`dcf-integration-test`): 
- Exec into the Fence pod in your env (`kubectl exec -it $(gen3 pod fence) bash`)...
- ... and run 
  `fence-create google-bucket-create --unique-name dcf-integration-test --google-project-id dcf-integration --project-auth-id test --public False`
- This should create a bucket, link it to the `test` Project.auth_id, and then create some Google Bucket Access Groups (all in the Fence db). 


## Do a usersync:
- Check [user yaml](https://github.com/uc-cdis/commons-users/blob/master/users/dev/user.yaml) for dev envs; make sure your email is in it and that it has access to `test`, `DEV`, `QA` Project.auth_ids 
- For DCF stuff you will need `read-storage` privilege
- If all that checks out then `gen3 job run usersync`
- Can check output: `gen3 joblogs usersync`. Should see stuff about adding people to google groups.



## Try it out: 
 - Having set all that up, you should be able to hit `/user/data/download/GUID?protocol=gs` using your record's GUID, and Fence should generate a signed URL which you can use to see the file. (use gs parameter only if desired)


## Troubleshooting: 
- Inspecting the Fence db (`gen3 psql fence`):
- Check that the right bucket is associated with the right Project.auth_id: 
```sql
select bucket.name, project.auth_id, google_bucket_access_group.email from project_to_bucket INNER JOIN project ON project.id=project_to_bucket.project_id INNER JOIN bucket ON bucket.id=project_to_bucket.bucket_id INNER JOIN google_bucket_access_group ON bucket.id=google_bucket_access_group.bucket_id ORDER BY project.auth_id;
```
- Check that your user is associated with the right Project.auth_id: 
```sql
select "User".username, project.auth_id from access_privilege INNER JOIN "User" on access_privilege.user_id="User".id INNER JOIN project on access_privilege.project_id=project.id ORDER BY "User".username;
```
- Check that your user is in the right GBAG:
  `select * from google_proxy_group_to_google_bucket_access_group;`
