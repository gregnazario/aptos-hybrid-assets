#!/bin/sh
PROFILE_NAME=$1
RESOURCE_ACCOUNT=$2

aptos move build-publish-payload --profile $PROFILE_NAME --named-addresses hybrid_address=$RESOURCE_ACCOUNT,deployer=$PROFILE_NAME --json-output-file output.json --assume-yes

METADATA=`cat output.json | jq '.args[0].value' | sed 's/"//g'`
CODE=`cat output.json | jq '.args[1].value'`

aptos move run --function-id $RESOURCE_ACCOUNT::package_manager::upgrade --profile $PROFILE_NAME --args "hex:$METADATA" "hex:$CODE" --assume-yes
