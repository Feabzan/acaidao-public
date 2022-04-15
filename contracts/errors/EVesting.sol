// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

abstract contract EVesting {
    uint256 public constant NO_ERROR = 0;
    uint256 public constant UNAUTHORIZED = 1;
    uint256 public constant CONTRACT_NOT_DISABLED = 2;
    uint256 public constant CONTRACT_NOT_ENABLED = 3;
    uint256 public constant REWARD_CONDITIONS_NOT_MET = 4;
    uint256 public constant VESTING_ALREADY_STARTED = 5;
}
