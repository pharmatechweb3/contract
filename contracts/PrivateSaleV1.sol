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
    
    struct Package {
        address buyer;
        uint256 amount;
        uint256 unlockTime;
        bool isUnlock;
    }

    mapping (address => uint256) private _lock;
    mapping(uint256 => uint256) public packages;
    mapping(uint256 => Package) public packageHistory;
    mapping(address => uint256[]) public userPackages;

    uint256 public packageIndex;
    IERC20 public immutable token;
    IERC20 public immutable tokenUsdt;
    address public immutable receiveAddress;
    uint256 public LOCK_DURATION = 15552000;
    bool public isLock;

    event Buy(
        address indexed buyer,
        uint256 amount,
        uint256 index
    );
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

        packages[1000 * 10 ** 18] = 10000 * 10 ** 18;
        packages[5000 * 10 ** 18] = 51020 * 10 ** 18;
        packages[10000 * 10 ** 18] = 105263 * 10 ** 18;
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
        require(packages[_amount] != 0, 'PrivateSale: cann not find package');
        require(token.balanceOf(address(this)) >= _amount, "PrivateSaleV1: insufficient token balance");
        address _sender = _msgSender();

        // send token to this address
        tokenUsdt.transferFrom(_sender, receiveAddress, _amount);

        // mint token to user address
        token.transfer(_sender, packages[_amount]);

        // lock token
        _lock[_sender] += packages[_amount];

        // add package history
        packageHistory[packageIndex] = Package(
            _sender,                            // buyer
            packages[_amount],                  // package
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
    function withdrawImmediately(address _to) external notContract nonReentrant onlyOwner{
        require(_to != address(0), 'Withdraw: transfer to null address');

        token.transfer(_to, token.balanceOf(address(this)));
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