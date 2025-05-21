// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ERC20_Extend} from "../src/NFTMarketExchange_upgradeable.sol";
import {ERC721_cna_upgradeableV2} from "../src/NFTMarketExchange_upgradeable.sol";
import {NFTMarket_upgradeableV2} from "../src/NFTMarketExchange_upgradeable.sol";

/**
 * @title NFT市场签名功能互动脚本
 * @dev 该脚本演示如何使用V2版本合约的离线签名功能
 * 运行方式：
 * 1. 首先设置环境变量: 
 *    export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_KEY"
 *    export SEPOLIA_PRIVATE_KEY="your_private_key_without_0x_prefix"
 *    export NFT_PROXY_ADDRESS="0x..."
 *    export MARKET_PROXY_ADDRESS="0x..."
 *    export TOKEN_ADDRESS="0x..."
 * 2. 运行脚本命令:
 *    forge script script/UseSignatureFeatures.s.sol:UseSignatureFeaturesScript --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --broadcast
 */
contract UseSignatureFeaturesScript is Script {
    // V2合约实例
    ERC721_cna_upgradeableV2 public nft;
    NFTMarket_upgradeableV2 public market;
    ERC20_Extend public token;
    
    // 用户信息
    address public userAddress; // 拥有NFT的用户地址
    uint256 public userPrivateKey; // 用户的私钥
    
    // 已部署的合约地址
    address public nftProxyAddress;
    address public marketProxyAddress;
    address public tokenAddress;
    
    function setUp() public {
        // 从环境变量中获取合约地址
        string memory nftProxyAddressStr = "0x3Cd01838509EAEf9E01DE6159A916dAfb6639367";
        string memory marketProxyAddressStr = "0xab61b7a093125919f31Fd5de6438622f7E32f320";
        string memory tokenAddressStr = "0x5a1F096d568366ef5A9aDc86e4A2a761FcEe409E";
        
        if (bytes(nftProxyAddressStr).length > 0) {
            nftProxyAddress = vm.parseAddress(nftProxyAddressStr);
        } else {
            // 如果环境变量未设置，使用硬编码的地址
            nftProxyAddress = address(0); // 替换为实际部署的地址
        }
        
        if (bytes(marketProxyAddressStr).length > 0) {
            marketProxyAddress = vm.parseAddress(marketProxyAddressStr);
        } else {
            // 如果环境变量未设置，使用硬编码的地址
            marketProxyAddress = address(0); // 替换为实际部署的地址
        }
        
        if (bytes(tokenAddressStr).length > 0) {
            tokenAddress = vm.parseAddress(tokenAddressStr);
        } else {
            // 如果环境变量未设置，使用硬编码的地址
            tokenAddress = address(0); // 替换为实际部署的地址
        }
        
        // 确保地址已设置
        require(nftProxyAddress != address(0), "NFT proxy address not set");
        require(marketProxyAddress != address(0), "Market proxy address not set");
        require(tokenAddress != address(0), "Token address not set");
        
        // 获取用户信息
        userPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        userAddress = vm.addr(userPrivateKey);
        
        // 包装代理以便调用
        nft = ERC721_cna_upgradeableV2(nftProxyAddress);
        market = NFTMarket_upgradeableV2(marketProxyAddress);
        token = ERC20_Extend(tokenAddress);
    }
    
    function run() public {
        console.log("User Address:", userAddress);
        
        vm.startBroadcast(userPrivateKey);
        
        // 1. 铸造NFT (如果用户有权限)
        try nft.awardItem(userAddress, "https://example.com/nft/signature-demo") returns (uint256 tokenId) {
            console.log("NFT minted successfully, TokenID:", tokenId);
            
            // 2. 演示NFT离线签名授权功能
            demonstrateNFTPermit(tokenId);
            
            // 3. 演示签名上架NFT功能
            demonstrateSignatureListing(tokenId);
            
        } catch {
            console.log("User has no minting permission, skipping NFT minting step");
            
            // 如果没有铸造权限，尝试使用已有的NFT
            uint256 balance = nft.balanceOf(userAddress);
            if (balance > 0) {
                // 获取用户拥有的NFT
                // 注意：由于合约没有实现ERC721Enumerable，我们无法使用tokenOfOwnerByIndex
                // 我们将尝试通过一系列可能的tokenId来找到用户拥有的NFT
                uint256 tokenId = 0;
                bool found = false;
                
                // 尝试找出用户拥有的NFT
                for (uint256 i = 0; i < 100; i++) {
                    try nft.ownerOf(i) returns (address owner) {
                        if (owner == userAddress) {
                            tokenId = i;
                            found = true;
                            break;
                        }
                    } catch {
                        // 这个tokenId可能不存在，继续尝试
                        continue;
                    }
                }
                
                if (found) {
                    console.log("Found user's NFT, TokenID:", tokenId);
                    
                    // 演示签名上架NFT功能
                    demonstrateSignatureListing(tokenId);
                } else {
                    console.log("No NFT found for user, cannot demonstrate signature feature");
                }
            } else {
                console.log("User has no NFTs, cannot demonstrate signature feature");
            }
        }
        
        vm.stopBroadcast();
    }
    
    function demonstrateNFTPermit(uint256 tokenId) internal {
        console.log("Starting demonstration of offline NFT authorization signature...");
        
        // 准备permit签名
        address spender = marketProxyAddress; // 授权给市场合约
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 domainSeparator = nft.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
        
        bytes32 structHash = keccak256(
            abi.encode(
                permitTypehash,
                userAddress,
                spender,
                tokenId,
                nft.nonces(userAddress),
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
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        
        // 使用permit进行授权
        nft.permit(userAddress, spender, tokenId, deadline, v, r, s);
        
        console.log("NFT authorization successful, caller:", userAddress);
        console.log("Authorization recipient:", spender);
        console.log("NFT ID:", tokenId);
    }
    
    function demonstrateSignatureListing(uint256 tokenId) internal {
        console.log("Starting demonstration of offline NFT listing signature...");
        
        // 确保NFT市场合约有权操作用户的所有NFT
        if (!nft.isApprovedForAll(userAddress, marketProxyAddress)) {
            nft.setApprovalForAll(marketProxyAddress, true);
            console.log("Market contract authorized to operate all NFTs");
        }
        
        // 准备listWithSignature签名
        uint256 price = 0.1 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 获取当前nonce
        uint256 currentNonce = market.listingNonces(userAddress, tokenId);
        
        // 构造签名消息
        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
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
        
        // 签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        
        // 使用签名上架NFT
        market.listWithSignature(userAddress, tokenId, price, deadline, v, r, s);
        
        console.log("NFT signature listing successful!");
        console.log("Seller:", userAddress);
        console.log("NFT ID:", tokenId);
        console.log("Price:", price);
    }
} 