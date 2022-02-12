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