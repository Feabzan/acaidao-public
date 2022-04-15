// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface IVesting {
    /**
     * @notice Indicator that this is a Vesting contract (for inspection)
     * @return true
     */
    function isVesting() external pure returns (bool);

    event Enabled();
    event Disabled();

    /**
     * Public fields.
     */

    function admin() external view returns (address);

    function enabled() external view returns (bool);

    function recipient() external view returns (address);

    function vestingToken() external view returns (address);

    function vestingStart() external view returns (uint256);

    function vestingEnd() external view returns (uint256);

    /**
     * Recipient UI.
     */

    /**
     * @notice Address of the ERC20 Token that is being vested.
     */
    function getTokenAddress() external view returns (address);

    /**
     * @notice Transfer contract ownership.
     */
    function transferOwner(address reciever) external returns (bool success);

    /**
     * @notice Amount of tokens yet to vest.
     */
    function unvestedAmount() external view returns (uint256);

    /**
     * @notice Amount of vested tokens that have vested.
     */
    function vestedAmount() external view returns (uint256);

    /**
     * @notice Amount of vested tokens held by vesting contract, ready to be claimed.
     */
    function claimableVestedAmount() external view returns (uint256);

    /**
     * @notice Transfers any vested tokens to contract owner.
     */
    function claimVested() external returns (bool success);

    /**
     * Admin UI.
     */

    /**
     * @notice Enables contract.
     * Requires canEnable()
     */
    function enable() external returns (bool success);

    /**
     * @notice Allows admin to check if contract can be enabled.
     * Requires vesting to be disabled.
     * Requires contract to be holding exact reward amount.
     */
    function canEnable() external view returns (uint error);

    /**
     * @notice Disables contract for admin corrections. A contract cannot be disabled if vesting has started.
     * Requires canDisable()
     */
    function disable() external returns (bool success);

    /**
     * @notice Allows admin to check if contract can be disabled.
     * Requires vesting to have not started yet.
     */
    function canDisable() external view returns (uint error);

    /**
     * @notice Sets a new reward recipient.
     * Requires vesting to be disabled.
     */
    function setRecipient(address recipient_) external returns (bool success);

    /**
     * @notice Sets a new vesting amount.
     * Requires vesting to be disabled.
     */
    function setVestingAmount(uint256 vestingAmount_)
        external
        returns (bool success);

    /**
     * @notice Sets a new vesting start and end.
     * Requires vesting to be disabled.
     */
    function setVestingSchedule(uint256 vestingStart_, uint256 vestingEnd_)
        external
        returns (bool success);

    /**
     * @notice Transfers all reward tokens to the admin.
     * Requires vesting to be disabled.
     */
    function withdrawReward() external returns (bool success);

    /**
     * @notice Transfers all reward tokens from the admin to this contract.
     * If contract currently holds more reward than vestingAmount, the difference will be withdrawn to admin.
     * Requires vesting to be disabled.
     * Requires ERC20.approve(this, vestingAmount).
     * Admin may also directly transfer reward to this contract instead of calling deposit reward.
     */
    function balanceReward() external returns (bool success);
}
