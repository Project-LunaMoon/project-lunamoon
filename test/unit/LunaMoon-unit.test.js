const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, ethers } = require("hardhat")

const DECIMALS = 10 ** 9

describe("LunaMoon Test", () => {
  let lunaMoon,
    dividendTrackerAddress,
    dividendTracker,
    pancakeRouter,
    WBNB,
    deployer
  beforeEach(async () => {
    const accounts = await getNamedAccounts()
    deployer = accounts.deployer
    user = accounts.user

    await deployments.fixture("all")

    lunaMoon = await ethers.getContract("TestNet_LunaMoon_V0_1", deployer)
    dividendTrackerAddress = await lunaMoon._lunaDividendTracker()
    dividendTracker = await ethers.getContractAt(
      "_LUNADividendTracker",
      dividendTrackerAddress
    )
    pancakeRouter = await ethers.getContract("PancakeRouterMock", deployer)
    WBNB = await ethers.getContract("WBNBMock", deployer)
    pancakeFactory = await ethers.getContract("PancakeFactoryMock", deployer)
  })

  describe("constructor", () => {
    it("deployed tracker, router and pair", async () => {
      const dividendTracker = await lunaMoon._lunaDividendTracker()
      const router = await lunaMoon.uniswapV2Router()
      const pair = await lunaMoon.uniswapV2Pair()
      assert(dividendTracker)
      assert.equal(router, pancakeRouter.address)
      assert(pair)
    })
    it("sets the automated market pair", async () => {
      const pair = await lunaMoon.uniswapV2Pair()
      assert(await lunaMoon.automatedMarketMakerPairs(pair))
    })
    it("excluded protocol wallets from dividends", async () => {
      assert(
        await dividendTracker.excludedFromDividends(dividendTrackerAddress)
      )
      assert(await dividendTracker.excludedFromDividends(lunaMoon.address))
      assert(await dividendTracker.excludedFromDividends(pancakeRouter.address))
      assert(
        await dividendTracker.excludedFromDividends(
          "0x000000000000000000000000000000000000dEaD"
        )
      )
      assert(await dividendTracker.excludedFromDividends(deployer))
    })
    it("excluded protocol wallets from fees", async () => {
      const marketingWallet = await lunaMoon.marketingWallet()
      const liqWallet = await lunaMoon.liqWallet()
      assert(await lunaMoon.excludedFromFees(marketingWallet))
      assert(await lunaMoon.excludedFromFees(liqWallet))
      assert(await lunaMoon.excludedFromFees(lunaMoon.address))
      assert(
        await lunaMoon.excludedFromFees(
          "0x000000000000000000000000000000000000dEaD"
        )
      )
      assert(await lunaMoon.excludedFromFees(deployer))
    })
    it("excluded protocol wallets from max wallet", async () => {
      const marketingWallet = await lunaMoon.marketingWallet()
      const liqWallet = await lunaMoon.liqWallet()
      const pair = await lunaMoon.uniswapV2Pair()
      assert(await lunaMoon.excludedFromMaxWallet(marketingWallet))
      assert(await lunaMoon.excludedFromMaxWallet(liqWallet))
      assert(await lunaMoon.excludedFromMaxWallet(lunaMoon.address))
      assert(
        await lunaMoon.excludedFromMaxWallet(
          "0x000000000000000000000000000000000000dEaD"
        )
      )
      assert(await lunaMoon.excludedFromMaxWallet(deployer))
      assert(await lunaMoon.excludedFromMaxWallet(pair))
    })
    it("sets pre-market users", async () => {
      const marketingWallet = await lunaMoon.marketingWallet()
      const liqWallet = await lunaMoon.liqWallet()
      assert(await lunaMoon.premarketUser(deployer))
      assert(await lunaMoon.premarketUser(marketingWallet))
      assert(await lunaMoon.premarketUser(liqWallet))
    })
    it("mints total supply to owner", async () => {
      assert.equal(
        (await lunaMoon.balanceOf(deployer)).toString(),
        "10000000000000000000"
      )
    })
    it("set tx and wallet limits", async () => {
      assert.equal(
        (await lunaMoon.maxSellTxAmount()).toString(),
        (100000000 * DECIMALS).toString()
      )
      assert.equal(
        (await lunaMoon.maxBuyTxAmount()).toString(),
        (100000000 * DECIMALS).toString()
      )
      assert.equal(
        (await lunaMoon.maxWalletAmount()).toString(),
        (100000000 * DECIMALS).toString()
      )
    })
    it("sets pre-launch fees", async () => {
      assert.equal(parseInt(await lunaMoon.totalBuyFees()), 98)
      assert.equal(parseInt(await lunaMoon.totalSellFees()), 98)
    })
  })
  describe("prepareForLaunch", () => {
    it("sets post-launch fees", async () => {
      await lunaMoon.prepareForLaunch()
      assert.equal(parseInt(await lunaMoon.totalBuyFees()), 8)
      assert.equal(parseInt(await lunaMoon.totalSellFees()), 8)
    })
  })
  describe("setSwapAndLiquify", () => {
    it("does not allow swapping more than allowed", async () => {
      await expect(
        lunaMoon.setSwapAndLiquify(true, 10, 1000, 2000)
      ).to.be.revertedWith("You cannot swap more than the minimum amount")
      await expect(
        lunaMoon.setSwapAndLiquify(
          true,
          10,
          5000000000000000000n,
          5000000000000000000n
        )
      ).to.be.revertedWith("token to swap limited to 0.1% supply")
    })
  })
  describe("setMaxTxAmount", () => {
    it("does not allow limiting transaction amounts to less than 0.1% of supply", async () => {
      await expect(lunaMoon.setMaxTxAmount(1, 10000000)).to.be.revertedWith(
        "maxBuyTxAmount should be at least 0.1% of total supply."
      )
      await expect(lunaMoon.setMaxTxAmount(10000000, 1)).to.be.revertedWith(
        "maxSellTxAmount should be at least 0.1% of total supply."
      )
    })
  })
  describe("Sweep", () => {
    it("allows the owner to retrieve the balance of the contract", async () => {
      const startingOwnerBalance = await ethers.provider.getBalance(deployer)
      const startingLunaMoonBalance = await ethers.provider.getBalance(
        lunaMoon.address
      )
      await lunaMoon.provider.call({ value: BigInt(10 * DECIMALS) })
      const txResponse = await lunaMoon.Sweep()
      const txReceipt = await txResponse.wait()
      const { gasUsed, effectiveGasPrice } = txReceipt
      const gasCost = gasUsed.mul(effectiveGasPrice)
      const endingOwnerBalance = await ethers.provider.getBalance(deployer)
      const endingLunaMoonBalance = await ethers.provider.getBalance(
        lunaMoon.address
      )
      assert.equal(endingLunaMoonBalance, 0)
      assert.equal(
        startingLunaMoonBalance.add(startingOwnerBalance).toString(),
        endingOwnerBalance.add(gasCost).toString()
      )
    })
  })
  describe("edit_excludeFromFees", () => {
    it("should exclude from fees", async () => {
      await lunaMoon.edit_excludeFromFees(deployer, true)
      assert(await lunaMoon.excludedFromFees(deployer))
    })
    it("should emit event", async () => {
      expect(lunaMoon.edit_excludeFromFees(deployer, true)).to.emit(
        lunaMoon,
        "ExcludeFromFees"
      )
    })
  })
  describe("setMaxWallet", () => {
    it("does not allow limiting wallets to less than 1% of supply", async () => {
      await expect(lunaMoon.setMaxWallet(true, 1)).to.be.revertedWith(
        "max wallet min amount: 1%"
      )
    })
  })
  describe("setBuyFees", () => {
    it("should not allow increasing fees over 25%", async () => {
      await lunaMoon.prepareForLaunch()
      await expect(lunaMoon.setBuyFees(5, 5, 5, 5, 5, 5)).to.be.revertedWith(
        "you cannot set fees more then 25%"
      )
    })
  })
  describe("setSellFees", () => {
    it("changes fee status if total is 0", async () => {
      await lunaMoon.prepareForLaunch()
      await lunaMoon.setSellFees(0, 0, 0, 0, 0, 0)
      assert.isNotTrue(await lunaMoon.sellFeeStatus())
    })
  })
  describe("transfer", () => {
    it("can be used to add initial liquidity", async () => {
      await WBNB._mint(deployer, BigInt(10000000000 * DECIMALS))
      await WBNB.approve(pancakeRouter.address, BigInt(9999999 * DECIMALS))
      await lunaMoon.approve(pancakeRouter.address, BigInt(9999999 * DECIMALS))
      await pancakeRouter.addLiquidity(
        WBNB.address,
        lunaMoon.address,
        BigInt(1000000 * DECIMALS),
        BigInt(100 * DECIMALS),
        BigInt(900000 * DECIMALS),
        BigInt(90 * DECIMALS),
        deployer,
        1763323680n
      )
      const pairAddress = await lunaMoon.uniswapV2Pair()
      const pair = await ethers.getContractAt("PancakePair", pairAddress)
      const reserves = (await pair.getReserves()).toString()
      assert(reserves)
    })
  })
})
