// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./AToken.sol";
import "./PriceOracle.sol";

contract ComptrollerStorage {
    /**
     * @notice Administrator for this contract
     */
    address public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address public pendingAdmin;

    /**
     * @notice Active brains of Unitroller
     */
    address public comptrollerImplementation;

    // /**
    //  * @notice Pending brains of Unitroller
    //  */
    // address public pendingComptrollerImplementation;

    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint256 public closeFactorMantissa;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    uint256 public liquidationIncentiveMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    uint256 public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => AToken[]) public accountAssets;

    struct VestingContractInfo {
        bool isListed;
        bool enabledAsCollateral;
        address vault;
        address unvestedTokenLiquidator;
        uint256 amountOwedToLiquidator;
    }

    mapping(IVesting => VestingContractInfo) public vestingContractInfo;
    mapping(address => IVesting) public accountRegisteredVesting;
}
