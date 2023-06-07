// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ISushi is IERC20 {
  function setMinter(address) external;

  function mint(address, uint256) external;
}
