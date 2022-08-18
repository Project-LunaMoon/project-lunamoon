//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../ERC20/ERC20.sol";
import "./IDividendPayingToken.sol";
import "./IDividendPayingTokenOptional.sol";
import "../access/Ownable.sol";
import "../math/SafeMath.sol";
import "../math/SafeMathInt.sol";
import "../math/SafeMathUint.sol";

contract DividendPayingToken is
  ERC20,
  IDividendPayingToken,
  IDividendPayingTokenOptional,
  Ownable
{
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 internal constant magnitude = 2**128;

  uint256 internal magnifiedDividendPerShare;
  uint256 internal lastAmount;

  address public dividendToken;

  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping(address => bool) internal _isAuth;

  uint256 public totalDividendsDistributed;

  modifier onlyAuth() {
    require(_isAuth[msg.sender], "Auth: caller is not the authorized");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _token
  ) ERC20(_name, _symbol) {
    dividendToken = _token;
    _isAuth[msg.sender] = true;
  }

  function setAuth(address account) external onlyOwner {
    _isAuth[account] = true;
  }

  function distributeDividends(uint256 amount) public onlyOwner {
    require(totalSupply() > 0);

    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, amount);

      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }

  function withdrawDividend() public virtual override {
    _withdrawDividendOfUser(payable(msg.sender));
  }

  function setDividendTokenAddress(address newToken)
    external
    virtual
    onlyOwner
  {
    dividendToken = newToken;
  }

  function _withdrawDividendOfUser(address payable user)
    internal
    returns (uint256)
  {
    uint256 _withdrawableDividend = withdrawableDividendOf(user);
    if (_withdrawableDividend > 0) {
      withdrawnDividends[user] = withdrawnDividends[user].add(
        _withdrawableDividend
      );
      emit DividendWithdrawn(user, _withdrawableDividend);
      bool success = IERC20(dividendToken).transfer(
        user,
        _withdrawableDividend
      );

      if (!success) {
        withdrawnDividends[user] = withdrawnDividends[user].sub(
          _withdrawableDividend
        );
        return 0;
      }

      return _withdrawableDividend;
    }

    return 0;
  }

  function dividendOf(address _owner) public view override returns (uint256) {
    return withdrawableDividendOf(_owner);
  }

  function withdrawableDividendOf(address _owner)
    public
    view
    override
    returns (uint256)
  {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  function withdrawnDividendOf(address _owner)
    public
    view
    override
    returns (uint256)
  {
    return withdrawnDividends[_owner];
  }

  function accumulativeDividendOf(address _owner)
    public
    view
    override
    returns (uint256)
  {
    return
      magnifiedDividendPerShare
        .mul(balanceOf(_owner))
        .toInt256Safe()
        .add(magnifiedDividendCorrections[_owner])
        .toUint256Safe() / magnitude;
  }

  function _transfer(
    address from,
    address to,
    uint256 value
  ) internal virtual override {
    require(false);

    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(
      _magCorrection
    );
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(
      _magCorrection
    );
  }

  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[
      account
    ].sub((magnifiedDividendPerShare.mul(value)).toInt256Safe());
  }

  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[
      account
    ].add((magnifiedDividendPerShare.mul(value)).toInt256Safe());
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if (newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if (newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
}
