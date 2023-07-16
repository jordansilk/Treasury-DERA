// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);      
}

interface IUniswapRouter {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface IAaveLendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external;
}

contract Treasury {
    
    struct protocol {
        uint256 weightRatio;
        address swapToken; // valid address incase of liquidity pool, zero address incase of yield pool
        uint256 amountInvested; 
    }

    address public owner;
    mapping (address => protocol) public protocols;    
    address[] public protocolList;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function addProtocol(address protocolAddress, uint256 weightRatio, address swapToken) external onlyOwner {
        require(protocolAddress != address(0), "Invalid protocol address");
        require(weightRatio > 0, "Invalid distribution ratio");
        protocols[protocolAddress] = protocol(weightRatio, swapToken, 0);
        protocolList.push(protocolAddress); 
    }

    function setDistributionRatio(address protocolAddress, uint256 newWeightRatio) external onlyOwner {
        require(protocolAddress != address(0), "Invalid protocol address");
        require(newWeightRatio > 0, "Invalid distribution ratio");
        protocols[protocolAddress].weightRatio = newWeightRatio;
    }

    function depositFunds(address stableCoin, uint256 amount) external {
        require(stableCoin != address(0), "Invalid stablecoin address");
        require(amount > 0, "Invalid deposit amount");

        require(IERC20(stableCoin).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Distribute the deposited stablecoin among the protocols
        for (uint256 i = 0; i < protocolList.length; i++) {
            address protocolAddress = protocolList[i];
            uint256 protocolRatio = protocols[protocolAddress].weightRatio;
            uint256 protocolAmount = (amount * protocolRatio) / 100;
            
            IERC20(stableCoin).approve(protocolAddress, protocolAmount);
            
            if (protocols[protocolAddress].swapToken != address(0)) {
                // Handle if the protocol is a liquidity pool and requires swapping
                // Swap stablecoin to the desired token
                address[] memory path = new address[](2);
                path[0] = stableCoin;
                path[1] = protocols[protocolAddress].swapToken; // Replace with the desired token address
                uint256[] memory amounts = IUniswapRouter(protocolAddress).swapExactTokensForTokens(protocolAmount, 0, path, address(this), block.timestamp);
                protocols[protocolAddress].amountInvested += amounts[amounts.length - 1];
            } else {
                // Handle if the protocol is a lending/borrowing protocol like Aave
                IAaveLendingPool(protocolAddress).deposit(stableCoin, protocolAmount, address(this), 0);
                protocols[protocolAddress].amountInvested += protocolAmount;
            }
        }
    }

    function withdrawFunds(address protocolAddress, address stableCoin, uint256 protocolAmount) external {
        require(stableCoin != address(0), "Invalid stablecoin address");
        require(protocolAmount > 0, "Invalid deposit amount");

        IERC20(protocols[protocolAddress].swapToken).approve(protocolAddress, protocolAmount);
        if (protocols[protocolAddress].swapToken != address(0)) {
                // Handle if the protocol is a liquidity pool and requires swapping
                address[] memory path = new address[](2);
                path[0] = protocols[protocolAddress].swapToken;
                path[1] = stableCoin;
                IUniswapRouter(protocolAddress).swapExactTokensForTokens(protocolAmount, 0, path, address(this), block.timestamp);
                protocols[protocolAddress].amountInvested -= protocolAmount;
            } else {
                // Handle if the protocol is a lending/borrowing protocol like Aave
                IAaveLendingPool(protocolAddress).withdraw(stableCoin, protocolAmount, address(this));
                protocols[protocolAddress].amountInvested -= protocolAmount;
            }
    }

    function calculateAggregateYield() external view returns (uint256) {
        uint256 aggregateYield = 0;

        for (uint256 i = 0; i < protocolList.length; i++) {
            address protocolAddress = protocolList[i];

            if (protocols[protocolAddress].swapToken != address(0)) {
                // Handle if the protocol is a liquidity pool
                // Calculate the yield of the pool and add to aggregateYield
            } else {
                // Handle if the protocol is a lending/borrowing protocol like Aave
                // Calculate the yield of the protocol and add to aggregateYield
            }
        }
        return aggregateYield;
    }

    function withdraw(uint256 amount, address token) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed");        
    }

}
