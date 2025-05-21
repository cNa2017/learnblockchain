// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {ERC20_Extend, ERC721_cna_upgradeable, NFTMarket_upgradeable, ERC721_cna_upgradeableV2, NFTMarket_upgradeableV2} from "../src/NFTMarketExchange_upgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketExchange_upgradeableMigrationTest is Test {
    // 合约实例
    ERC20_Extend public token;
    
    // NFT实现合约和代理
    ERC721_cna_upgradeable public nftImpl;
    ERC721_cna_upgradeable public nft;
    ERC721_cna_upgradeableV2 public nftImplV2;
    ERC721_cna_upgradeableV2 public nftV2;
    
    // 市场实现合约和代理
    NFTMarket_upgradeable public marketImpl;
    NFTMarket_upgradeable public market;
    NFTMarket_upgradeableV2 public marketImplV2;
    NFTMarket_upgradeableV2 public marketV2;
    
    // 测试地址
    address public owner;
    address public user1;
    address public user2;
    address public projectSigner;
    
    // NFT代理地址
    address public nftProxyAddress;
    // 市场代理地址
    address public marketProxyAddress;
    
    // NFT ID和元数据
    uint256[] public tokenIds;
    uint256[] public listedTokenIds;
    string[] public tokenURIs;
    uint256[] public tokenPrices;
    
    // 初始代币供应量
    uint256 public initialSupply = 1000 ether;
    
    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        projectSigner = makeAddr("projectSigner");
        
        // 准备NFT数据
        tokenURIs = new string[](5);
        tokenURIs[0] = "https://example.com/token/1";
        tokenURIs[1] = "https://example.com/token/2";
        tokenURIs[2] = "https://example.com/token/3";
        tokenURIs[3] = "https://example.com/token/4";
        tokenURIs[4] = "https://example.com/token/5";
        
        tokenPrices = new uint256[](5);
        tokenPrices[0] = 1 ether;
        tokenPrices[1] = 2 ether;
        tokenPrices[2] = 1.5 ether;
        tokenPrices[3] = 2.5 ether;
        tokenPrices[4] = 3 ether;
        
        vm.startPrank(owner);
        
        // 部署代币合约
        token = new ERC20_Extend(initialSupply);
        
        // 部署NFT实现合约
        nftImpl = new ERC721_cna_upgradeable();
        
        // 部署NFT代理
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeable.initialize.selector,
            "TestNFT",
            "TNFT",
            owner
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImpl),
            nftInitData
        );
        nftProxyAddress = address(nftProxy);
        nft = ERC721_cna_upgradeable(nftProxyAddress);
        
        // 部署市场实现合约
        marketImpl = new NFTMarket_upgradeable();
        
        // 部署市场代理
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeable.initialize.selector,
            address(token),
            nftProxyAddress
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketImpl),
            marketInitData
        );
        marketProxyAddress = address(marketProxy);
        market = NFTMarket_upgradeable(marketProxyAddress);
        
        // 为测试用户铸造代币
        token.transfer(user1, 100 ether);
        token.transfer(user2, 100 ether);
        
        vm.stopPrank();
    }
    
    function test_PreUpgradeNFTMintAndUpgrade() public {
        // 记录铸造的NFT IDs
        tokenIds = new uint256[](3);
        
        // 1. 测试升级前NFT铸造功能
        vm.startPrank(owner);
        
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = nft.awardItem(user1, tokenURIs[i]);
            
            // 验证铸造成功
            assertEq(nft.ownerOf(tokenIds[i]), user1);
            assertEq(nft.tokenURI(tokenIds[i]), tokenURIs[i]);
        }
        
        // 2. 升级NFT合约
        // 部署NFT V2实现合约
        nftImplV2 = new ERC721_cna_upgradeableV2();
        
        // 使用upgradeToAndCall升级NFT合约
        bytes memory initData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplV2),
            initData
        );
        
        // 将代理地址转换为V2合约类型
        nftV2 = ERC721_cna_upgradeableV2(nftProxyAddress);
        
        vm.stopPrank();
        
        // 3. 验证升级后铸造的NFT数据完整性
        for (uint256 i = 0; i < 3; i++) {
            // 验证所有权和元数据没有变化
            assertEq(nftV2.ownerOf(tokenIds[i]), user1);
            assertEq(nftV2.tokenURI(tokenIds[i]), tokenURIs[i]);
        }
        
        // 4. 使用升级后的合约继续铸造NFT
        vm.startPrank(owner);
        
        uint256 newTokenId = nftV2.awardItem(user2, tokenURIs[3]);
        assertEq(nftV2.ownerOf(newTokenId), user2);
        assertEq(nftV2.tokenURI(newTokenId), tokenURIs[3]);
        
        vm.stopPrank();
        
        // 5. 验证之前铸造的NFT仍然可以转移
        vm.startPrank(user1);
        nftV2.transferFrom(user1, user2, tokenIds[0]);
        vm.stopPrank();
        
        assertEq(nftV2.ownerOf(tokenIds[0]), user2);
    }
    
    function test_PreUpgradeNFTMarketAndUpgrade() public {
        // 记录铸造的NFT IDs
        tokenIds = new uint256[](5);
        listedTokenIds = new uint256[](3);
        
        // 1. 铸造NFT
        vm.startPrank(owner);
        
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = nft.awardItem(user1, tokenURIs[i]);
        }
        
        vm.stopPrank();
        
        // 2. 上架部分NFT
        vm.startPrank(user1);
        
        for (uint256 i = 0; i < 3; i++) {
            nft.approve(marketProxyAddress, tokenIds[i]);
            market.list(tokenIds[i], tokenPrices[i]);
            listedTokenIds[i] = tokenIds[i];
        }
        
        vm.stopPrank();
        
        // 3. 验证上架信息
        for (uint256 i = 0; i < 3; i++) {
            (address listingSeller, uint256 listingPrice, bool listingActive) = market.listings(listedTokenIds[i]);
            assertEq(listingSeller, user1);
            assertEq(listingPrice, tokenPrices[i]);
            assertTrue(listingActive);
        }
        
        // 4. 先升级NFT合约
        vm.startPrank(owner);
        
        nftImplV2 = new ERC721_cna_upgradeableV2();
        
        // 使用upgradeToAndCall升级NFT合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplV2),
            nftInitData
        );
        
        nftV2 = ERC721_cna_upgradeableV2(nftProxyAddress);
        
        // 5. 再升级市场合约
        marketImplV2 = new NFTMarket_upgradeableV2();
        
        // 使用upgradeToAndCall升级市场合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(marketProxyAddress).upgradeToAndCall(
            address(marketImplV2),
            marketInitData
        );
        
        marketV2 = NFTMarket_upgradeableV2(marketProxyAddress);
        
        vm.stopPrank();
        
        // 6. 验证升级后上架信息是否保持一致
        for (uint256 i = 0; i < 3; i++) {
            (address updatedSeller, uint256 updatedPrice, bool updatedActive) = marketV2.listings(listedTokenIds[i]);
            assertEq(updatedSeller, user1);
            assertEq(updatedPrice, tokenPrices[i]);
            assertTrue(updatedActive);
        }
        
        // 7. 购买一个上架的NFT
        vm.startPrank(user2);
        
        token.approve(marketProxyAddress, tokenPrices[0]);
        marketV2.buyNFT(listedTokenIds[0]);
        
        vm.stopPrank();
        
        // 8. 验证购买后NFT所有权转移和上架状态更新
        assertEq(nftV2.ownerOf(listedTokenIds[0]), user2);
        
        (,, bool postPurchaseActive) = marketV2.listings(listedTokenIds[0]);
        assertFalse(postPurchaseActive);
        
        // 9. 使用V2版本的市场合约上架剩余NFT
        vm.startPrank(user1);
        
        nftV2.approve(marketProxyAddress, tokenIds[3]);
        marketV2.list(tokenIds[3], tokenPrices[3]);
        
        vm.stopPrank();
        
        // 10. 验证新上架的NFT
        (address newSeller, uint256 newPrice, bool newActive) = marketV2.listings(tokenIds[3]);
        assertEq(newSeller, user1);
        assertEq(newPrice, tokenPrices[3]);
        assertTrue(newActive);
    }
    
    function test_CrossUpgradeInteraction() public {
        // 1. 铸造NFT
        vm.startPrank(owner);
        uint256 tokenId = nft.awardItem(user1, tokenURIs[0]);
        vm.stopPrank();
        
        // 2. 上架NFT
        vm.startPrank(user1);
        nft.approve(marketProxyAddress, tokenId);
        market.list(tokenId, tokenPrices[0]);
        vm.stopPrank();
        
        // 3. 只升级NFT合约，保持市场合约不变
        vm.startPrank(owner);
        
        nftImplV2 = new ERC721_cna_upgradeableV2();
        
        // 使用upgradeToAndCall升级NFT合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplV2),
            nftInitData
        );
        
        nftV2 = ERC721_cna_upgradeableV2(nftProxyAddress);
        
        vm.stopPrank();
        
        // 4. 使用旧版市场合约和新版NFT交互
        vm.startPrank(user2);
        token.approve(marketProxyAddress, tokenPrices[0]);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // 5. 验证跨版本交互成功
        assertEq(nftV2.ownerOf(tokenId), user2);
        
        // 6. 现在升级市场合约
        vm.startPrank(owner);
        
        marketImplV2 = new NFTMarket_upgradeableV2();
        
        // 使用upgradeToAndCall升级市场合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(marketProxyAddress).upgradeToAndCall(
            address(marketImplV2),
            marketInitData
        );
        
        marketV2 = NFTMarket_upgradeableV2(marketProxyAddress);
        
        // 7. 铸造新NFT
        uint256 newTokenId = nftV2.awardItem(user1, tokenURIs[1]);
        vm.stopPrank();
        
        // 8. 使用新版市场合约上架NFT
        vm.startPrank(user1);
        nftV2.approve(marketProxyAddress, newTokenId);
        marketV2.list(newTokenId, tokenPrices[1]);
        vm.stopPrank();
        
        // 9. 购买NFT
        vm.startPrank(user2);
        token.approve(marketProxyAddress, tokenPrices[1]);
        marketV2.buyNFT(newTokenId);
        vm.stopPrank();
        
        // 10. 验证交易成功
        assertEq(nftV2.ownerOf(newTokenId), user2);
    }
    
    function test_GasEfficiencyAfterUpgrade() public {
        // 1. 铸造NFT
        vm.startPrank(owner);
        
        uint256[] memory preUpgradeTokenIds = new uint256[](2);
        uint256[] memory postUpgradeTokenIds = new uint256[](2);
        
        // 升级前铸造NFT
        preUpgradeTokenIds[0] = nft.awardItem(user1, tokenURIs[0]);
        preUpgradeTokenIds[1] = nft.awardItem(user1, tokenURIs[1]);
        
        // 升级合约
        nftImplV2 = new ERC721_cna_upgradeableV2();
        marketImplV2 = new NFTMarket_upgradeableV2();
        
        // 升级NFT合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplV2),
            nftInitData
        );
        
        nftV2 = ERC721_cna_upgradeableV2(nftProxyAddress);
        
        // 升级市场合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(marketProxyAddress).upgradeToAndCall(
            address(marketImplV2),
            marketInitData
        );
        
        marketV2 = NFTMarket_upgradeableV2(marketProxyAddress);
        
        // 升级后铸造NFT
        postUpgradeTokenIds[0] = nftV2.awardItem(user1, tokenURIs[2]);
        postUpgradeTokenIds[1] = nftV2.awardItem(user1, tokenURIs[3]);
        
        vm.stopPrank();
        
        // 2. 测试升级前铸造的NFT上架和购买
        vm.startPrank(user1);
        
        // 上架第一个预升级NFT
        uint256 gasBefore1 = gasleft();
        nft.approve(marketProxyAddress, preUpgradeTokenIds[0]);
        market.list(preUpgradeTokenIds[0], tokenPrices[0]);
        uint256 gasAfter1 = gasleft();
        uint256 gasUsed1 = gasBefore1 - gasAfter1;
        
        vm.stopPrank();
        
        // 购买第一个预升级NFT
        vm.startPrank(user2);
        token.approve(marketProxyAddress, tokenPrices[0]);
        uint256 gasBefore2 = gasleft();
        marketV2.buyNFT(preUpgradeTokenIds[0]);
        uint256 gasAfter2 = gasleft();
        uint256 gasUsed2 = gasBefore2 - gasAfter2;
        vm.stopPrank();
        
        // 3. 测试升级后铸造的NFT上架和购买
        vm.startPrank(user1);
        
        // 上架第一个升级后NFT
        uint256 gasBefore3 = gasleft();
        nftV2.approve(marketProxyAddress, postUpgradeTokenIds[0]);
        marketV2.list(postUpgradeTokenIds[0], tokenPrices[2]);
        uint256 gasAfter3 = gasleft();
        uint256 gasUsed3 = gasBefore3 - gasAfter3;
        
        vm.stopPrank();
        
        // 购买第一个升级后NFT
        vm.startPrank(user2);
        token.approve(marketProxyAddress, tokenPrices[2]);
        uint256 gasBefore4 = gasleft();
        marketV2.buyNFT(postUpgradeTokenIds[0]);
        uint256 gasAfter4 = gasleft();
        uint256 gasUsed4 = gasBefore4 - gasAfter4;
        vm.stopPrank();
        
        // 记录Gas使用量
        console.log("Gas used for pre-upgrade NFT listing: ", gasUsed1);
        console.log("Gas used for pre-upgrade NFT purchase: ", gasUsed2);
        console.log("Gas used for post-upgrade NFT listing: ", gasUsed3);
        console.log("Gas used for post-upgrade NFT purchase: ", gasUsed4);
        
        // 验证功能正常工作 (所有权转移)
        assertEq(nftV2.ownerOf(preUpgradeTokenIds[0]), user2);
        assertEq(nftV2.ownerOf(postUpgradeTokenIds[0]), user2);
    }
    
    function test_SignatureListingAfterUpgrade() public {
        // 用户私钥
        uint256 userPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        address userAddress = vm.addr(userPrivateKey);

        
        // 1. 准备初始环境
        vm.startPrank(owner);
        // 升级前 铸造NFT给用户
        uint256 tokenId = nft.awardItem(userAddress, "https://example.com/token/signature-test");
        
        // 升级NFT合约
        nftImplV2 = new ERC721_cna_upgradeableV2();
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplV2),
            nftInitData
        );
        nftV2 = ERC721_cna_upgradeableV2(nftProxyAddress);
        
        // 升级市场合约
        marketImplV2 = new NFTMarket_upgradeableV2();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeableV2.initializeV2.selector
        );
        UUPSUpgradeable(marketProxyAddress).upgradeToAndCall(
            address(marketImplV2),
            marketInitData
        );
        marketV2 = NFTMarket_upgradeableV2(marketProxyAddress);
        
        // 给用户转一些代币以支付交易
        token.transfer(userAddress, 10 ether);
        
        vm.stopPrank();
        
        // 2. 用户授权市场合约操作所有NFT
        vm.startPrank(userAddress);
        nftV2.setApprovalForAll(marketProxyAddress, true);
        vm.stopPrank();
        
        // 3. 准备离线签名上架参数
        uint256 price = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 获取当前nonce
        uint256 currentNonce = marketV2.listingNonces(userAddress, tokenId);
        
        // 构造要签名的消息
        bytes32 domainSeparator = marketV2.DOMAIN_SEPARATOR();
        bytes32 listTypehash = keccak256("ListWithSignature(address owner,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(
                listTypehash,
                userAddress,
                tokenId,
                price,
                currentNonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        // 使用用户私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        
        // 4. 第三方代表用户提交签名上架交易
        vm.prank(user2);
        marketV2.listWithSignature(userAddress, tokenId, price, deadline, v, r, s);
        
        // 5. 验证NFT已经成功上架
        (address seller, uint256 listedPrice, bool active) = marketV2.listings(tokenId);
        assertEq(seller, userAddress);
        assertEq(listedPrice, price);
        assertTrue(active);
        
        // 6. 验证NFT所有权已转移到市场合约
        assertEq(nftV2.ownerOf(tokenId), marketProxyAddress);
        
        // 7. 购买已上架的NFT
        vm.startPrank(user2);
        token.approve(marketProxyAddress, price);
        marketV2.buyNFT(tokenId);
        vm.stopPrank();
        
        // 8. 验证购买后NFT已转移给买家
        assertEq(nftV2.ownerOf(tokenId), user2);
        
        // 9. 验证上架状态已更新
        (,, active) = marketV2.listings(tokenId);
        assertFalse(active);
    }
} 