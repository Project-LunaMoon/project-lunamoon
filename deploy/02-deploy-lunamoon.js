const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const lunaMoon = await deploy("TestNet_LunaMoon_V0_1", {
    from: deployer,
    args: [],
    log: true,
  })
  log(`LunaMoon deployed at ${lunaMoon.address}`)

  if (!developmentChains.includes(network.name)) {
    await verify(lunaMoon.address)
  }
}

module.exports.tags = ["lunamn", "all"]
