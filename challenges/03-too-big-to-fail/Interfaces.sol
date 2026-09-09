// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITroveManager {
    function batchLiquidateTroves(address[] calldata _troveArray) external;
    function liquidateTroves(uint256 _n) external;
    function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);
    function getTroveColl(address _borrower) external view returns (uint256);
    function getTroveDebt(address _borrower) external view returns (uint256);
}
