#!/bin/bash

basedir=$2

n=$1

mode=$3

max_port=$((8100+$n))

if [[ -z "${mode// }" ]]; then
	killall geth
else 
	for node in $(eval echo "{8100..$max_port}")
	do
		 docker stop eth-node-$node
		 docker rm eth-node-$node
	done	

	docker network rm geth-network
fi

for node in $(eval echo "{8100..$max_port}")
do
	 node_dir=$basedir/$node
	 rm -rf $node_dir
done	

rm $basedir/genesis.json