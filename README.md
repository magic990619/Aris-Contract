# aries_contract 🍉

This repository is for aries staking contracts


## Setup Environment Variables

    Please copy .env.example file to .env file. And then put the following.

    MORALIS_API_KEY = 
    ALCHEMY_API_KEY = 
    PRIVATE_KEY = 
    BSCSCAN_API_KEY = 

## Installation

Install Node.js

```bash
sudo curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 

nvm install 16

node -v
```
    
## Deployment

### Commands
#### 1.  Install necessarily Node.js packages.
    npm install     
#### 2. Deploy smart contracts to the BSC blockchain.
    npm run deploy:bsc
#### 3. Deploy smart contracts to the BSC Testnet blockchain.
    npm run deploy:bsctest
#### 3. Verify smart contracts to the BSC blockchain.
    npx hardhat verify argument --network bsctest
    npx hardhat verify argument --network bsc
#### 4. Hardhat can test your smart contracts.
    npm run test