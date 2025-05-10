// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20_Extend} from "../src/NFTMarketExchange.sol";
import {ERC721_cna} from "../src/NFTMarketExchange.sol";
import {NFTMarket} from "../src/NFTMarketExchange.sol";

contract NFTMarketTest is Test {
    ERC20_Extend private token;
    ERC721_cna private nft;
    NFTMarket private market;

    address admin = address(0x9999);
    address user1 = address(0x123);
    address user2 = address(0x456);
    address user3 = address(0x789);

    uint256 tokenId1 = 0;
    uint256 tokenId2 = 0;
    uint256 tokenId3 = 0;

    function setUp() public {
        user1 = address(0x123);
        user2 = address(0x456);
        user3 = address(0x789);
        
         vm.startPrank(admin);
        // 1. 部署ERC20代币合约
        token = new ERC20_Extend(1000000 * 10**18);
        // 2. 部署ERC721 NFT合约
        nft = new ERC721_cna(admin);
        // 3. 部署NFT市场合约
        market = new NFTMarket(address(token), address(nft));
       
        // 4. 给多个用户分发代币
        token.transfer(user1, 1000 * 10**18);
        token.transfer(user2, 1000 * 10**18);
        token.transfer(user3, 1000 * 10**18);
        
        // 5. 为多个用户创建NFT
        tokenId1 = nft.awardItem(user1, "ipfs://test1");
        tokenId2 = nft.awardItem(user2, "ipfs://test2");
        tokenId3 = nft.awardItem(user3, "ipfs://test3");

         vm.stopPrank();
    }

    function test_run() external {
        
        // 6. 测试场景1: 用户1上架NFT
        vm.startPrank(user1);
        nft.approve(address(market), tokenId1);
        market.list(tokenId1, 100 * 10**18);
        vm.stopPrank();
        
        // 7. 测试场景2: 用户2购买NFT
        vm.startPrank(user2);
        token.approve(address(market), 100 * 10**18);
        market.buyNFT(tokenId1);
        // user2上架tokenId2
        nft.approve(address(market), tokenId2);
        market.list(tokenId2, 100 * 10**18);

        vm.stopPrank();


        
        // 8. 测试场景3: 用户3使用transferWithCallback购买NFT
        vm.startPrank(user3);
        bytes memory data = abi.encodeWithSelector(NFTMarket.buyNFT.selector, tokenId2);
        token.transferWithCallback(address(market), 100 * 10**18, data);
        // user3上架tokenId3
        nft.approve(address(market), tokenId3);
        market.list(tokenId3, 100 * 10**18);
        vm.stopPrank();

        // user1购买tokenId3
        vm.startPrank(user1);
        token.approve(address(market), 100 * 10**18);
        market.buyNFT(tokenId3);
        vm.stopPrank();

        console.log("user1 balanceOf: %d", token.balanceOf(user1));
        assertEq(token.balanceOf(user1), 1000 * 10**18);
    }

    function invariant_ERC20_balanceOf() external view {
        // 检查Erc20合约的余额是否正确
        assertEq(token.totalSupply(), 1000000 * 10**18);
    }
}