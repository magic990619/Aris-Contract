/**
 *Submitted for verification at BscScan.com on 2021-02-26
*/

pragma solidity 0.6.6;

import "./AFIR.sol";

interface IAFIFairLaunch {
  function poolLength() external view returns (uint256);

  function addPool(
    uint256 _allocPoint,
    address _stakeToken,
    bool _withUpdate
  ) external;

  function setPool(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) external;

  function pendingAFIR(uint256 _pid, address _user) external view returns (uint256);

  function updatePool(uint256 _pid) external;

  function deposit(address _for, uint256 _pid, uint256 _amount) external;

  function withdraw(address _for, uint256 _pid, uint256 _amount) external;

  function withdrawAll(address _for, uint256 _pid) external;

  function harvest(uint256 _pid) external;
}

// FairLaunch is a smart contract for distributing AFIR by asking user to stake the ERC20-based token.
contract AFIFairLaunch is IAFIFairLaunch, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many Staking tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    uint256 bonusDebt; // Last block that user exec something to the pool.
    address fundedBy; // Funded by who?
    //
    // We do some fancy math here. Basically, any point in time, the amount of AFIRs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.amount * pool.accAFIRPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
    //   1. The pool's `accAFIRPerShare` (and `lastRewardBlock`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  // Info of each pool.
  struct PoolInfo {
    address stakeToken; // Address of Staking token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. AFIRs to distribute per block.
    uint256 lastRewardBlock; // Last block number that AFIRs distribution occurs.
    uint256 accAFIRPerShare; // Accumulated AFIRs per share, times 1e12. See below.
    uint256 accAFIRPerShareTilBonusEnd; // Accumated AFIRs per share until Bonus End.
  }

  // The AFIR TOKEN!
  AFIR public afi;
  // Dev address.
  address public devaddr;
  // AFIR tokens created per block.
  uint256 public AFIRPerBlock;
  // Bonus muliplier for early AFIR makers.
  uint256 public bonusMultiplier;
  // Block number when bonus AFIR period ends.
  uint256 public bonusEndBlock;
  // Bonus lock-up in BPS
  uint256 public bonusLockUpBps;

  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes Staking tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation poitns. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;
  // The block number when AFIR mining starts.
  uint256 public startBlock;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

  constructor(
    AFIR _AFIR,
    address _devaddr,
    uint256 _AFIRPerBlock,
    uint256 _startBlock,
    uint256 _bonusLockupBps,
    uint256 _bonusEndBlock
  ) public {
    bonusMultiplier = 0;
    totalAllocPoint = 0;
    afi = _AFIR;
    devaddr = _devaddr;
    AFIRPerBlock = _AFIRPerBlock;
    bonusLockUpBps = _bonusLockupBps;
    bonusEndBlock = _bonusEndBlock;
    startBlock = _startBlock;
  }

  // Update dev address by the previous dev.
  function setDev(address _devaddr) public {
    require(msg.sender == devaddr, "dev: wut?");
    devaddr = _devaddr;
  }

  function setAFIRPerBlock(uint256 _AFIRPerBlock) public onlyOwner {
    AFIRPerBlock = _AFIRPerBlock;
  }

  // Set Bonus params. bonus will start to accu on the next block that this function executed
  // See the calculation and counting in test file.
  function setBonus(
    uint256 _bonusMultiplier,
    uint256 _bonusEndBlock,
    uint256 _bonusLockUpBps
  ) public onlyOwner {
    require(_bonusEndBlock > block.number, "setBonus: bad bonusEndBlock");
    require(_bonusMultiplier > 1, "setBonus: bad bonusMultiplier");
    bonusMultiplier = _bonusMultiplier;
    bonusEndBlock = _bonusEndBlock;
    bonusLockUpBps = _bonusLockUpBps;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  function addPool(
    uint256 _allocPoint,
    address _stakeToken,
    bool _withUpdate
  ) public override onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    require(_stakeToken != address(0), "add: not stakeToken addr");
    require(!isDuplicatedPool(_stakeToken), "add: stakeToken dup");
    uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({
        stakeToken: _stakeToken,
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accAFIRPerShare: 0,
        accAFIRPerShareTilBonusEnd: 0
      })
    );
  }

  // Update the given pool's AFIR allocation point. Can only be called by the owner.
  function setPool(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public override onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    poolInfo[_pid].allocPoint = _allocPoint;
  }

  function isDuplicatedPool(address _stakeToken) public view returns (bool) {
    uint256 length = poolInfo.length;
    for (uint256 _pid = 0; _pid < length; _pid++) {
      if(poolInfo[_pid].stakeToken == _stakeToken) return true;
    }
    return false;
  }

  function poolLength() external override view returns (uint256) {
    return poolInfo.length;
  }

  function manualMint(address _to, uint256 _amount) public onlyOwner {
    afi.manualMint(_to, _amount);
  }

  // Return reward multiplier over the given _from to _to block.
  function getMultiplier(uint256 _lastRewardBlock, uint256 _currentBlock) public view returns (uint256) {
    if (_currentBlock <= bonusEndBlock) {
      return _currentBlock.sub(_lastRewardBlock).mul(bonusMultiplier);
    }
    if (_lastRewardBlock >= bonusEndBlock) {
      return _currentBlock.sub(_lastRewardBlock);
    }
    // This is the case where bonusEndBlock is in the middle of _lastRewardBlock and _currentBlock block.
    return bonusEndBlock.sub(_lastRewardBlock).mul(bonusMultiplier).add(_currentBlock.sub(bonusEndBlock));
  }

  // View function to see pending AFIRs on frontend.
  function pendingAFIR(uint256 _pid, address _user) external override view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accAFIRPerShare = pool.accAFIRPerShare;
    uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(address(this));
    if (block.number > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
      uint256 AFIRReward = multiplier.mul(AFIRPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
      accAFIRPerShare = accAFIRPerShare.add(AFIRReward.mul(1e12).div(lpSupply));
    }
    return user.amount.mul(accAFIRPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Update reward vairables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public override {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.number <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(address(this));
    if (lpSupply == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
    uint256 AFIRReward = multiplier.mul(AFIRPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
    afi.mint(devaddr, AFIRReward.div(10));
    afi.mint(address(this), AFIRReward);
    pool.accAFIRPerShare = pool.accAFIRPerShare.add(AFIRReward.mul(1e12).div(lpSupply));
    // update accAFIRPerShareTilBonusEnd
    if (block.number <= bonusEndBlock) {
      afi.lock(devaddr, AFIRReward.div(10).mul(bonusLockUpBps).div(10000));
      pool.accAFIRPerShareTilBonusEnd = pool.accAFIRPerShare;
    }
    if(block.number > bonusEndBlock && pool.lastRewardBlock < bonusEndBlock) {
      uint256 AFIRBonusPortion = bonusEndBlock.sub(pool.lastRewardBlock).mul(bonusMultiplier).mul(AFIRPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
      afi.lock(devaddr, AFIRBonusPortion.div(10).mul(bonusLockUpBps).div(10000));
      pool.accAFIRPerShareTilBonusEnd = pool.accAFIRPerShareTilBonusEnd.add(AFIRBonusPortion.mul(1e12).div(lpSupply));
    }
    pool.lastRewardBlock = block.number;
  }

  // Deposit Staking tokens to FairLaunchToken for AFIR allocation.
  function deposit(address _for, uint256 _pid, uint256 _amount) public override {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_for];
    if (user.fundedBy != address(0)) require(user.fundedBy == msg.sender, "bad sof");
    require(pool.stakeToken != address(0), "deposit: not accept deposit");
    updatePool(_pid);
    if (user.amount > 0) _harvest(_for, _pid);
    if (user.fundedBy == address(0)) user.fundedBy = msg.sender;
    IERC20(pool.stakeToken).safeTransferFrom(address(msg.sender), address(this), _amount);
    user.amount = user.amount.add(_amount);
    user.rewardDebt = user.amount.mul(pool.accAFIRPerShare).div(1e12);
    user.bonusDebt = user.amount.mul(pool.accAFIRPerShareTilBonusEnd).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw Staking tokens from FairLaunchToken.
  function withdraw(address _for, uint256 _pid, uint256 _amount) public override {
    _withdraw(_for, _pid, _amount);
  }

  function withdrawAll(address _for, uint256 _pid) public override {
    _withdraw(_for, _pid, userInfo[_pid][_for].amount);
  }

  function _withdraw(address _for, uint256 _pid, uint256 _amount) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_for];
    require(user.fundedBy == msg.sender, "only funder");
    require(user.amount >= _amount, "withdraw: not good");
    updatePool(_pid);
    _harvest(_for, _pid);
    user.amount = user.amount.sub(_amount);
    user.rewardDebt = user.amount.mul(pool.accAFIRPerShare).div(1e12);
    user.bonusDebt = user.amount.mul(pool.accAFIRPerShareTilBonusEnd).div(1e12);
    if (pool.stakeToken != address(0)) {
      IERC20(pool.stakeToken).safeTransfer(address(msg.sender), _amount);
    }
    emit Withdraw(msg.sender, _pid, user.amount);
  }

  // Harvest AFIRs earn from the pool.
  function harvest(uint256 _pid) public override {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    _harvest(msg.sender, _pid);
    user.rewardDebt = user.amount.mul(pool.accAFIRPerShare).div(1e12);
    user.bonusDebt = user.amount.mul(pool.accAFIRPerShareTilBonusEnd).div(1e12);
  }

  function _harvest(address _to, uint256 _pid) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_to];
    require(user.amount > 0, "nothing to harvest");
    uint256 pending = user.amount.mul(pool.accAFIRPerShare).div(1e12).sub(user.rewardDebt);
    require(pending <= afi.balanceOf(address(this)), "wtf not enough AFIR");
    uint256 bonus = user.amount.mul(pool.accAFIRPerShareTilBonusEnd).div(1e12).sub(user.bonusDebt);
    safeAFIRTransfer(_to, pending);
    afi.lock(_to, bonus.mul(bonusLockUpBps).div(10000));
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    IERC20(pool.stakeToken).safeTransfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

    // Safe AFIR transfer function, just in case if rounding error causes pool to not have enough AFIRs.
  function safeAFIRTransfer(address _to, uint256 _amount) internal {
    uint256 AFIRBal = afi.balanceOf(address(this));
    if (_amount > AFIRBal) {
      afi.transfer(_to, AFIRBal);
    } else {
      afi.transfer(_to, _amount);
    }
  }

}