// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./IAToken.sol";

abstract contract IAErc20 {
    /*** User Interface ***/

    function mint(uint256 mintAmount) external virtual returns (uint256);

    function redeem(uint256 redeemTokens) external virtual returns (uint256);

    function redeemUnderlying(uint256 redeemAmount)
        external
        virtual
        returns (uint256);

    function borrow(uint256 borrowAmount) external virtual returns (uint256);

    function repayBorrow(uint256 repayAmount)
        external
        virtual
        returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount)
        external
        virtual
        returns (uint256);

    // function liquidateBorrow(
    //     address borrower,
    //     uint256 repayAmount,
    //     IAToken cTokenCollateral
    // ) external virtual returns (uint256);

    /*** Admin Functions ***/

    function _addReserves(uint256 addAmount) external virtual returns (uint256);
}
