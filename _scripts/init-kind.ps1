$clusterName = 'alltrails';

if(!((kind get clusters) -contains $clusterName)) {
    kind create cluster --config "$psscriptroot/kind.yaml" --wait 5m --name $clusterName
}
else {
    Write-Host "$clusterName already exists, skipping creation of cluster.";
}

$hostip = ip route|awk '/default/ { print $3 }'
Write-Host "Determined that the host of this workstation container has IP: $hostip"

$configLocation = "$psscriptroot/../kubeconfig";

Write-Host "Updating the configuration of $configLocation to allow for this workstation computer to communicate with the kind cluster hosted on this image's host ($hostip)."
$kubeConfig = get-content $configLocation | convertfrom-yaml
$kindClusterConfig = ($kubeConfig.clusters | where name -eq "kind-$clusterName").cluster;
$sln = 'alltrails-takehome'

if($kindClusterConfig) {
    # Here, we configure this kubernetes context to skip TLS verification for the control plane endpoint.  Only ever do this for development, against a local k8s cluster like kind!
    # A more robust approach would be to configure the kind endpoint with an SSL certificate whose CA is trusted by your machine.
    $kindClusterConfig.Remove('certificate-authority-data');
    $kindClusterconfig.Remove('insecure-skip-tls-verify')
    $kindClusterConfig.Add('insecure-skip-tls-verify', $true);

    # kind, by default, will take whatever IP address is specified in the kind.yaml file and also provide that in the kubeconfig.
    # We actually want this kubectl context to point to the "gateway" of this dev container, which is your physical machine.
    $kindClusterConfig.server = $kindClusterConfig.server.Replace('0.0.0.0', $hostIp);
    $kubeConfig | convertto-yaml > $configLocation;

    # Installing ingress-nginx
    Write-Host "Applying patches to allow for ingress according to https://kind.sigs.k8s.io/docs/user/ingress/"
    kubectl apply -f 'https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml'
    Write-Host "Waiting up to 5 mins for the cluster to start..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

    # Creating a namespace for this repository, and setting it as the default namespace for your kubectl commands.
    # I like to do this as a standard practice, so that I can have multiple repositories sharing the same kind cluster. (Running one cluster per repo is an alternative approach, but more complex.)
    Write-Host "Setting your preferred namespace to be $sln."
    kubectl config set-context --current --namespace=$sln
    kubectl create namespace $sln;
}
else { 
    Write-Error "Unable to find cluster with name kind-$clusterName"
}