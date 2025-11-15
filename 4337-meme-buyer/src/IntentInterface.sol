// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

interface IntentInterface {
    enum IntentStatus {
        None,
        PendingQuote,
        Fillable,
        Rejected
    }

    struct BuyIntent {
        uint64 chainselector;
        address memeToken; 
        uint256 amountOut;
        uint256 maxEthIn;
        uint256 maxSlippageBps;
        uint64 helperSelector;
        uint256 deadline;
        bytes32 nonce;
    }

    event HelperUpdated(address indexed helper);
    event IntentSubmitted(bytes32 indexed intentId, address indexed user);
    event IntentQuoteRequested(bytes32 indexed intentId, bytes32 indexed requestId);
    event IntentChainResolved(bytes32 indexed intentId, uint256 helperChainId);

    error HelperNotSet();
    error IntentExpired();
    error IntentAlreadySeen();
    error InvalidHelperResponse();
    error HelperSelectorMismatch();
    event SourceAllowed(uint64 indexed selector, address indexed gateway);
    event SourceRemoved(uint64 indexed selector);
    event ChainIdReported(
        bytes32 indexed responseMessageId,
        bytes32 indexed requestMessageId,
        uint256 helperChainId
    );
    event IntentReceived(
        bytes32 indexed intentId,
        bytes32 indexed messageId,
        address indexed memeToken,
        uint256 ethAmount,
        uint256 maxEthIn
    );
    event SwapExecuted(
        bytes32 indexed intentId,
        address indexed memeToken,
        uint256 ethAmount,
        uint256 amountOut,
        bool success
    );

    error SourceNotAllowed();
}
