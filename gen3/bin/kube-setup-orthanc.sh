
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


gen3 roll orthanc
g3kubectl apply -f "${GEN3_HOME}/kube/services/dicom-viewer/dicom-viewer-service.yaml"

cat <<EOM
The dicom-viewer service has been deployed onto the k8s cluster.
EOM