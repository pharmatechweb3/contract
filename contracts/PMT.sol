//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';

import "./ILock.sol";

contract PMT is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    address[] public lockAddress;

    constructor() ERC20('Pharmatech Token', 'PMT') {
        _mint(msg.sender, 200000000 ether);
    }

    function addLockContract(address _lockAddress) external onlyOwner {
        require(_lockAddress != address(0), "AddLockContract: lockAddress is null address");

        lockAddress.push(_lockAddress);
    }

    function removeLockContract(uint256 index) external onlyOwner {
        if (index >= lockAddress.length) return;

        for (uint i = index; i<lockAddress.length-1; i++){
            lockAddress[i] = lockAddress[i+1];
        }
        delete lockAddress[lockAddress.length-1];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override  {

        if (lockAddress.length > 0) {
            uint256 lockAmount;

            uint256 lockAddressLength = lockAddress.length;

            for (uint i = 0; i < lockAddressLength; i++) {
                ILock lock = ILock(lockAddress[i]);

                lockAmount += lock.getLockBalance(from);
            }

            uint256 availableAmount = balanceOf(from).sub(lockAmount);
            require(availableAmount >= amount, 'Transfer: Not enough available token');
        }
        
        super._beforeTokenTransfer(from, to, amount);
    }
}