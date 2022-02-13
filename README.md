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
* App Web Application (app)
* Navigation Service (navsvc)

It runs in KinD when running it on your local machine, and looks like this:

![Demo Arch on KinD](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Demo%20Architecture.png)

The "app" is really just a static HTML page hosted in an nginx container.  The assignment specification mentioned that the imaginary rails app was hosted on port 3000, so I configured the nginx container to listen to port 3000 to accomodate this detail.


# Security #
This demo was not built with any security in mind.  All communication is unencrypted using HTTP, and both the app and the navsvc indiscriminately respond to requests.  If this were a real production application, it would be reinforced in three major ways:
1. All communication internal to the cluster would be encrypted in transit using Istio with Mutual TLS.  All communication external to the cluster would be using HTTPS at minimum.
1. All requests to either the rails application or the navsvc would require application-level authentication using an SSO provider over OpenID Connect.
1. Any infrastructure supporting the kubernetes cluster (such as cloud resources) would be locked down using Identity and Access Management policies.

## Security at the Network Level ##
All communication needs to be encrypted as it traverses the network.  To achieve this, all ingress traffic coming into the cluster would need to use HTTPS over port 443. If port 80 is left open at the ingress controller, it would only serve as a means to serve HTTP 301 redirection to port 443.

Communication within the cluster would leverage Istio (and implicitly Envoy).  Istio would allow us to ensure that all communication between endpoints in the cluster are able to mutually identify one another and encrypt traffic using mutual TLS.  This is all done using sidecar containers at the pod level, bypassing the need to reconfigure any of the individual containers that run our applications.

If we applied the aforementioned changes to the demo architecture, it would look like this:

![Demo Arch With Network Security](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Arch%20w_Network%20Security.png)

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

![Demo Arch With Application Security](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Full%20Prod%20Arch%20(AWS).png)

The Certificate Manager would offer us a place to store our SSL certificates for use in both the Istio control plane and in the AWS Application Load Balancer handling ingress requests.

AWS STS would be used in conjunction with AWS IAM to grant EKS the ability to provision cluster nodes with access to the AWS infrastructure.  This will be useful when fetching things such as OSM files from AWS S3.  Note: it's assumed that the EKS Cluster is configured to use AWS STS as an OIDC provider to allow for node-level role integration.

Not pictured are details regarding VPC security for the sake of brevity.  It's assumed that before deploying to production, the appropriate subnet, internet gateway, nat gateway, and Route 53 infrastructure would be provisioned using either Terraform or CloudFormation to make the system robust at every level.

## Notes to Self ##
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