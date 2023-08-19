//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;


interface ILock {
    // get lock token of user
    function getLockBalance(address sender) external view returns(uint256);

}