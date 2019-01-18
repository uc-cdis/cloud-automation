#!/bin/bash

# set -v

export GEN3_HOME=~/cloud-automation
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi


DESTROY_JUPYTER="NO"


OLD_KUBECONFIG="/home/-------/-------/kubeconfig"
NEW_KUBECONFIG="/home/-------/-------/kubeconfig"

SNAPSHOT_PREFIX="OLD-"
NEW_VOLUME_PREFIX="copy-"

IMPORT_LOCATION="/tmp/"
EXEC_IMPORT="NO"

CREATED_SNAPSHOTS=()


# We need to list all the existing volumes related to Jupyter, usually named pvc-"[Aa0-zZ9]?-*", and we have to rule out the one for the deployment.
# Then we should create snapshots for those volumens 
gen3 arun kubectl --kubeconfig ${OLD_KUBECONFIG} get persistentvolume -o yaml |yq '.items[] | select(.spec.claimRef.namespace == "jupyter-pods") | .metadata.name' -r |while read i; do echo $i; done


function createSnapshots()
{
    for pv in $(gen3 arun kubectl --kubeconfig ${OLD_KUBECONFIG} get persistentvolume -o yaml |yq '.items[] | select(.spec.claimRef.namespace == "jupyter-pods") | .metadata.name' -r);
    do
            local volume_id=$(gen3 arun kubectl --kubeconfig ${OLD_KUBECONFIG} get persistentvolume -o go-template --template="{{.spec.awsElasticBlockStore.volumeID}}" ${pv} | awk -F/ '{print $NF}')
            echo "Creating snapshot for ${pv} with base volume ${volume_id}"
            local snapshot_id=$(aws ec2 create-snapshot --description "${SNAPSHOT_PREFIX}${pv}" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=${pv}}]" --volume-id ${volume_id} --query "SnapshotId" --output text)
            CREATED_SNAPSHOTS[${#CREATED_SNAPSHOTS[@]}]=${snapshot_id}
    done
}


function createVolumesCopy()
{
    local COUNTER=0

    # AZ(s) where the new nodes are so we can place the volumes there 
    local AZs=($(gen3 arun kubectl --kubeconfig ${NEW_KUBECONFIG} get node -o json  -l role=jupyter |jq '.items[].metadata.labels["failure-domain.beta.kubernetes.io/zone"]' -r |sort |uniq))

    # When we have snapshots of the active volumes, we must restore them so the hub can find them respectively. Keep in mind that certain tags are required for jupyter to understand which volumes these are.
    # SNAPSHOTS=$(aws ec2 describe-snapshots --filters "Name=description,Values=${SNAPSHOT_PREFIX}*" --query "Snapshots[].SnapshotId" --owner-ids $(aws sts get-caller-identity --query "Account" --output text) --output text)

    #for SNAP in ${SNAPSHOTS};
    for SNAP in ${CREATED_SNAPSHOTS[@]};
    do
            # Get the volumenID for which the snapshot belongs to so we can gatther a little more information about it.
        local VOL=$(aws ec2 describe-snapshots --filters "Name=snapshot-id,Values=${SNAP}" --query "Snapshots[].VolumeId" --output text)
        local OLDIFS=${IFS}
        local taggo=""
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
                        VAL="${NEW_VOLUME_PREFIX}${VAL}"
                        #PVNAME="copy-${VAL}"
                #elif [ ${KEY} == "kubernetes.io/created-for/pvc/name" ];
                #then
                #        PVCNAME="${VAL}"
                fi
                taggo="$taggo,{Key=${KEY},Value=${VAL}}"
        done


        taggo=${taggo#","}

        echo "Creating Volume off Snapshot ${SNAP}"
        #echo "aws ec2 create-volume --availability-zone ${AZs[${COUNTER}]} --snapshot-id ${SNAP} --tag-specifications \"ResourceType=volume,Tags=[${taggo}]\" --query \"VolumeId\" --output text"
        local NEWVOL=$(aws ec2 create-volume --volume-type gp2 --availability-zone ${AZs[${COUNTER}]} --snapshot-id ${SNAP} --tag-specifications "ResourceType=volume,Tags=[${taggo}]" --query "VolumeId" --output text)
        echo "Volume ${NEWVOL} created"

        echo "Creating export files"
        #kubectl get persistentvolume --kubeconfig /home/bhcprodv2/bhcprodv2/kubeconfig-kube-aws ${PVNAME} -o yaml --export |sed -e "s/vol\-[a-z0-9]*/${NEWVOL}/g" -e "s/pvc.*/copy-${PVNAME}/g" -e "s/uid:.*//" -e "s/resourceVersion:.*//" -e "s#us-east-1[a-f]#us-east-1${AZs[$COUNTER]}#" > ${PVNAME}.yaml
        gen3 arun kubectl --kubeconfig ${OLD_KUBECONFIG} get persistentvolume ${PVNAME} -o yaml --export |sed -e "s/vol\-[a-z0-9]*/${NEWVOL}/g" -e "s/pvc.*/copy-${PVNAME}/g" -e "s/uid:.*//" -e "s/resourceVersion:.*//" -e "s#us-east-1[a-f]#${AZs[$COUNTER]}#" > ${IMPORT_LOCATION}${PVNAME}.yaml
        echo "Import ${IMPORT_LOCATION}${PVNAME}.yaml created"

        # Now let's import those newly ceated volumes into our new cluster
        if [[ ${EXEC_IMPORT} == YES ]];
        then
                gen3 arun kubectl --kubeconfig ${NEW_KUBECONFIG} apply -f ${IMPORT_LOCATION}${PVNAME}.yaml
        else
                echo "Remember to import the new volumes into your new cluster:"
                echo "        kubectl apply -f ${IMPORT_LOCATION}${PVNAME}.yaml"
                echo
        fi

        IFS=${OLDIFS}
        if [ ${COUNTER} -ge $(( ${#AZs[@]} - 1 )) ];
        then
                COUNTER=0
        else
                COUNTER=$(( COUNTER + 1 ))
        fi
        #echo $taggo

    done
}

function destroyJupyter()
{
    if [[ "${DESTROY_JUPYTER}" == "YES" ]];
    then
        gen3 arun kubectl --kubeconfig ${OLD_KUBECONFIG} delete statefulsets.apps jupyterhub-deployment
        OIFS=${IFS};IFS=$'\n';
        for i in $(grep apply ${GEN3_HOME}/gen3/bin/kube-setup-jupyterhub.sh |awk '{print $NF}'); 
        do 
                gen3 arun kubectl delete -f $i
        done
        gen3 arun kubectl delete namespace jupyter-pods
        IFS=${OIFS}
    fi
}

function main()
{
    createSnapshots

    local COUNTER=0
    while true;
    do

        # When we have snapshots of the active volumes, we must restore them so the hub can find them respectively. Keep in mind that certain tags are required for jupyter to understand which volumes these are.
        # SNAPSHOTS=$(aws ec2 describe-snapshots --filters "Name=description,Values=${SNAPSHOT_PREFIX}*" --query "Snapshots[].SnapshotId"  --owner-ids $(aws sts get-caller-identity --query "Account" --output text) --output text)

        local control=true
        for i in ${CREATED_SNAPSHOTS[@]};
        do
            local progress=$(aws ec2 describe-snapshots --snapshot-ids ${i} --query "Snapshots[].Progress" --output text)
            echo "${i} snapshot progress = ${progress}"
            if ! [[ ${progress} == 100% ]];
            then
                control=false
            fi
        done
        
        if [ ${COUNTER} -gt 30 ];
        then
            break
        elif [ "${control}" = true ];
        then
            createVolumesCopy
            break
        fi

        COUNTER=$(( COUNTER + 1 ))
        sleep 10
    done
    # Snapshot creation takes quite a few depending on the size of the volume to be snapshoted, therefore there is no need to create volumes off snapshots right away
    # 

}

main
