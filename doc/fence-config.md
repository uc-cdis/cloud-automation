# Fence config helper
Little helper to split/merge fence configs, or delete/extract/replace secrets from fence configs

## Use

* `gen3 fence-config extract-secrets [input-yaml-path] [output-json-path]`

  Extract secrets and output into a JSON file

* `gen3 fence-config remove-secrets [input-yaml-path] [output-yaml-path]`

  Delete secrets and output into a yaml file, without losing comments. 
  Those secrets listed in $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml will be erased.

* `gen3 fence-config remove-secrets-by-template [input-yaml-path] [output-yaml-path] [secret-template-json-path]`
  
  Delete secrets and output into a yaml file using customized template. 

* `gen3 fence-config override [input-yaml-path] [output-yaml-path]`

  Override a default fence config. 
  Default fence config link: https://raw.githubusercontent.com/uc-cdis/fence/master/fence/config-default.yaml. 
  
* `gen3 fence-config merge [input-secret-config] [input-public-config]`

  Merge secret fence config and public fence config into default config. 
  Order could change, but the latter config will always overrider the former config. 
  
* `gen3 fence-config split`
  
  Split a fence config into secret json and public config. 
  Just a combination of `gen3 fence-config extract-secrets` and `gen3 fence-config remove-secrets`. 
