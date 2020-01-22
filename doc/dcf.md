# TL;DR

Those Gen3 commands are used to generate data refresh reports, augmented manifests and validate the data refresh

## Use

* `gen3 dcf aws-refresh DR16 legacy`

  generate aws data refresh report for the data release 16 legacy manifest

* `gen3 dcf validate-aws-refresh DR16 legacy`

  run validation of aws data refresh for the DR16 legacy manifest

* `gen3 dcf google-refresh DR16 legacy`

  generate google data refresh report for the DR16 legacy manifest

* `gen3 dcf validate-google-refresh DR16 legacy`

  run validation of google data refresh for the DR16 legacy manifest

* `gen3 dcf generate-augmented-manifest DR16 legacy`

  Generate augmented dcf manifest for data release 16 legacy manifest

* `gen3 dcf redaction DR16`

  Generate redaction report for data release 16

* `gen3 dcf create-google-bucket gdc-target-phsxxx-controlled phsxxx controlled`

  Create controlled GS bucket with phsxxx
