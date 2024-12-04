#!/bin/sh
HYBRID_DEPLOYER=$1
HYBRID_ADDRESS=0xbbe8a08f3b9774fccb31e02def5a79f1b7270b2a1cb9ffdc05b2622813298f2a
if [ $# -eq 0 ]; then
    printf "Usage: sh update-base.sh <hybrid-cli-profile>\n"
    echo "--------------------------------------------------"
    printf "\tPlease use 'aptos init --profile hybrid' and input the private key prior to running this script.\n"
    printf "\n"
    printf "\tThen run 'sh update-base.sh hybrid'.\n"
    exit 255;
fi

echo "== Deploying Hybrid Assets =="

echo "We'll deploy using $HYBRID_DEPLOYER"

cd hybrid-base || exit 255

# Remove old output.json
if [ -e "output.json" ]; then
  rm output.json
fi

# Build a publish payload
echo "aptos move build-publish-payload --profile $HYBRID_DEPLOYER --named-addresses hybrid_address=$HYBRID_ADDRESS,deployer=$HYBRID_DEPLOYER --json-output-file output.json"
aptos move build-publish-payload --profile "$HYBRID_DEPLOYER" --named-addresses hybrid_address="$HYBRID_ADDRESS",deployer="$HYBRID_DEPLOYER" --json-output-file output.json

# Extract the pieces
METADATA=$(jq '.args[0].value' < output.json | sed 's/"//g')
CODE=$(jq '.args[1].value' < output.json)

# Publish to resource account
echo "aptos move run --function-id $HYBRID_ADDRESS::package_manager::upgrade --profile $HYBRID_DEPLOYER --args \"hex:...\" \"hex:...\""
aptos move run --function-id $HYBRID_ADDRESS::package_manager::upgrade --profile "$HYBRID_DEPLOYER" --args "hex:$METADATA" "hex:$CODE"
