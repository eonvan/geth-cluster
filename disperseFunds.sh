#!/bin/bash

basedir=$1

PWD="$(pwd)"

function unlockAccount {
	password=$1
	port=$2

	cmd="curl -X POST --data '{\"jsonrpc\":\"2.0\",\"method\":\"personal_listAccounts\",\"params\":[],\"id\":1}' http://localhost:$port | jq '.result[0]'"
	echo "$cmd"
	account_output=$(bash -c "$cmd")
	echo $account_output
	curlcmd="curl -X POST --data '{\"jsonrpc\":\"2.0\",\"method\":\"personal_unlockAccount\",\"params\":[$account_output, \"$password\", 3600],\"id\":1}' http://localhost:$port"
	echo "$curlcmd"
	bash -c "$curlcmd"
	last_account=$account_output
	echo "$last_account unlocked"
}

tpassword="$(cat $PWD/password)"
echo "$tpassword"

#Unlock the main account
unlockAccount $tpassword 8100

main_account=$last_account

echo "$main_account"

while read p; do
	IFS== read account node <<< "$p"
	tport=$(echo "$node" | sed -e "s/eth-node-//p")
	echo "$tport"

	unlockAccount $tpassword $tport
	
	hexamount="0x$(printf '%x\n' 10000)"

	curlcmd="curl -X POST --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_sendTransaction\",\"params\":[{\"from\": $main_account, \"to\": $last_account, \"value\" : \"$hexamount\"}],\"id\":1}' http://localhost:8100"
	echo "Transferring funds from $main_account to $last_account"
	echo "$curlcmd"
	bash -c "$curlcmd"

done < $basedir/accounts.db