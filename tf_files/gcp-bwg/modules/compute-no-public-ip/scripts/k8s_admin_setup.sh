#!/bin/bash

echo "********Installing kubectl**********"
which kubectl
if [[ "$?" -ne 0 ]];then
  sudo snap install kubectl --classic
fi

echo "***************Installing helm***************"
which helm
if [[ "$?" -ne 0 ]];then
  sudo snap install helm --classic
fi

echo "***************Getting kube credentials*****************"
gcloud beta container clusters get-credentials "$CLUSTER_NAME" --region "$CLUSTER_REGION"  --project "$PROJECT"
cat ~/.kube/config


echo "************************************Installing and securing helm-tiller***************************"
kubectl create ns tiller
kubectl create sa tiller -n tiller
kubectl -n tiller create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=tiller:tiller
kubectl patch deploy --namespace tiller tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
kubectl create clusterrolebinding hashicorp-demo-user-cluster-admin-binding --clusterrole=cluster-admin --user=876821984853-compute@developer.gserviceaccount.com
kubectl create clusterrolebinding hashicorp-demo-user-cluster-admin-binding --clusterrole=cluster-admin --user=112580339606785142716@developer.gserviceaccount.com
kubectl create clusterrolebinding hashicorp-demo-user-cluster-admin-binding --clusterrole=cluster-admin --user=112580339606785142716
kubectl create clusterrolebinding hashicorp-demo-user-cluster-admin-binding --clusterrole=cluster-admin --user=anderton.james@gmail.com

echo "*************************Running helm init*************************************"
helm init --service-account=tiller --tiller-namespace=tiller
