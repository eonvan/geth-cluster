# Expiremental go-ethereum docker cluster

## Key features
* Contains scripts to start a cluster that syncs via a master node
* All docker based so it should be light on the setup side of the equation
* Sets up a docker network to enable cluster communication between geth nodes
* Contains a cleanup script to tear it all down again

### How To

#### Running a cluster
Just execute `./runcluster.sh 4 $A_DIRECTORY_OF_YOUR_CHOOSING`

####Deleting a cluster
Just execute `./clean.sh 4 $RUN_DIRECTORY`