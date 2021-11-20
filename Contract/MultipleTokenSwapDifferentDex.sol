// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

interface IPancakePair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
}

contract TokenSwap {
    using SafeMath for uint;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    receive() external payable {}
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function sweep(address _tokenAddress) onlyOwner public {
        uint balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).transfer(msg.sender, balance);
    }
    
    // amountIn: (input amount in Wei)
    // path : (token addresses for swaps)  
    // pairs: (lp pairs from different DEX)
    // fees : (lp fee sample below)
    //     0.30% lp fee: 10000 - 30 = 9970
    //     0.20% lp fee: 10000 - 20 = 9980
    //     0.25% lp fee: 10000 - 25 = 9975
    
    // -- sample input 
    // Contract must have enough "Token1" for swap to execute
    // amountIn: 1000000000000000000
    // path: ['Token1', 'Token2', 'Token3', 'Token1']
    // pairs: [lp1, lp2, lp3]
    // fees:  [lp1_fee, lp2_fee, lp3_fee]
    function swap(uint amountIn, address[] calldata path, address[] calldata pairs, uint[] calldata fees) external {
        (uint[] memory amounts, bool[] memory loc) = getAmountsOut(amountIn, path, pairs, fees);
        IERC20(path[0]).transfer(pairs[0], amounts[0]);
        for (uint i; i < pairs.length; i++) {
            address to = i == pairs.length - 1 ? address(this) : pairs[i+1];
            (uint amount0Out, uint amount1Out) = loc[i] ? (uint(0), amounts[i+1]) : (amounts[i+1], uint(0));
            IPancakePair(pairs[i]).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    
    function getAmountsOut(uint amountIn, address[] memory path, address[] memory pair, uint[] memory fees) private view returns (uint[] memory amounts, bool[] memory loc) {
        uint112 reserveIn;
        uint112 reserveOut;
        amounts = new uint[](pair.length+1);
        loc     = new bool[](pair.length);
        amounts[0] = amountIn;
        for (uint i; i < pair.length; i++) {
            (reserveIn, reserveOut, loc[i]) = getReserves(pair[i], path[i], path[i+1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, fees[i]);
        }
        require(amounts[pair.length] > amounts[0], "arbitrage fail");
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint fee) private pure returns (uint amountOut) {
        require(amountIn > 0, 'PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(fee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
    
    function getReserves(address pairAddress, address tokenA, address tokenB) private view returns(uint112 reserveA, uint112 reserveB, bool loc) {  
        (address token0,) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint112 reserve0, uint112 reserve1,) = IPancakePair(pairAddress).getReserves();
        (reserveA, reserveB, loc) = tokenA  == token0 ? (reserve0, reserve1, true) : (reserve1, reserve0, false);
    }
    
}

