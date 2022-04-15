// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface IVault {
    /**
     * @notice Indicator that this is a Vesting contract (for inspection)
     * @return true
     */
    function isVault() external pure returns (bool);

    function admin() external view returns (address);

    function collateralFactorMantissa() external view returns (uint256);
    function originalRecipient() external view returns (address);

    function getNPV() external view returns (uint256);
}