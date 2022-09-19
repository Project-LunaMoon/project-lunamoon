const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const pancakeFactory = await deploy("PancakeFactoryMock", {
    from: deployer,
    args: [deployer],
    log: true,
  })
  const pancakeFactoryAddress = pancakeFactory.address
  log(`PancakeFactory deployed at ${pancakeFactoryAddress}`)

  if (!developmentChains.includes(network.name)) {
    await verify(pancakeFactory.address, deployer)
  }
}

module.exports.tags = ["factory", "all"]
