// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

interface IPancakeMasterChef {

    function CAKE() external view returns (address);
    
    function lpToken(uint256 _pid) external view returns (address);
    
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function enterStaking(uint256 _amount) external;

    function leaveStaking(uint256 _amount) external;

    function pendingCake(uint256 _pid, address _user) external view returns (uint256);

    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    function emergencyWithdraw(uint256 _pid) external;
}