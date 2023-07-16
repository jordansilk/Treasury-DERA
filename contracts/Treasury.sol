// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Interface for ERC-20 tokens
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Treasury {
    
    mapping (address => uint256) reserves;

    function deposit(uint256 amount, address token) external {
        require(amount > 0, "Amount must be greater than 0");
        reserves[token] += amount;
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function withdraw(uint256 amount, address token) external {
        require(amount > 0, "Amount must be greater than 0");
        require(reserves[token] >= amount, "Insufficient token balance");
        reserves[token] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed");        
    }


}
