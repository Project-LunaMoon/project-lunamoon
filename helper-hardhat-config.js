const ethers = require("hardhat")

const networkConfig = {
  31337: {
    name: "hardhat",
  },
}

const developmentChains = ["hardhat", "localhost"]
const hardhatPancakeFactory = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
const testnetPancakeFactory = "0xb4e6031F3a95E737046370a05d9add865c3D9A3B"

module.exports = {
  networkConfig,
  developmentChains,
  hardhatPancakeFactory,
  testnetPancakeFactory,
}
