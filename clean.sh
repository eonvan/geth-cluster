#!/bin/bash

basedir=$2

docker stop eth-node-master | xargs -I@ docker rm @

n=$1

max_port=$((8100+$n))

for node in $(eval echo "{8101..$max_port}")
do
	 docker stop eth-node-$node
	 docker rm eth-node-$node
	 node_dir=$basedir/$node
	 rm -rf $node_dir
done

rm -rf $basedir/master

rm $basedir/genesis.json

docker network rm geth-network