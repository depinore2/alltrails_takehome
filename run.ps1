# run this script to initialize everything from scratch, including the creation of the kind cluster.

# NOTE: 
#   The kind cluster assumes that ports 80 and 443 are available on your host machine.
#   If this is not the case, update lines 7 and 10 of /automation/kind.yaml

& $psscriptroot/_scripts/init-kind.ps1 # initialize kind if it's not already
get-childitem deploy.ps1 -recurse | % { & $_.fullname } # run every deploy script in the repo