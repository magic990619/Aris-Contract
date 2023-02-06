// SPDX-License-Identifier: MIT


pragma solidity 0.6.6;

import "./interface/Ownable.sol";
import "./interface/IERC20.sol";
import "./interface/SafeMath.sol";
import "./interface/ReentrancyGuard.sol";
import "./interface/Initializable.sol";

import "./interface/IPancakeFactory.sol";
import "./interface/IPancakePair.sol";
import "./interface/IPancakeRouter02.sol";
import "./interface/IStrategy.sol";
import "./interface/IWorker.sol";
import "./interface/IPancakeMasterChef.sol";
import "./utils/AlpacaMath.sol";
import "./utils/SafeToken.sol";

contract PancakeswapV2Worker is OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe, IWorker {
  /// @notice Libraries
  using SafeToken for address;
  using SafeMath for uint256;

  /// @notice Events
  event Reinvest(address indexed caller, uint256 reward, uint256 bounty);
  event AddShare(uint256 indexed id, uint256 share);
  event RemoveShare(uint256 indexed id, uint256 share);
  event Liquidate(uint256 indexed id, uint256 wad);

  /// @notice Configuration variables
  IPancakeMasterChef public masterChef;
  IPancakeFactory public factory;
  IPancakeRouter02 public router;
  IPancakePair public override lpToken;
  address public wNative;
  address public override baseToken;
  address public override farmingToken;
  address public aries;
  address public cake;
  address public operator;
  uint256 public pid;

  /// @notice Mutable state variables
  mapping(uint256 => uint256) public shares;
  mapping(address => bool) public okStrats;
  uint256 public totalShare;
  IStrategy public addStrat;
  IStrategy public liqStrat;
  uint256 public reinvestBountyBps;
  uint256 public maxReinvestBountyBps;
  mapping(address => bool) public okReinvestors;

  uint256 public controllerFee;
  uint256 public controllerFeeMax;
  uint256 public controllerFeeUL;

  uint256 public buyBackRate;
  uint256 public buyBackRateMax;
  uint256 public buyBackRateUL;
  address public buyBackAddress;

  address public fundManager;
  address public fundManager2; 
  address public fundManager3;
  address public receiveFee;

  uint256 public slippageFactor;
  uint256 public slippageFactorUL;

  bool public enableAddLiquidity;

  /// @notice Configuration varaibles for V2
  uint256 public fee;
  uint256 public feeDenom;

  function initialize(
    address _operator,
    address _baseToken,
    IPancakeMasterChef _masterChef,
    IPancakeRouter02 _router,
    uint256 _pid,
    IStrategy _addStrat,
    IStrategy _liqStrat,
    uint256 _reinvestBountyBps,
    address _aries
  ) external initializer {
    OwnableUpgradeSafe.__Ownable_init();
    ReentrancyGuardUpgradeSafe.__ReentrancyGuard_init();

    operator = _operator;
    baseToken = _baseToken;
    aries = _aries;
    wNative = _router.WETH();
    masterChef = _masterChef;
    router = _router;
    factory = IPancakeFactory(_router.factory());
    // Get lpToken and farmingToken from MasterChef pool
    pid = _pid;
    address _lpToken = masterChef.lpToken(_pid);
    lpToken = IPancakePair(_lpToken);
    address token0 = lpToken.token0();
    address token1 = lpToken.token1();
    farmingToken = token0 == baseToken ? token1 : token0;
    cake = address(masterChef.CAKE());
    addStrat = _addStrat;
    liqStrat = _liqStrat;
    okStrats[address(addStrat)] = true;
    okStrats[address(liqStrat)] = true;
    reinvestBountyBps = _reinvestBountyBps;
    maxReinvestBountyBps = 500;
    fee = 9975;
    feeDenom = 10000;
    controllerFee = 2800;
    controllerFeeMax = 10000; // 100 = 1%
    controllerFeeUL = 6000;
    buyBackRate = 4200;
    buyBackRateMax = 10000; // 100 = 1%
    buyBackRateUL = 6000;
    buyBackAddress = 0x000000000000000000000000000000000000dEaD;

    fundManager = address(0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396);
    fundManager2 = address(0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396); 
    fundManager3 = address(0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396);
    receiveFee = address(0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396);

    slippageFactor = 950; // 5% default slippage tolerance
    slippageFactorUL = 995;
    
    enableAddLiquidity = true;

    require(
      reinvestBountyBps <= maxReinvestBountyBps,
      "PancakeswapWorker::initialize:: reinvestBountyBps exceeded maxReinvestBountyBps"
    );
    require(
      (farmingToken == lpToken.token0() || farmingToken == lpToken.token1()) &&
        (baseToken == lpToken.token0() || baseToken == lpToken.token1()),
      "PancakeswapWorker::initialize:: LP underlying not match with farm & base token"
    );
  }

  /// @dev Require that the caller must be an EOA account to avoid flash loans.
  modifier onlyEOA() {
    require(msg.sender == tx.origin, "PancakeswapWorker::onlyEOA:: not eoa");
    _;
  }

  /// @dev Require that the caller must be the operator.
  modifier onlyOperator() {
    require(msg.sender == operator, "PancakeswapWorker::onlyOperator:: not operator");
    _;
  }

  //// @dev Require that the caller must be ok reinvestor.
  modifier onlyReinvestor() {
    require(okReinvestors[msg.sender], "PancakeswapWorker::onlyReinvestor:: not reinvestor");
    _;
  }

  /// @dev Return the entitied LP token balance for the given shares.
  /// @param share The number of shares to be converted to LP balance.
  function shareToBalance(uint256 share) public view returns (uint256) {
    if (totalShare == 0) return share; // When there's no share, 1 share = 1 balance.
    (uint256 totalBalance, ) = masterChef.userInfo(pid, address(this));
    return share.mul(totalBalance).div(totalShare);
  }

  /// @dev Return the number of shares to receive if staking the given LP tokens.
  /// @param balance the number of LP tokens to be converted to shares.
  function balanceToShare(uint256 balance) public view returns (uint256) {
    if (totalShare == 0) return balance; // When there's no share, 1 share = 1 balance.
    (uint256 totalBalance, ) = masterChef.userInfo(pid, address(this));
    return balance.mul(totalShare).div(totalBalance);
  }

  /// @dev Re-invest whatever this worker has earned back to staked LP tokens.
  function reinvest() external override onlyEOA onlyReinvestor nonReentrant {
    // 1. Approve tokens
    cake.safeApprove(address(router), uint256(-1));
    address(lpToken).safeApprove(address(masterChef), uint256(-1));
    // 2. Withdraw all the rewards.
    masterChef.withdraw(pid, 0);
    uint256 reward = cake.balanceOf(address(this));
    if (reward == 0) return;
    // 3. Send the reward bounty to the caller.
    uint256 bounty = reward.mul(reinvestBountyBps) / 10000;
    if (bounty > 0) cake.safeTransfer(msg.sender, bounty);
    reward = reward.sub(bounty);
    // 4. Convert earn tokens into wbnb tokens
    address[] memory earnedToWbnbPath;
    earnedToWbnbPath = new address[](2);
    earnedToWbnbPath[0] = address(cake);
    earnedToWbnbPath[1] = address(wNative);
    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(reward, 0, earnedToWbnbPath, address(this), block.timestamp.add(600));
    // 5. Distribute fees.
    uint256 wbnbBal = wNative.balanceOf(address(this));
    wbnbBal = distributeFees(wbnbBal);
    // 6. Convert buyback wbnb into ARIES token and send to buyBackAddress.
    uint256 buyBackAmt = wbnbBal.mul(buyBackRate).div(buyBackRateMax);
    address[] memory wbnbToARIESPath;
    wbnbToARIESPath = new address[](2);
    wbnbToARIESPath[0] = address(wNative);
    wbnbToARIESPath[1] = aries;
    uint256[] memory amounts = router.getAmountsOut(buyBackAmt, wbnbToARIESPath);
    uint256 amountOut = amounts[amounts.length.sub(1)];
    router
      .swapExactTokensForTokensSupportingFeeOnTransferTokens(
        buyBackAmt,
        amountOut.mul(slippageFactor).div(100),
        wbnbToARIESPath,
        buyBackAddress,
        block.timestamp.add(600)
      );

    // 7. Add Liquidity
    if (enableAddLiquidity) {
      uint256 earnedAddressHalf = wNative.balanceOf(address(this)).div(2);
      if (baseToken != wNative) {
        address[] memory wbnbToBasePath;
        wbnbToBasePath = new address[](2);
        wbnbToBasePath[0] = address(wNative);
        wbnbToBasePath[1] = address(baseToken);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(earnedAddressHalf, 0, wbnbToBasePath, address(this), now.add(600));
      }
      if (farmingToken != wNative) {
        address[] memory wbnbToFarmingPath;
        wbnbToFarmingPath = new address[](2);
        wbnbToFarmingPath[0] = address(wNative);
        wbnbToFarmingPath[1] = address(farmingToken);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(earnedAddressHalf, 0, wbnbToFarmingPath, address(this), now.add(600));
      }
      uint256 baseBal = baseToken.balanceOf(address(this));
      uint256 farmingBal = farmingToken.balanceOf(address(this));
      router.addLiquidity(
        address(baseToken),
        address(farmingToken),
        baseBal,
        farmingBal,
        0,
        0,
        address(this),
        now
      );
    }

    // 8. Farming
    masterChef.deposit(pid, lpToken.balanceOf(address(this)));
    // 9. Reset approve
    cake.safeApprove(address(router), 0);
    address(lpToken).safeApprove(address(masterChef), 0);
    emit Reinvest(msg.sender, reward, bounty);
  }

  /// @dev Work on the given position. Must be called by the operator.
  /// @param id The position ID to work on.
  /// @param user The original user that is interacting with the operator.
  /// @param debt The amount of user debt to help the strategy make decisions.
  /// @param data The encoded data, consisting of strategy address and calldata.
  function work(
    uint256 id,
    address user,
    uint256 debt,
    bytes calldata data
  ) external override onlyOperator nonReentrant {
    // 1. Convert this position back to LP tokens.
    _removeShare(id);
    // 2. Perform the worker strategy; sending LP tokens + BaseToken; expecting LP tokens + BaseToken.
    (address strat, bytes memory ext) = abi.decode(data, (address, bytes));
    require(okStrats[strat], "PancakeswapWorker::work:: unapproved work strategy");
    require(
      lpToken.transfer(strat, lpToken.balanceOf(address(this))),
      "PancakeswapWorker::work:: unable to transfer lp to strat"
    );
    baseToken.safeTransfer(strat, baseToken.myBalance());
    IStrategy(strat).execute(user, debt, ext);
    // 3. Add LP tokens back to the farming pool.
    _addShare(id);
    // 4. Return any remaining BaseToken back to the operator.
    baseToken.safeTransfer(msg.sender, baseToken.myBalance());
  }

  /// @dev Return maximum output given the input amount and the status of Uniswap reserves.
  /// @param aIn The amount of asset to market sell.
  /// @param rIn the amount of asset in reserve for input.
  /// @param rOut The amount of asset in reserve for output.
  function getMktSellAmount(
    uint256 aIn,
    uint256 rIn,
    uint256 rOut
  ) public view returns (uint256) {
    if (aIn == 0) return 0;
    require(rIn > 0 && rOut > 0, "PancakeswapWorker::getMktSellAmount:: bad reserve values");
    uint256 aInWithFee = aIn.mul(fee);
    uint256 numerator = aInWithFee.mul(rOut);
    uint256 denominator = rIn.mul(feeDenom).add(aInWithFee);
    return numerator / denominator;
  }

  /// @dev Return the amount of BaseToken to receive if we are to liquidate the given position.
  /// @param id The position ID to perform health check.
  function health(uint256 id) external view override returns (uint256) {
    // 1. Get the position's LP balance and LP total supply.
    uint256 lpBalance = shareToBalance(shares[id]);
    uint256 lpSupply = lpToken.totalSupply(); // Ignore pending mintFee as it is insignificant
    // 2. Get the pool's total supply of BaseToken and FarmingToken.
    (uint256 r0, uint256 r1, ) = lpToken.getReserves();
    (uint256 totalBaseToken, uint256 totalFarmingToken) = lpToken.token0() == baseToken ? (r0, r1) : (r1, r0);
    // 3. Convert the position's LP tokens to the underlying assets.
    uint256 userBaseToken = lpBalance.mul(totalBaseToken).div(lpSupply);
    uint256 userFarmingToken = lpBalance.mul(totalFarmingToken).div(lpSupply);
    // 4. Convert all FarmingToken to BaseToken and return total BaseToken.
    return
      getMktSellAmount(userFarmingToken, totalFarmingToken.sub(userFarmingToken), totalBaseToken.sub(userBaseToken))
        .add(userBaseToken);
  }

  /// @dev Liquidate the given position by converting it to BaseToken and return back to caller.
  /// @param id The position ID to perform liquidation
  function liquidate(uint256 id) external override onlyOperator nonReentrant {
    // 1. Convert the position back to LP tokens and use liquidate strategy.
    _removeShare(id);
    lpToken.transfer(address(liqStrat), lpToken.balanceOf(address(this)));
    liqStrat.execute(address(0), 0, abi.encode(0));
    // 2. Return all available BaseToken back to the operator.
    uint256 wad = baseToken.myBalance();
    baseToken.safeTransfer(msg.sender, wad);
    emit Liquidate(id, wad);
  }

  /// @dev Internal function to stake all outstanding LP tokens to the given position ID.
  function _addShare(uint256 id) internal {
    uint256 balance = lpToken.balanceOf(address(this));
    if (balance > 0) {
      // 1. Approve token to be spend by masterChef
      address(lpToken).safeApprove(address(masterChef), uint256(-1));
      // 2. Convert balance to share
      uint256 share = balanceToShare(balance);
      // 3. Deposit balance to PancakeMasterChef
      masterChef.deposit(pid, balance);
      // 4. Update shares
      shares[id] = shares[id].add(share);
      totalShare = totalShare.add(share);
      // 5. Reset approve token
      address(lpToken).safeApprove(address(masterChef), 0);
      emit AddShare(id, share);
    }
  }

  /// @dev Internal function to remove shares of the ID and convert to outstanding LP tokens.
  function _removeShare(uint256 id) internal {
    uint256 share = shares[id];
    if (share > 0) {
      uint256 balance = shareToBalance(share);
      masterChef.withdraw(pid, balance);
      totalShare = totalShare.sub(share);
      shares[id] = 0;
      emit RemoveShare(id, share);
    }
  }

  /// @dev Distribute fees to several wallets
  function distributeFees(uint256 _earnedAmt) internal returns (uint256) {
    if (_earnedAmt > 0) {
      // Performance fee
      if (controllerFee > 0) {
        uint256 calcFee = _earnedAmt.mul(controllerFee).div(
          controllerFeeMax
        );
        wNative.safeTransfer(fundManager, calcFee.mul(36).div(100));
        wNative.safeTransfer(fundManager2, calcFee.mul(7).div(100));
        wNative.safeTransfer(fundManager3, calcFee.mul(3).div(100));
        wNative.safeTransfer(receiveFee, calcFee.mul(54).div(100));
        _earnedAmt = _earnedAmt.sub(calcFee);
      }
    }

    return _earnedAmt;
  }

  /// @dev Set the reward bounty for calling reinvest operations.
  /// @param _reinvestBountyBps The bounty value to update.
  function setReinvestBountyBps(uint256 _reinvestBountyBps) external onlyOwner {
    require(
      _reinvestBountyBps <= maxReinvestBountyBps,
      "PancakeswapWorker::setReinvestBountyBps:: _reinvestBountyBps exceeded maxReinvestBountyBps"
    );
    reinvestBountyBps = _reinvestBountyBps;
  }

  /// @dev Set Max reinvest reward for set upper limit reinvest bounty.
  /// @param _maxReinvestBountyBps The max reinvest bounty value to update.
  function setMaxReinvestBountyBps(uint256 _maxReinvestBountyBps) external onlyOwner {
    require(
      _maxReinvestBountyBps >= reinvestBountyBps,
      "PancakeswapWorker::setMaxReinvestBountyBps:: _maxReinvestBountyBps lower than reinvestBountyBps"
    );
    maxReinvestBountyBps = _maxReinvestBountyBps;
  }

  /// @dev Set the given strategies' approval status.
  /// @param strats The strategy addresses.
  /// @param isOk Whether to approve or unapprove the given strategies.
  function setStrategyOk(address[] calldata strats, bool isOk) external override onlyOwner {
    uint256 len = strats.length;
    for (uint256 idx = 0; idx < len; idx++) {
      okStrats[strats[idx]] = isOk;
    }
  }

  /// @dev Set the given address's to be reinvestor.
  /// @param reinvestors The reinvest bot addresses.
  /// @param isOk Whether to approve or unapprove the given strategies.
  function setReinvestorOk(address[] calldata reinvestors, bool isOk) external override onlyOwner {
    uint256 len = reinvestors.length;
    for (uint256 idx = 0; idx < len; idx++) {
      okReinvestors[reinvestors[idx]] = isOk;
    }
  }

  /// @dev Update critical strategy smart contracts. EMERGENCY ONLY. Bad strategies can steal funds.
  /// @param _addStrat The new add strategy contract.
  /// @param _liqStrat The new liquidate strategy contract.
  function setCriticalStrategies(IStrategy _addStrat, IStrategy _liqStrat) external onlyOwner {
    addStrat = _addStrat;
    liqStrat = _liqStrat;
  }

  /// @dev Set the perfomance fee
  /// @param _controllerFee The new perfomance fee
  function setControllerFee(uint256 _controllerFee) external onlyOwner {
    require(_controllerFee <= controllerFeeUL, "too high");
    controllerFee = _controllerFee;
  }

  /// @dev Set the buyBack Rate
  /// @param _buyBackRate The new buyback rate
  function setbuyBackRate(uint256 _buyBackRate) external onlyOwner {
    require(buyBackRate <= buyBackRateUL, "too high");
    buyBackRate = _buyBackRate;
  }

  /// @dev Set addLiquidity status
  /// @param _status The new status
  function setEnableAddLiquidity(bool _status) external onlyOwner {
    enableAddLiquidity = _status;
  }

  /// @dev Set FundManager address
  /// @param _fundManager The new fundManager address
  function setfundManager(address _fundManager) external onlyOwner {
    fundManager = _fundManager;
  }

  /// @dev Set FundManager2 address
  /// @param _fundManager2 The new fundManager address
  function setfundManager2(address _fundManager2) external onlyOwner {
    fundManager2 = _fundManager2;
  }

  /// @dev Set FundManager address
  /// @param _fundManager3 The new fundManager address
  function setfundManager3(address _fundManager3) external onlyOwner {
    fundManager3 = _fundManager3;
  }

  /// @dev Update ARIES Address
  /// @param _aries The new fundManager address
  function setAries(address _aries) external onlyOwner {
    aries = _aries;
  }

}
