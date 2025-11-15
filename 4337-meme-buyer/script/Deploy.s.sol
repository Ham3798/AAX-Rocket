// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IntentGateway} from "../src/IntentGateway.sol";

contract Deploy is Script {
    function run() external {
        string memory chainName = vm.envString("CHAIN_NAME");
        uint256 pk = vm.envUint("INTENT_GATEWAY_PRIVATE_KEY");

        string memory activePath = string.concat("configs/chains/", chainName, ".json");
        string memory activeJson = vm.readFile(activePath);

        if (!vm.keyExists(activeJson, "$.contracts.intentGateway")) {
            revert("Active config missing: contracts.intentGateway");
        }
        if (!vm.keyExists(activeJson, "$.uniswap.router")) {
            revert("Active config missing: uniswap.router");
        }

        address gatewayAddress = vm.parseJsonAddress(activeJson, "$.contracts.intentGateway");
        address uniswapRouter = vm.parseJsonAddress(activeJson, "$.uniswap.router");

        vm.startBroadcast(pk);
        IntentGateway gateway = IntentGateway(gatewayAddress);
        gateway.setUniswapRouter(uniswapRouter);
        vm.stopBroadcast();

        console2.log("=== IntentGateway Configuration ===");
        console2.log("Chain:", chainName);
        console2.log("IntentGateway:", gatewayAddress);
        console2.log("Uniswap Router:", uniswapRouter);
    }
}
