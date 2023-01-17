const { ethers } = require("hardhat");


const encodeString = ethers.utils.defaultAbiCoder.encode(
    ["address", "bytes"],
    [
      "0xC37f4447f88AF96367fE3555E9597EF14864C123",
      ethers.utils.defaultAbiCoder.encode(
        ["uint256", "uint256"],
        [ethers.utils.parseEther("5"), ethers.utils.parseEther("0")]
      ),
    ]
  );
  console.log(encodeString);  