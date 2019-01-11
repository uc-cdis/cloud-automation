#!/bin/bash


# We need to list all the existing volumes related to Jupyter, usually named pvc-"[Aa0-zZ9]?-*", and we have to rule out the one for the deployment.
# Then we should create snapshots for those volumens 
# kubectl get persistentvolume --kubeconfig fauziv1/kubeconfig-KUBE_AWS -o name |cut -d/ -f2 |grep -v pvc-5a172428-d643-11e8-82ba-0e3bbdfa5f60 |while read i; do aws ec2 create-snapshot --description "SS-${i}" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=${i}}]" --volume-id $(kubectl --kubeconfig fauziv1/kubeconfig-KUBE_AWS get persistentvolume -o yaml --export $i |yq -r .spec.awsElasticBlockStore.volumeID | awk -F/ '{print $NF}'); done

# kubectl get persistentvolume -o name |cut -d/ -f2 |grep -v pvc-47b422cc-854a-11e8-84de-0ec14f5e5db4 |while read i; do aws ec2 create-snapshot --description "SS-${i}" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=${i}}]" --volume-id $(kubectl get persistentvolume -o yaml --export $i |yq -r .spec.awsElasticBlockStore.volumeID | awk -F/ '{print $NF}'); done

AZs=("a" "c" "d")
COUNTER=0

# When we have snapshots of the active volumes, we must restore them so the hub can find them respectively.
SNAPSHOTS=$(aws ec2 describe-snapshots --filters "Name=description,Values=SS*" --query "Snapshots[].SnapshotId" --output text)

for SNAP in ${SNAPSHOTS};
do
        # Get the volumenID for which the snapshot belongs to so we can gatther a little more information about it.
        VOL=$(aws ec2 describe-snapshots --filters "Name=snapshot-id,Values=${SNAP}" --query "Snapshots[].VolumeId" --output text)
        OLDIFS=${IFS}
        taggo=""
        IFS=$'\n'
        # With the Volume ID we can now get tags that belongs(ed) to the original volume, we must apply the same to the new volumens
        for tags in $(aws ec2 describe-volumes --volume-ids ${VOL} --query 'Volumes[].[Tags[]]' --output text)
        do 
                KEY=$(echo $tags |awk '{print $1}')
                VAL=$(echo $tags |awk '{print $2}')
                if [ ${KEY} == "Name" ];
                then
                        VAL="copy-${VAL}"
                elif [ ${KEY} == "kubernetes.io/created-for/pv/name" ];
                then
                        PVNAME="${VAL}"
                        VAL="copy-${VAL}"
                        #PVNAME="copy-${VAL}"
                #elif [ ${KEY} == "kubernetes.io/created-for/pvc/name" ];
                #then
                #        PVCNAME="${VAL}"
                fi
                taggo="$taggo,{Key=${KEY},Value=${VAL}}"
        done


        taggo=${taggo#","}

        echo "Creating Volume off Snapshot ${SNAP}"
        #echo "aws ec2 create-volume --availability-zone us-east-1${AZs[${COUNTER}]} --snapshot-id ${SNAP} --tag-specifications \"ResourceType=volume,Tags=[${taggo}]\" --query \"VolumeId\" --output text"
        NEWVOL=$(aws ec2 create-volume --volume-type gp2 --availability-zone us-east-1${AZs[${COUNTER}]} --snapshot-id ${SNAP} --tag-specifications "ResourceType=volume,Tags=[${taggo}]" --query "VolumeId" --output text)
        echo "Volume ${NEWVOL} created"

        echo "Creating export files"
        #kubectl get persistentvolume --kubeconfig /home/bhcprodv2/bhcprodv2/kubeconfig-kube-aws ${PVNAME} -o yaml --export |sed -e "s/vol\-[a-z0-9]*/${NEWVOL}/g" -e "s/pvc.*/copy-${PVNAME}/g" -e "s/uid:.*//" -e "s/resourceVersion:.*//" -e "s#us-east-1[a-f]#us-east-1${AZs[$COUNTER]}#" > ${PVNAME}.yaml
        kubectl get persistentvolume ${PVNAME} -o yaml --export |sed -e "s/vol\-[a-z0-9]*/${NEWVOL}/g" -e "s/pvc.*/copy-${PVNAME}/g" -e "s/uid:.*//" -e "s/resourceVersion:.*//" -e "s#us-east-1[a-f]#us-east-1${AZs[$COUNTER]}#" > ${PVNAME}.yaml
#       kubectl get persistentvolumeclaims --kubeconfig /home/bhcprodv2/bhcprodv2/kubeconfig-kube-aws -n jupyter-pods ${PVCNAME} -o yaml --export |sed -e "s/pvc.*/copy-${PVNAME}/g" > ${PVCNAME}.yaml

        IFS=${OLDIFS}
        if [ ${COUNTER} -ge $(( ${#AZs[@]} - 1 )) ];
        then
                COUNTER=0
        else
                COUNTER=$(( COUNTER + 1 ))
        fi
        #echo $taggo

done
