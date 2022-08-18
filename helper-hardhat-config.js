const networkConfig = {
  31337: {
    name: "localhost",
  },
}
const INITIAL_SUPPLY = "100000000000"

const developmentChains = ["hardhat", "localhost"]

module.exports = {
  networkConfig,
  developmentChains,
  INITIAL_SUPPLY,
}
