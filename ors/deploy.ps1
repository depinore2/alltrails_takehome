$configMapName = 'ors-config'
if((kubectl get configmap $configMapName).Length -gt 0) {
    kubectl delete configmap $configMapName;
}

kubectl create configmap $configMapName --from-file=$psscriptroot/ors-config.json
kubectl apply -f $psscriptroot/k8s.yaml