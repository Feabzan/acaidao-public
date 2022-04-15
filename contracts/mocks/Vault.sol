// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVesting} from "../interfaces/IVesting.sol";
import {IVault} from "../interfaces/IVault.sol";

contract Vault is IVault {
    function isVault() external pure returns (bool) {
        return true;
    }

    /**
     * @notice Administrator for this contract
     */
    address public admin;

    IVesting public vestingContract;
    address public vestingToken;
    uint256 public discountMantissa;
    uint256 public collateralFactorMantissa;
    address public originalRecipient;

    constructor(
        IVesting _vestingContract,
        uint256 _discountMantissa,
        uint256 _collateralFactorMantissa
    ) {
        admin = msg.sender;
        vestingContract = _vestingContract;
        discountMantissa = _discountMantissa;
        collateralFactorMantissa = _collateralFactorMantissa;
        vestingToken = _vestingContract.vestingToken();
        originalRecipient = _vestingContract.recipient();
    }

    /**
     * Linear vesting NPV, sum of tokens held by vesting contract, claimable vested tokens,
     * and a linear discount of unvested tokens. UnvestedAmount * discount factor / 2;
     */
    function getNPV() external view returns (uint256) {
        return
            vestingContract.claimableVestedAmount() +
            (vestingContract.unvestedAmount() * discountMantissa) /
            2; // Linear vest
    }
}
