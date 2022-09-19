const { getNamedAccounts, deployments, network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const {
  developmentChains,
  hardhatPancakeFactory,
  testnetPancakeFactory,
} = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const WBNB = await deploy("WBNBMock", {
    from: deployer,
    args: ["WBNBMock", "WBNB"],
    log: true,
  })
  log(`WBNBMock deployed at ${WBNB.address}`)

  if (!developmentChains.includes(network.name)) {
    await verify(WBNB.address, ["WBNBMock", "WBNB"])
  }

  const erc20 = await deploy("ERC20Mock", {
    from: deployer,
    args: ["ERC20Mock", "ERCM"],
    log: true,
  })
  log(`ERC20Mock deployed at ${erc20.address}`)

  if (!developmentChains.includes(network.name)) {
    await verify(erc20.address, ["ERC20Mock", "ERCM"])
  }

  const pancakeRouter = await deploy("PancakeRouterMock", {
    from: deployer,
    args: [hardhatPancakeFactory, WBNB.address],
    log: true,
  })
  log(`PancakeRouter deployed at ${pancakeRouter.address}`)

  if (!developmentChains.includes(network.name)) {
    await verify(pancakeRouter.address, [testnetPancakeFactory, WBNB.address])
  }
}

module.exports.tags = ["mocks", "all"]
