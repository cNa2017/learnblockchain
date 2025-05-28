// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleV2ERC20
 * @dev 简化的ERC20合约，用作流动性代币
 */
contract SimpleV2ERC20 {
    string public constant name = "SimpleV2";
    string public constant symbol = "SV2";
    uint8 public constant decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev 内部铸造函数
     */
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 内部销毁函数
     */
    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 批准代币转移
     */
    function approve(address spender, uint256 value)
        external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转移代币
     */
    function transfer(address to, uint256 value)
        external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 代理转移代币
     */
    function transferFrom(address from, address to, uint256 value)
        external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 内部转移函数
     */
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
} 