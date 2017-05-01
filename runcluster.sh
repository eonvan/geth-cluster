#!/bin/bash

basedir=$2

mode=$3

echo $basedir

PWD="$(pwd)"

master_node=0

function prepareNodeDir {
	node=$1
	nodedir=$basedir/$node
	if [ ! -f $nodedir ]; then
		mkdir -p $basedir/$node
		
		makeaccount=$(geth --verbosity 1 --password $PWD/password --datadir $nodedir --networkid 247 account new)

		echo "$makeaccount"

		account=$(echo $makeaccount | sed -n 's/Address: {\([[:alnum:]]*\)}/\1/p') 

		echo $account

		echo "$account=eth-node-$node" >> $basedir/accounts.db
		if [ ! -f $basedir/genesis.json ]; then
			cp genesis.json.template $basedir/genesis.json

			sed -i '' -e "s/ACCOUNT/$account/g" $basedir/genesis.json
		fi

		geth --datadir $basedir/$node --networkid 247 init $basedir/genesis.json
	fi
}

function startDocker {
	node=$1	
	enode=$2
	port="3$1"
	node_name=eth-node-$node
	node_dir=$basedir/$node

	prepareNodeDir $node

	if [[ -z "${enode// }" ]]; then
		cmd="docker run --net=geth-network -d --name $node_name -p $node:8545 -p $port:30303 -v \
		   $node_dir:/root/.ethereum/ \
           ethereum/client-go --rpc --rpcaddr 0.0.0.0 --rpcapi eth,net,web3,personal,miner,admin \
           --datadir /root/.ethereum --networkid 247"
	else
		cmd="docker run --net=geth-network -d --name $node_name -p $node:8545 -p $port:30303 -v \
		   $node_dir:/root/.ethereum/ \
           ethereum/client-go --rpc --rpcaddr 0.0.0.0 --rpcapi eth,net,web3,personal,miner,admin \
           --datadir /root/.ethereum --networkid 247 --bootnodes $enode"
	fi

	echo "$cmd"
    bash -c "$cmd"

}

function startNative {
	node=$1	
	enode=$2
	port="3$1"

	prepareNodeDir $node

	node_dir=$basedir/$node

	if [[ -z "${enode// }" ]]; then
		cmd="nohup geth --rpc --rpcaddr 0.0.0.0 --rpcport $node --port $port --rpcapi eth,net,web3,personal,miner,admin \
           --datadir $node_dir --networkid 247 > $node_dir/nohup.out 2>&1&"
	else
		cmd="nohup geth --rpc --rpcaddr 0.0.0.0 --rpcport $node --port $port --rpcapi eth,net,web3,personal,miner,admin \
           --datadir $node_dir --networkid 247 --bootnodes $enode > $node_dir/nohup.out 2>&1&"
	fi

	echo "$cmd"

    bash -c "$cmd"

    echo "eth-node-$node starting, logs written to $node_dir/nohup.out for debugging"
}

if [[ -z "${mode// }" ]]; then
	startNative 8100
else
	docker network create geth-network

	startDocker 8100 
fi

if [[ ! -z "${mode// }" ]]; then
	echo "Contain run state `docker inspect -f {{.State.Running}} eth-node-8100`"
fi

echo "waiting for rpc server to start"
sleep 10

enode=$(curl -X POST -d "@$PWD/admin.nodeInfo.rpc" http://localhost:8100 | jq '.result.enode' | sed -n "s/\(.*@\)\[\:\:\]\(.*\)/\1eth-node-8100\2/p")

echo "enode url is $enode"

curl -X POST --data '{"jsonrpc":"2.0","method":"miner_start","params":[],"id":1}' http://localhost:8100

if [[ -z "${mode// }" ]]; then
	ipaddres="127.0.0.1"
else
	ipaddres=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" eth-node-8100)
fi

enode=$(echo $enode | sed -n "s/eth-node-8100/$ipaddres/p")

echo "enode switched to ip $enode"

#read the number of instances
n=$1

max_port=$((8100+$n))

echo "max port is $max_port"

for node in $(eval echo "{8101..$max_port}")
do
	if [[ -z "${mode// }" ]]; then
		startNative $node $enode
	else
		startDocker $node $enode 
	fi

	echo "waiting for restart"
	sleep 10

	curl -X POST --data '{"jsonrpc":"2.0","method":"miner_start","params":[],"id":1}' http://localhost:$node

    echo "$cmd"

done

#add peers
# for node in $(eval echo "{8100..$max_port}")
# do
# 	for peer in $(eval echo "{$node..$max_port}")
# 	do
# 		if [[ $node != $peer ]]; then
# 			enode=$(curl -X POST -d "@$PWD/admin.nodeInfo.rpc" http://localhost:$node | jq '.result.enode' | sed -n "s/\(.*@\)\[\:\:\]\(.*\)/\1eth-node-$peer\2/p")

# 			echo "enode url is $enode"

# 			if [[ -z "${mode// }" ]]; then
# 				ipaddres="127.0.0.1"
# 			else
# 				ipaddres=$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" eth-node-$peer)
# 			fi

# 			enode=$(echo $enode | sed -n "s/eth-node-$peer/$ipaddres/p")

# 			echo "enode switched to ip $enode"

# 			echo "Adding peer eth-node-$peer to eth-node-$node"

# 			curl -X POST --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[$enode],\"id\":1}" http://localhost:$node

# 		fi
# 	done
# done