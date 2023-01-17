const { expect, util } = require("chai");
const { ethers, artifacts } = require("hardhat");

describe("InterestModel test", () => {
    let interestModelContract
    before(async () => {
      const interestModelContractABI = await ethers.getContractFactory("TripleSlopeModel");
      interestModelContract = await (await interestModelContractABI.deploy()).deployed();
  
    });
  
    it("Return 0 value with null inputs ", async () => {
        const interestValue = await interestModelContract.getInterestRate(0, 0 )
        expect (interestValue).to.be.equal(0)
    });

    it("Check if utilizaion smaller than CEIL_SLOPE_1 ", async () => {
        const ceil_slope_1 = await interestModelContract.CEIL_SLOPE_1()
        const max_interest_slope = await interestModelContract.MAX_INTEREST_SLOPE_1()
        const interestValue = await interestModelContract.getInterestRate(ethers.utils.parseEther("0.1"), ethers.utils.parseEther("1") )
        const utilization = ethers.utils.parseEther("0.1") * 100 / 1.1
        const returnValue = utilization * max_interest_slope / ceil_slope_1 / (86400 * 365)
      expect (parseInt(interestValue)).to.be.equal(parseInt(returnValue))
        });
    it("Check if utilizaion smaller than CEIL_SLOPE_2 ", async () => {
      const max_interest_slope2 = await interestModelContract.MAX_INTEREST_SLOPE_2()
      const interestValue = await interestModelContract.getInterestRate(ethers.utils.parseEther("2"), ethers.utils.parseEther("1") )
      const returnValue = max_interest_slope2 / (86400 * 365)
      expect (parseInt(interestValue)).to.be.equal(parseInt(returnValue))
    });

    it("Check if utilizaion smaller than CEIL_SLOPE_3 ", async () => {
      const ceil_slope_2 = await interestModelContract.CEIL_SLOPE_2()
      const ceil_slope_3 = await interestModelContract.CEIL_SLOPE_3()
      const max_interest_slope2 = await interestModelContract.MAX_INTEREST_SLOPE_2()
      const max_interest_slope3 = await interestModelContract.MAX_INTEREST_SLOPE_3()
      const interestValue = await interestModelContract.getInterestRate(ethers.utils.parseEther("1"), ethers.utils.parseEther("0.1") )
      const utilization = ethers.utils.parseEther("1") * 100 / 1.1
      const returnValue = (parseInt(max_interest_slope2) + (utilization-ceil_slope_2) * (max_interest_slope3-max_interest_slope2) / (ceil_slope_3-ceil_slope_2)) / (86400 * 365)
      expect(parseInt(interestValue)).to.be.equal(parseInt(returnValue))
    });
    it("Check if else", async () => {
      const max_interest_slope3 = await interestModelContract.MAX_INTEREST_SLOPE_3()
      const interestValue = await interestModelContract.getInterestRate(ethers.utils.parseEther("1"), ethers.utils.parseEther("0") )
      const returnValue = parseInt(max_interest_slope3) / (86400 * 365)
      expect(parseInt(interestValue)).to.be.equal(parseInt(returnValue))
    });
});
