// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./interfaces/IPriceOracle.sol";

abstract contract PriceOracle is IPriceOracle {
    /**
     * @notice Indicator that this is a PriceOracle contract (for inspection)
     * @return true
     */
    function isPriceOracle() external pure returns (bool) {
        return true;
    }
}
