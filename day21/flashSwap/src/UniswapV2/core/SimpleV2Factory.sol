// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimpleV2Pair.sol";

/**
 * @title SimpleV2Factory
 * @dev 简化版本的Uniswap V2工厂合约，用于创建交易对
 */
contract SimpleV2Factory {
    // 存储所有交易对的映射 tokenA => tokenB => pair地址
    mapping(address => mapping(address => address)) public getPair;
    
    // 存储所有交易对地址的数组
    address[] public allPairs;

    // 事件：交易对创建
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 length
    );

    /**
     * @dev 获取所有交易对的数量
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev 创建新的交易对
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return pair 新创建的交易对地址
     */
    function createPair(address tokenA, address tokenB)
        external returns (address pair) {
        require(tokenA != tokenB, "SimpleV2: IDENTICAL_ADDRESSES");
        
        // 按地址大小排序，确保token0 < token1
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SimpleV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "SimpleV2: PAIR_EXISTS");

        // 使用CREATE2部署交易对合约，确保地址可预测
        bytes memory bytecode = type(SimpleV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // 初始化交易对
        SimpleV2Pair(pair).initialize(token0, token1);
        
        // 更新映射和数组
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 反向映射
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
} 