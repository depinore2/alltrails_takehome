docker build $psscriptroot -t app:local
kind load docker-image --name alltrails app:local
kubectl apply -f $psscriptroot/k8s.yaml