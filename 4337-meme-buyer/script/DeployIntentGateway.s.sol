// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IntentGateway} from "../src/IntentGateway.sol";

contract DeployIntentGateway is Script {
    function run() external {
        string memory chainName = vm.envString("CHAIN_NAME");
        string memory helperName;
        try vm.envString("HELPER_NAME") returns (string memory s) {
            helperName = s;
        } catch {
            helperName = "";
        }
        uint256 pk = vm.envUint("INTENT_GATEWAY_PRIVATE_KEY");

        string memory activePath = string.concat("configs/chains/", chainName, ".json");
        string memory activeJson = vm.readFile(activePath);

        if (!vm.keyExists(activeJson, "$.common.ccipRouter")) revert("Active config missing: common.ccipRouter");
        if (!vm.keyExists(activeJson, "$.common.linkToken")) revert("Active config missing: common.linkToken");

        address router = vm.parseJsonAddress(activeJson, "$.common.ccipRouter");
        address linkToken = vm.parseJsonAddress(activeJson, "$.common.linkToken");

        if (bytes(helperName).length == 0) {
            helperName = vm.parseJsonString(activeJson, "$.ccip.helperChain");
        }

        string memory helperPath = string.concat("configs/chains/helpers/", helperName, ".json");
        string memory helperJson = vm.readFile(helperPath);
        if (!vm.keyExists(helperJson, "$.common.chainSelector")) revert("Helper config missing: common.chainSelector");

        uint64 helperSelector = uint64(vm.parseJsonUint(helperJson, "$.common.chainSelector"));

        vm.startBroadcast(pk);
        IntentGateway gateway = new IntentGateway(router, helperSelector, linkToken);
        vm.stopBroadcast();

        console2.log("=== IntentGateway Deployment ===");
        console2.log("Active Chain:", chainName);
        console2.log("Helper Chain:", helperName);
        console2.log("IntentGateway:", address(gateway));
        console2.log("Helper selector:", helperSelector);
        console2.log("Router:", router);
        console2.log("LINK:", linkToken);
        console2.log("Update configs with new gateway address!");
    }
}

