// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarketExchange.sol";

contract NFTMarketDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("user1PrivateKey");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署ERC20代币合约（初始供应量100万）
        ERC20_Extend token = new ERC20_Extend(1000000 * 10**18);
        console.log("ERC20_Extend address: %s", address(token));

        // 2. 部署ERC721 NFT合约（管理员为部署者）
        ERC721_cna nft = new ERC721_cna(msg.sender);
        console.log("ERC721_cna address: %s", address(nft));

        // 3. 部署NFT市场合约并传入代币和NFT地址
        NFTMarket market = new NFTMarket(address(token), address(nft));
        console.log("NFTMarket address: %s", address(market));

        vm.stopBroadcast();
    }
}