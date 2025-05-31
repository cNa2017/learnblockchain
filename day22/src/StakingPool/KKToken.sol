// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title KK Token
 * @dev ERC20代币，用作质押奖励
 */
contract KKToken is ERC20, Ownable {
    
    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {}

    /**
     * @dev 铸造代币，只能由owner调用
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
} 