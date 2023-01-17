const { expect } = require("chai");
const { ethers, artifacts } = require("hardhat");
const delay = require("delay");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
let AlpacaToken;
let FairLaunch;
let StakeToken;

let _allocPoint;
let _want;
let _withUpdate;
let _strat;

let signer;
let user1;
let user2;

describe("FairLaunch Test", () => {
  
  before(async () => {

    [signer, user1, user2] = await ethers.getSigners();

    let _startReleaseBlock = "0"
    let _endReleaseBlock = "100"
    const _AlpacaToken = await ethers.getContractFactory("AlpacaToken");
    AlpacaToken = await (await _AlpacaToken.deploy(_startReleaseBlock, _endReleaseBlock)).deployed();
    let  _alpaca = AlpacaToken.address
    let _devaddr = signer.address;
    let _alpacaPerBlock = 100
    let _startBlock = 100
    let _bonusLockupBps = 100
    let _bonusEndBlock = 100

    const _FairLaunch = await ethers.getContractFactory("FairLaunch");
    FairLaunch = await (await _FairLaunch.deploy(
      _alpaca, _devaddr, _alpacaPerBlock, _startBlock, _bonusLockupBps, _bonusEndBlock
    )).deployed();

    const _AFI = await ethers.getContractFactory("AFI");
    StakeToken = await (await _AFI.deploy()).deployed();

    const tx = await (await AlpacaToken.transferOwnership(FairLaunch.address)).wait();
    const tx1 = await (await StakeToken.mint(signer.address, 10000)).wait();
    // const tx2 = await (await AFI.mint(user1.address, 10000)).wait();
    // const tx3 = await (await AFI.mint(AFIFarmB.address, 10000)).wait();
    // console.log(await AFI.name());
  });

  it("Deploy AlpacaToken ", async () => {
    expect(AlpacaToken.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Deploy FairLaunch ", async () => {
    expect(FairLaunch.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Update dev address by the previous dev", async () => {
    const tx = await (await FairLaunch.connect(signer).setDev(user1.address)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("setAlpacaPerBlock by owner", async () => {
    let _alpacaPerBlock = 10
    const tx = await (await FairLaunch.connect(signer).setAlpacaPerBlock(_alpacaPerBlock)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("setAlpacaPerBlock by user", async () => {
    let _alpacaPerBlock = 10
    await expect(FairLaunch.connect(user1).setAlpacaPerBlock(_alpacaPerBlock)).to.be.reverted;
  });

  it("Add a new lp to the pool by owner", async () => {
    let _allocPoint = 10
    let _stakeToken = StakeToken.address
    let _withUpdate = false
    const tx = await (await FairLaunch.connect(signer).addPool(_allocPoint, _stakeToken, _withUpdate)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Add a new lp to the pool by user", async () => {
    let _allocPoint = 10
    let _stakeToken = StakeToken.address
    let _withUpdate = false
    await expect(FairLaunch.connect(user1).addPool(_allocPoint, _stakeToken, _withUpdate)).to.be.reverted;
  });

  it("Update the given pool's ALPACA allocation point by owner", async () => {
    let _pid = 0
    let _allocPoint = 10
    let _withUpdate = false
    const tx = await (await FairLaunch.connect(signer).setPool(_pid, _allocPoint, _withUpdate)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Update the given pool's ALPACA allocation point by user", async () => {
    let _pid = 0
    let _allocPoint = 10
    let _withUpdate = false
    await expect(FairLaunch.connect(user1).setPool(_pid, _allocPoint, _withUpdate)).to.be.reverted;
  });

  it("isDuplicatedPool with exact stake token address", async () => {
    let _stakeToken = StakeToken.address
    expect(await FairLaunch.connect(signer).isDuplicatedPool(_stakeToken)).to.be.equal(true);
  });

  it("isDuplicatedPool with wrong stake token address", async () => {
    let _stakeToken = user1.address
    expect(await FairLaunch.connect(signer).isDuplicatedPool(_stakeToken)).to.be.equal(false);
  });

  it("check poolLength", async () => {
    expect(await FairLaunch.connect(signer).poolLength()).to.be.equal(1);
  });

  it("manualMint function by owner", async () => {
    let _to = signer.address;
    let _amount = 100000
    const tx = await (await FairLaunch.connect(signer).manualMint(_to, _amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("manualMint function by user", async () => {
    let _to = signer.address;
    let _amount = 100000
    await expect(FairLaunch.connect(user1).setPool(_to, _amount)).to.be.reverted;
  });

  it("Deposit Staking tokens to FairLaunchToken for ALPACA allocation", async () => {
    let _for = signer.address;
    let _pid = 0;
    let _amount = 100;
    
    // before deposit, staked balance is 0
    expect(ethers.BigNumber.from(await StakeToken.balanceOf(FairLaunch.address))).to.be.equal("0");
    await StakeToken.connect(signer).approve(FairLaunch.address, _amount);

    const tx = await (await FairLaunch.connect(signer).deposit(_for, _pid, _amount)).wait();
    expect(await tx.status).to.equal(1);

    // before deposit, staked balance is 100
    expect(ethers.BigNumber.from(await StakeToken.balanceOf(FairLaunch.address))).to.be.equal("100");
  });

  it("Withdraw Staking tokens from FairLaunchToken", async () => {
    let _for = signer.address;
    let _pid = 0;
    let _amount = 100;
    // before withraw, user's staked balance is 100
    const tx = await (await FairLaunch.connect(signer).withdraw(_for, _pid, _amount)).wait();
    expect(await tx.status).to.equal(1);

  });

  it("Withdraw ALL Staking tokens from FairLaunchToken", async () => {
    let _for = signer.address;
    let _pid = 0;
    let _amount = 100;
    await StakeToken.connect(signer).approve(FairLaunch.address, _amount);

    const tx = await (await FairLaunch.connect(signer).deposit(_for, _pid, _amount)).wait();
    expect(await tx.status).to.equal(1);

    const tx1 = await (await FairLaunch.connect(signer).withdrawAll(_for, _pid)).wait();
    expect(await tx1.status).to.equal(1);

  });

  it("Harvest ALPACAs earn from the pool", async () => {
    let _for = signer.address;
    let _pid = 0;
    let _amount = 100;
    await StakeToken.connect(signer).approve(FairLaunch.address, _amount);
    const tx = await (await FairLaunch.connect(signer).deposit(_for, _pid, _amount)).wait();
    expect(await tx.status).to.equal(1);

    const tx1 = await (await FairLaunch.connect(signer).harvest( _pid)).wait();
    expect(await tx1.status).to.equal(1);

  });

  it("EmergencyWithdraw function", async () => {
    let _pid = 0
    const tx = await (await FairLaunch.connect(signer).emergencyWithdraw(_pid)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Update reward vairables for all pools", async () => {
    const tx = await (await FairLaunch.connect(signer).massUpdatePools()).wait();
    expect(await tx.status).to.equal(1);
  });

  it("updatePool", async () => {
    let _pid = 0
    const tx = await (await FairLaunch.connect(signer).updatePool(_pid)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("View function to see pending ALPACAs on frontend", async () => {
    let _pid = 0; 
    let _user = signer.address;
    let _wantAmt = 100

    // await WANT.approve(AFIFarmB.address, _wantAmt);

    // const tx1 = await (await AFIFarmB.connect(signer).deposit(_pid, _wantAmt)).wait();
    // expect(await tx1.status).to.equal(1);

    const pendingAlpaca = await FairLaunch.pendingAlpaca(_pid, _user);
    expect(ethers.BigNumber.from(pendingAlpaca).toString()).to.equal("0");

    // console.log(ethers.BigNumber.from(pendingAFI).toString())

  });

});
