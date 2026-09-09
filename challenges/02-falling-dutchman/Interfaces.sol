// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDutchExchange {
    function deposit(address tokenAddress, uint256 amount) external returns (uint256);
    function withdraw(address tokenAddress, uint256 amount) external returns (uint256);
    function postBuyOrder(address sellToken, address buyToken, uint256 auctionIndex, uint256 amount)
        external
        returns (uint256 newBuyerBal);
    function claimBuyerFunds(address sellToken, address buyToken, address user, uint256 auctionIndex)
        external
        returns (uint256 returned, uint256 frtsIssued);
    function getAuctionIndex(address sellToken, address buyToken) external view returns (uint256);
    function getCurrentAuctionPrice(address sellToken, address buyToken, uint256 auctionIndex)
        external
        view
        returns (uint256 num, uint256 den);
}

interface IUniswapV1Exchange {
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline)
        external
        payable
        returns (uint256 tokensBought);
}
