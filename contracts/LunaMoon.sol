//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ERC20/ERC20.sol";
import "./access/Ownable.sol";
import "./math/SafeMath.sol";
import "./uniswap/IUniswapV2Router02.sol";
import "./LunaDividendTracker.sol";
import "./uniswap/IUniswapV2Pair.sol";
import "./uniswap/IUniswapV2Factory.sol";

contract LunaMoon is ERC20, Ownable {
  //library
  using SafeMath for uint256;
  //custom
  IUniswapV2Router02 public uniswapV2Router;
  _LUNADividendTracker public _lunaDividendTracker;
  //address
  address public uniswapV2Pair;
  address public marketingWallet; // to be made
  address public lunaBurnWallet = 0x6F3B3b903813679DDb21E4f2391638eE55ff3F89; // check required
  address public liqWallet; // to be made
  address public _lunaDividendToken;
  address public deadWallet = 0x000000000000000000000000000000000000dEaD;
  address public lunaAddress = 0x156ab3346823B651294766e23e6Cf87254d68962; // LUNA Wormhole
  //bool
  bool public marketingSwapSendActive = true;
  bool public lunaBurnSwapSendActive = true;
  bool public LiqSwapSendActive = true;
  bool public swapAndLiquifyEnabled = true;
  bool public ProcessDividendStatus = true;
  bool public _lunaDividendEnabled = true;
  bool public marketActive;
  bool public blockMultiBuys = true;
  bool public limitSells = true;
  bool public limitBuys = true;
  bool public feeStatus = true;
  bool public buyFeeStatus = true;
  bool public sellFeeStatus = true;
  bool public maxWallet = true;
  bool private isInternalTransaction;

  //uint
  uint256 public buySecondsLimit = 3;
  uint256 public minimumWeiForTokenomics = 1 * 10**17; // 0.1 bnb
  uint256 public maxBuyTxAmount; // 1% tot supply (constructor)
  uint256 public maxSellTxAmount; // 1% tot supply (constructor)
  uint256 public minimumTokensBeforeSwap = 10_000_000 * 10**decimals();
  uint256 public tokensToSwap = 10_000_000 * 10**decimals();
  uint256 public intervalSecondsForSwap = 20;
  uint256 public LUNARewardsBuyFee = 2;
  uint256 public LUNARewardsSellFee = 2;
  uint256 public LUNABurnBuyFee = 2; // check required
  uint256 public LUNABurnSellFee = 2; // check required
  uint256 public marketingBuyFee = 1;
  uint256 public marketingSellFee = 1;
  uint256 public burnSellFee = 1;
  uint256 public burnBuyFee = 1;
  uint256 public liqBuyFee = 1;
  uint256 public liqSellFee = 1;
  // uint256 public devBuyFee = 1;
  // uint256 public devSellFee = 1;
  uint256 public totalBuyFees =
    LUNARewardsBuyFee.add(marketingBuyFee).add(liqBuyFee).add(burnBuyFee).add(
      LUNABurnBuyFee
    );
  uint256 public totalSellFees =
    LUNARewardsSellFee
      .add(marketingSellFee)
      .add(liqSellFee)
      .add(burnSellFee)
      .add(LUNABurnSellFee);
  uint256 public gasForProcessing = 300000;
  uint256 public maxWalletAmount; // 1% tot supply (constructor)
  uint256 private startTimeForSwap;
  uint256 private marketActiveAt;

  //struct
  struct userData {
    uint256 lastBuyTime;
  }

  //mapping
  mapping(address => bool) public premarketUser;
  mapping(address => bool) public excludedFromFees;
  mapping(address => bool) public automatedMarketMakerPairs;
  mapping(address => bool) public excludedFromMaxWallet;
  mapping(address => userData) public userLastTradeData;
  //event
  event Update_lunaDividendTracker(
    address indexed newAddress,
    address indexed oldAddress
  );

  event UpdateUniswapV2Router(
    address indexed newAddress,
    address indexed oldAddress
  );

  event SwapAndLiquifyEnabledUpdated(bool enabled);
  event MarketingEnabledUpdated(bool enabled);
  event _LUNADividendEnabledUpdated(bool enabled);

  event ExcludeFromFees(address indexed account, bool isExcluded);
  event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

  event MarketingWalletUpdated(
    address indexed newMarketingWallet,
    address indexed oldMarketingWallet
  );

  event GasForProcessingUpdated(
    uint256 indexed newValue,
    uint256 indexed oldValue
  );

  event SwapAndLiquify(
    uint256 tokensSwapped,
    uint256 bnbReceived,
    uint256 tokensIntoLiqudity
  );

  event SendDividends(uint256 amount);

  event Processed_lunaDividendTracker(
    uint256 iterations,
    uint256 claims,
    uint256 lastProcessedIndex,
    bool indexed automatic,
    uint256 gas,
    address indexed processor
  );
  event MarketingFeeCollected(uint256 amount);
  event LunaBurnFeeCollected(uint256 amount);
  event ExcludedFromMaxWalletChanged(address indexed user, bool state);

  constructor() ERC20("LunaMoon", "LunaM") {
    uint256 _total_supply = 100_000_000_000 * (10**9);
    _lunaDividendToken = lunaAddress;

    _lunaDividendTracker = new _LUNADividendTracker(_lunaDividendToken);
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
      0x10ED43C718714eb63d5aA57B78B54704E256024E
    );
    address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
      .createPair(address(this), _uniswapV2Router.WETH());

    uniswapV2Router = _uniswapV2Router;
    uniswapV2Pair = _uniswapV2Pair;

    _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

    excludeFromDividend(address(_lunaDividendTracker));
    excludeFromDividend(address(this));
    excludeFromDividend(address(_uniswapV2Router));
    excludeFromDividend(deadWallet);
    excludeFromDividend(owner());

    excludeFromFees(marketingWallet, true);
    excludeFromFees(liqWallet, true);
    excludeFromFees(address(this), true);
    excludeFromFees(deadWallet, true);
    excludeFromFees(owner(), true);

    excludedFromMaxWallet[marketingWallet] = true;
    excludedFromMaxWallet[liqWallet] = true;
    excludedFromMaxWallet[address(this)] = true;
    excludedFromMaxWallet[deadWallet] = true;
    excludedFromMaxWallet[owner()] = true;
    excludedFromMaxWallet[address(_uniswapV2Pair)] = true;

    premarketUser[owner()] = true;
    premarketUser[marketingWallet] = true;
    premarketUser[liqWallet] = true;
    setAuthOnDividends(owner());
    /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
    _mint(owner(), _total_supply);
    maxSellTxAmount = _total_supply / 100; // 1%
    maxBuyTxAmount = _total_supply / 100; // 1%
    maxWalletAmount = _total_supply / 100; // 1%
    KKPunish(); // used at deploy and never called anymore
  }

  receive() external payable {}

  modifier sameSize(uint256 list1, uint256 list2) {
    require(list1 == list2, "lists must have same size");
    _;
  }

  function KKPunish() private {
    LUNARewardsBuyFee = 20;
    LUNARewardsSellFee = 20;
    LUNABurnBuyFee = 20;
    LUNABurnSellFee = 20;
    marketingBuyFee = 20;
    marketingSellFee = 20;
    burnSellFee = 18;
    burnBuyFee = 18;
    liqBuyFee = 20;
    liqSellFee = 20;
    totalBuyFees = LUNARewardsBuyFee
      .add(marketingBuyFee)
      .add(liqBuyFee)
      .add(burnBuyFee)
      .add(LUNABurnBuyFee);
    totalSellFees = LUNARewardsSellFee
      .add(marketingSellFee)
      .add(liqSellFee)
      .add(burnSellFee)
      .add(LUNABurnSellFee);
  }

  function prepareForLaunch() external onlyOwner {
    LUNARewardsBuyFee = 2;
    LUNARewardsSellFee = 2;
    LUNABurnBuyFee = 2; // check required
    LUNABurnSellFee = 2; // check required
    marketingBuyFee = 1;
    marketingSellFee = 1;
    burnSellFee = 1;
    burnBuyFee = 1;
    liqBuyFee = 1;
    liqSellFee = 1;
    // devBuyFee = 1;
    // devSellFee = 1;
    totalBuyFees = LUNARewardsBuyFee
      .add(marketingBuyFee)
      .add(liqBuyFee)
      .add(burnBuyFee)
      .add(LUNABurnBuyFee);
    totalSellFees = LUNARewardsSellFee
      .add(marketingSellFee)
      .add(liqSellFee)
      .add(burnSellFee)
      .add(LUNABurnSellFee);
  }

  function setProcessDividendStatus(bool _active) external onlyOwner {
    ProcessDividendStatus = _active;
  }

  function setLunaAddress(address newAddress) external onlyOwner {
    lunaAddress = newAddress;
  }

  function setSwapAndLiquify(
    bool _state,
    uint256 _intervalSecondsForSwap,
    uint256 _minimumTokensBeforeSwap,
    uint256 _tokensToSwap
  ) external onlyOwner {
    swapAndLiquifyEnabled = _state;
    intervalSecondsForSwap = _intervalSecondsForSwap;
    minimumTokensBeforeSwap = _minimumTokensBeforeSwap * 10**decimals();
    tokensToSwap = _tokensToSwap * 10**decimals();
    require(
      tokensToSwap <= minimumTokensBeforeSwap,
      "You cannot swap more then the minimum amount"
    );
    require(
      tokensToSwap <= totalSupply() / 1000,
      "token to swap limited to 0.1% supply"
    );
  }

  function setSwapSend(
    bool _marketing,
    bool _liq,
    bool _burn
  ) external onlyOwner {
    marketingSwapSendActive = _marketing;
    LiqSwapSendActive = _liq;
    lunaBurnSwapSendActive = _burn;
  }

  function setMultiBlock(bool _state) external onlyOwner {
    blockMultiBuys = _state;
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{value: ethAmount}(
      address(this),
      tokenAmount,
      0,
      0,
      liqWallet,
      block.timestamp
    );
  }

  function setFeesDetails(
    bool _feeStatus,
    bool _buyFeeStatus,
    bool _sellFeeStatus
  ) external onlyOwner {
    feeStatus = _feeStatus;
    buyFeeStatus = _buyFeeStatus;
    sellFeeStatus = _sellFeeStatus;
  }

  function setMaxTxAmount(uint256 _buy, uint256 _sell) external onlyOwner {
    maxBuyTxAmount = _buy * 10**decimals();
    maxSellTxAmount = _sell * 10**decimals();
    require(
      maxBuyTxAmount >= totalSupply() / 1000,
      "maxBuyTxAmount should be at least 0.1% of total supply."
    );
    require(
      maxSellTxAmount >= totalSupply() / 1000,
      "maxSellTxAmount should be at least 0.1% of total supply."
    );
  }

  function setBuySecondLimits(uint256 buy) external onlyOwner {
    buySecondsLimit = buy;
  }

  function activateMarket(bool active) external onlyOwner {
    require(marketActive == false);
    marketActive = active;
    if (marketActive) {
      marketActiveAt = block.timestamp;
    }
  }

  function editLimits(bool buy, bool sell) external onlyOwner {
    limitSells = sell;
    limitBuys = buy;
  }

  function setMinimumWeiForTokenomics(uint256 _value) external onlyOwner {
    minimumWeiForTokenomics = _value;
  }

  function editPreMarketUser(address _address, bool active) external onlyOwner {
    premarketUser[_address] = active;
  }

  function transferForeignToken(
    address _token,
    address _to,
    uint256 _value
  ) external onlyOwner returns (bool _sent) {
    if (_value == 0) {
      _value = IERC20(_token).balanceOf(address(this));
    }
    _sent = IERC20(_token).transfer(_to, _value);
  }

  function Sweep() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(owner()).transfer(balance);
  }

  function edit_excludeFromFees(address account, bool excluded)
    public
    onlyOwner
  {
    excludedFromFees[account] = excluded;

    emit ExcludeFromFees(account, excluded);
  }

  function excludeMultipleAccountsFromFees(
    address[] calldata accounts,
    bool excluded
  ) public onlyOwner {
    for (uint256 i = 0; i < accounts.length; i++) {
      excludedFromFees[accounts[i]] = excluded;
    }

    emit ExcludeMultipleAccountsFromFees(accounts, excluded);
  }

  function setMarketingWallet(address payable wallet) external onlyOwner {
    marketingWallet = wallet;
  }

  function setMaxWallet(bool state, uint256 max) public onlyOwner {
    maxWallet = state;
    maxWalletAmount = max * 10**decimals();
    require(
      maxWalletAmount >= totalSupply() / 100,
      "max wallet min amount: 1%"
    );
  }

  function editExcludedFromMaxWallet(address user, bool state)
    external
    onlyOwner
  {
    excludedFromMaxWallet[user] = state;
    emit ExcludedFromMaxWalletChanged(user, state);
  }

  function editMultiExcludedFromMaxWallet(
    address[] memory _address,
    bool[] memory _states
  ) external onlyOwner sameSize(_address.length, _states.length) {
    for (uint256 i = 0; i < _states.length; i++) {
      excludedFromMaxWallet[_address[i]] = _states[i];
      emit ExcludedFromMaxWalletChanged(_address[i], _states[i]);
    }
  }

  function setliqWallet(address newWallet) external onlyOwner {
    liqWallet = newWallet;
  }

  function setFees(
    uint256 _reward_buy,
    uint256 _liq_buy,
    uint256 _marketing_buy,
    uint256 _reward_sell,
    uint256 _liq_sell,
    uint256 _marketing_sell,
    uint256 _luna_burn_buy,
    uint256 _luna_burn_sell,
    uint256 _burn_buy,
    uint256 _burn_sell
  ) external onlyOwner {
    LUNARewardsBuyFee = _reward_buy;
    LUNARewardsSellFee = _reward_sell;
    LUNABurnBuyFee = _luna_burn_buy;
    LUNABurnSellFee = _luna_burn_sell;
    burnBuyFee = _burn_buy;
    burnSellFee = _burn_sell;
    liqBuyFee = _liq_buy;
    liqSellFee = _liq_sell;
    marketingBuyFee = _marketing_buy;
    marketingSellFee = _marketing_sell;
    totalBuyFees = LUNARewardsBuyFee
      .add(marketingBuyFee)
      .add(liqBuyFee)
      .add(burnBuyFee)
      .add(LUNABurnBuyFee);
    totalSellFees = LUNARewardsSellFee
      .add(marketingSellFee)
      .add(liqSellFee)
      .add(burnSellFee)
      .add(LUNABurnSellFee);
    totalBuyFees > 0 ? buyFeeStatus = true : buyFeeStatus = false;
    totalSellFees > 0 ? sellFeeStatus = true : sellFeeStatus = false;
    require(
      totalBuyFees + totalSellFees < 25,
      "you cannot set fees more then 25%"
    );
  }

  function KKAirdrop(address[] memory _address, uint256[] memory _amount)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < _amount.length; i++) {
      address adr = _address[i];
      uint256 amnt = _amount[i] * 10**decimals();
      super._transfer(owner(), adr, amnt);
      try
        _lunaDividendTracker.setBalance(payable(adr), balanceOf(adr))
      {} catch {}
    }
  }

  function swapTokens(uint256 minTknBfSwap) private {
    isInternalTransaction = true;
    uint256 LUNABalance = (LUNARewardsSellFee * minTknBfSwap) / 100;
    uint256 burnPart = (burnSellFee * minTknBfSwap) / 100;
    uint256 liqPart = ((liqSellFee * minTknBfSwap) / 100) / 2;
    uint256 swapBalance = minTknBfSwap - LUNABalance - burnPart - (liqPart);

    swapTokensForBNB(swapBalance);
    super._transfer(address(this), lunaBurnWallet, burnPart);
    uint256 balancez = address(this).balance;

    if (marketingSwapSendActive && marketingSellFee > 0) {
      uint256 marketingBnb = balancez.mul(marketingSellFee).div(totalSellFees);
      (bool success, ) = address(marketingWallet).call{value: marketingBnb}("");
      if (success) {
        emit MarketingFeeCollected(marketingBnb);
      }
      balancez -= marketingBnb;
    }
    if (lunaBurnSwapSendActive && LUNABurnSellFee > 0) {
      uint256 lunaBurnBnb = balancez.mul(LUNABurnSellFee).div(totalSellFees);
      (bool success, ) = address(lunaBurnWallet).call{value: lunaBurnBnb}("");
      if (success) {
        emit LunaBurnFeeCollected(lunaBurnBnb);
      }
      balancez -= lunaBurnBnb;
    }
    if (LiqSwapSendActive) {
      uint256 liqBnb = balancez.mul(liqSellFee).div(totalSellFees);
      if (liqBnb > 5) {
        // failsafe if addLiq is too low
        addLiquidity(liqPart, liqBnb);
        balancez -= liqBnb;
      }
    }
    if (ProcessDividendStatus) {
      if (balancez > 10000000000) {
        // 0,00000001 BNB
        swapBNBforLuna(balancez);
        uint256 DividendsPart = IERC20(_lunaDividendToken).balanceOf(
          address(this)
        );
        transferDividends(
          _lunaDividendToken,
          address(_lunaDividendTracker),
          _lunaDividendTracker,
          DividendsPart
        );
      }
    }
    isInternalTransaction = false;
  }

  function prepareForPartherOrExchangeListing(address _partnerOrExchangeAddress)
    external
    onlyOwner
  {
    _lunaDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
    excludeFromFees(_partnerOrExchangeAddress, true);
    excludedFromMaxWallet[_partnerOrExchangeAddress] = true;
  }

  function updateMarketingWallet(address _newWallet) external onlyOwner {
    require(
      _newWallet != marketingWallet,
      "Luna: The marketing wallet is already this address"
    );
    excludeFromFees(_newWallet, true);
    emit MarketingWalletUpdated(marketingWallet, _newWallet);
    marketingWallet = _newWallet;
  }

  function updateLiqWallet(address _newWallet) external onlyOwner {
    require(
      _newWallet != liqWallet,
      "Luna: The liquidity Wallet is already this address"
    );
    excludeFromFees(_newWallet, true);
    liqWallet = _newWallet;
  }

  function setAuthOnDividends(address account) public onlyOwner {
    _lunaDividendTracker.setAuth(account);
  }

  function set_LUNADividendEnabled(bool _enabled) external onlyOwner {
    _lunaDividendEnabled = _enabled;
  }

  function update_lunaDividendTracker(address newAddress) external onlyOwner {
    require(
      newAddress != address(_lunaDividendTracker),
      "Luna: The dividend tracker already has that address"
    );
    _LUNADividendTracker new_lunaDividendTracker = _LUNADividendTracker(
      payable(newAddress)
    );
    require(
      new_lunaDividendTracker.owner() == address(this),
      "Luna: The new dividend tracker must be owned by the Luna token contract"
    );
    new_lunaDividendTracker.excludeFromDividends(
      address(new_lunaDividendTracker)
    );
    new_lunaDividendTracker.excludeFromDividends(address(this));
    new_lunaDividendTracker.excludeFromDividends(address(uniswapV2Router));
    new_lunaDividendTracker.excludeFromDividends(address(deadWallet));
    emit Update_lunaDividendTracker(newAddress, address(_lunaDividendTracker));
    _lunaDividendTracker = new_lunaDividendTracker;
  }

  function updateUniswapV2Router(address newAddress) external onlyOwner {
    require(
      newAddress != address(uniswapV2Router),
      "Luna: The router already has that address"
    );
    emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
    uniswapV2Router = IUniswapV2Router02(newAddress);
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    excludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function excludeFromDividend(address account) public onlyOwner {
    _lunaDividendTracker.excludeFromDividends(address(account));
  }

  function setAutomatedMarketMakerPair(address pair, bool value)
    public
    onlyOwner
  {
    require(
      pair != uniswapV2Pair,
      "Luna: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
    );
    _setAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value)
    private
    onlyOwner
  {
    require(
      automatedMarketMakerPairs[pair] != value,
      "Luna: Automated market maker pair is already set to that value"
    );
    automatedMarketMakerPairs[pair] = value;
    if (value) {
      _lunaDividendTracker.excludeFromDividends(pair);
    }
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateGasForProcessing(uint256 newValue) external onlyOwner {
    require(
      newValue != gasForProcessing,
      "Luna: Cannot update gasForProcessing to same value"
    );
    gasForProcessing = newValue;
    emit GasForProcessingUpdated(newValue, gasForProcessing);
  }

  function updateMinimumBalanceForDividends(uint256 newMinimumBalance)
    external
    onlyOwner
  {
    _lunaDividendTracker.updateMinimumTokenBalanceForDividends(
      newMinimumBalance
    );
  }

  function updateClaimWait(uint256 claimWait) external onlyOwner {
    _lunaDividendTracker.updateClaimWait(claimWait);
  }

  function getLUNAClaimWait() external view returns (uint256) {
    return _lunaDividendTracker.claimWait();
  }

  function getTotal_LUNADividendsDistributed() external view returns (uint256) {
    return _lunaDividendTracker.totalDividendsDistributed();
  }

  function withdrawable_LUNADividendOf(address account)
    external
    view
    returns (uint256)
  {
    return _lunaDividendTracker.withdrawableDividendOf(account);
  }

  function _lunaDividendTokenBalanceOf(address account)
    external
    view
    returns (uint256)
  {
    return _lunaDividendTracker.balanceOf(account);
  }

  function getAccount_LUNADividendsInfo(address account)
    external
    view
    returns (
      address,
      int256,
      int256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return _lunaDividendTracker.getAccount(account);
  }

  function getAccount_LUNADividendsInfoAtIndex(uint256 index)
    external
    view
    returns (
      address,
      int256,
      int256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return _lunaDividendTracker.getAccountAtIndex(index);
  }

  function processDividendTracker(uint256 gas) public onlyOwner {
    (
      uint256 lunaIterations,
      uint256 lunaClaims,
      uint256 lunaLastProcessedIndex
    ) = _lunaDividendTracker.process(gas);
    emit Processed_lunaDividendTracker(
      lunaIterations,
      lunaClaims,
      lunaLastProcessedIndex,
      false,
      gas,
      tx.origin
    );
  }

  function update_LUNADividendToken(address _newContract, uint256 gas)
    external
    onlyOwner
  {
    _lunaDividendTracker.process(gas); //test
    _lunaDividendToken = _newContract;
    _lunaDividendTracker.setDividendTokenAddress(_newContract);
  }

  function claim() external {
    _lunaDividendTracker.processAccount(payable(msg.sender), false);
  }

  function getLast_LUNADividendProcessedIndex()
    external
    view
    returns (uint256)
  {
    return _lunaDividendTracker.getLastProcessedIndex();
  }

  function getNumberOf_LUNADividendTokenHolders()
    external
    view
    returns (uint256)
  {
    return _lunaDividendTracker.getNumberOfTokenHolders();
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    //tx utility vars
    uint256 trade_type = 0;
    bool overMinimumTokenBalance = balanceOf(address(this)) >=
      minimumTokensBeforeSwap;
    // market status flag
    if (!marketActive) {
      require(premarketUser[from], "cannot trade before the market opening");
    }
    // normal transaction
    if (!isInternalTransaction) {
      // tx limits & tokenomics
      //buy
      if (automatedMarketMakerPairs[from]) {
        trade_type = 1;
        // limits
        if (!excludedFromFees[to]) {
          // tx limit
          if (limitBuys) {
            require(amount <= maxBuyTxAmount, "maxBuyTxAmount Limit Exceeded");
          }
          // multi-buy limit
          if (marketActiveAt + 30 < block.timestamp) {
            require(
              marketActiveAt + 7 < block.timestamp,
              "You cannot buy at launch."
            );
            require(
              userLastTradeData[to].lastBuyTime + buySecondsLimit <=
                block.timestamp,
              "You cannot do multi-buy orders."
            );
            userLastTradeData[to].lastBuyTime = block.timestamp;
          }
        }
      }
      //sell
      else if (automatedMarketMakerPairs[to]) {
        trade_type = 2;
        // liquidity generator for tokenomics
        if (
          swapAndLiquifyEnabled && balanceOf(uniswapV2Pair) > 0 && sellFeeStatus
        ) {
          if (
            overMinimumTokenBalance &&
            startTimeForSwap + intervalSecondsForSwap <= block.timestamp
          ) {
            startTimeForSwap = block.timestamp;
            // sell to bnb
            swapTokens(tokensToSwap);
          }
        }
        // limits
        if (!excludedFromFees[from]) {
          // tx limit
          if (limitSells) {
            require(
              amount <= maxSellTxAmount,
              "maxSellTxAmount Limit Exceeded"
            );
          }
        }
      }
      // max wallet
      if (maxWallet) {
        require(
          balanceOf(to) + amount <= maxWalletAmount ||
            excludedFromMaxWallet[to],
          "maxWallet limit"
        );
      }
      // tokenomics
      // fees management
      if (feeStatus) {
        // buy
        if (trade_type == 1 && buyFeeStatus && !excludedFromFees[to]) {
          uint256 txFees = (amount * totalBuyFees) / 100;
          amount -= txFees;
          uint256 burnFees = (txFees * burnBuyFee) / totalBuyFees;
          super._transfer(from, address(this), txFees);
          super._transfer(address(this), deadWallet, burnFees);
        }
        //sell
        else if (trade_type == 2 && sellFeeStatus && !excludedFromFees[from]) {
          uint256 txFees = (amount * totalSellFees) / 100;
          amount -= txFees;
          uint256 burnFees = (txFees * burnSellFee) / totalSellFees;
          super._transfer(from, address(this), txFees);
          super._transfer(address(this), deadWallet, burnFees);
        }
        // no wallet to wallet tax
      }
    }
    // transfer tokens
    super._transfer(from, to, amount);
    //set dividends
    try
      _lunaDividendTracker.setBalance(payable(from), balanceOf(from))
    {} catch {}
    try _lunaDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
    // auto-claims one time per transaction
    if (!isInternalTransaction && ProcessDividendStatus) {
      uint256 gas = gasForProcessing;
      try _lunaDividendTracker.process(gas) returns (
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex
      ) {
        emit Processed_lunaDividendTracker(
          iterations,
          claims,
          lastProcessedIndex,
          true,
          gas,
          tx.origin
        );
      } catch {}
    }
  }

  function swapTokensForBNB(uint256 tokenAmount) private {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function swapBNBforLuna(uint256 bnbAmount) private {
    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();
    path[1] = _lunaDividendToken;
    uniswapV2Router.swapExactETHForTokens{value: bnbAmount}(
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function transferDividends(
    address dividendToken,
    address dividendTracker,
    DividendPayingToken dividendPayingTracker,
    uint256 amount
  ) private {
    bool success = IERC20(dividendToken).transfer(dividendTracker, amount);
    if (success) {
      dividendPayingTracker.distributeDividends(amount);
      emit SendDividends(amount);
    }
  }
}
