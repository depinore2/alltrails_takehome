## Starting the Demo ##
- Open this solution in VS Code
- Assuming you have the Remote Development extension installed, Command Palette --> Reopen and Rebuild in Container.
- Now that you're in the dev container, start a `pwsh` terminal.
- Execute the following command: `./run.ps1`.
## Interacting with the Demo ##
- You can interact with the 'rails' app at http://localhost/
- You can interact with the navigation service at http://localhost/nav/{lat1}/{lon1}/{lat2}/{lon2}
- An example GET request for the nav service is http://localhost/nav/8.676581/49.418204/8.692803/49.409465
## Design Considerations ##
For detailed information regarding the design of the application, and answers to questions specifically asked in the exercise, please refer to the repo wiki.

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