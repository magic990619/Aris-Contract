// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./AFIR.sol";

// For interacting with our own strategy
interface IStrategy {
    // Total want tokens managed by stratfegy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    // Main want token compounding function
    function earn() external;

    // Transfer want tokens Farm -> strategy
    function deposit(address _userAddress, uint256 _wantAmt)
        external
        returns (uint256);

    // Transfer want tokens strategy -> Farm
    function withdraw(address _userAddress, uint256 _wantAmt)
        external
        returns (uint256);

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) external;
}

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract AFIFarmB is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        // We do some fancy math here. Basically, any point in time, the amount of AFI
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accAFIPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accAFIPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. AFI to distribute per block.
        uint256 lastRewardBlock; // Last block number that AFI distribution occurs.
        uint256 accAFIPerShare; // Accumulated AFI per share, times 1e12. See below.
        address strat; // Strategy address that will afi compound want tokens
    }
    
    address public burnAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public ownerAFIReward = 0; // 0%

    uint256 public AFIMaxSupply = 8000000e18;
    uint256 public AFIPerBlock = 80000000000000000; // 0.08 AFI tokens created per block
    uint256 public startBlock = 22636068; //https://bscscan.com/block/countdown/3888888 22636068   21128514

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    address public AFI;
    address public AFIB;

    constructor() public {
        AFI = 0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3;
        AFIB = 0xbE80fAc8F7C06D01203211CEAaA57AEB23E7f472;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setTokenAddress(
        address _address,
        uint256 _type
    ) public onlyOwner {
        if(_type == 1){
            AFI = _address;
        }else{
            AFIB = _address;
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)

    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accAFIPerShare: 0,
                strat: _strat
            })
        );
    }

    // Update the given pool's AFI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (IERC20(AFIB).totalSupply() >= AFIMaxSupply) {
            return 0;
        }
        return _to.sub(_from);
    }

    // View function to see pending AFI on frontend.
    function pendingAFI(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accAFIPerShare = pool.accAFIPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 AFIReward =
                multiplier.mul(AFIPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accAFIPerShare = accAFIPerShare.add(
                AFIReward.mul(1e12).div(sharesTotal)
            );
        }
        return user.shares.mul(accAFIPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see pending AFI on frontend.
    function pendingTestAFI(uint256 _pid, address _user, uint256 _time)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accAFIPerShare = pool.accAFIPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        // if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
        uint256 multiplier = _time;//getMultiplier(pool.lastRewardBlock, block.number);
        uint256 AFIReward =
            multiplier.mul(AFIPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        accAFIPerShare = accAFIPerShare.add(
            AFIReward.mul(1e12).div(sharesTotal)
        );
        // }
        return user.shares.mul(accAFIPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier <= 0) {
            return;
        }
        uint256 AFIReward =
            multiplier.mul(AFIPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        AFIR(AFI).mint(
            owner(),
            AFIReward.mul(ownerAFIReward).div(1000)
        );
        AFIR(AFI).mint(address(this), AFIReward);

        pool.accAFIPerShare = pool.accAFIPerShare.add(
            AFIReward.mul(1e12).div(sharesTotal)
        );
        pool.lastRewardBlock = block.number;
    }

    // Want tokens moved from user -> Farm (AFI allocation) -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pending =
                user.shares.mul(pool.accAFIPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeAFITransfer(msg.sender, pending);
            }
        }
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );

            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
            uint256 sharesAdded =
                IStrategy(poolInfo[_pid].strat).deposit(msg.sender, _wantAmt);
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebt = user.shares.mul(pool.accAFIPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending AFI
        uint256 pending =
            user.shares.mul(pool.accAFIPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeAFITransfer(msg.sender, pending);
        }

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved =
                IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }
        user.rewardDebt = user.shares.mul(pool.accAFIPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid) public {
        withdraw(_pid, uint256(100));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, amount);

        pool.want.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        user.rewardDebt = 0;
    }

    // Safe AFI transfer function, just in case if rounding error causes pool to not have enough
    function safeAFITransfer(address _to, uint256 _AFIAmt) internal {
        uint256 AFIBal = IERC20(AFI).balanceOf(address(this));
        if (_AFIAmt > AFIBal) {
            IERC20(AFI).transfer(_to, AFIBal);
        } else {
            IERC20(AFI).transfer(_to, _AFIAmt);
        }
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public onlyOwner
    {
        require(_token != AFI, "!safe");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function migrateToAFIB(uint256 _inputAmt) public {
        //require(block.number < 6102268, "too late"); //Mon Mar 29 2021 20:00:44 GMT+0800 (Taipei Standard Time) https://bscscan.com/block/countdown/6102268
        IERC20(AFI).safeIncreaseAllowance(burnAddress, _inputAmt);
        IERC20(AFI).safeTransferFrom(
            address(msg.sender),
            burnAddress,
            _inputAmt
        );
        AFIR(AFIB).mint(msg.sender, _inputAmt);
    }

    function setAFIPerBlock(uint256 _inputAmt) public onlyOwner {
      AFIPerBlock = _inputAmt;
    }
}
/**
    function checkBlockNumber() public view returns(uint256){
        return (block.number);
    }
 */