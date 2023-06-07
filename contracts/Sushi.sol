// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/ISushi.sol';

contract Sushi is Ownable, ERC20, ISushi {
  address public minter;

  event MinterChanged(address indexed minter_);

  modifier onlyMinter() {
    require(msg.sender == minter, 'Access: Only minter can call this');
    _;
  }

  constructor(uint256 initialSupply_) ERC20('Sushi Token', 'SST') {
    _mint(msg.sender, initialSupply_);
  }

  function setMinter(address minter_) external override onlyOwner {
    minter = minter_;
    emit MinterChanged(minter);
  }

  function mint(address to, uint256 amount) external override onlyMinter {
    _mint(to, amount);
  }
}
