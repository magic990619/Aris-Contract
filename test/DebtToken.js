const { expect } = require("chai");
const { ethers, artifacts, upgrades } = require("hardhat");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const _timelock = "0x4000000001400000000000000050000000000000";

let DebtToken;

let signer;
let user1;

describe("DebtToken Test", () => {
  
  before(async () => {
    const _DebtToken = await ethers.getContractFactory("DebtToken");
    DebtToken = await(await upgrades.deployProxy(_DebtToken, ["DebtToken"," DebtToken", _timelock], {
      initializer: "initialize",
      kind: "transparent",
    })).deployed();
    [signer, user1] = await ethers.getSigners();

  });

  it("Deploy DebtToken ", async () => {
    expect(DebtToken.address).to.not.equal(ZERO_ADDRESS);
  });

  it("Call setOkHolders function by owner", async () => {
    let _isOk = true;
    let _okHolders = [signer.address, "0x4000000001400000000000000050000000000000", "0x4000000001400000010000000005000000000000", "0x4000000001400000060070000050000000000000"]
    const tx = await (await DebtToken.connect(signer).setOkHolders(_okHolders, _isOk)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Call setOkHolders function by user", async () => {
    let _isOk = true;
    let _okHolders = [signer.address, "0x4000000001400000000000000050000000000000", "0x4000000001400000010000000005000000000000", "0x4000000001400000060070000050000000000000"]
    const tx = await (await DebtToken.setOkHolders(_okHolders, _isOk)).wait();
    await expect(DebtToken.connect(user1).setOkHolders(_okHolders, _isOk)).to.be.reverted;
  });

  it("Call mint function with approved address by Owner", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000000";
    const tx = await (await DebtToken.connect(signer).mint(to, amount)).wait();
    expect(await tx.status).to.equal(1);
    const tx1 = await (await DebtToken.connect(signer).mint(signer.address, amount)).wait();
    expect(await tx1.status).to.equal(1);
  });

  it("Call mint function with unapproved by Owner", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000001";
    await expect(DebtToken.mint(to, amount)).to.be.reverted;
  });

  it("Call mint function by user", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000000";
    await expect(DebtToken.connect(user1).mint(to, amount)).to.be.reverted;
  });

  it("Call burn function with approved by Owner", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000000";
    const tx = await (await DebtToken.connect(signer).burn(to, amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Call burn function with unapproved by Owner", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000001";
    await expect(DebtToken.connect(user1).burn(to, amount)).to.be.reverted;
  });

  it("Call transfer function with approved by Owner", async () => {
    let amount = 1;
    let to = "0x4000000001400000000000000050000000000000";
    const tx = await (await DebtToken.connect(signer).transfer(to, amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Call transfer function with unapproved by Owner", async () => {
    let amount = 1000;
    let to = "0x4000000001400000000000000050000000000011";
    await expect(DebtToken.connect(signer).transfer(to, amount)).to.be.reverted;
  });

  it("Call transfer function with approved by Owner", async () => {
    let amount = 1;
    let from = "0x4000000001400000000000000050000000000000"
    let to = "0x4000000001400000000000000050000000000000";
    const tx = await (await DebtToken.connect(signer).transferFrom(from, to, amount)).wait();
    expect(await tx.status).to.equal(1);
  });

  it("Call transfer function with unapproved by Owner", async () => {
    let amount = 1000;
    let from = "0x4000000001400000000000000050000000000011";
    let to = "0x4000000001400000000000000050000000000011";
    await expect(DebtToken.connect(signer).transferFrom(from, to, amount)).to.be.reverted;
  });

});