Seed Project is the first project created.

Once the Seed Project has been created, then create a service account.

Permissions

In order to execute this module you must have a Service Account with the following roles:

    roles/resourcemanager.folderViewer on the folder that you want to create the project in
    roles/resourcemanager.organizationViewer on the organization
    roles/resourcemanager.projectCreator on the organization
    roles/billing.user on the organization
    roles/storage.admin on bucket_project
    If you are using shared VPC:
        roles/billing.user on the organization
        roles/compute.xpnAdmin on the organization
        roles/compute.networkAdmin on the organization
        roles/browser on the Shared VPC host project
        roles/resourcemanager.projectIamAdmin on the Shared VPC host project

