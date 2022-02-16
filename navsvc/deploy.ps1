$loc = get-location;
cd "$psscriptroot/src"
npm i;
cd $loc;

docker build $psscriptroot -t navsvc:local
kind load docker-image --name alltrails navsvc:local
kubectl apply -f $psscriptroot/k8s.yaml
kubectl rollout restart deployment navsvc-deployment