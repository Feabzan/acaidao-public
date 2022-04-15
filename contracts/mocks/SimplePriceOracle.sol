// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../AToken.sol";
import "../interfaces/IAToken.sol";
import "../AErc20.sol";
import "../PriceOracle.sol";

contract SimplePriceOracle is PriceOracle {
    mapping(address => uint256) prices;
    event PricePosted(
        address asset,
        uint256 previousPriceMantissa,
        uint256 requestedPriceMantissa,
        uint256 newPriceMantissa
    );

    function _getUnderlyingAddress(IAToken aToken)
        private
        view
        returns (address)
    {
        address asset;
        if (compareStrings(aToken.symbol(), "aETH")) {
            asset = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        } else {
            asset = address(AErc20(address(aToken)).underlying());
        }
        return asset;
    }

    function getUnderlyingPrice(IAToken aToken)
        public
        view
        returns (uint256)
    {
        return prices[_getUnderlyingAddress(aToken)];
    }

    function getPrice(address asset) public view returns (uint256) {
        return prices[asset];
    }

    function setUnderlyingPrice(IAToken aToken, uint256 underlyingPriceMantissa)
        public
    {
        address asset = _getUnderlyingAddress(aToken);
        emit PricePosted(
            asset,
            prices[asset],
            underlyingPriceMantissa,
            underlyingPriceMantissa
        );
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint256 price) public {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint256) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
