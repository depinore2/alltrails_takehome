## Starting the Demo ##
- Open this solution in VS Code
- Assuming you have the Remote Development extension installed, Command Palette --> Reopen and Rebuild in Container.
- Now that you're in the dev container, start a `pwsh` session.
- Execute the following command: `./start.ps1`.
## Interacting with the Demo ##
- You can interact with the 'rails' app at http://localhost/
- You can interact with the navigation service at http://localhost/nav/{lat1}/{lon1}/{lat2}/{lon2}
- An example GET request for the nav service is http://localhost/nav/8.676581/49.418204/8.692803/49.409465
## Architecture ##
The demo consists of three major subsystems:
* ORS Service (ors)
* App Web Application (app)
* Navigation Service (navsvc)

It runs in KinD when running it on your local machine.

![Demo Arch on KinD](https://github.com/depinore2/alltrails_takehome/raw/master/docs/alltrails-Demo%20Architecture.png)

The "app" is really just a static HTML page hosted in an nginx container.  The assignment specification mentioned that the imaginary rails app was hosted on port 3000, so I configured the nginx container to listen to port 3000 to accomodate this detail.



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