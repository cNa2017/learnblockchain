// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WETH
 * @dev Wrapped ETH合约，实现ETH和WETH的相互转换
 */
contract WETH is ERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Wrapped Ether", "WETH") {}

    /**
     * @dev 存入ETH，铸造等量WETH
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 提取ETH，销毁等量WETH
     * @param wad 要提取的数量
     */
    function withdraw(uint256 wad) public {
        require(balanceOf(msg.sender) >= wad, "WETH: INSUFFICIENT_BALANCE");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /**
     * @dev 接收ETH时自动转换为WETH
     */
    receive() external payable {
        deposit();
    }

    /**
     * @dev fallback函数，接收ETH
     */
    fallback() external payable {
        deposit();
    }
} 