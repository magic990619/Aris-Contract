// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// mock class using ERC20
contract AFI is ERC20, Ownable {
    
    constructor() ERC20("AFI", "AFI") {}

    function mint(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }
}
