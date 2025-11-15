// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {IntentExecutionHelper} from "../src/IntentExecutionHelper.sol";

contract DeployIntentHelper is Script {
    function run() external {
        string memory helperName = vm.envString("HELPER_NAME");
        uint256 pk = vm.envUint("INTENT_HELPER_PRIVATE_KEY");

        string memory helperPath = string.concat("configs/chains/helpers/", helperName, ".json");
        string memory helperJson = vm.readFile(helperPath);

        if (!vm.keyExists(helperJson, "$.common.ccipRouter")) revert("Helper config missing: common.ccipRouter");
        if (!vm.keyExists(helperJson, "$.common.linkToken")) revert("Helper config missing: common.linkToken");

        address router = vm.parseJsonAddress(helperJson, "$.common.ccipRouter");
        address linkToken = vm.parseJsonAddress(helperJson, "$.common.linkToken");

        vm.startBroadcast(pk);
        IntentExecutionHelper helper = new IntentExecutionHelper(router, linkToken);
        vm.stopBroadcast();

        console2.log("=== IntentExecutionHelper Deployment ===");
        console2.log("Helper Chain:", helperName);
        console2.log("IntentExecutionHelper:", address(helper));
        console2.log("Router:", router);
        console2.log("LINK:", linkToken);
        console2.log("Update helper config with new helper address!");
    }
}

