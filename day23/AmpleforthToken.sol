// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AmpleforthToken
 * @dev 通缩型 rebase token，每年自动通缩 1%
 * @notice 这是一个教学合约，用于理解 rebase 机制
 */
contract AmpleforthToken is ERC20, Ownable, ReentrancyGuard {
    // 事件
    event Rebase(uint256 oldSupply, uint256 newSupply, uint256 timestamp);
    event RebaseScheduled(uint256 nextRebaseTime);

    // 常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 public constant REBASE_INTERVAL = 365 days; // 1年
    uint256 public constant DEFLATION_RATE = 99; // 99%，意味着1%通缩
    uint256 public constant RATE_DENOMINATOR = 100;

    // 状态变量
    uint256 public totalGons; // 内部余额单位
    uint256 public gonsPerFragment; // 每个代币对应的 gons 数量
    uint256 public lastRebaseTime; // 上次rebase时间
    uint256 public rebaseCount; // rebase次数

    // 用户的 gons 余额映射
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    /**
     * @dev 构造函数
     * @param _owner 合约拥有者地址
     */
    constructor(address _owner) ERC20("AmpleforthToken", "AMPL") Ownable(_owner) {
        // 初始化 gons 相关变量
        totalGons = INITIAL_SUPPLY * 10**24; // 使用更高精度
        gonsPerFragment = totalGons / INITIAL_SUPPLY;
        
        // 设置初始余额
        _gonBalances[_owner] = totalGons;
        
        // 设置初始rebase时间
        lastRebaseTime = block.timestamp;
        
        emit Transfer(address(0), _owner, INITIAL_SUPPLY);
        emit RebaseScheduled(lastRebaseTime + REBASE_INTERVAL);
    }

    /**
     * @dev 重写 totalSupply 函数，返回当前有效总供应量
     */
    function totalSupply() public view override returns (uint256) {
        return totalGons / gonsPerFragment;
    }

    /**
     * @dev 重写 balanceOf 函数，返回用户的有效余额
     * @param account 用户地址
     * @return 用户的代币余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _gonBalances[account] / gonsPerFragment;
    }

    /**
     * @dev 重写 transfer 函数
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        address sender = _msgSender();
        uint256 gonAmount = amount * gonsPerFragment;
        
        require(_gonBalances[sender] >= gonAmount, "ERC20: transfer amount exceeds balance");
        
        _gonBalances[sender] -= gonAmount;
        _gonBalances[to] += gonAmount;
        
        emit Transfer(sender, to, amount);
        return true;
    }

    /**
     * @dev 重写 transferFrom 函数
     * @param from 发送地址
     * @param to 接收地址
     * @param amount 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        uint256 currentAllowance = allowance(from, spender);
        
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        
        uint256 gonAmount = amount * gonsPerFragment;
        require(_gonBalances[from] >= gonAmount, "ERC20: transfer amount exceeds balance");
        
        _gonBalances[from] -= gonAmount;
        _gonBalances[to] += gonAmount;
        
        // 更新授权余额
        _allowedFragments[from][spender] = currentAllowance - amount;
        
        // 也更新父合约的授权映射以保持兼容性
        super._approve(from, spender, currentAllowance - amount);
        
        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @dev 重写 approve 函数
     * @param spender 被授权地址
     * @param amount 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        
        // 更新我们的内部授权映射
        _allowedFragments[owner][spender] = amount;
        
        // 也调用父合约的 approve 来确保兼容性
        super._approve(owner, spender, amount);
        
        return true;
    }

    /**
     * @dev 重写 allowance 函数
     * @param owner 拥有者地址
     * @param spender 被授权地址
     * @return 授权金额
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowedFragments[owner][spender];
    }

    /**
     * @dev 执行 rebase 操作，进行通缩
     * @notice 只有在满足时间条件时才能执行
     */
    function rebase() external nonReentrant returns (uint256) {
        require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, "Rebase: too early to rebase");
        
        uint256 oldSupply = totalSupply();
        
        // 通缩：减少 1%
        // 使用更精确的计算方法：gonsPerFragment 乘以 100/99
        gonsPerFragment = (gonsPerFragment * RATE_DENOMINATOR) / DEFLATION_RATE;
        
        uint256 newSupply = totalSupply();
        lastRebaseTime = block.timestamp;
        rebaseCount++;
        
        emit Rebase(oldSupply, newSupply, block.timestamp);
        emit RebaseScheduled(lastRebaseTime + REBASE_INTERVAL);
        
        return newSupply;
    }

    /**
     * @dev 检查是否可以执行 rebase
     * @return 是否可以 rebase
     */
    function canRebase() external view returns (bool) {
        return block.timestamp >= lastRebaseTime + REBASE_INTERVAL;
    }

    /**
     * @dev 获取下次 rebase 时间
     * @return 下次 rebase 的时间戳
     */
    function nextRebaseTime() external view returns (uint256) {
        return lastRebaseTime + REBASE_INTERVAL;
    }

    /**
     * @dev 获取距离下次 rebase 的剩余时间
     * @return 剩余秒数
     */
    function timeToNextRebase() external view returns (uint256) {
        uint256 nextTime = lastRebaseTime + REBASE_INTERVAL;
        if (block.timestamp >= nextTime) {
            return 0;
        }
        return nextTime - block.timestamp;
    }

    /**
     * @dev 获取用户的 gons 余额（用于调试）
     * @param account 用户地址
     * @return gons 余额
     */
    function gonBalanceOf(address account) external view returns (uint256) {
        return _gonBalances[account];
    }

    /**
     * @dev 获取当前的 gonsPerFragment 值（用于调试）
     * @return gonsPerFragment 值
     */
    function getGonsPerFragment() external view returns (uint256) {
        return gonsPerFragment;
    }

    /**
     * @dev 获取总 gons 数量（用于调试）
     * @return 总 gons 数量
     */
    function getTotalGons() external view returns (uint256) {
        return totalGons;
    }
} 