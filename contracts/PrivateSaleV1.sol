//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./ILock.sol";

contract PrivateSaleV1 is ILock, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    
    enum PackageType {
        Basic,
        Medium,
        Premium
    }

    struct Package {
        uint256 index;
        PackageType packageType;
        address buyer;
        uint256 amount;
        uint256 unlockTime;
        bool isUnlock;
    }

    struct PackageInfo{
        uint256 price;
        PackageType packageType;
    }

    mapping (address => uint256) private _lock;
    mapping(uint256 => PackageInfo) public packages;
    mapping(uint256 => Package) public packageHistory;
    mapping(address => uint256[]) public userPackages;

    uint256 public packageIndex;
    IERC20 public immutable token;
    IERC20 public immutable tokenUsdt;
    address public immutable receiveAddress;
    uint256 public LOCK_DURATION = 600;
    bool public isLock;

    // event
    event Buy(address indexed buyer, uint256 amount, uint256 index);
    event Unlock(uint256 packageIndex);

    modifier notContract() {
        require(!_isContract(msg.sender), 'Contract not allowed');
        require(msg.sender == tx.origin, 'Proxy contract not allowed');
        _;
    }

    constructor(address _tokenAddress, address _tokenUsdtAddress, address _receiveAddress) {
        token = IERC20(_tokenAddress);
        tokenUsdt = IERC20(_tokenUsdtAddress);
        receiveAddress = _receiveAddress;
        isLock = false;

        packages[1000 * 10 ** 18] = PackageInfo(90, PackageType.Basic); // 0.090 USDT/PMT
        packages[5000 * 10 ** 18] = PackageInfo(85, PackageType.Medium); // 0.085 USDT/PMT
        packages[10000 * 10 ** 18] = PackageInfo(80, PackageType.Premium);// 0.080 USDT/PMT
    }

    /**
    * change sell status
    * @param _status is status
    */
    function changeSellStatus(bool _status) external onlyOwner {
        isLock = _status;
    }

    /**
    * buy private sale
    * @param _amount is amount of package
    */
    function buy(uint256 _amount) external notContract nonReentrant {
        require(isLock == false, 'PrivateSale: ended');
        require(packages[_amount].price != 0, 'PrivateSale: cann not find package');
        require(token.balanceOf(address(this)) >= _amount, "PrivateSaleV1: insufficient token balance");
        address _sender = _msgSender();

        PackageInfo memory _package = packages[_amount];

        // send token to this address
        tokenUsdt.transferFrom(_sender, receiveAddress, _amount);

        uint256 amount = _amount.mul(1000).div(_package.price);

        // mint token to user address
        token.transfer(_sender, amount);

        // lock token
        _lock[_sender] += amount;

        // add package history
        packageHistory[packageIndex] = Package(
            packageIndex,                       // package index
            _package.packageType,               // package type
            _sender,                            // buyer
            amount,                             // package
            block.timestamp + LOCK_DURATION,    // duration
            false                               // lock status
        );

        // push package index to userPackages
        userPackages[_sender].push(packageIndex);

        emit Buy(_sender, _amount, packageIndex);
        packageIndex++;
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

        _lock[sender] -= package.amount;

        package.isUnlock = true;

        emit Unlock(index);
    }

    /**
    * for withdraw immediately if there are some problems
    * @param _to is address receive token
    */
    function withdrawImmediately(address _to, uint256 _amount) external notContract nonReentrant onlyOwner {
        require(_to != address(0), "PrivateSaleV1: transfer to null address");
        require(_amount <= token.balanceOf(address(this)), "PrivateSaleV1: amount greater than token balance");

        token.transfer(_to, _amount);
    }


    function getUserPackageIndex() public view returns(uint256[] memory) {
        return userPackages[msg.sender];
    }

    /**
    * get lock balance
    * @param sender is sender
    */
    function getLockBalance(address sender) external view returns(uint256) {
        return _lock[sender];
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
