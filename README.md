# Overview #
## Starting the Demo ##
- Open this solution in VS Code
- Assuming you have the Remote Development extension installed, Command Palette --> Reopen and Rebuild in Container.
- Now that you're in the dev container, start a `pwsh` session.
- Execute the following command: `./start.ps1`.
## Interacting with the Demo ##
- You can interact with the 'rails' app at http://localhost/
- You can interact with the navigation service at http://localhost/nav/{lat1}/{lon1}/{lat2}/{lon2}
- An example GET request for the nav service is http://localhost/nav/8.676581/49.418204/8.692803/49.409465
## Architecture as Coded ##
The demo consists of three major subsystems:
* ORS Service (ors)
* App Web Application (app), which is a static HTML file in nginx.
* Navigation Service (navsvc), which is a nodejs express API.

It runs in KinD when running it on your local machine, and looks like this:

![Demo Arch on KinD](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Demo%20Architecture.png)

The "app" is really just a static HTML page hosted in an nginx container.  The assignment specification mentioned that the imaginary rails app was hosted on port 3000, so I configured the nginx container to listen to port 3000 to accomodate this detail.

# NGINX #
The exercise mentions use of nginx as a reverse proxy for ingress traffic.  This is such a common pattern that the good folks at the kubernetes team created a dedicated ingress-nginx Ingress Controller in order to embed nginx into the ingress functionality of a kubernetes cluster.

This averts the need to deploy and manually configure your own nginx server, and instead allows a kubernetes administrator to simply define Ingress definitions in their YAML files. Due to the fact that the ingress-nginx controller is closer to how I would "really" implement this system, I opted for that approach rather than provisioning an actual nginx server as described in the exercise scenario.

For the sake of completeness, however, I would like to share what an nginx configuration file would look like had I provisioned it myself, based on the specs in the assignment:

```
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;

    keepalive_timeout  65;

    # this assumes we created multiple rails application endpoints
    upstream rails_group   {
        server my.rails1.app;
        server my.rails2.app;
        # etc
    }

    # this assumes we created multiple navservice application endpoints.
    upstream navservice_group {
        server my.nav1.api;
        server my.nav2.api;
        # etc
    }

# we didn't make an entry for the ORS service, because we don't want end-users to be able to hit ORS directly.

    server {
        listen       80;

        # === the following would be uncommented when using SSL ===
        # listen 443 ssl;
        # ssl_certificate cert-public-key-goes-here
        # ssl_certificate_key cert-private-key-goes-here
        
        server_name  localhost;

        location ~* ^/(.*) {
            proxy_pass http://rails_group/$1$is_args$args;
        }
        location ~* ^/navservice/(.*) {
            proxy_pass http://navservice_group/$1$is_args$args;
        }
    }
}
```

The above configuration doesn't take advantage of anything like kubernetes Services, and was done for illustrative purposes.

# Security #
This demo was not built with any security in mind.  All communication is unencrypted using HTTP, and both the app and the navsvc indiscriminately respond to requests.  If this were a real production application, it would be reinforced in three major ways:
1. All communication internal to the cluster would be encrypted in transit using Istio with Mutual TLS.  All communication external to the cluster would be using HTTPS at minimum.
1. All requests to either the rails application or the navsvc would require application-level authentication using an SSO provider over OpenID Connect.
1. Any infrastructure supporting the kubernetes cluster (such as cloud resources) would be locked down using Identity and Access Management policies.

## Security at the Network Level ##
All communication needs to be encrypted as it traverses the network.  To achieve this, all ingress traffic coming into the cluster would need to use HTTPS over port 443. If port 80 is left open at the ingress controller, it would only serve as a means to serve HTTP 301 redirection to port 443.

Communication within the cluster would leverage Istio (and implicitly Envoy).  Istio would allow us to ensure that all communication between endpoints in the cluster are able to mutually identify one another and encrypt traffic using mutual TLS.  This is all done using sidecar containers at the pod level, bypassing the need to reconfigure any of the individual containers that run our applications.

If we applied the aforementioned changes to the demo architecture, it would look like this:

![Demo Arch With Network Security](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Arch%20w_Network%20Security_2.png)

Note: some details from the previous diagram were omitted for clarity.

## Security at the Application Level ##
In addition to encrypting traffic for network-level security, we also want to ensure that only users that are authorized to use our applications can access our data.  The most common way to achieve this is to use a Single-Sign On provider such as Okta, AWS Cognito, Apple SSO, or Google SSO--which all communicate over the OpenID Connect protocol.

The pattern tends to look like this, assuming a Single-Page javascript application and a stateless API:
1. An unauthenticated user makes a request to our rails application.
1. The rails application checks for the existence of an SSO token identifying them.  
1. Due to the absence of a token in the HTTP request, the user is navigated to the SSO provider's login page.
1. The user provides their credentials, and is redirected back to the rails app.
1. During use of the rails app, the user triggers a javascript `fetch()` request to the navigation API.
1. The `fetch()` request makes sure to embed an HTTP `Authorization: Bearer <bearer token from SSO>` header, giving the navservice access to the token identifying the user.
1. Before responding to any requests, the navservice would run a validation procedure directly with the SSO provider from step 3.
    1. If the user is not authorized to use this endpoint, the endpoint immediately returns with an `HTTP 403 Forbidden`.
    1. If the user is authorized to use this endpoint, the endpoint continues by sending the appropriate requests to the backing ORS endpoint.

![Demo Arch With Application Security](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-OIDC%20Security%20View.png)

## Security in the Context of Cloud Infrastructure ##
Eventually, our system needs to actually run in production infrastructure.  Assuming our infrastructure provider is Amazon Web Services, we would combine all of the above considerations and add AWS IAM, Certificate Manager, and even lock down our S3 buckets like this:

![Prod Arch with Infrastructure Security](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Full%20Prod%20Arch%20(AWS)_2.png)

The Certificate Manager would offer us a place to store our SSL certificates for use in both the Istio control plane and in the AWS Application Load Balancer handling ingress requests.

AWS STS would be used in conjunction with AWS IAM to grant EKS the ability to provision cluster nodes with access to the AWS infrastructure.  This will be useful when fetching things such as OSM files from AWS S3.  Note: it's assumed that the EKS Cluster is configured to use AWS STS as an OIDC provider to allow for node-level role integration.

Not pictured are details regarding VPC security for the sake of brevity.  It's assumed that before deploying to production, the appropriate subnet, internet gateway, nat gateway, and Route 53 infrastructure would be provisioned using either Terraform or CloudFormation to make the system robust at every level.

# Deployment and Testing #
To test this system, I would have two separate environments: test and production.  Each environment would have its own isolated EKS cluster and associated AWS networking infrastructure (VPC, gateways, etc).  While both environments are designed to be similar, deploying to them would be different.

## Test Environment ##
Let's start with the test environment.  The workflow would go like this:
1. Devops engineer checks in their source code to AWS CodeCommit.
1. AWS CodeBuild detects a change in the source code, which then downloads the latest source code.
1. CodeBuild builds the latest version of all containers.
1. CodeBuild publishes all artifacts
    1. If the artifact is a container, push it to AWS Elastic Container Registry.
    1. If the artifact is anything else, such as a YAML file or other metadata, push it into an S3 bucket.
1. It's assumed that this environment uses continuous integration, so successful builds push immediately into the test using terraform, kubectl, and any other tools.
1. The Test EKS cluster will then pull any containers referenced in the YAML from either AWS ECR or Docker Hub.
1. Once publish is completed, you could optionally begin automated integration testing:
    1. CodeBuild can broadcast into an AWS SMS topic, indicating the deployment is complete.
    1. An automated testing system picks up this SMS message and begins running tests.
    1. When the tests are done, the results can be published to Slack or MS Teams using AWS SNS.

![Deploying into the Test Environment](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Deployment%20(Test).png)

## Production Environment ##
The workflow in the production environment is somewhat simplified, due to the fact that there is no new code to take into account, nor new artifacts to produce.  All of that was already built and deployed to the test environment.  

Instead, the process of deploying to production would be approved by somebody in the team, and manually triggered in some way--either via AWS Management Console, or some other UI tool.

The deployment process would go as follows:
1. Stakeholder or some other release engineer approves the release.
1. CodeCommit triggers a release, pulling any relevant artifacts from S3 and applying them to the production EKS cluster using kubectl, terraform, etc.
1. The production EKS cluster would pull these ECR images down and apply them into the cluster.

![Deploying into the Test Environment](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Deployment%20(Prod).png)

To validate that a production deployment went successfully, I would advocate for a blue-green deployment strategy.  Using istio, you can configure it to prevent any end-users from seeing the latest unverified deployment (green) and only see the last verified build (blue).  From there, you can configure istio to only allow an internal automated test suite to access the green deployment.

Once the automated testing suite has verified that all is working properly, istio can be updated once more to begin transitioning end-users from the blue deployment to the green deployment--thereby making it public.

As stated in the test environment, once all is done, SNS can be used to notify the engineering team that the deployment has completed successfully.

# Scaling Considerations #
Between the navservice and the ORS endpoint, the navservice does very little in terms of computation.  Its scaling needs can be handled easily with a `HorizontalPodAutoScaler`. 

ORS, on the other hand, is nuanced in how to maximize performance as the dataset its working on grows.  If special consideration isn't taken to handle large datasets, the pods running the endpoint can run out of memory or take too long to start up.

## RAM ##
As noted in the exercise specification, the data that populates OpenRouteService can vary wildly--from a few tens of MB into the GB range.  According to the ORS documentation and [some commentary online](https://ask.openrouteservice.org/t/requirements-based-on-osm-data/2016/2), the service performs best when allocated twice the size in RAM of the largest OSM file used--per navigation profile.  What this means is that RAM consumption increasees linearly with the size of the OSM files.

To save on costs, the first course of action I would take is to slice up the data into small regional chunks not exceeding 500MB.  This way, each node would at most require 1GB of RAM. 

## Cache? ##
I originally thought that an in-memory cache such as Elasticache could be useful to offload the work on the ORS endpoint.  Caches are great when it comes to minimizing the impact of calculating CPU-intensive data.  According to some commentary I read on ORS forums, CPUs aren't really the bottleneck as data grows--it's the RAM. To avoid unnecessary complexity, I abandoned the idea of a cache.

## Building the "Graph" ##
According to [the ORS documentation](https://giscience.github.io/openrouteservice/installation/Advanced-Docker-Setup.html#instance-infrastructure), ORS builds up a graph data structure when it receives new OSM data.  For the sample heidelberg data set (14MB), startup takes nearly 4 minutes on my machine.  I don't even want to know how long it would take for a file that is in the hundreds of MB.

This characteristic of building a graph can negatively impact startup times whenever updated map data is introduced into an environment.  To reduce downtime, a sidecar container can be used to build up the graph when it detects a change.  In this way, the main container can field requests while the sidecar is churning away building the graph.  Once the graph is built, it can be handed off to the main container to respond to requests with.

## Use of S3 ##
Because I'm recommending to split up containers into small regional verticals, it's important to deal with the proliferation of data files.  If we embed the data file directly into the docker container at build time, we will end up with many thousands of versions of a container when deploying an updated data set.  This can complicate management, in addition to incurring a large cost if your container repository charges you by the MB.

Instead, OSM files can be stored in S3, and then fetched at deployment time using an initContainer.  In this way, we can use a single ORS image but configure the associated yaml to point to different OSM data files.  I use this technique in the ORS k8s.yaml file.

# Challenges #
I've never worked with OpenRouteService before, so it required a fair amount of documentation reading and tinkering with an ORS docker container.

Once I wrapped my head around the relationship between the various configuration files and server switches, I ran into issues related to the slow startup time of the server itself. For example, if I started up all of the pods at once, the navservice would crash due to the fact that the ORS endpoint wasn't done building its graph.

I ended up writing a few kubernetes probes that polled the `/ors/v2/health` endpoint, and that ensured that both the navservice and ORS service were given the appropriate time to start up.  To see an example of this, refer to /ors/k8s.yaml.

Another stumbling block I ran into was the fact that ORS expects a certain folder structure to exist before starting up.  I was able to resolve this by creating various volumeMounts.

# Closing Thoughts #
I didn't expect to have as much fun as I did with this little exercise. I might've gone a little overboard with this, but honestly it was entertaining. I can now say that I know a little bit about OpenRouteService, and how it relates to OpenStreetMap. 

The source file for the various diagrams are located in /docs, and can be opened using https://app.diagrams.net.

I appreciate your time, and hope you enjoyed reading through my work.

# Notes to Self #
The following are notes I jotted down as I worked my way through the exercise.  I'm sharing them to give a sense for how my thought process went.

How to run with just docker:
- https://giscience.github.io/openrouteservice/installation/Running-with-Docker#install-and-run-openrouteservice-with-docker

Using a custom OSM file:
- https://giscience.github.io/openrouteservice/installation/Running-with-Docker#different-osm-file

Scaling considerations:
- https://ask.openrouteservice.org/t/requirements-based-on-osm-data/2016
Given the comments above, I would probably assign 2.1x the OSM data size to the container in the yaml definition, and then 2x the java heap size to the JVM itself.
- Because the dataset can be quite large, it would be ideal to store the OSM files in a file share, like S3.  From there, we could use an init container to download the file and place it on the correct location.
- For large datasets, I would also create a multi-container pod, with a graph builder sidecar: https://giscience.github.io/openrouteservice/installation/Advanced-Docker-Setup.html#instance-infrastructure

Running a test request with the provided heidelberg dataset:
curl 'http://localhost:8080/ors/v2/directions/driving-car?start=8.676581,49.418204&end=8.692803,49.409465'

Additional information about ORS:
- The configmap is located in /ors-conf/ors-config.json.  We can load our custom config file as a ConfigMap and then pass it down into /ors-conf/ors-config.json in order to customize the behavior of the ORS instance.  In our case, we plan to provide a customized ors.services.routing.sources property to our volumeMount which contains our custom-downloaded heidelberg file.