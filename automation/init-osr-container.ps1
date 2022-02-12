$dirs = @('conf','elevation_cache','graphs','logs/ors','logs/tomcat');

# first, make the directories that will store the various config and cache files.
$dirsList = ($dirs | % { "$psscriptroot/../$_" }) -join ' '
$cmd = "mkdir -p $dirsList"
Write-Host "Executing $cmd"
iex $cmd;

$osmFile = 'heidelberg.osm.gz'
$containerName = 'ors-app'
invoke-webrequest 'https://github.com/GIScience/openrouteservice/raw/master/openrouteservice/src/main/files/heidelberg.osm.gz' -outfile "$psscriptroot/../$osmFile"

# "${UID}:${GID}"
$uid = bash -c 'echo $UID';
$gid = bash -c 'echo $GID'

docker rm $containerName -f

clear;

docker run -it --rm -u "$($uid):$gid"`
  --name $containerName `
  -p 8080:8080 `
  -v $psscriptroot/../graphs:/ors-core/data/graphs `
  -v $psscriptroot/../elevation_cache:/ors-core/data/elevation_cache `
  -v $psscriptroot/../conf:/ors-conf `
  -v "$psscriptroot/../$($osmFile):/ors-core/data/$osmFile" `
  -e "JAVA_OPTS=-Djava.awt.headless=true -server -XX:TargetSurvivorRatio=75 -XX:SurvivorRatio=64 -XX:MaxTenuringThreshold=3 -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:ParallelGCThreads=4 -Xms1g -Xmx2g" `
  -e "CATALINA_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9001 -Dcom.sun.management.jmxremote.rmi.port=9001 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=localhost" `
  openrouteservice/openrouteservice:latest -f