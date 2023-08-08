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
  ReentrancyGuard
{
  using SafeMath for uint256;

  struct Package {
    address buyer;
    uint256 amount;
    uint256 unlockTime;
    bool isUnlock;
  }

  uint256 public MAX_SUPPLY = 200000000 * 10 ** decimals();
  uint256 public MAX_PRIVATE_SALE = 50000000 * 10 ** decimals();
  uint256 public LOCK_DURATION = 15552000;
  uint256 public END_PRIVATE_SALE_TIME = 1710892800;

  mapping(address => bool) public leaders;
  mapping(address => address) public refInfo;
  mapping(address => uint256) public lockToken;
  mapping(uint256 => uint256) public packages;
  mapping(uint256 => Package) public packageHistory;
  mapping(address => uint256) public commissionToken;
  uint256[3] public commissions = [3, 2, 1]; // 0.3, 0.2, 0.1
  uint256 public commissionDecimal = 1000;
  uint256 public packageIndex = 1;
  IERC20 public tokenUSDT;

  uint256 private _totalPrivateSale = 0;

  modifier notContract() {
    require(!_isContract(msg.sender), 'Contract not allowed');
    require(msg.sender == tx.origin, 'Proxy contract not allowed');
    _;
  }

  modifier onlyLeader() {
    require(leaders[msg.sender], 'only leader');
    _;
  }

  event BuyPrivateSale(
    address indexed buyer,
    uint256 amount,
    address referral,
    uint256 index
  );
  event ChangeCommission(address indexed leader, uint256 amount);
  event WithdrawCommission(address indexed leader, uint256 amount);
  event AddLeader(address indexed leader, address indexed referral);
  event RemoveLeader(address indexed leader);
  event Unlock(uint256 packageIndex);

  /**
   * initialize function
   * @param _usdtAddress is usdt address
   */
  constructor(
    address _adminAddress,
    address _usdtAddress
  ) ERC20('Pharmatech Token', 'PMT') {
    require(_usdtAddress != address(0), 'invalid-USDT');
    tokenUSDT = IERC20(_usdtAddress);

    _grantRole(DEFAULT_ADMIN_ROLE, _adminAddress);
    leaders[_adminAddress] = true;

    packages[1000 * 10 ** decimals()] = 10000 * 10 ** decimals();
    packages[5000 * 10 ** decimals()] = 51020 * 10 ** decimals();
    packages[10000 * 10 ** decimals()] = 105263 * 10 ** decimals();
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
    address _leader,
    address _referral
  ) external notContract nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_leader != address(0), 'AddLeader: can not add address 0');
    leaders[_leader] = true;

    refInfo[_leader] = _referral;

    emit AddLeader(_leader, _referral);
  }

  /**
   * add sub leader
   * @param _subLeader is leader address
   */
  function addSubLeader(
    address _subLeader
  ) external notContract nonReentrant onlyLeader {
    leaders[_subLeader] = true;

    refInfo[_subLeader] = msg.sender;
    emit AddLeader(_subLeader, msg.sender);
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
    require(block.timestamp <= END_PRIVATE_SALE_TIME, 'PrivateSale: ended');
    require(packages[_amount] != 0, 'PrivateSale: cann not find package');
    require(
      _totalPrivateSale + packages[_amount] <= MAX_PRIVATE_SALE,
      'PrivateSale: Reach max private sale'
    );
    require(
      totalSupply() + _amount <= MAX_SUPPLY,
      'PrivateSale: Reach max supply'
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

    // add package history
    packageHistory[packageIndex] = Package(
      _sender,
      packages[_amount],
      block.timestamp + LOCK_DURATION,
      false
    );

    emit BuyPrivateSale(_sender, _amount, _referral, packageIndex);

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

    packageIndex++;
  }

  /**
   * leader withdraw their commission
   */
  function leaderWithdraw() external notContract nonReentrant onlyLeader {
    address sender = _msgSender();

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
  function unlock(uint256 index) external notContract nonReentrant {
    uint256 currentTimestamp = block.timestamp;
    address sender = _msgSender();

    Package storage package = packageHistory[index];

    require(sender == package.buyer, 'Unlock: not buyer');
    require(
      currentTimestamp >= package.unlockTime,
      'Unlock: not time to unlock yet'
    );
    require(package.isUnlock == false, 'Unlock: package already unlock');

    lockToken[sender] -= package.amount;

    package.isUnlock = true;

    emit Unlock(index);
  }

  /**
   * get available balance of user
   * @param _wallet is user wallet
   */
  function getAvailableBalance(address _wallet) public view returns (uint256) {
    return balanceOf(_wallet).sub(lockToken[_wallet]);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) public override returns (bool) {
    uint256 availableAmount = getAvailableBalance(_from);
    require(availableAmount >= _amount, 'Not Enough Available Token');

    return super.transferFrom(_from, _to, _amount);
  }

  function transfer(
    address _to,
    uint256 _amount
  ) public override returns (bool) {
    uint256 availableAmount = getAvailableBalance(_msgSender());
    require(availableAmount >= _amount, 'Not Enough Available Token');

    return super.transfer(_to, _amount);
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
