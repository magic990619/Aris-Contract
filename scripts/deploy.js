// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy

  /*

  const InterestModel = await hre.ethers.getContractFactory("TripleSlopeModel");
  const interestModel = await InterestModel.deploy();
  await interestModel.deployed();
  console.log("InterestModel contract deployed to:", interestModel.address);

  /*---------------------------------------*/
  /*-----------WNativeRelayer--------------*/
  /*---------------------------------------*/

  // Deploy WNativeRelayer
  // Deployed Address: 0x7c48e7bf6f03abf60dc4bd6a1868f54ec8b3fef8 - BSC TestNet
  /*
  const WNativeRelayer = await hre.ethers.getContractFactory("WNativeRelayer");
  const wNativeRelayer = await WNativeRelayer.deploy(
    "0xae13d989dac2f0debff460ac112a837c89baa7cd"
  ); //  pram: wbnb wrapped bnb address
  await wNativeRelayer.deployed();
  console.log("WNativeRelayer contract deployed to:", wNativeRelayer.address);
  */

  /*---------------------------------------*/
  /*----------------AFIR-------------------*/
  /*---------------------------------------*/

  // Deploy AFIR Token
  // Deployed Address: 0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3 - BSC Testnet
  /*
  const AFIR = await hre.ethers.getContractFactory("AFIR");
  const afir = await AFIR.deploy("25525120", "32980890");
  await afir.deployed();
  console.log("AFIR Token contract deployed to:", afir.address);
  */
  // Verify AFIR
  /*
  await hre.run("verify:verify", {
    address: "0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3",
    constructorArguments: [
      "25525120",
      "32980890"
    ]
  });
  */

  /*---------------------------------------*/
  /*-------------FAIRLAUNCH----------------*/
  /*---------------------------------------*/

  // Deploy FairLaunch
  // Deployed Address: 0xa9B7046654BF0E5e2d827e45fD86F0A37aE0210A - BSC Testnet
  /*
  const FairLaunch = await hre.ethers.getContractFactory("FairLaunch");
  const fairLaunch = await FairLaunch.deploy(
    "0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3", // afir
    "0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396", // dev
    "10000000000000000",                          // afirPerBlock
    "25525120",                                   // startBlock
    "200",                                        // bonusLockupBps
    "26025120"                                    // bonusEndBlock
  );
  await fairLaunch.deployed();
  console.log("FairLaunch contract deployed to:", fairLaunch.address);
  */

  /*---------------------------------------*/
  /*-----------AFIRFAIRLAUNCH--------------*/
  /*---------------------------------------*/

  // Deploy AFIFairLaunch
  // Deployed Address: 0x36B5d43B515f47448bE7eFb65aA491d9FdD76D47 - BSC Testnet
  /*
  const AFIFairLaunch = await hre.ethers.getContractFactory("AFIFairLaunch");
  const afiFairLaunch = await AFIFairLaunch.deploy(
    "0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3", // afir
    "0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396", // dev
    "10000000000000000",                          // afirPerBlock
    "25525120",                                   // startBlock
    "200",                                        // bonusLockupBps
    "26025120"                                    // bonusEndBlock
  );
  await afiFairLaunch.deployed();
  console.log("AFIFairLaunch contract deployed to:", afiFairLaunch.address);

  // Verify AFIFairLaunch
  
  await hre.run("verify:verify", {
    address: afiFairLaunch.address,
    constructorArguments: [
      "0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3", // afir
      "0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396", // dev
      "10000000000000000",                          // afirPerBlock
      "25525120",                                   // startBlock
      "200",                                        // bonusLockupBps
      "26025120" 
    ]
  });
  */
  

  /*---------------------------------------*/
  /*-----------SIMPLEVAULTCONFIG-----------*/
  /*---------------------------------------*/

  // Deploy SimpleVaultConfig Contracts
  // Deployed Address: 0xd62cc2AAf458dD06cEe9Ab493bab20593367D1A5 - BSC Testnet
  /*
  const Config = await hre.ethers.getContractFactory("SimpleVaultConfig");
  const config = await hre.upgrades.deployProxy(Config, [
    "33000000000000000000", // minDebtSize
    "4000000000",           // interestRate
    "1900",                 // reservePoolBps
    "100",                  // killBps
    "0xae13d989dac2f0debff460ac112a837c89baa7cd", // WrapperNativeAddr
    "0x7c48e7bf6f03abf60dc4bd6a1868f54ec8b3fef8", // WNativeRelayer
    "0x36B5d43B515f47448bE7eFb65aA491d9FdD76D47", // FairLaunch
    "400",                  // getKillTreasuryBps
    "0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396"  // Treasury
  ]);
  await config.deployed();
  console.log("Config contract deployed to:", config.address);

  // Verify SimpleVaultConfig
  await hre.run("verify:verify", {
    address: config.address
  });
  */

  /*---------------------------------------*/
  /*---------------DEBTTOKEN---------------*/
  /*---------------------------------------*/
  
  // Deploy DebtToken
  // Deployed Address: 0xDee9E378e483AB862D93364069aE381377bb2899 - BSC TestNet
  // Deployed Address: 0xB9c4B80C2456084B128cf0398b9a2a5B6399D664 - BSC TestNet
  // Deployed Address: 0x5940EeD0553a34c0B2aeE6A58051379A7660ba99 - BSC TestNet
  /*
  const DebtToken = await hre.ethers.getContractFactory("DebtToken");
  const debtToken = await hre.upgrades.deployProxy(DebtToken, [
    "Debt BUSD Token",  // name
    "debtibBUSD",       // symbol
    "0xc8c3ac919f43b8aa875DA490610fc4AD7F74d396", // timelock
  ]);
  await debtToken.deployed();
  console.log("DebtToken contract deployed to:", debtToken.address);

  // Verify DebtToken
  await hre.run("verify:verify", {
    address: debtToken.address
  });
  */


  /*---------------------------------------*/
  /*-----------------VAULT-----------------*/
  /*---------------------------------------*/

  // Deploy Vault: BUSD & ibBUSD
  // Deployed Address: 0xfC48d0dF8c4adeE0893524F2dBeBdBadf202b3C2 - BSC Testnet
  // Deployed Address: 0x62568F35518894850f79cA8112BD6d61f0C917d8 - BSC Testnet
  // Deployed Address: 0x7A853BD49EF7bc709e312497EA513B2eB48a07F5 - BSC Testnet
  /*
  const Vault = await hre.ethers.getContractFactory("Vault");
  const vault = await hre.upgrades.deployProxy(Vault, [
    "0xd62cc2AAf458dD06cEe9Ab493bab20593367D1A5", // SimpleVaultConfig
    "0x8516Fc284AEEaa0374E66037BD2309349FF728eA", // BUSD Token
    "Interest Bearing BUSD",  // name
    "ibBUSD",                 // symbol
    "18",                     // decimals
    "0x5940EeD0553a34c0B2aeE6A58051379A7660ba99"  // DebtToken
  ]);
  await vault.deployed();
  console.log("Vault Contract deployed to:", vault.address);

  // Verify Vault
  await hre.run("verify:verify", {
    address: vault.address
  });
  */

  /*---------------------------------------*/
  /*----------------AFIFARMB---------------*/
  /*---------------------------------------*/

  // Deploy AFIFARMB
  // Deployed Address: 0x2d70E0C0afA7f6E2d3B2b0b71d9B8fa4de781601 - BSC Testnet
  
  /*
  const FARM = await hre.ethers.getContractFactory("AFIFarmB");
  const farm = await FARM.deploy();
  await farm.deployed();
  console.log("FARM Contract deployed to:", farm.address);

  // Verify Farm
  await hre.run("verify:verify", {
    address: farm.address
  });
  */


  // BUSD-DAI LP: 0xf8e4ce287e0d1f9c9fda5ec917515cb87d9c1e6c - BSC TestNet
  /*---------------------------------------*/
  /*----------------STRATEGY---------------*/
  /*---------------------------------------*/

  // Deploy Strategy for BUSD-DAI Pair
  // Deployed Address: 0x87ffE9b74fABCd583D9A62DBcF608E062712A824 - BSC Testnet
  
  /*
  const STRATEGY = await hre.ethers.getContractFactory("StratX");
  const strategy = await STRATEGY.deploy(
    "0x2d70E0C0afA7f6E2d3B2b0b71d9B8fa4de781601", // farm
    false,
    "0xf8e4ce287e0d1f9c9fda5ec917515cb87d9c1e6c" // BUSD-DAI
  );
  await strategy.deployed();
  console.log("Strategy Contract deployed to:", strategy.address);
  // Verify Strategy
  await hre.run("verify:verify", {
    address: strategy.address,
    constructorArguments: [
      "0x2d70E0C0afA7f6E2d3B2b0b71d9B8fa4de781601", // farm
      false,
      "0xf8e4ce287e0d1f9c9fda5ec917515cb87d9c1e6c" // BUSD-DAI
    ]
  });
  
*/

  // MasterChefV2:  0xB4A466911556e39210a6bB2FaECBB59E4eB7E43d - BSC testnet
  // RouterV2: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 - BSC testnet
  // Cake: 0xFa60D973F7642B748046464e165A65B7323b0DEE
  // BUSD: 0x8516Fc284AEEaa0374E66037BD2309349FF728eA
  // WBNB: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd

  /*------------------------------------------------------------------*/
  /*--------------PancakeswapV2StrategyAddBaseTokenOnly---------------*/
  /*------------------------------------------------------------------*/

  // Deploy PancakeswapV2StrategyAddBaseTokenOnly
  // Deployed Address: 0x9a961d9A6944DC69C3bA4D59DEbC5935f202f6eC - BSC Testnet
   
  /*
  const PancakeswapV2StrategyAddBaseTokenOnly = await hre.ethers.getContractFactory("PancakeswapV2StrategyAddBaseTokenOnly");
  const addStrat = await hre.upgrades.deployProxy(PancakeswapV2StrategyAddBaseTokenOnly, [
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1" // RouterV2
  ]);
  await addStrat.deployed();
  console.log("AddStrat Contract deployed to:", addStrat.address);

  // Verify addStrat
  await hre.run("verify:verify", {
    address: addStrat.address
  });
  */  

  /*-----------------------------------------------------------*/
  /*--------------PancakeswapV2StrategyLiquidate---------------*/
  /*-----------------------------------------------------------*/

  // Deploy PancakeswapV2StrategyLiquidate
  // Deployed Address: 0xf86bf0438F506B361bf0A9594D0e2aEA5a8ae443 - BSC Testnet
   
  /*
  const PancakeswapV2StrategyLiquidate = await hre.ethers.getContractFactory("PancakeswapV2StrategyLiquidate");
  const liqStrat = await hre.upgrades.deployProxy(PancakeswapV2StrategyLiquidate, [
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1" // RouterV2
  ]);
  await liqStrat.deployed();
  console.log("LiqStrat Contract deployed to:", liqStrat.address);

  // Verify liqStrat
  await hre.run("verify:verify", {
    address: "0xf86bf0438F506B361bf0A9594D0e2aEA5a8ae443"
  });
*/    

  /*------------------------------------------------*/
  /*--------------PancakeswapV2Worker---------------*/
  /*------------------------------------------------*/

  // Deploy PancakeswapV2Worker
  // Deployed Address: 0xfA9b4357dDB4a2e95567F2b56a81118F7a58B43D - BSC Testnet
  // Deployed Address: 0xE1e38F2DAd885a47B737b9e04dCBd73A576c0ae7 - BSC Testnet
  // Deployed Address: 0x267c6FC94600837660F51379Ca5cb665002872FA - BSC Testnet
  // Deployed Address: 0xEc756F91DF53E4DfE0fF7738bF7C030DDf3636fA - BSC Testnet
    
  const PancakeswapV2Worker = await hre.ethers.getContractFactory("PancakeswapV2Worker");
  const pancakeswapV2Worker = await hre.upgrades.deployProxy(PancakeswapV2Worker, [
    "0x7A853BD49EF7bc709e312497EA513B2eB48a07F5", // vault
    "0x8516Fc284AEEaa0374E66037BD2309349FF728eA", // BUSD Token
    "0xB4A466911556e39210a6bB2FaECBB59E4eB7E43d", // MasterChefV2
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1", // RouterV2
    "3",                      // pid BUSD-CAKE
    "0x9a961d9A6944DC69C3bA4D59DEbC5935f202f6eC", // addStrat
    "0xf86bf0438F506B361bf0A9594D0e2aEA5a8ae443", // liqStrat
    "100",                     // reinvestBountyBps,
    "0x72F2F63D14aaF51bb0E05D655cD40Fe01DA1CAE3"
  ]);
  await pancakeswapV2Worker.deployed();
  console.log("PancakeswapV2Worker Contract deployed to:", pancakeswapV2Worker.address);

  // Verify Vault
  await hre.run("verify:verify", {
    address: pancakeswapV2Worker.address
  });
  

  /*------------------------------------------------------------------------------*/
  /*--------------PancakeswapV2RestrictedStrategyAddTwoSidesOptimal---------------*/
  /*------------------------------------------------------------------------------*/

  // Deploy PancakeswapV2RestrictedStrategyAddTwoSidesOptimal
  // Deployed Address: 0x4d274Ef11f2B849b5634995DE17F9910a4e2a100 - BSC Testnet
  // Deployed Address: 0xC37f4447f88AF96367fE3555E9597EF14864C123 - BSC Testnet
  // Deployed Address: 0xCC546b2971f86Cbae9df09897dEb3af9dCEC03B7 - BSC Testnet
    
  /*
  const PancakeswapV2RestrictedStrategyAddTwoSidesOptimal = await hre.ethers.getContractFactory("PancakeswapV2RestrictedStrategyAddTwoSidesOptimal");
  const pancakeswapV2RestrictedStrategyAddTwoSidesOptimal = await hre.upgrades.deployProxy(PancakeswapV2RestrictedStrategyAddTwoSidesOptimal, [
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1", // RouterV2
    "0x7A853BD49EF7bc709e312497EA513B2eB48a07F5" // vault
  ]);
  await pancakeswapV2RestrictedStrategyAddTwoSidesOptimal.deployed();
  console.log("PancakeswapV2RestrictedStrategyAddTwoSidesOptimal Contract deployed to:", pancakeswapV2RestrictedStrategyAddTwoSidesOptimal.address);
  // Verify Vault
  await hre.run("verify:verify", {
    address: pancakeswapV2RestrictedStrategyAddTwoSidesOptimal.address
  });
*/
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
