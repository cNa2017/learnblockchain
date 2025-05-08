// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "forge-std/console.sol";

contract NFTMarketTest is Test {
    // 合约实例
    NFTMarket public market;
    MyERC20 public token;
    MyNFT public nft;

    // 测试账户
    address public owner = address(uint160(1));
    address public seller = address(uint160(2));
    address public buyer = address(uint160(3));

    // 测试数据
    uint256 public initialSupply = 1000000;
    uint256 public nftPrice = 100;
    uint256 public tokenId;
    string public constant NFT_URI = "ipfs://test-uri";

    // 设置测试环境
    function setUp() public {
        // 使用不同的账户部署合约
        vm.startPrank(owner);
        market = new NFTMarket();
        token = new MyERC20("Test Token", "TEST", initialSupply);
        nft = new MyNFT("Test NFT", "TNFT");
        vm.stopPrank();

        // 铸造NFT给卖家
        vm.startPrank(owner);
        tokenId = nft.mint(seller, NFT_URI);
        vm.stopPrank();

        // 给买家转一些代币
        vm.startPrank(owner);
        token.transfer(buyer, 1000000);
        vm.stopPrank();
    }

    // 测试上架NFT成功
    function testListNFTSuccess() public {
        vm.startPrank(seller);
        
        // 授权市场合约操作NFT
        nft.approve(address(market), tokenId);
        
        // 监听事件
        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(nft), tokenId, seller, address(token), nftPrice);
        
        // 上架NFT
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        
        // 验证上架信息
        NFTMarket.Listing memory listing = market.getListing(address(nft), tokenId);
        assertEq(listing.seller, seller);
        assertEq(listing.tokenAddress, address(token));
        assertEq(listing.price, nftPrice);
        assertTrue(listing.active);
        
        vm.stopPrank();
    }

    // 测试上架NFT失败 - 价格为0
    function testListNFTFailZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        
        vm.expectRevert("Price must be greater than zero");
        market.listNFT(address(nft), tokenId, address(token), 0);
        
        vm.stopPrank();
    }

    // 测试上架NFT失败 - 不是NFT拥有者
    function testListNFTFailNotOwner() public {
        vm.startPrank(buyer);
        
        vm.expectRevert("Not the owner of this NFT");
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        
        vm.stopPrank();
    }

    // 测试上架NFT失败 - 未授权市场合约
    function testListNFTFailNotApproved() public {
        vm.startPrank(seller);
        
        vm.expectRevert("Market not approved to transfer this NFT");
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        
        vm.stopPrank();
    }

    // 测试购买NFT成功
    function testBuyNFTSuccess() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        // 授权市场合约转移代币
        token.approve(address(market), nftPrice);
        
        // 监听事件
        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(nft), tokenId, seller, buyer, address(token), nftPrice);
        
        // 购买NFT
        market.buyNFT(address(nft), tokenId);
        
        // 验证NFT所有权已转移
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // 验证代币已转移
        assertEq(token.balanceOf(seller), nftPrice);
        
        // 验证上架状态已更新
        NFTMarket.Listing memory listing = market.getListing(address(nft), tokenId);
        assertFalse(listing.active);
        
        vm.stopPrank();
    }

    // 测试购买NFT失败 - 购买自己的NFT
    function testBuyNFTFailBuyOwnNFT() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        
        // 尝试购买自己的NFT
        vm.expectRevert("Cannot buy your own NFT");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }

    // 测试购买NFT失败 - NFT未上架
    function testBuyNFTFailNotListed() public {
        vm.startPrank(buyer);
        
        vm.expectRevert("NFT not listed for sale");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }

    // 测试购买NFT失败 - NFT已被购买
    function testBuyNFTFailAlreadySold() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        vm.stopPrank();
        
        // 买家1购买NFT
        vm.startPrank(buyer);
        token.approve(address(market), nftPrice);
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
        
        // 创建买家2
        address buyer2 = address(4);
        vm.startPrank(owner);
        token.transfer(buyer2, 10000);
        vm.stopPrank();
        
        // 买家2尝试购买同一个NFT
        vm.startPrank(buyer2);
        token.approve(address(market), nftPrice);
        
        vm.expectRevert("NFT not listed for sale");
        market.buyNFT(address(nft), tokenId);
        
        vm.stopPrank();
    }

    // 测试购买NFT失败 - 代币授权不足
    function testBuyNFTFailInsufficientAllowance() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        // 授权金额不足
        token.approve(address(market), nftPrice - 1);
        
        // 预期会失败，但错误信息来自SafeERC20，这里我们只验证交易失败
        (bool success,) = address(market).call(
            abi.encodeWithSelector(market.buyNFT.selector, address(nft), tokenId)
        );
        assertFalse(success);
        
        vm.stopPrank();
    }

    // 测试购买NFT失败 - 代币余额不足
    function testBuyNFTFailInsufficientBalance() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        vm.stopPrank();
        
        // 创建余额不足的买家
        address poorBuyer = address(5);
        vm.startPrank(owner);
        token.transfer(poorBuyer, nftPrice - 1); // 余额不足
        vm.stopPrank();
        
        vm.startPrank(poorBuyer);
        token.approve(address(market), nftPrice);
        
        // 预期会失败，但错误信息来自SafeERC20，这里我们只验证交易失败
        (bool success,) = address(market).call(
            abi.encodeWithSelector(market.buyNFT.selector, address(nft), tokenId)
        );
        assertFalse(success);
        
        vm.stopPrank();
    }

    // 测试取消上架NFT
    function testCancelListing() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        
        // 监听事件
        vm.expectEmit(true, true, true, true);
        emit NFTListingCancelled(address(nft), tokenId, seller);
        
        // 取消上架
        market.cancelListing(address(nft), tokenId);
        
        // 验证上架状态已更新
        NFTMarket.Listing memory listing = market.getListing(address(nft), tokenId);
        assertFalse(listing.active);
        
        vm.stopPrank();
    }

    // 测试取消上架NFT失败 - 不是卖家
    function testCancelListingFailNotSeller() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), nftPrice);
        vm.stopPrank();
        
        // 非卖家尝试取消上架
        vm.startPrank(buyer);
        
        vm.expectRevert("Not the seller of this NFT");
        market.cancelListing(address(nft), tokenId);
        
        vm.stopPrank();
    }

    // 模糊测试 - 随机价格上架和购买NFT
    function testFuzz_ListAndBuyNFT(uint256 price, address randomBuyer) public {
        // 限制价格范围在0.01-10000之间
        price = bound(price, 10**16, 10**22);
        // 确保随机买家不是零地址、卖家或合约地址
        vm.assume(randomBuyer != address(0));
        vm.assume(randomBuyer != seller);
        vm.assume(randomBuyer != address(market));
        vm.assume(randomBuyer != address(nft));
        vm.assume(randomBuyer != address(token));
        vm.assume(uint160(randomBuyer) > 10000); // 避免使用保留地址
        
        // 给随机买家转代币
        vm.startPrank(owner);
        token.transfer(randomBuyer, price * 2); // 确保有足够的代币
        vm.stopPrank();
        
        // 上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, address(token), price);
        vm.stopPrank();
        
        // 随机买家购买NFT
        vm.startPrank(randomBuyer);
        token.approve(address(market), price);
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
        
        // 验证NFT所有权已转移
        assertEq(nft.ownerOf(tokenId), randomBuyer);
        
        // 验证代币已转移
        assertEq(token.balanceOf(seller), price);
    }
    

    // 不变性测试 - 确保NFTMarket合约不会持有任何代币
    function invariant_MarketHasNoTokens() public {
        // 创建多个NFT和代币进行测试
        address[] memory testUsers = new address[](3);
        address[] memory testBuyUsers = new address[](3);
        for(uint i = 0; i < 3; i++) {
            testUsers[i] = address(uint160(1000 + i));
            testBuyUsers[i] = address(uint160(10000 + i));
            console.log("address",address(testUsers[i]));
            // 给测试用户转代币
            vm.startPrank(owner);
            // token.transfer(testUsers[i], 1000);
            token.transfer(testBuyUsers[i], 1000);
            vm.stopPrank();
            
            // 铸造NFT给测试用户
            vm.startPrank(owner);
            uint256 newTokenId = nft.mint(testUsers[i], string(abi.encodePacked(NFT_URI, "-", i)));
            vm.stopPrank();
            
            // // 上架NFT
            vm.startPrank(testUsers[i]);
            nft.approve(address(market), newTokenId);
            market.listNFT(address(nft), newTokenId, address(token), 100 + i);
            vm.stopPrank();
            console.log("address(market)",address(market));
            // // 另一个用户购买NFT
            // uint buyerIndex = (i + 1) % 3;
            vm.startPrank(testBuyUsers[i]);
            token.approve(address(market), 100 + i);
            market.buyNFT(address(nft), newTokenId);
            vm.stopPrank();
        }
        
        // 验证市场合约不持有任何代币
        assertEq(token.balanceOf(address(market)), 0);
    }

    // 事件定义，用于测试
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, address tokenAddress, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address seller, address buyer, address tokenAddress, uint256 price);
    event NFTListingCancelled(address indexed nftContract, uint256 indexed tokenId, address indexed seller);
}