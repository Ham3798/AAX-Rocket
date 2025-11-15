export CHAIN_NAME=monad-testnet
export HELPER_NAME=ethereum-sepolia

forge script script/DeployIntentHelper.s.sol:DeployIntentHelper \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $INTENT_HELPER_PRIVATE_KEY

forge script script/DeployIntentGateway.s.sol:DeployIntentGateway \
  --rpc-url $MONAD_TESTNET_RPC_URL \
  --broadcast \
  --private-key $INTENT_GATEWAY_PRIVATE_KEY

CHAIN_NAME=monad-testnet HELPER_NAME=ethereum-sepolia \
forge script script/ConfigureIntent.s.sol:ConfigureIntentGateway \
  --rpc-url $MONAD_TESTNET_RPC_URL \
  --broadcast \
  --private-key $INTENT_GATEWAY_PRIVATE_KEY

CHAIN_NAME=monad-testnet HELPER_NAME=ethereum-sepolia \
forge script script/ConfigureIntent.s.sol:ConfigureIntentHelper \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $INTENT_HELPER_PRIVATE_KEY


cast send $INTENT_GATEWAY \
    "submitIntent((address,uint256,uint256,uint256,uint64,uint256,bytes32))" \
    "(0xd00ae08403B9bbb9124bB305C09058E32C39A48c,1000000000000000000,100000000000000000,200,$SEPOLIA_SELECTOR,$(($(date +%s)+600)),0x000000000000000000000000000000000000000000000000000000000000abcd)" \
    --rpc-url $MONAD_TESTNET_RPC_URL \
    --private-key $INTENT_GATEWAY_PRIVATE_KEY