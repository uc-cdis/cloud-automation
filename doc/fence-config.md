# Fence config helper
Little helper to split/merge fence configs, or delete/extract/replace secrets from fence configs

## Use

* `gen3 fence-config extract-secrets [input-yaml-path] [output-json-path] [secret-template-yaml]`

  Generate secrets file - Extract secrets and output into a JSON file.
  Those secrets listed in template (by default $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml) will be extracted and output to a JSON file.
  * `input-yaml-path` required: yaml config to extract secrets from
  * `output-json-path` required: the generated secret JSON file path
  * `secret-template-yaml` optional: the secret template, by default: $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml

* `gen3 fence-config remove-secrets [input-yaml-path] [output-yaml-path] [secret-template-yaml]`

  Generate public file - Delete secrets and output into a yaml file, without losing comments. 
  Those secrets listed in template (by default $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml) will be erased.
  * `input-yaml-path` required: YAML config for input
  * `output-yaml-path` required: the generated public YAML file path
  * `secret-template-yaml` optional: the secret template, by default: $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml

* `gen3 fence-config merge [input-secret-config] [input-public-config] [output-path]`

  Merge secret fence config and public fence config into default config. 
  Order could change, but the latter config will always override the former config. 
  We use defaut fence config from: https://raw.githubusercontent.com/uc-cdis/fence/master/fence/config-default.yaml. 
  * `input-secret-config` required: YAML config for input
  * `input-public-config` required: the generated public YAML file path
  * `output-path` optional: the output path, by default: ./merged-config.yaml

* `gen3 fence-config split [input-config-yaml-path] [output-public-yaml] [output-secret-json]`

  Split a fence config into public yaml config and secret json config. 
  Just a combination of `gen3 fence-config extract-secrets` and `gen3 fence-config remove-secrets`.
  Use default fence secret template $GEN3_HOME/gen3/lib/fence/fence-secret-config-template.yaml
  * `input-config-yaml-path` required: YAML config for input
  * `output-public-yaml` required: the generated public YAML config path
  * `output-secret-json` required: the generated secret JSON config path

* `gen3 fence-config replace [input-config-yaml-path] [new-config-yaml-path] [output-yaml-path]`

  Read configs in [input-config-yaml-path] and replace with the configs in [new-config-yaml-path], and output to [output-yaml-path]
  * `input-config-yaml-path` required: the input YAML config
  * `new-config-yaml-path` required: YAML config to replace with
  * `output-yaml-path` required: the generated YAML config path
