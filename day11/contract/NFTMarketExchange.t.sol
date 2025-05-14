// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC20_Extend, ERC721_cna, NFTMarket} from "../src/NFTMarketExchange.sol";

contract NFTMarketExchangeTest is Test {
    ERC20_Extend token;
    ERC721_cna nft;
    NFTMarket market;

    // Test accounts
    address deployer = address(1);
    address seller = address(2);
    address buyer = address(3);
    address whitelistedBuyer = address(4);

    // 项目方签名者私钥与地址
    uint256 private signerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address public projectSigner;

    // Constants
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18;
    uint256 constant BUYER_TOKENS = 10_000 * 10**18;
    uint256 constant NFT_PRICE = 100 * 10**18;

    function setUp() public {
        // 初始化项目方签名者地址
        projectSigner = vm.addr(signerPrivateKey);
        
        // Set up contracts with deployer
        vm.startPrank(deployer);
        token = new ERC20_Extend(INITIAL_SUPPLY);
        nft = new ERC721_cna(deployer);
        market = new NFTMarket(address(token), address(nft), projectSigner);
        vm.stopPrank();

        // Set up seller with NFT
        vm.startPrank(deployer);
        uint256 tokenId = nft.awardItem(seller, "https://example.com/nft/1");
        token.transfer(buyer, BUYER_TOKENS);
        token.transfer(whitelistedBuyer, BUYER_TOKENS);
        vm.stopPrank();
    }

    // 辅助函数：获取listings信息
    function getListingInfo(uint256 tokenId) internal view returns (address _seller, uint256 _price, bool _active) {
        (_seller, _price, _active) = market.listings(tokenId);
    }

    function testListNFT() public {
        // Seller lists NFT
        vm.startPrank(seller);
        uint256 tokenId = 0; // First minted NFT
        
        // Approve market to transfer NFT
        nft.approve(address(market), tokenId);
        
        // List NFT
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // Verify listing
        (address listedSeller, uint256 listedPrice, bool isActive) = getListingInfo(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, NFT_PRICE);
        assertTrue(isActive);
        
        // Verify NFT ownership transferred to market
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    function testBuyNFTDirectMethod() public {
        // First list the NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // Buyer purchases NFT using direct buyNFT method
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        market.buyNFT(tokenId);
        vm.stopPrank();
        
        // Verify purchase
        (,, bool isActive) = getListingInfo(tokenId);
        assertFalse(isActive);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), NFT_PRICE);
    }

    function testBuyNFTWithCallback() public {
        // First list the NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // Prepare the data for the callback
        bytes4 selector = bytes4(keccak256("buyNFT(uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId);
        
        // Buyer purchases NFT using callback method
        vm.startPrank(buyer);
        token.transferWithCallback(address(market), NFT_PRICE, data);
        vm.stopPrank();
        
        // Verify purchase
        (,, bool isActive) = getListingInfo(tokenId);
        assertFalse(isActive);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), NFT_PRICE);
    }

    function testBuyNFTWithExcessAmount() public {
        // First list the NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        uint256 excessAmount = NFT_PRICE + 50 * 10**18;
        uint256 refundAmount = excessAmount - NFT_PRICE;
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        
        // Prepare the data for the callback
        bytes4 selector = bytes4(keccak256("buyNFT(uint256)"));
        bytes memory data = abi.encodeWithSelector(selector, tokenId);
        
        // Buyer purchases NFT with excess amount
        vm.startPrank(buyer);
        token.transferWithCallback(address(market), excessAmount, data);
        vm.stopPrank();
        
        // Verify purchase and refund
        (,, bool isActive) = getListingInfo(tokenId);
        assertFalse(isActive);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerInitialBalance - NFT_PRICE);
    }

    function test_RevertWhen_ListingUnownedNFT() public {
        vm.startPrank(buyer); // buyer doesn't own the NFT
        uint256 tokenId = 0;
        
        // 期望revert，并包含错误消息
        vm.expectRevert("Not the owner of this NFT");
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
    }

    function test_RevertWhen_BuyingUnlistedNFT() public {
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        
        // 期望revert，并包含错误消息
        vm.expectRevert("NFT not listed for sale");
        market.buyNFT(999); // non-existent token
        vm.stopPrank();
    }

    function test_RevertWhen_BuyingWithInsufficientFunds() public {
        // First list the NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // Prepare insufficient amount
        uint256 insufficientAmount = NFT_PRICE - 1;
        
        // Try to buy with insufficient funds
        vm.startPrank(buyer);
        token.approve(address(market), insufficientAmount);
        
        // 不使用具体的错误消息，而是期望任何revert
        vm.expectRevert();
        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    function testListAndCancelMultipleNFTs() public {
        // Setup multiple NFTs
        vm.startPrank(deployer);
        uint256 tokenId1 = nft.awardItem(seller, "https://example.com/nft/2");
        uint256 tokenId2 = nft.awardItem(seller, "https://example.com/nft/3");
        vm.stopPrank();

        // List multiple NFTs
        vm.startPrank(seller);
        
        nft.approve(address(market), tokenId1);
        market.list(tokenId1, NFT_PRICE);
        
        nft.approve(address(market), tokenId2);
        market.list(tokenId2, NFT_PRICE * 2);
        
        vm.stopPrank();
        
        // Verify both listings
        (address seller1, uint256 price1, bool active1) = getListingInfo(tokenId1);
        (address seller2, uint256 price2, bool active2) = getListingInfo(tokenId2);
        
        assertTrue(active1);
        assertTrue(active2);
        assertEq(price1, NFT_PRICE);
        assertEq(price2, NFT_PRICE * 2);
    }

    // 为permitBuy生成签名
    function _signPermitBuy(
        address _buyer,
        uint256 _tokenId,
        uint256 _deadline
    ) private view returns (uint8 v, bytes32 r, bytes32 s) {
        // 构建相同的消息哈希，与合约中完全一致
        bytes32 hash = keccak256(abi.encodePacked(_buyer, _tokenId, _deadline));
        
        // 使用与合约中一致的方式构建签名消息
        // 这里直接复制合约中MessageHashUtils.toEthSignedMessageHash的实现
        bytes32 message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        
        // 使用foundry的vm签名功能
        (v, r, s) = vm.sign(signerPrivateKey, message);
    }

    function test_permitBuy() public {
        // 首先列出NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // 设置deadline (当前时间 + 1小时)
        uint256 deadline = block.timestamp + 1 hours;
        
        // 为白名单用户生成签名
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(whitelistedBuyer, tokenId, deadline);
        
        // 白名单用户使用签名购买NFT
        vm.startPrank(whitelistedBuyer);
        token.approve(address(market), NFT_PRICE);
        market.permitBuy(tokenId, deadline, v, r, s);
        vm.stopPrank();
        
        // 验证购买结果
        (,, bool isActive) = getListingInfo(tokenId);
        assertFalse(isActive);
        assertEq(nft.ownerOf(tokenId), whitelistedBuyer);
        assertEq(token.balanceOf(seller), NFT_PRICE);
    }

    function test_RevertWhen_InvalidSignature() public {
        // 首先列出NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // 设置deadline
        uint256 deadline = block.timestamp + 1 hours;
        
        // 为whitelistedBuyer生成签名
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(whitelistedBuyer, tokenId, deadline);
        
        // 非白名单用户尝试使用签名购买NFT
        vm.startPrank(buyer); // 使用不在白名单的买家
        token.approve(address(market), NFT_PRICE);
        
        // 期望交易失败，因为签名不匹配
        vm.expectRevert("Invalid signature");
        market.permitBuy(tokenId, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_RevertWhen_ExpiredSignature() public {
        // 首先列出NFT
        vm.startPrank(seller);
        uint256 tokenId = 0;
        nft.approve(address(market), tokenId);
        market.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // 设置已过期的deadline - 使用当前时间而不是减去时间
        uint256 expiredDeadline = 0;
        
        // 处理边界情况：确保deadline不会是负数
        // if (block.timestamp < 1 hours) {
        //     expiredDeadline = 0;
        // }
        
        // 为白名单用户生成签名（使用过期的deadline）
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(whitelistedBuyer, tokenId, expiredDeadline);
        
        // 白名单用户尝试使用过期签名购买NFT
        vm.startPrank(whitelistedBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 期望交易失败，因为签名已过期 - 使用确切的错误消息
        vm.expectRevert("Permit expired");
        market.permitBuy(tokenId, expiredDeadline, v, r, s);
        vm.stopPrank();
    }

    function test_RevertWhen_NotListedNFT() public {
        // 设置一个未上架的tokenId
        uint256 nonListedTokenId = 999;
        
        // 设置deadline
        uint256 deadline = block.timestamp + 1 hours;
        
        // 为白名单用户生成签名
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(whitelistedBuyer, nonListedTokenId, deadline);
        
        // 白名单用户尝试购买未上架的NFT
        vm.startPrank(whitelistedBuyer);
        token.approve(address(market), NFT_PRICE);
        
        // 期望交易失败，因为NFT未上架销售 - 使用确切的错误消息
        vm.expectRevert("NFT not listed for sale");
        market.permitBuy(nonListedTokenId, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_MultiplePermitBuys() public {
        // 设置多个NFT
        vm.startPrank(deployer);
        uint256 tokenId1 = nft.awardItem(seller, "https://example.com/nft/2");
        uint256 tokenId2 = nft.awardItem(seller, "https://example.com/nft/3");
        vm.stopPrank();

        // 上架多个NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId1);
        market.list(tokenId1, NFT_PRICE);
        
        nft.approve(address(market), tokenId2);
        market.list(tokenId2, NFT_PRICE * 2);
        vm.stopPrank();
        
        // 设置deadline
        uint256 deadline = block.timestamp + 1 hours;
        
        // 为白名单用户生成第一个NFT的签名
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermitBuy(whitelistedBuyer, tokenId1, deadline);
        
        // 白名单用户购买第一个NFT
        vm.startPrank(whitelistedBuyer);
        token.approve(address(market), NFT_PRICE * 3); // 批准足够的代币用于购买两个NFT
        market.permitBuy(tokenId1, deadline, v1, r1, s1);
        
        // 为白名单用户生成第二个NFT的签名
        (uint8 v2, bytes32 r2, bytes32 s2) = _signPermitBuy(whitelistedBuyer, tokenId2, deadline);
        
        // 白名单用户购买第二个NFT
        market.permitBuy(tokenId2, deadline, v2, r2, s2);
        vm.stopPrank();
        
        // 验证两个NFT都成功购买
        (,, bool isActive1) = getListingInfo(tokenId1);
        (,, bool isActive2) = getListingInfo(tokenId2);
        
        assertFalse(isActive1);
        assertFalse(isActive2);
        assertEq(nft.ownerOf(tokenId1), whitelistedBuyer);
        assertEq(nft.ownerOf(tokenId2), whitelistedBuyer);
        assertEq(token.balanceOf(seller), NFT_PRICE * 3); // 原始NFT(100) + 两个新NFT的总价(100 + 200)
    }
} 