// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/ISushiLP.sol';

contract SushiLP is ERC20, ISushiLP {
  constructor(
    uint256 initialSupply_,
    string memory name_,
    string memory symbol_
  ) ERC20(name_, symbol_) {
    _mint(msg.sender, initialSupply_);
  }
}
