// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

/**
 * @title IntentGateway
 * @notice Minimal CCIP-enabled intent dispatcher that sends BuyIntent payloads to a helper chain.
 *         Helper replies determine whether an intent is fillable or rejected.
 */
contract IntentGateway is CCIPReceiver, Ownable {
    enum IntentStatus {
        None,
        PendingQuote,
        Fillable,
        Rejected
    }

    struct BuyIntent {
        address memeToken;
        uint256 amountOut;
        uint256 maxEthIn;
        uint256 maxSlippageBps;
        uint64 helperSelector;
        uint256 deadline;
        bytes32 nonce;
    }

    IERC20 public immutable link;
    IRouterClient public immutable router;
    uint64 public immutable helperSelector;

    address public helper;

    mapping(bytes32 => IntentStatus) public intentStatus;
    mapping(bytes32 => address) public intentOwner;
    mapping(bytes32 => bytes32) public requestIdByIntent;

    event HelperUpdated(address indexed helper);
    event IntentSubmitted(bytes32 indexed intentId, address indexed user);
    event IntentQuoteRequested(bytes32 indexed intentId, bytes32 indexed requestId);
    event IntentChainResolved(bytes32 indexed intentId, uint256 helperChainId);

    error HelperNotSet();
    error IntentExpired();
    error IntentAlreadySeen();
    error InvalidHelperResponse();
    error HelperSelectorMismatch();

    constructor(address _router, uint64 _helperSelector, address _link)
        CCIPReceiver(_router)
        Ownable(msg.sender)
    {
        router = IRouterClient(_router);
        helperSelector = _helperSelector;
        link = IERC20(_link);
    }

    function setHelper(address helper_) external onlyOwner {
        helper = helper_;
        emit HelperUpdated(helper_);
    }

    function submitIntent(BuyIntent calldata intent) external returns (bytes32 intentId) {
        if (helper == address(0)) revert HelperNotSet();
        if (intent.deadline < block.timestamp) revert IntentExpired();
        if (intent.helperSelector != helperSelector) revert HelperSelectorMismatch();

        intentId = keccak256(abi.encode(intent, msg.sender));
        if (intentStatus[intentId] != IntentStatus.None) revert IntentAlreadySeen();

        intentOwner[intentId] = msg.sender;
        intentStatus[intentId] = IntentStatus.PendingQuote;

        _dispatchIntent(intentId, intent);
        emit IntentSubmitted(intentId, msg.sender);
    }

    function _dispatchIntent(bytes32 intentId, BuyIntent calldata intent) internal {
        Client.EVM2AnyMessage memory payload = Client.EVM2AnyMessage({
            receiver: abi.encode(helper),
            data: abi.encode(intentId, intent),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(link)
        });

        uint256 fee = router.getFee(helperSelector, payload);
        if (link.allowance(address(this), address(router)) < fee) {
            link.approve(address(router), type(uint256).max);
        }

        bytes32 requestId = router.ccipSend(helperSelector, payload);
        requestIdByIntent[intentId] = requestId;

        emit IntentQuoteRequested(intentId, requestId);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (message.sourceChainSelector != helperSelector) revert InvalidHelperResponse();
        if (helper == address(0)) revert HelperNotSet();

        address source = abi.decode(message.sender, (address));
        if (source != helper) revert InvalidHelperResponse();

        (bytes32 intentId, uint256 helperChainId) = abi.decode(message.data, (bytes32, uint256));

        if (intentStatus[intentId] != IntentStatus.PendingQuote) revert InvalidHelperResponse();

        if (helperChainId == 0) {
            intentStatus[intentId] = IntentStatus.Rejected;
        } else {
            intentStatus[intentId] = IntentStatus.Fillable;
        }

        emit IntentChainResolved(intentId, helperChainId);
    }
}

