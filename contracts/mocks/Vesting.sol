// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../errors/EVesting.sol";
import "../interfaces/IVesting.sol";

contract Vesting is IVesting, EVesting {
    function isVesting() external pure returns (bool) {
        return true;
    }

    address public admin;
    bool public enabled = false;

    address public recipient;
    address public vestingToken;
    uint256 public vestingAmount;
    uint256 public vestingStart;
    uint256 public vestingEnd;

    uint256 private lastUpdate;

    constructor(
        address recipient_,
        address vestingToken_,
        uint256 vestingAmount_,
        uint256 vestingStart_,
        uint256 vestingEnd_
    ) {
        admin = msg.sender;

        recipient = recipient_;
        vestingToken = vestingToken_;
        vestingAmount = vestingAmount_;
        setVestingSchedule(vestingStart_, vestingEnd_);
    }

    function getTokenAddress() external view returns (address) {
        return vestingToken;
    }

    function vestedAmount() external view returns (uint256) {
        uint256 currentTime = Math.min(block.timestamp, vestingEnd);
        return
            (vestingAmount * (currentTime - vestingStart)) /
            (vestingEnd - vestingStart);
    }

    function unvestedAmount() external view returns (uint256) {
        return vestingAmount - this.vestedAmount();
    }

    function claimableVestedAmount() public view returns (uint256) {
        require(enabled, "Contract must be enabled");

        uint256 currentTime = Math.min(block.timestamp, vestingEnd);
        return
            (vestingAmount * (currentTime - lastUpdate)) /
            (vestingEnd - vestingStart);
    }

    function claimVested() public returns (bool success) {
        require(enabled, "Contract must be enabled");
        uint256 currentTime = Math.min(block.timestamp, vestingEnd);
        uint256 amount;
        if (block.timestamp >= vestingEnd) {
            // Vesting complete, transfer any remaining tokens
            amount = vestingBalance();
        } else {
            amount = claimableVestedAmount();
        }
        lastUpdate = currentTime;

        ERC20(vestingToken).transfer(recipient, amount);
        return true;
    }

    function transferOwner(address reciever) external returns (bool success) {
        require(msg.sender == recipient, "Unauthorized");
        recipient = reciever;
        return true;
    }

    function enable() external returns (bool success) {
        require(msg.sender == admin, "Unauthorized");
        require(canEnable() == EVesting.NO_ERROR, "canEnable() failed");
        enabled = true;
        return true;
    }

    function canEnable() public view returns (uint256 error) {
        require(msg.sender == admin, "Unauthorized");
        if (enabled) return EVesting.CONTRACT_NOT_DISABLED;
        if (vestingBalance() != vestingAmount)
            return EVesting.REWARD_CONDITIONS_NOT_MET;
        return EVesting.NO_ERROR;
    }

    function disable() external returns (bool success) {
        require(msg.sender == admin, "Unauthorized");
        require(canDisable() == EVesting.NO_ERROR, "canDisable() failed");
        enabled = false;
        return true;
    }

    function canDisable() public view returns (uint256 error) {
        uint256 currentTime = block.timestamp;
        if (currentTime >= vestingStart)
            return EVesting.VESTING_ALREADY_STARTED;
        return EVesting.NO_ERROR;
    }

    function setRecipient(address recipient_) external returns (bool success) {
        require(msg.sender == admin, "Unauthorized");
        require(!enabled, "Contract must not be enabled");
        recipient = recipient_;
        return true;
    }

    function setVestingAmount(uint256 vestingAmount_)
        external
        returns (bool success)
    {
        require(msg.sender == admin, "Unauthorized");
        require(!enabled, "Contract must not be enabled");
        vestingAmount = vestingAmount_;
        return true;
    }

    function setVestingSchedule(uint256 vestingStart_, uint256 vestingEnd_)
        public
        returns (bool success)
    {
        require(msg.sender == admin, "Unauthorized");
        require(!enabled, "Contract must not be enabled");

        require(
            vestingStart_ < vestingEnd_,
            "vestingStart must precede vestingEnd"
        );

        vestingStart = vestingStart_;
        vestingEnd = vestingEnd_;
        return true;
    }

    function withdrawReward() external returns (bool success) {
        require(msg.sender == admin, "Unauthorized");
        require(!enabled, "Contract must not be enabled");
        uint256 balance = vestingBalance();
        if (balance == 0) return true;
        ERC20(vestingToken).transfer(admin, balance);
        return true;
    }

    function balanceReward() external returns (bool success) {
        require(msg.sender == admin, "Unauthorized");
        require(!enabled, "Contract must not be enabled");
        uint256 balance = vestingBalance();
        if (balance == vestingAmount) return true;
        if (balance > vestingAmount) {
            ERC20(vestingToken).transfer(admin, balance);
            return true;
        }

        uint256 amount = vestingAmount - balance;

        ERC20(vestingToken).transferFrom(admin, address(this), amount);
        return true;
    }

    /**
     * Internal functions
     */
    function vestingBalance() internal view returns (uint256) {
        return ERC20(vestingToken).balanceOf(address(this));
    }
}
