// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IntentInterface, IUniswapV2Router02} from "./IntentInterface.sol";
/**
 * @title IntentGateway
 * @notice Minimal CCIP-enabled intent dispatcher that sends BuyIntent payloads to a helper chain.
 *         Helper replies determine whether an intent is fillable or rejected.
 */
contract IntentGateway is IntentInterface, CCIPReceiver, Ownable {

    IERC20 public immutable link;
    IRouterClient public immutable router;
    uint64 public immutable helperSelector;

    address public helper;
    address public uniswapRouter;
    address public weth;
    uint64 public constant MONAD_CHAIN_SELECTOR = 2183018362218727504;
    
    mapping(address => uint64) public moand_launchpad_list;
    mapping(bytes32 => IntentStatus) public intentStatus;
    mapping(bytes32 => address) public intentOwner;
    mapping(bytes32 => bytes32) public requestIdByIntent;

    constructor(address _router, uint64 _helperSelector, address _link)
        CCIPReceiver(_router)
        Ownable(msg.sender)
    {
        router = IRouterClient(_router);
        helperSelector = _helperSelector;
        link = IERC20(_link);
    }
    function setMoandLaunchpadList(address _launchpad, uint64 _chainselector) external onlyOwner {
        moand_launchpad_list[_launchpad] = _chainselector;
    }

    function removeMoandLaunchpadList(address _launchpad) external onlyOwner {
        delete moand_launchpad_list[_launchpad];
    }

    function setHelper(address helper_) external onlyOwner {
        helper = helper_;
        emit HelperUpdated(helper_);
    }

    function setUniswapRouter(address _uniswapRouter) external onlyOwner {
        uniswapRouter = _uniswapRouter;
    }


    function submitIntent(BuyIntent calldata intent) external payable returns (bytes32 intentId) {
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
        // Check if memeToken is mapped to Monad chain selector
        if(moand_launchpad_list[intent.memeToken] == MONAD_CHAIN_SELECTOR || intent.chainselector == MONAD_CHAIN_SELECTOR) {
            // Direct swap on Monad using Uniswap router
            require(uniswapRouter != address(0), "Uniswap router not set");
            require(msg.value >= intent.maxEthIn, "Insufficient ETH sent");
            
            // Get WETH address from router (required: path[0] must equal Router's WETH)
            // Router checks: require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH')
            address routerWETH = IUniswapV2Router02(uniswapRouter).WETH();
            require(routerWETH != address(0), "Router WETH not set");
            
            // Calculate minimum amount out with slippage protection
            uint256 minAmountOut = intent.amountOut * (10000 - intent.maxSlippageBps) / 10000;
            
            // Build swap path: ETH -> WETH -> MEMEToken
            // path[0] MUST be Router's WETH address, otherwise INVALID_PATH error
            address[] memory path = new address[](2);
            path[0] = routerWETH;
            path[1] = intent.memeToken;
            
            // Execute swap via Uniswap router
            try IUniswapV2Router02(uniswapRouter).swapExactETHForTokens{value: intent.maxEthIn}(
                minAmountOut,
                path,
                intentOwner[intentId], // Send tokens to intent owner
                intent.deadline
            ) returns (uint[] memory) {
                // Swap successful
                intentStatus[intentId] = IntentStatus.Fillable;
                emit IntentChainResolved(intentId, block.chainid);
            } catch {
                // Swap failed, try with fee-on-transfer token support
                try IUniswapV2Router02(uniswapRouter).swapExactETHForTokensSupportingFeeOnTransferTokens{value: intent.maxEthIn}(
                    minAmountOut,
                    path,
                    intentOwner[intentId],
                    intent.deadline
                ) {
                    // Swap successful with fee-on-transfer support
                    intentStatus[intentId] = IntentStatus.Fillable;
                    emit IntentChainResolved(intentId, block.chainid);
                } catch {
                    // Swap failed, mark as rejected
                    intentStatus[intentId] = IntentStatus.Rejected;
                    emit IntentChainResolved(intentId, 0);
                }
            }
            // Refund excess ETH if any
            if (msg.value > intent.maxEthIn) {
                payable(intentOwner[intentId]).transfer(msg.value - intent.maxEthIn);
            }
        }
        else{
            // Prepare token amounts: send ETH (native token) to helper for swapping
            Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: address(0), // address(0) represents native token (ETH)
                amount: intent.maxEthIn
            });
            
            Client.EVM2AnyMessage memory payload = Client.EVM2AnyMessage({
                receiver: abi.encode(helper),
                data: abi.encode(intentId, intent),
                tokenAmounts: tokenAmounts,
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
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (message.sourceChainSelector != helperSelector) revert InvalidHelperResponse();
        if (helper == address(0)) revert HelperNotSet();
        
        address source = abi.decode(message.sender, (address));
        if (source != helper) revert InvalidHelperResponse();

        // Decode response: intentId, helperChainId, swapSuccess, amountOut
        (bytes32 intentId, uint256 helperChainId, bool swapSuccess,) = 
            abi.decode(message.data, (bytes32, uint256, bool, uint256));

        if (intentStatus[intentId] != IntentStatus.PendingQuote) revert InvalidHelperResponse();

        // Handle received meme tokens from helper
        if (message.destTokenAmounts.length > 0) {
            for (uint i = 0; i < message.destTokenAmounts.length; i++) {
                address token = message.destTokenAmounts[i].token;
                uint256 amount = message.destTokenAmounts[i].amount;
                
                // Transfer meme tokens to intent owner
                if (token != address(0) && amount > 0) {
                    IERC20(token).transfer(intentOwner[intentId], amount);
                }
            }
        }

        if (helperChainId == 0 || !swapSuccess) {
            intentStatus[intentId] = IntentStatus.Rejected;
        } else {
            intentStatus[intentId] = IntentStatus.Fillable;
        }

        emit IntentChainResolved(intentId, helperChainId);
    }
}

