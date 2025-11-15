// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IntentGateway} from "../src/IntentGateway.sol";
import {IntentExecutionHelper} from "../src/IntentExecutionHelper.sol";

contract ConfigureIntentGateway is Script {
    function run() external {
        string memory chainName = vm.envString("CHAIN_NAME");
        string memory helperName;
        try vm.envString("HELPER_NAME") returns (string memory s) {
            helperName = s;
        } catch {
            helperName = "";
        }

        uint256 gatewayPk = vm.envUint("INTENT_GATEWAY_PRIVATE_KEY");

        string memory activePath = string.concat("configs/chains/", chainName, ".json");
        string memory activeJson = vm.readFile(activePath);
        if (!vm.keyExists(activeJson, "$.contracts.intentGateway")) {
            revert("Active config missing: contracts.intentGateway");
        }
        address gatewayAddr = vm.parseJsonAddress(activeJson, "$.contracts.intentGateway");

        if (bytes(helperName).length == 0) {
            helperName = vm.parseJsonString(activeJson, "$.ccip.helperChain");
        }

        string memory helperPath = string.concat("configs/chains/helpers/", helperName, ".json");
        string memory helperJson = vm.readFile(helperPath);
        if (!vm.keyExists(helperJson, "$.contracts.intentHelper")) {
            revert("Helper config missing: contracts.intentHelper");
        }
        if (!vm.keyExists(helperJson, "$.common.chainSelector")) {
            revert("Helper config missing: common.chainSelector");
        }

        address helperAddr = vm.parseJsonAddress(helperJson, "$.contracts.intentHelper");
        uint64 helperSelector = uint64(vm.parseJsonUint(helperJson, "$.common.chainSelector"));

        vm.startBroadcast(gatewayPk);
        IntentGateway(gatewayAddr).setHelper(helperAddr);
        vm.stopBroadcast();

        console2.log("=== Intent Gateway Configuration ===");
        console2.log("Active Chain:", chainName);
        console2.log("Helper Chain:", helperName);
        console2.log("Gateway:", gatewayAddr);
        console2.log("Helper:", helperAddr);
        console2.log("Selector:", helperSelector);
    }
}

contract ConfigureIntentHelper is Script {
    function run() external {
        string memory helperName = vm.envString("HELPER_NAME");
        string memory chainName = vm.envString("CHAIN_NAME");
        uint256 helperPk = vm.envUint("INTENT_HELPER_PRIVATE_KEY");

        string memory helperPath = string.concat("configs/chains/helpers/", helperName, ".json");
        string memory helperJson = vm.readFile(helperPath);
        if (!vm.keyExists(helperJson, "$.contracts.intentHelper")) {
            revert("Helper config missing: contracts.intentHelper");
        }
        if (!vm.keyExists(helperJson, "$.common.chainSelector")) {
            revert("Helper config missing: common.chainSelector");
        }

        address helperAddr = vm.parseJsonAddress(helperJson, "$.contracts.intentHelper");
        uint64 helperSelector = uint64(vm.parseJsonUint(helperJson, "$.common.chainSelector"));

        string memory gatewayPath = string.concat("configs/chains/", chainName, ".json");
        string memory gatewayJson = vm.readFile(gatewayPath);
        if (!vm.keyExists(gatewayJson, "$.contracts.intentGateway")) {
            revert("Active config missing: contracts.intentGateway");
        }
        address gatewayAddr = vm.parseJsonAddress(gatewayJson, "$.contracts.intentGateway");

        vm.startBroadcast(helperPk);
        IntentExecutionHelper helper = IntentExecutionHelper(helperAddr);
        helper.addSource(helperSelector, gatewayAddr);
        
        // Set Uniswap Router if configured
        if (vm.keyExists(helperJson, "$.uniswap.router")) {
            address uniswapRouter = vm.parseJsonAddress(helperJson, "$.uniswap.router");
            helper.setUniswapRouter(uniswapRouter);
            console2.log("Uniswap Router set:", uniswapRouter);
        }
        vm.stopBroadcast();

        console2.log("=== Intent Helper Configuration ===");
        console2.log("Active Chain:", chainName);
        console2.log("Helper Chain:", helperName);
        console2.log("Helper:", helperAddr);
        console2.log("Gateway:", gatewayAddr);
        console2.log("Selector:", helperSelector);
    }
}

