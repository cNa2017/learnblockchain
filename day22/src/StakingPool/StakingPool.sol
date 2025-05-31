// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title KK Token接口
 */
interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title Staking接口
 */
interface IStaking {
    /**
     * @dev 质押ETH到合约
     */
    function stake() payable external;

    /**
     * @dev 赎回质押的ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external; 

    /**
     * @dev 领取KK Token收益
     */
    function claim() external;

    /**
     * @dev 获取质押的ETH数量
     * @param account 质押账户
     * @return 质押的ETH数量
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取待领取的KK Token收益
     * @param account 质押账户
     * @return 待领取的KK Token收益
     */
    function earned(address account) external view returns (uint256);
}

/**
 * @title StakingPool
 * @dev 质押池合约，允许用户质押ETH获得KK Token奖励
 */
contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    IToken public immutable rewardToken;
    
    // 每个区块产出的KK Token数量
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    // 全局状态
    uint256 public totalStaked;           // 总质押数量
    uint256 public lastUpdateBlock;       // 上次更新的区块号
    uint256 public rewardPerTokenStored;  // 每个代币的累积奖励
    
    // 用户状态
    mapping(address => uint256) public stakes;                    // 用户质押数量
    mapping(address => uint256) public userRewardPerTokenPaid;   // 用户已支付的每代币奖励
    mapping(address => uint256) public rewards;                  // 用户待领取奖励
    
    // 事件
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    /**
     * @dev 构造函数
     * @param _rewardToken KK Token合约地址
     */
    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = IToken(_rewardToken);
        lastUpdateBlock = block.number;
    }
    
    /**
     * @dev 更新奖励状态的修饰符
     * @param account 账户地址
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
    
    /**
     * @dev 计算每个代币的累积奖励
     * @return 每个代币的累积奖励
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        
        uint256 blocksPassed = block.number - lastUpdateBlock;
        uint256 totalReward = blocksPassed * REWARD_PER_BLOCK;
        
        return rewardPerTokenStored + (totalReward * 1e18) / totalStaked;
    }
    
    /**
     * @dev 计算用户当前可领取的奖励
     * @param account 用户地址
     * @return 可领取的奖励数量
     */
    function earned(address account) public view returns (uint256) {
        uint256 stakedAmount = stakes[account];
        uint256 rewardPerTokenDiff = rewardPerToken() - userRewardPerTokenPaid[account];
        
        return (stakedAmount * rewardPerTokenDiff) / 1e18 + rewards[account];
    }
    
    /**
     * @dev 质押ETH到合约
     */
    function stake() external payable updateReward(msg.sender) nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        stakes[msg.sender] += msg.value;
        totalStaked += msg.value;
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev 赎回质押的ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot unstake 0 ETH");
        require(stakes[msg.sender] >= amount, "Insufficient staked amount");
        
        stakes[msg.sender] -= amount;
        totalStaked -= amount;
        
        // 转移ETH给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取KK Token收益
     */
    function claim() external updateReward(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        rewards[msg.sender] = 0;
        rewardToken.mint(msg.sender, reward);
        
        emit RewardsClaimed(msg.sender, reward);
    }
    
    /**
     * @dev 获取质押的ETH数量
     * @param account 质押账户
     * @return 质押的ETH数量
     */
    function balanceOf(address account) external view returns (uint256) {
        return stakes[account];
    }
} 