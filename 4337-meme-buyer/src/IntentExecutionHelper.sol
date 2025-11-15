// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IntentInterface, IUniswapV2Router02} from "./IntentInterface.sol";

/**
 * @title IntentExecutionHelper
 * @notice Receives BuyIntent payloads from IntentGateway, checks price feeds, and responds with fill status.
 */
contract IntentExecutionHelper is IntentInterface, CCIPReceiver, Ownable {

    IERC20 public immutable link;
    IRouterClient public immutable router;
    
    address public uniswapRouter;
    address public weth;

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

    function setUniswapRouter(address _uniswapRouter) external onlyOwner {
        uniswapRouter = _uniswapRouter;
    }

    function setWETH(address _weth) external onlyOwner {
        weth = _weth;
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Decode the message data to get intentId and BuyIntent
        (bytes32 intentId, BuyIntent memory intent) = abi.decode(message.data, (bytes32, BuyIntent));
    
        address expected = allowedGateways[message.sourceChainSelector];
        if (expected == address(0)) revert SourceNotAllowed();

        address senderAddr = abi.decode(message.sender, (address));
        if (senderAddr != expected) revert SourceNotAllowed();
        
        // Get ETH amount from CCIP message (native token transfer)
        uint256 ethAmount = 0;
        for (uint i = 0; i < message.destTokenAmounts.length; i++) {
            if (message.destTokenAmounts[i].token == address(0)) {
                ethAmount = message.destTokenAmounts[i].amount;
                break;
            }
        }
        // Emit intent received event
        emit IntentReceived(
            intentId,
            message.messageId,
            intent.memeToken,
            ethAmount,
            intent.maxEthIn
        );
        
        // Basic validation to ensure the intent hasn't expired.
        bool validIntent = block.timestamp <= intent.deadline;
        uint256 helperChainId = block.chainid;
        (uint256 amountOut, bool swapSuccess) = _executeSwap(intentId, intent, ethAmount, validIntent);
        
        // Prepare response data: intentId, helperChainId, swapSuccess, amountOut
        bytes memory responseData = abi.encode(intentId, swapSuccess ? helperChainId : uint256(0), swapSuccess, amountOut);
        
        // If swap was successful, send meme tokens back to gateway via CCIP
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        if (swapSuccess && amountOut > 0) {
            IERC20 memeToken = IERC20(intent.memeToken);
            // Approve router to spend meme tokens
            if (memeToken.allowance(address(this), address(router)) < amountOut) {
                memeToken.approve(address(router), type(uint256).max);
            }
            
            // Include meme tokens in the response
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: intent.memeToken,
                amount: amountOut
            });
        }

        Client.EVM2AnyMessage memory response = Client.EVM2AnyMessage({
            receiver: message.sender,
            data: responseData,
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(link)
        });

        uint256 fee = router.getFee(message.sourceChainSelector, response);
        if (link.allowance(address(this), address(router)) < fee) {
            link.approve(address(router), type(uint256).max);
        }
        
        bytes32 responseId = router.ccipSend(message.sourceChainSelector, response);
        
        // Emit events
        emit ChainIdReported(responseId, message.messageId, helperChainId);
    }
    
    function _executeSwap(
        bytes32 intentId,
        BuyIntent memory intent,
        uint256 ethAmount,
        bool validIntent
    ) internal returns (uint256 amountOut, bool swapSuccess) {
        // If intent is valid and we have ETH from CCIP, perform swap
        if (!validIntent || uniswapRouter == address(0) || ethAmount == 0 || ethAmount > intent.maxEthIn) {
            emit SwapExecuted(intentId, intent.memeToken, ethAmount, 0, false);
            return (0, false);
        }
        
        // Get WETH address from router (required for swapExactETHForTokens)
        address routerWETH = IUniswapV2Router02(uniswapRouter).WETH();
        if (routerWETH == address(0)) {
            emit SwapExecuted(intentId, intent.memeToken, ethAmount, 0, false);
            return (0, false);
        }
        
        // Calculate minimum amount out with slippage protection
        uint256 minAmountOut = intent.amountOut * (10000 - intent.maxSlippageBps) / 10000;
        
        // Build swap path: ETH -> WETH -> MEMEToken
        // Note: swapExactETHForTokens requires path[0] to be Router's WETH address
        address[] memory path = new address[](2);
        path[0] = routerWETH;
        path[1] = intent.memeToken;
        
        // Execute swap via Uniswap router
        try IUniswapV2Router02(uniswapRouter).swapExactETHForTokens{value: ethAmount}(
            minAmountOut,
            path,
            address(this), // Send tokens to this contract first
            intent.deadline
        ) returns (uint[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
            swapSuccess = true;
            emit SwapExecuted(intentId, intent.memeToken, ethAmount, amountOut, true);
        } catch {
            // Swap failed, try with fee-on-transfer token support
            try IUniswapV2Router02(uniswapRouter).swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
                minAmountOut,
                path,
                address(this),
                intent.deadline
            ) {
                // For fee-on-transfer tokens, we need to check balance
                IERC20 memeToken = IERC20(intent.memeToken);
                amountOut = memeToken.balanceOf(address(this));
                swapSuccess = true;
                emit SwapExecuted(intentId, intent.memeToken, ethAmount, amountOut, true);
            } catch {
                // Swap failed, will report as rejected
                swapSuccess = false;
                emit SwapExecuted(intentId, intent.memeToken, ethAmount, 0, false);
            }
        }
    }
}

