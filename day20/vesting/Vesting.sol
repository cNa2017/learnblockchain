// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VestingToken
 * @dev 用于 Vesting 的 ERC20 代币合约
 */
contract VestingToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 100万代币

    constructor(address initialOwner) ERC20("VestingToken", "VT") Ownable(initialOwner) {
        _mint(initialOwner, INITIAL_SUPPLY);
    }

    /**
     * @dev 铸造新代币（仅限 owner）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币（仅限 owner）
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}

/**
 * @title Vesting
 * @dev 基于 OpenZeppelin VestingWallet 的代币释放合约
 * @notice 12个月 cliff + 24个月线性释放
 */
contract Vesting is VestingWallet {
    using SafeERC20 for IERC20;

    // 时间常量
    uint256 public constant CLIFF_DURATION = 365 days; // 12个月 cliff
    uint256 public constant VESTING_DURATION = 730 days; // 24个月线性释放
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 总共36个月

    // Vesting 代币地址
    address public immutable vestingToken;
    
    // 事件
    event VestingInitialized(address indexed beneficiary, address indexed token, uint256 amount);
    event TokensReleased(address indexed token, uint256 amount);

    /**
     * @dev 构造函数
     * @param beneficiary 受益人地址
     * @param token ERC20 代币地址
     */
    constructor(address beneficiary, address token) VestingWallet(beneficiary, uint64(block.timestamp + CLIFF_DURATION), uint64(VESTING_DURATION)) {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(token != address(0), "Token cannot be zero address");
        
        vestingToken = token;
        
        emit VestingInitialized(beneficiary, token, 0);
    }

    /**
     * @dev 重写释放计算逻辑以实现线性释放
     * @notice VestingWallet 自动处理 cliff 期，这里只需要实现线性释放逻辑
     * @param totalAllocation 总分配量
     * @param timestamp 当前时间戳
     * @return 应该释放的数量
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        }
        
        uint256 timeElapsed = timestamp - start();
        
        if (timeElapsed >= VESTING_DURATION) {
            // 释放完毕
            return totalAllocation;
        }
        
        // 线性释放计算
        return (totalAllocation * timeElapsed) / VESTING_DURATION;
    }

    /**
     * @dev 释放当前可用的代币给受益人
     * @return 释放的代币数量
     */
    function releaseVesting() external returns (uint256) {
        uint256 releasableAmount = releasable(vestingToken);
        require(releasableAmount > 0, "No tokens available for release");
        
        release(vestingToken);
        
        emit TokensReleased(vestingToken, releasableAmount);
        return releasableAmount;
    }

    /**
     * @dev 获取受益人地址
     * @return 受益人地址
     */
    function beneficiary() external view returns (address) {
        return owner();
    }

    /**
     * @dev 获取合约部署时间（实际的开始时间）
     * @return 合约部署时间戳
     */
    function getDeployTime() external view returns (uint256) {
        return start() - CLIFF_DURATION;
    }

    /**
     * @dev 获取 Cliff 结束时间（等于线性释放开始时间）
     * @return Cliff 结束时间戳
     */
    function getCliffEnd() external view returns (uint256) {
        return start();
    }

    /**
     * @dev 获取 Vesting 结束时间
     * @return Vesting 结束时间戳
     */
    function getVestingEnd() external view returns (uint256) {
        return start() + VESTING_DURATION;
    }

    /**
     * @dev 获取线性释放开始时间
     * @return 线性释放开始时间戳
     */
    function getStartTime() external view returns (uint256) {
        return start();
    }

    /**
     * @dev 获取已释放的代币数量
     * @param token 代币地址
     * @return 已释放的数量
     */
    function getReleasedAmount(address token) external view returns (uint256) {
        return released(token);
    }

    /**
     * @dev 获取合约持有的代币总量
     * @param token 代币地址
     * @return 代币总量
     */
    function getTotalBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev 紧急提取功能（仅限受益人，仅在特殊情况下使用）
     * @param token 代币地址
     * @param amount 提取数量
     */
    function emergencyWithdraw(address token, uint256 amount) external {
        require(msg.sender == owner(), "Only beneficiary can withdraw");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20(token).safeTransfer(owner(), amount);
    }
}
