const { expect } = require("chai");
const { ethers, artifacts } = require("hardhat");
const delay = require("delay");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
let AFIFarmB;
let AFI;
let AFIB;
let WANT;
let STRATEGY;

let _allocPoint;
let _want;
let _withUpdate;
let _strat;

let signer;
let user1;
let user2;

describe("AFIstaking Test", () => {
  
  before(async () => {
    const _AFIFarmB = await ethers.getContractFactory("AFIFarmB");
    AFIFarmB = await (await _AFIFarmB.deploy()).deployed();
    const _AFI = await ethers.getContractFactory("AFI");
    AFI = await (await _AFI.deploy()).deployed();
    const _AFIB = await ethers.getContractFactory("AFIB");
    AFIB = await (await _AFIB.deploy()).deployed();
    const _WANT = await ethers.getContractFactory("AFIB");
    WANT = await (await _WANT.deploy()).deployed();
    const _STRATEGY = await ethers.getContractFactory("StratX");
    STRATEGY = await (await _STRATEGY.deploy(AFIFarmB.address, false, WANT.address)).deployed();
    [signer, user1, user2] = await ethers.getSigners();

    const tx = await (await WANT.mint(signer.address, 10000)).wait();
    const tx1 = await (await AFI.mint(signer.address, 10000)).wait();
    const tx2 = await (await AFI.mint(user1.address, 10000)).wait();
    const tx3 = await (await AFI.mint(AFIFarmB.address, 10000)).wait();
    const tx4 = await (await AFI.transferOwnership(AFIFarmB.address)).wait();
    const tx5 = await (await AFIB.transferOwnership(AFIFarmB.address)).wait();

  });

  it("Deploy AFIFarmB ", async () => {
    expect(AFIFarmB.address).to.not.equal(ZERO_ADDRESS);
    console.log("faming arddress",AFIFarmB.address)
  });

  it("Deploy Mock AFI Token ", async () => {
    expect(AFI.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Deploy Mock AFIB Token ", async () => {
    expect(AFIB.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Deploy Mock WANT Token ", async () => {
    expect(WANT.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Deploy Mock STRATEGY Token ", async () => {
    expect(STRATEGY.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Change AFI, AFIB Token Address by owner", async () => {
    const tx = await (await AFIFarmB.connect(signer).setTokenAddress(AFI.address, 1)).wait();
    expect(await tx.status).to.equal(1);

    const tx1 = await (await AFIFarmB.connect(signer).setTokenAddress(AFIB.address, 2)).wait();
    expect(await tx1.status).to.equal(1);
    expect(await AFIFarmB.AFI()).to.be.equal(AFI.address);
    expect(await AFIFarmB.AFIB()).to.be.equal(AFIB.address);
  });

  it("Add a new LP to the Pool with _withUpdate=false By Owner", async () => {
    _allocPoint = 1000;
    _want = WANT.address;
    _withUpdate = false;
    _strat = STRATEGY.address;
    // add pool
    const tx = await (await AFIFarmB.connect(signer).add(_allocPoint, _want, _withUpdate, _strat)).wait();
    expect(await tx.status).to.equal(1);

    // check whether allocPoint is added
    expect(await AFIFarmB.totalAllocPoint()).to.be.equal(_allocPoint);
    //check pool length
    expect(ethers.BigNumber.from(await AFIFarmB.poolLength()).toString()).to.be.equal("1");
  });

  it("Add a new LP to the Pool with _withUpdate=false By User", async () => {
    // should revert
    _allocPoint = 1000;
    _want = WANT.address;
    _withUpdate = false;
    _strat = STRATEGY.address;
    await expect(AFIFarmB.connect(user1).add(_allocPoint, _want, _withUpdate, _strat)).to.be.reverted;
  });

  it("Set the given pool's AFI allocation point with _withUpdate=false", async () => {
    _pid = 0
    _allocPoint = 100
    _withUpdate = false

    const tx = await (await AFIFarmB.connect(signer).set(_pid, _allocPoint, _withUpdate)).wait();
    expect(await tx.status).to.equal(1);
    // check whether allocPoint is set
    expect(await AFIFarmB.totalAllocPoint()).to.be.equal(100);

  });

  it("Set the given pool's AFI allocation point with _withUpdate=true", async () => {
    _pid = 0
    _allocPoint = 100
    _withUpdate = true

    const tx = await (await AFIFarmB.connect(signer).set(_pid, _allocPoint, _withUpdate)).wait();
    expect(await tx.status).to.equal(1);
    console.log("set tx is ", tx)

  });

  it("Deposit want tokens from user to Farm->Strat", async () => {
    _pid = 0
    _wantAmt = 100
    // before deposit, user's staked balance is 0
    const stakedWantTokens1 = await AFIFarmB.connect(signer).stakedWantTokens(_pid, signer.address);
    expect(ethers.BigNumber.from(stakedWantTokens1).toString()).to.be.equal("0");

    await WANT.connect(signer).approve(AFIFarmB.address, _wantAmt);

    const tx = await (await AFIFarmB.connect(signer).deposit(_pid, _wantAmt)).wait();
    expect(await tx.status).to.equal(1);

    // before deposit, user's staked balance is 100
    const stakedWantTokens = await AFIFarmB.connect(signer).stakedWantTokens(_pid, signer.address);
    expect(ethers.BigNumber.from(stakedWantTokens).toString()).to.be.equal("100");

  });

  it("Withdraw LP tokens from MasterChef", async () => {
    _pid = 0
    _wantAmt = 100
    // before withraw, user's staked balance is 100
    const stakedWantTokens = await AFIFarmB.connect(signer).stakedWantTokens(_pid, signer.address);
    expect(ethers.BigNumber.from(stakedWantTokens).toString()).to.be.equal("100");

    const tx = await (await AFIFarmB.connect(signer).withdraw(_pid, _wantAmt)).wait();
    expect(await tx.status).to.equal(1);

    const stakedWantTokens1 = await AFIFarmB.connect(signer).stakedWantTokens(_pid, signer.address);
    expect(ethers.BigNumber.from(stakedWantTokens1).toString()).to.be.equal("0");

  });

  it("WithdrawAll with owner", async () => {
    _pid = 0
    _wantAmt = 100
    await WANT.approve(AFIFarmB.address, _wantAmt);

    const tx1 = await (await AFIFarmB.connect(signer).deposit(_pid, _wantAmt)).wait();
    expect(await tx1.status).to.equal(1);
    await delay(5000)
    const tx = await (await AFIFarmB.connect(signer).withdrawAll(_pid)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("EmergencyWithdraw", async () => {
    _pid = 0
    _wantAmt = 100
    await WANT.approve(AFIFarmB.address, _wantAmt);
    const tx1 = await (await AFIFarmB.connect(signer).deposit(_pid, _wantAmt)).wait();
    expect(await tx1.status).to.equal(1);

    const tx = await (await AFIFarmB.connect(signer).emergencyWithdraw(_pid)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("InCaseTokensGetStuck with owner", async () => {
    let _amount  = 10;
    await AFI.approve(AFIFarmB.address, _amount);
    const tx = await (await AFIFarmB.connect(signer).inCaseTokensGetStuck(AFI.address, _amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("MigrateToAFIB with owner", async () => {
    let amount  = 10;

    // console.log(ethers.BigNumber.from(await AFI.balanceOf(signer.address)).toString())
    // console.log(ethers.BigNumber.from(await AFIB.balanceOf(signer.address)).toString())
    expect(ethers.BigNumber.from(await AFIB.balanceOf(signer.address)).toString()).to.equal("0");
    const tx = await (await AFIFarmB.migrateToAFIB(amount)).wait();
    expect(await tx.status).to.equal(1);
    expect(ethers.BigNumber.from(await AFIB.balanceOf(signer.address)).toString()).to.equal("10");

    // console.log(ethers.BigNumber.from(await AFI.balanceOf(signer.address)).toString())
    // console.log(ethers.BigNumber.from(await AFIB.balanceOf(signer.address)).toString())

  });

  it("SetAFIPerBlock with owner", async () => {
    let amount  = 10;
    const tx = await (await AFIFarmB.connect(signer).setAFIPerBlock(amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("View function to see pending AFI on frontend", async () => {
    let _pid = 0; 
    let _user = signer.address;
    let _wantAmt = 100
    console.log(await ethers.provider.getBlockNumber())
    await WANT.approve(AFIFarmB.address, _wantAmt);

    const tx1 = await (await AFIFarmB.connect(signer).deposit(_pid, _wantAmt)).wait();
    expect(await tx1.status).to.equal(1);

    // const sevenDays = 100 * 24 * 60 * 60;

    // const blockNumBefore = await ethers.provider.getBlockNumber();
    // const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    // const timestampBefore = blockBefore.timestamp;

    // await ethers.provider.send('evm_increaseTime', [sevenDays]);
    // await ethers.provider.send('evm_mine');

    // const blockNumAfter = await ethers.provider.getBlockNumber();
    // const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    // const timestampAfter = blockAfter.timestamp;
    // expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
    // expect(timestampAfter).to.be.equal(timestampBefore + sevenDays);
    // console.log(await ethers.provider.getBlockNumber())

    const pendingAFI = await AFIFarmB.pendingAFI(_pid, _user);
    expect(ethers.BigNumber.from(pendingAFI).toString()).to.equal("0");

    // console.log(ethers.BigNumber.from(pendingAFI).toString())
  });

  it("View function to see staked Want tokens on frontend", async () => {
    let _pid = 0; 
    let _user = signer.address;

    const stakedWantTokens = await AFIFarmB.stakedWantTokens(_pid, _user);
    expect(ethers.BigNumber.from(stakedWantTokens).toString()).to.equal("100");

  });

  it("View function to see pending AFI For APY on frontend", async () => {
    let _pid = 0; 
    let _user = signer.address;
    let APY = 365 * 24 * 60 * 60 / 3; // Period
    const pendingAFI = await AFIFarmB.pendingTestAFI(_pid, _user, APY);
    // console.log(ethers.BigNumber.from(pendingAFI).toString())
    expect(ethers.BigNumber.from(pendingAFI).toString()).to.equal("105120000");

  });

});
