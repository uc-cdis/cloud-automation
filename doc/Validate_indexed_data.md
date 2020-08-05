# Sanity check for the indexed data 
Endpoint to verify data got indexed: ```<commons_url>/index/index/<prefix>/<GUID from the manifest>```
Example: ```<commons_url>/index/dg.4DFC/0ef66e31-3218-4994-a85b-4e3e15b39bd8```

# Verify we would be able to download the file 
1. Use or get the client ID/secret.

2. ```curl -v "<commons_url>/user/oauth2/authorize?response_type=code&client_id=<$client_id>&scope=openid+user+data&redirect_uri=https://<commons_url>/"```
this request should redirect you to the login---get the `Location` it sends you to and open in a browser

do the login stuff

after logging in it should send you to a URL something like this: ```<commons_url>/?code=ABCD...```
The code is what we want for the next step. let's say that'll be $code

3. ```curl -v -X POST --user $client:$secret "<commons_url>/user/oauth2/token?code=$code&grant_type=authorization_code&client_id=$client&redirect_uri=<commons_url>"```
This request should actually give you the set of tokens and we will need access token. 

4. Download data 

```curl -v -H "Authorization: Bearer $access_token "<commons_url>/user/data/download/{whatever GUID you want}"```
