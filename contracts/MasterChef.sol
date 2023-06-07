// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './interfaces/ISushi.sol';
import './interfaces/ISushiLP.sol';
import '../node_modules/hardhat/console.sol';

contract MasterChef is Ownable {
  using SafeERC20 for ISushi;
  using SafeERC20 for ISushiLP;

  // Refer to the information of individual liquidity provision
  struct StakingInfo {
    // Amount of liquidity
    uint256 stakedAmount;
    // Cumulated claimed reward
    /* Tips: This is not the regular cumulative. See below */
    uint256 claimedAmount;
  }

  // Refer to the address of Sushi token playing the role of reward as well as liquidity
  ISushi public immutable sushi;

  // Datasets of liquidity information of Sushi stakers
  mapping(address => StakingInfo) private stakers_;

  // Datasets of liquidity information of SushiLP stakers
  mapping(address => mapping(address => StakingInfo)) private lpstakers_;

  // Determine how much reward Should be given to both sushi and sushiLP depositors
  uint256 public constant REWARD = 1e19;

  // Determine the last index of number reward had already given
  uint256 public lastBlockNumber;

  // Determine the amounts of deposits of both sushi and sushiLP
  uint256 public totalDeposited;
  uint256 public totalLPDeposited;

  // Determine the allocation point between sushi and sushiLP
  // Should be smaller than 255 so neither side is zero profited
  uint8 public alloc2sushi;

  // Reward cumulatives
  /*
    Tips: This is not the historic cumulatives
      If a new staker stakes his or her liquidity here, the cumulated reward Should be
        * `depositor.claimedAmount = cumulatedReward_ * amount / totalDeposited`
        * `cumulatedReward_ = cumulatedReward_ * (totalDeposited + amount) / totalDeposited`
      If stakers withdraw their liquidity, we need to update both claimedAmount and cumulatedReward_
        * `depositor.claimedAmount = depositor.claimedAmount * (depositor.stakedAmount - amount) / depositor.stakedAmount`
        * `depositor.claimedAmount -= amount`
        * `cumulatedReward_ = cumulatedReward * (totalDeposited - amount) / totalDeposited`
        * `totalDeposited = totalDeposited - amount`
      If stakers claim their reward
        * `reward = cumulatedReward_ * amount / totalDeposited - depositor.claimedAmount`
        * `depositor.claimedAmount = depositor.claimedAmount + reward`
      The reward Should be given individually so we just sum up with `cumulatedReward_`
        * `cumulatedReward_ = cumulatedReward_ + (blockPassed * 10)
  */
  uint256 private cumulatedReward_;
  uint256 private cumulatedLPReward_;

  event Deposited(address indexed sender, uint amountDeposited, uint depositedTotal);
  event LPDeposited(
    address indexed sender,
    address indexed tokenId,
    uint amountDeposited,
    uint depositedTotal
  );
  event Withdrawn(address indexed sender, uint amountWithdrawn, uint remainingAmount);
  event LPWithdrawn(
    address indexed sender,
    address indexed tokenId,
    uint amountWithdrawn,
    uint remainingAmount
  );
  event Claimed(address indexed sender, uint amountClaimed);
  event LPClaimed(address indexed sender, address indexed tokenId, uint amountClaimed);
  event AllocPointModified(uint8 prev, uint8 modified);

  modifier greaterThanZero(uint256 value) {
    require(value > 0, 'Params: Input value must be greater than zero');
    _;
  }

  constructor(ISushi sushi_, uint8 alloc2sushi_) {
    sushi = sushi_;
    alloc2sushi = alloc2sushi_;
  }

  // Deposit Sushi token
  function deposit(uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    // Check for the block reward
    _mint();

    sushi.transferFrom(msg.sender, address(this), tokenAmount);

    // Handler to the dataset
    StakingInfo storage depositor = stakers_[msg.sender];

    // If this is the first time of staking, then modify storage values and cumulatedReward_ as well
    if (depositor.stakedAmount == 0) {
      depositor.stakedAmount = tokenAmount;
      // We need to set claimedAmount even though it is being created since for the further distribution
      if (totalDeposited > 0)
        depositor.claimedAmount = (cumulatedReward_ * tokenAmount) / totalDeposited;
      cumulatedReward_ += depositor.claimedAmount;
    } else {
      // Claim everytime when the user calls any apis
      _claim(msg.sender);
      depositor.stakedAmount += tokenAmount;
    }

    // Update totalDeposited value
    totalDeposited += tokenAmount;

    // Since it's the user interaction, we need to notify it
    emit Deposited(msg.sender, tokenAmount, depositor.stakedAmount);
  }

  // Deposit Sushi LP token: Same logic but little difference with LPs
  function depositLP(ISushiLP lpToken, uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    _mint();

    lpToken.transferFrom(msg.sender, address(this), tokenAmount);

    StakingInfo storage depositor = lpstakers_[address(lpToken)][msg.sender];

    if (depositor.stakedAmount == 0) {
      depositor.stakedAmount = tokenAmount;
      if (totalLPDeposited > 0)
        depositor.claimedAmount = (cumulatedLPReward_ * tokenAmount) / totalLPDeposited;
      cumulatedLPReward_ += depositor.claimedAmount;
    } else {
      _claimLP(msg.sender, lpToken);
      depositor.stakedAmount += tokenAmount;
    }

    totalLPDeposited += tokenAmount;

    emit LPDeposited(msg.sender, address(lpToken), tokenAmount, depositor.stakedAmount);
  }

  // Withdraw Sushi Token
  function withdraw(uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    require(stakers_[msg.sender].stakedAmount >= tokenAmount, 'Withdraw: Not enough Sushi');

    // Check for the block reward
    _mint();

    // Claim everytime when the user calls any apis
    _claim(msg.sender);

    // Handler to the dataset
    StakingInfo storage depositor = stakers_[msg.sender];

    // Of all the cases, we need to update the amountClaimed value since we don't need to subtract
    // the claimed amount of withdrawn tokens that doesn't give any reward
    depositor.claimedAmount =
      (depositor.claimedAmount * (depositor.stakedAmount - tokenAmount)) /
      depositor.stakedAmount;
    depositor.stakedAmount -= tokenAmount;

    // Update both cumulatedReward and totalDeposited for accurate distribution of reward
    cumulatedReward_ = (cumulatedReward_ * (totalDeposited - tokenAmount)) / totalDeposited;
    totalDeposited -= tokenAmount;

    // Finally, returning withdrawn token
    sushi.transfer(msg.sender, tokenAmount);

    // Since it's the user interaction, we need to notify it
    emit Withdrawn(msg.sender, tokenAmount, depositor.stakedAmount);
  }

  // Withdraw SushiLP Token: Same logic but little difference with LPs
  function withdrawLP(ISushiLP lpToken, uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    require(
      lpstakers_[address(lpToken)][msg.sender].stakedAmount >= tokenAmount,
      'WithdrawLP: Not enough SushiLP'
    );
    _mint();
    _claimLP(msg.sender, lpToken);

    StakingInfo storage depositor = lpstakers_[address(lpToken)][msg.sender];
    depositor.claimedAmount =
      (depositor.claimedAmount * (depositor.stakedAmount - tokenAmount)) /
      depositor.stakedAmount;
    depositor.stakedAmount -= tokenAmount;

    cumulatedLPReward_ = (cumulatedLPReward_ * (totalLPDeposited - tokenAmount)) / totalLPDeposited;
    totalLPDeposited -= tokenAmount;

    lpToken.transfer(msg.sender, tokenAmount);
    emit LPWithdrawn(msg.sender, address(lpToken), tokenAmount, depositor.stakedAmount);
  }

  // Define external api for the internal claim function
  function claim() external {
    // Check for the block reward
    _mint();

    uint256 claimedAmount = _claim(msg.sender);

    // Since it's the user interaction, we need to notify it
    emit Claimed(msg.sender, claimedAmount);
  }

  function claimLP(ISushiLP lpToken) external {
    _mint();

    uint256 claimedAmount = _claimLP(msg.sender, lpToken);

    emit LPClaimed(msg.sender, address(lpToken), claimedAmount);
  }

  // Set allocation point between group of Sushi stakers and LP stakers
  // Can only be done by the owner or governance
  function setAllocationPoint(uint8 alloc2sushi_) external onlyOwner {
    _mint();

    uint8 prev = alloc2sushi;
    alloc2sushi = alloc2sushi_;

    // Since it's the user interaction, we need to notify it
    emit AllocPointModified(prev, alloc2sushi);
  }

  // Claim accumulated reward Sushi stakers
  function _claim(address claimer) internal returns (uint256) {
    // Handler to the dataset
    StakingInfo storage info = stakers_[claimer];

    // If nothing was deposited, just end
    // This can prevent the `division by zero` fault caused by `totalDeposited = 0`
    if (info.stakedAmount == 0) return 0;

    // Calculate reward distribution according to the staked amount
    uint256 rewardDistributed = (cumulatedReward_ * info.stakedAmount) /
      totalDeposited -
      info.claimedAmount;
    info.claimedAmount = info.claimedAmount + rewardDistributed;

    sushi.mint(claimer, rewardDistributed);

    return rewardDistributed;
  }

  // Claim accumulated reward for LP stakers: Same logic but little difference with LPs
  function _claimLP(address claimer, ISushiLP lpToken) internal returns (uint256) {
    StakingInfo storage info = lpstakers_[address(lpToken)][claimer];

    if (info.stakedAmount == 0) return 0;

    uint256 rewardDistributed = (cumulatedLPReward_ * info.stakedAmount) /
      totalLPDeposited -
      info.claimedAmount;
    info.claimedAmount = info.claimedAmount + rewardDistributed;

    sushi.mint(claimer, rewardDistributed);

    return rewardDistributed;
  }

  // Mint accumulated token
  function _mint() internal returns (uint256, uint256) {
    // Calculate the reward amount of sushi
    uint256 accumulated = (block.number - lastBlockNumber) * REWARD;
    lastBlockNumber = block.number;

    if (totalDeposited == 0 && totalLPDeposited == 0) return (uint256(0), uint256(0));
    // If either one side is without liquidity, we do not need to distribute it
    uint256 rate = uint256(alloc2sushi);
    if (totalDeposited == 0) rate = 0;
    if (totalLPDeposited == 0) rate = uint256(256);

    uint256 rewardSushi = (accumulated * rate) / uint256(256);
    uint256 rewardLP = accumulated - rewardSushi;

    cumulatedReward_ = cumulatedReward_ + rewardSushi;
    cumulatedLPReward_ = cumulatedLPReward_ + rewardLP;

    return (rewardSushi, rewardLP);
  }
}
