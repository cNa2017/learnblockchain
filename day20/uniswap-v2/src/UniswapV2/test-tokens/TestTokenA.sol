// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestTokenA
 * @dev 用于测试的ERC20代币A
 */
contract TestTokenA is ERC20 {
    constructor() ERC20("Test Token A", "TKA") {
        // 预先铸造1000万枚代币给部署者
        _mint(msg.sender, 10_000_000 * 10**decimals());
    }

    /**
     * @dev 允许任何人铸造代币用于测试
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
} 