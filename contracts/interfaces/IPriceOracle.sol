// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./IAToken.sol";

interface IPriceOracle {
    /**
     * @notice Indicator that this is a PriceOracle contract (for inspection)
     * @return true
     */
    function isPriceOracle() external pure returns (bool);

    /**
     * @notice Get the underlying price of a aToken asset
     * @param aToken The aToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(IAToken aToken)
        external
        view
        returns (uint256);

    function getPrice(address asset) external view returns (uint);
}
