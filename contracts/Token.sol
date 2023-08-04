//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract Token is
  ERC20,
  ERC20Burnable,
  AccessControlEnumerable,
  Ownable,
  ReentrancyGuard
{
  using SafeMath for uint256;
  IERC20 public tokenUSDT;

  // Max supply of PMT token
  uint256 public MAX_SUPPLY = 200000000;
  uint256 public MAX_PRIVATE_SALE = 50000000;
  uint256 public UNLOCK_TIME = 12312312312;
  uint256 private _totalPrivateSale = 0;
  // End time of private sale 20/3/2024
  uint256 endTime = 1710892800;

  mapping(address => bool) public leaders;
  mapping(address => address) public refInfo;
  mapping(address => uint256) public lockToken;
  mapping(uint256 => uint256) public packages;
  mapping(address => uint256) public commissionToken;
  uint256[3] public commissions = [3, 2, 1]; // 0.3, 0.2, 0.1
  uint256 public commissionDecimal = 1000;

  modifier notContract() {
    require(!_isContract(msg.sender), 'Contract not allowed');
    require(msg.sender == tx.origin, 'Proxy contract not allowed');
    _;
  }

  event BuyPrivateSale(address indexed buyer, uint256 amount, address referral);
  event ChangeCommission(address indexed leader, uint256 amount);
  event WithdrawCommission(address indexed leader, uint256 amount);
  event AddLeader(address indexed leader);
  event RemoveLeader(address indexed leader);

  /**
   * initialize function
   * @param _usdtAddress is usdt address
   */
  constructor(address _usdtAddress) ERC20('Pharmatech Token', 'PMT') {
    require(_usdtAddress != address(0), 'invalid-USDT');
    tokenUSDT = IERC20(_usdtAddress);

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    packages[1000 * 10 ** 18] = 10000 * 10 ** 18;
    packages[5000 * 10 ** 18] = 51020 * 10 ** 18;
    packages[10000 * 10 ** 18] = 105263 * 10 ** 18;
  }

  /**
   * mint token, only admin can mint token
   * @param _to is address to receive token minted
   * @param _amount is amount of token minted
   */
  function mint(
    address _to,
    uint256 _amount
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_amount > 0, 'Mint: amount must greater than 0');
    require(
      totalSupply() + _amount <= MAX_SUPPLY,
      'Mint: total minted must less than max_supply'
    );

    _mint(_to, _amount);
  }

  /**
   * add leader
   * @param _leader is leader address
   */
  function addLeader(
    address _leader
  ) external notContract nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_leader != address(0), 'AddLeader: can not add address 0');
    leaders[_leader] = true;

    emit AddLeader(_leader);
  }

  /**
   * remove leader
   * @param _leader is leader address
   */
  function removeLeader(
    address _leader
  ) external notContract nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_leader != address(0), 'RemoveLeader: can not remove address 0');
    leaders[_leader] = false;

    emit RemoveLeader(_leader);
  }

  /**
   * buy private sale
   * @param _referral is referral address of leader
   * @param _amount is amount of package
   */
  function privateSale(
    address _referral,
    uint256 _amount
  ) external notContract nonReentrant {
    require(block.timestamp <= endTime, 'PrivateSale: ended');
    require(packages[_amount] != 0, 'PrivateSale: cann not find package');
    require(
      _totalPrivateSale + packages[_amount] <= MAX_PRIVATE_SALE,
      'PrivateSale: Reach max private sale'
    );
    require(leaders[_referral], 'PrivateSale: address is not leader');

    address _sender = _msgSender();
    refInfo[_sender] = _referral;

    // send token to this address
    tokenUSDT.transferFrom(_sender, address(this), _amount);

    // mint token to user address
    _mint(_sender, packages[_amount]);
    _totalPrivateSale += packages[_amount];

    // lock token
    lockToken[_sender] = packages[_amount];

    emit BuyPrivateSale(_sender, _amount, _referral);

    // share token to leader
    uint256 _maxLevel = commissions.length;

    for (uint256 i = 0; i < _maxLevel; i++) {
      address _parent = refInfo[_sender];

      if (_parent != address(0) && leaders[_parent] == true) {
        uint256 commission = _amount.div(commissionDecimal).mul(commissions[i]);
        commissionToken[_parent] += commission;
        emit ChangeCommission(_parent, commission);
      }
      _sender = _parent;
    }
  }

  /**
   * leader withdraw their commission
   */
  function leaderWithdraw() external notContract nonReentrant {
    address sender = _msgSender();

    require(leaders[sender], 'LeaderWithdraw: sender not leader');
    require(
      commissionToken[sender] > 0,
      'LeaderWithdraw: commission must greater than 0'
    );

    uint256 withdrawAmount = commissionToken[sender];
    // transfer token to leader
    tokenUSDT.transfer(sender, withdrawAmount);

    // reset commission
    commissionToken[sender] = 0;

    emit WithdrawCommission(sender, withdrawAmount);
  }

  /**
   * for withdraw immediately if there are some problems
   * @param _to is address receive token
   */
  function withdrawImmediately(
    address _to
  ) external notContract nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_to != address(0), 'Withdraw: transfer to null address');

    tokenUSDT.transfer(_to, balanceOf(address(this)));
  }

  /**
   * unlock token of user
   */
  function unlock() external notContract nonReentrant {
    uint256 currentTimestamp = block.timestamp;
    require(currentTimestamp >= UNLOCK_TIME, 'Not Unlock Time');
  }

  /**
   * get available balance of user
   * @param _wallet is user wallet
   */
  function getAvailableBalance(address _wallet) public view returns (uint256) {
    return balanceOf(_wallet).sub(lockToken[_wallet]);
  }

  /**
   * check before transfer
   * @param from from address
   * @param to is to address
   * @param amount is amount of transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    uint256 availableAmount = getAvailableBalance(from);
    require(availableAmount >= amount, 'Not Enough Available Token');

    super._beforeTokenTransfer(from, to, amount);
  }

  /**
   * @notice Check if an address is a contract
   */
  function _isContract(address _addr) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(_addr)
    }
    return size > 0;
  }
}