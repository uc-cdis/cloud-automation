# TL;DR

This script facilitates the management of database backup and restore within the Gen3 environment. It can establish policies, service accounts, roles, and S3 buckets. Depending on the command provided, it can initiate a database dump, perform a restore, migrate databases to a new RDS instance on Aurora, or clone databases to an RDS Aurora instance.

## Usage

```sh
gen3 dbbackup [dump|restore|va-dump|create-sa|migrate-to-aurora|copy-to-aurora]
```

### Commands

#### dump

Initiates a database dump and pushes it to an S3 bucket, creating the essential AWS resources if they are absent. The dump operation is intended to be executed from the namespace/commons that requires the backup.

```sh
gen3 dbbackup dump
```

#### restore

Initiates a database restore from an S3 bucket, creating the essential AWS resources if they are absent. The restore operation is meant to be executed in the target namespace where the backup needs to be restored.

```sh
gen3 dbbackup restore
```

#### create-sa

Creates the necessary service account and roles for DB copy.

```sh
gen3 dbbackup create-sa
```

#### migrate-to-aurora

Triggers a service account creation and a job to migrate a Gen3 commons to an AWS RDS Aurora instance.

```sh
gen3 dbbackup migrate-to-aurora
```

#### copy-to-aurora

Triggers a service account creation and a job to copy the databases Indexd, Sheepdog & Metadata to new databases within an RDS Aurora cluster from another namespace <source-namespace> in same RDS cluster.

```sh
gen3 dbbackup copy-to-aurora <source-namespace>
```

