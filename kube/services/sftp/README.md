## SFTP
SFTP server for testing. SFTP runs in a separate namespace called `sftp`. You need to switch to the new namespace when running kubectl. The new namespace require another AWS Certificate.

### Run sftp service
- run `bash tf_files/configs/kube-setup-sftp.sh $VPC_NAME`
- update Route53 Hosted Zones point to the link gotten from the previous command
