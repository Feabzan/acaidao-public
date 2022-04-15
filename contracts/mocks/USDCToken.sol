// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCToken is ERC20 {
    constructor(
        address _initialAccount,
        uint256 _initialBalance,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
    {
        _mint(_initialAccount, _initialBalance);
    }

   function mint(address to, uint amount) external {
       _mint(to, amount);
   }

   function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
