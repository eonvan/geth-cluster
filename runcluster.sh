#!/bin/bash

basedir=$2

echo $basedir

mkdir -p $basedir/master

PWD="$(pwd)"

makeaccount=$(geth --verbosity 1 --password $PWD/password --datadir $basedir/master --networkid 247 account new)

echo "$makeaccount"

account=$(echo $makeaccount | sed -n 's/Address: {\([[:alnum:]]*\)}/\1/p') 

echo $account

cp genesis.json.template $basedir/genesis.json

sed -i '' -e "s/ACCOUNT/$account/g" $basedir/genesis.json

geth --datadir $basedir/master --networkid 247 init $basedir/genesis.json

docker network create geth-network

docker run --net=geth-network -d --name eth-node-master -p 8100:8545 -p 38100:30303 -v \
		   $basedir/master:/root/.ethereum/ \
           ethereum/client-go --fast --cache=512 --rpc --rpcaddr 0.0.0.0 --rpcapi eth,net,web3,admin \
           --datadir /root/.ethereum --networkid 247

echo "Contain run state `docker inspect -f {{.State.Running}} eth-node-master`"

echo "waiting for rpc server to start"
sleep 5

enode=$(curl -X POST -d "@$basedir/admin.nodeInfo.rpc" http://localhost:8100 | jq '.result.enode' | sed -n "s/\(.*@\)\[\:\:\]\(.*\)/\1eth-node-master\2/p")

echo "enode url is $enode"

docker stop eth-node-master && docker rm eth-node-master

#Start a more secure version of master with rpc disabled
docker run --net=geth-network -d --name eth-node-master -p 8100:8545 -p 38100:30303 -v \
		   $basedir/master:/root/.ethereum/ \
           ethereum/client-go  --rpc --rpcaddr 0.0.0.0 \
           --datadir /root/.ethereum --networkid 247

ipaddres=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" eth-node-master)

enode=$(echo $enode | sed -n "s/eth-node-master/$ipaddres/p")

echo "enode switched to ip $enode"

#read the number of instances
n=$1

max_port=$((8100+$n))

echo "max port is $max_port"

for node in $(eval echo "{8101..$max_port}")
do
	echo "Creating directory $basedir/$node"

	node_dir=$basedir/$node
	mkdir $node_dir

	makeaccount=$(geth --verbosity 1 --password $PWD/password --datadir $node_dir --networkid 247 account new)

	echo "$makeaccount"

	account=$(echo $makeaccount | sed -n 's/Address: {\([[:alnum:]]*\)}/\1/p') 

	echo $account

	cp $basedir/genesis.json $node_dir/genesis.json

	#sed -i '' -e "s/ACCOUNT/$account/g" $basedir/$node/genesis.json

	geth --datadir $node_dir --networkid 247 init $node_dir/genesis.json

	node_port=$((30000 +$node))

	node_name="eth-node-$node"

	echo "starting node $node_name on port $node_port"

	cmd="docker run --net=geth-network -d --name $node_name -p $node:8545 -p $node_port:30303 -v \
		   $node_dir:/root/.ethereum/ \
           ethereum/client-go --fast --cache=512  --rpc --rpcaddr 0.0.0.0 \
           --datadir /root/.ethereum --networkid 247 --bootnodes $enode"
    
    echo "$cmd"

    bash -c "$cmd"
done

docker network inspect geth-network