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

  struct StakingInfo {
    uint256 stakedAmount;
    uint256 claimedAmount;
  }

  struct PoolInfo {
    ISushiLP lpToken;
    uint256 lastRewardBlock;
    uint256 sharePerToken;
    uint256 allocPoint;
  }

  ISushi public immutable sushi;

  PoolInfo[] public poolInfo;

  mapping(address => StakingInfo) private stakers_;
  mapping(uint => mapping(address => StakingInfo)) private lpstakers_;

  uint256 public totalAllocPoint = 0;

  uint256 public sharePerSushiToken = 0;
  uint256 public lastSushiRewardBlock;

  uint8 public alloc2sushi;

  uint256 public constant REWARD = 1e19;

  event Deposited(address indexed sender, uint amountDeposited, uint depositedTotal);
  event LPDeposited(
    address indexed sender,
    uint indexed tokenId,
    uint amountDeposited,
    uint depositedTotal
  );
  event Withdrawn(address indexed sender, uint amountWithdrawn, uint remainingAmount);
  event LPWithdrawn(
    address indexed sender,
    uint indexed tokenId,
    uint amountWithdrawn,
    uint remainingAmount
  );
  event Claimed(address indexed sender, uint amountClaimed);
  event LPClaimed(address indexed sender, uint indexed tokenId, uint amountClaimed);
  event PoolAdded(address indexed token, uint indexed tokenId, uint allocPoint);
  event AllocPointModified(uint8 prev, uint8 modified);

  modifier greaterThanZero(uint256 value) {
    require(value > 0, 'Params: Input value must be greater than zero');
    _;
  }

  constructor(ISushi sushi_, uint8 alloc2sushi_) {
    sushi = sushi_;
    alloc2sushi = alloc2sushi_;
  }

  function deposit(uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    _mintSushi();

    sushi.transferFrom(msg.sender, address(this), tokenAmount);

    StakingInfo storage depositor = stakers_[msg.sender];

    if (depositor.stakedAmount == 0) {
      depositor.stakedAmount = tokenAmount;
      depositor.claimedAmount = (sharePerSushiToken * tokenAmount) / 1e12;
    } else {
      _claim(msg.sender);
      depositor.stakedAmount += tokenAmount;
    }

    emit Deposited(msg.sender, tokenAmount, depositor.stakedAmount);
  }

  function depositLP(
    uint256 lpTokenId_,
    uint256 tokenAmount
  ) external greaterThanZero(tokenAmount) {
    _mintPool(lpTokenId_);

    PoolInfo storage pool = poolInfo[lpTokenId_];

    pool.lpToken.transferFrom(msg.sender, address(this), tokenAmount);

    StakingInfo storage depositor = lpstakers_[lpTokenId_][msg.sender];

    if (depositor.stakedAmount == 0) {
      depositor.stakedAmount = tokenAmount;
      depositor.claimedAmount = (pool.sharePerToken * tokenAmount) / 1e12;
    } else {
      _claimLP(msg.sender, lpTokenId_);
      depositor.stakedAmount += tokenAmount;
    }

    emit LPDeposited(msg.sender, lpTokenId_, tokenAmount, depositor.stakedAmount);
  }

  function withdraw(uint256 tokenAmount) external greaterThanZero(tokenAmount) {
    require(stakers_[msg.sender].stakedAmount >= tokenAmount, 'Withdraw: Not enough Sushi');

    _mintSushi();
    _claim(msg.sender);

    StakingInfo storage depositor = stakers_[msg.sender];
    depositor.stakedAmount -= tokenAmount;
    depositor.claimedAmount = (sharePerSushiToken * depositor.stakedAmount) / 1e12;

    sushi.transfer(msg.sender, tokenAmount);

    emit Withdrawn(msg.sender, tokenAmount, depositor.stakedAmount);
  }

  function withdrawLP(
    uint256 lpTokenId_,
    uint256 tokenAmount
  ) external greaterThanZero(tokenAmount) {
    require(
      lpstakers_[lpTokenId_][msg.sender].stakedAmount >= tokenAmount,
      'WithdrawLP: Not enough SushiLP'
    );

    _mintPool(lpTokenId_);
    _claimLP(msg.sender, lpTokenId_);

    PoolInfo storage pool = poolInfo[lpTokenId_];

    StakingInfo storage depositor = lpstakers_[lpTokenId_][msg.sender];
    depositor.stakedAmount -= tokenAmount;
    depositor.claimedAmount = (pool.sharePerToken * depositor.stakedAmount) / 1e12;

    pool.lpToken.transfer(msg.sender, tokenAmount);

    emit LPWithdrawn(msg.sender, lpTokenId_, tokenAmount, depositor.stakedAmount);
  }

  function claim() external {
    _mintSushi();
    uint256 claimedAmount = _claim(msg.sender);

    emit Claimed(msg.sender, claimedAmount);
  }

  function claimLP(uint256 lpTokenId_) external {
    _mintPool(lpTokenId_);
    uint256 claimedAmount = _claimLP(msg.sender, lpTokenId_);

    emit LPClaimed(msg.sender, lpTokenId_, claimedAmount);
  }

  function pendingSushi() external view returns (uint256) {
    StakingInfo storage info = stakers_[msg.sender];

    uint256 allocPoint = uint256(alloc2sushi);
    if (poolInfo.length == 0) allocPoint = 256;

    uint256 accumulated = ((block.number - lastSushiRewardBlock) *
      REWARD *
      allocPoint *
      info.stakedAmount) / (256 * sushi.balanceOf(address(this)));

    return accumulated;
  }

  function pendingSushiLP(uint256 lpTokenId_) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[lpTokenId_];
    StakingInfo storage info = lpstakers_[lpTokenId_][msg.sender];

    uint256 allocPoint = (256 - uint256(alloc2sushi));
    if (sushi.balanceOf(address(this)) == 0) allocPoint = 256;

    uint256 accumulated = ((block.number - pool.lastRewardBlock) *
      REWARD *
      allocPoint *
      pool.allocPoint *
      info.stakedAmount) / (256 * totalAllocPoint * pool.lpToken.balanceOf(address(this)));

    return accumulated;
  }

  function addPool(ISushiLP lpToken_, uint256 allocPoint_) external onlyOwner {
    _mint();
    totalAllocPoint += allocPoint_;

    uint256 tokenId = poolInfo.length;

    poolInfo.push(
      PoolInfo({
        lpToken: lpToken_,
        lastRewardBlock: block.number,
        sharePerToken: 0,
        allocPoint: allocPoint_
      })
    );

    emit PoolAdded(address(lpToken_), tokenId, poolInfo[tokenId].allocPoint);
  }

  function setAllocationPoint(uint8 alloc2sushi_) external onlyOwner {
    _mint();

    uint8 prev = alloc2sushi;
    alloc2sushi = alloc2sushi_;

    emit AllocPointModified(prev, alloc2sushi);
  }

  function _claim(address claimer_) internal returns (uint256) {
    StakingInfo storage info = stakers_[claimer_];

    if (info.stakedAmount == 0) return 0;

    uint256 rewardDistributed = ((sharePerSushiToken * info.stakedAmount) / 1e12) -
      info.claimedAmount;
    info.claimedAmount = info.claimedAmount + rewardDistributed;

    sushi.mint(claimer_, rewardDistributed);

    return rewardDistributed;
  }

  function _claimLP(address claimer_, uint256 lpTokenId_) internal returns (uint256) {
    PoolInfo storage pool = poolInfo[lpTokenId_];
    StakingInfo storage info = lpstakers_[lpTokenId_][claimer_];

    if (info.stakedAmount == 0) return 0;

    uint256 rewardDistributed = ((pool.sharePerToken * info.stakedAmount) / 1e12) -
      info.claimedAmount;
    info.claimedAmount = info.claimedAmount + rewardDistributed;

    sushi.mint(claimer_, rewardDistributed);

    return rewardDistributed;
  }

  function _mint() internal {
    uint256 length = poolInfo.length;
    for (uint256 id = 0; id < length; ++id) {
      _mintPool(id);
    }
    _mintSushi();
  }

  function _mintSushi() internal {
    if (sushi.balanceOf(address(this)) == 0) {
      lastSushiRewardBlock = block.number;
      return;
    }

    uint256 allocPoint = uint256(alloc2sushi);
    if (poolInfo.length == 0) allocPoint = 256;

    uint256 accumulated = ((block.number - lastSushiRewardBlock) * REWARD * allocPoint) / 256;

    lastSushiRewardBlock = block.number;
    sharePerSushiToken += (accumulated * 1e12) / sushi.balanceOf(address(this));
  }

  function _mintPool(uint256 lpTokenId_) internal {
    PoolInfo storage pool = poolInfo[lpTokenId_];

    if (pool.lpToken.balanceOf(address(this)) == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }

    uint256 allocPoint = (256 - uint256(alloc2sushi));
    if (sushi.balanceOf(address(this)) == 0) allocPoint = 256;

    uint256 accumulated = ((block.number - pool.lastRewardBlock) *
      REWARD *
      allocPoint *
      pool.allocPoint) / (256 * totalAllocPoint);

    pool.lastRewardBlock = block.number;
    pool.sharePerToken += (accumulated * 1e12) / pool.lpToken.balanceOf(address(this));
  }
}
