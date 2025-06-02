// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

/**
 * @title GovernanceTimelock
 * @dev 治理时间锁合约，继承自 OpenZeppelin TimelockController
 *      提案在执行前需要经过延迟期，提高安全性
 */
contract GovernanceTimelock is TimelockController {
    /**
     * @dev 构造函数
     * @param minDelay 最小延迟时间（秒）
     * @param proposers 提案者地址数组（通常是 Governor 合约）
     * @param executors 执行者地址数组（可以是任何人，设置为空数组表示任何人都可以执行）
     * @param admin 管理员地址（通常设置为 address(0) 表示没有管理员）
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) 
        TimelockController(minDelay, proposers, executors, admin) {}
} 