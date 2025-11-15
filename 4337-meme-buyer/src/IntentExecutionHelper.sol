// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IntentInterface} from "./IntentInterface.sol";
/**
 * @title IntentExecutionHelper
 * @notice Receives BuyIntent payloads from IntentGateway, checks price feeds, and responds with fill status.
 */
contract IntentExecutionHelper is IntentInterface, CCIPReceiver, Ownable {

    mapping(address => uint64) public moand_launchpad_list;


    IERC20 public immutable link;
    IRouterClient public immutable router;

    mapping(uint64 => address) public allowedGateways;


    constructor(address _router, address _link)
        CCIPReceiver(_router)
        Ownable(msg.sender)
    {
        router = IRouterClient(_router);
        link = IERC20(_link);
    }

    function addSource(uint64 selector, address gateway) external onlyOwner {
        allowedGateways[selector] = gateway;
        emit SourceAllowed(selector, gateway);
    }

    function removeSource(uint64 selector) external onlyOwner {
        delete allowedGateways[selector];
        emit SourceRemoved(selector);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Decode the message data to get intentId and BuyIntent
        (bytes32 intentId, BuyIntent memory intent) = abi.decode(message.data, (bytes32, BuyIntent));
    
        address expected = allowedGateways[message.sourceChainSelector];
        if (expected == address(0)) revert SourceNotAllowed();

        address senderAddr = abi.decode(message.sender, (address));
        if (senderAddr != expected) revert SourceNotAllowed();
        
        // For now, simply report the helper chain's chainId back to the gateway.
        // Future versions can derive pricing/volatility data here.
        uint256 helperChainId = block.chainid;

        // Basic validation to ensure the intent hasn't expired.
        bool validIntent = block.timestamp <= intent.deadline;

        Client.EVM2AnyMessage memory response = Client.EVM2AnyMessage({
            receiver: message.sender,
            data: abi.encode(intentId, validIntent ? helperChainId : uint256(0)),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(link)
        });

        uint256 fee = router.getFee(message.sourceChainSelector, response);
        if (link.allowance(address(this), address(router)) < fee) {
            link.approve(address(router), type(uint256).max);
        }
        
        bytes32 responseId = router.ccipSend(message.sourceChainSelector, response);
        emit ChainIdReported(responseId, message.messageId, helperChainId);
    }
}

