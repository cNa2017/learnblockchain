// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ERC721_cna_upgradeableV2, NFTMarket_upgradeableV2} from "../src/NFTMarketExchange_upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title 升级NFT市场合约脚本
 * @dev 该脚本用于将已部署的NFT市场和NFT合约升级到V2版本
 * 运行方式：
 * 1. 首先设置环境变量: 
 *    export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_KEY"
 *    export SEPOLIA_PRIVATE_KEY="your_private_key_without_0x_prefix"
 *    export NFT_PROXY_ADDRESS="0x..."
 *    export MARKET_PROXY_ADDRESS="0x..."
 * 2. 运行升级命令:
 *    forge script script/UpgradeNFTMarket.s.sol:UpgradeNFTMarketScript --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --broadcast --verify
 */
contract UpgradeNFTMarketScript is Script {
    // 已部署的代理合约地址 (需要在运行前更新这些地址)
    address public nftProxyAddress;
    address public marketProxyAddress;
    
    // V2实现合约
    ERC721_cna_upgradeableV2 public nftImplementationV2;
    NFTMarket_upgradeableV2 public marketImplementationV2;
    
    function setUp() public {
        nftProxyAddress = 0x3Cd01838509EAEf9E01DE6159A916dAfb6639367;//需要修改
        marketProxyAddress = 0xab61b7a093125919f31Fd5de6438622f7E32f320;//需要修改
        
        // 确保地址已设置
        require(nftProxyAddress != address(0), "NFT proxy address not set");
        require(marketProxyAddress != address(0), "Market proxy address not set");
    }
    
    function run() public {
        // 获取部署者地址
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Upgrader address:", deployer);
        console.log("Starting NFT marketplace contract upgrade...");
        console.log("NFT proxy address:", nftProxyAddress);
        console.log("Market proxy address:", marketProxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署NFT V2实现合约
        nftImplementationV2 = new ERC721_cna_upgradeableV2();
        console.log("NFT V2 implementation contract deployed:", address(nftImplementationV2));
        
        // 2. 部署市场 V2实现合约
        marketImplementationV2 = new NFTMarket_upgradeableV2();
        console.log("Market V2 implementation contract deployed:", address(marketImplementationV2));
        
        // 3. 升级NFT合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(nftProxyAddress).upgradeToAndCall(
            address(nftImplementationV2),
            nftInitData
        );
        console.log("NFT contract upgraded successfully");
        
        // 4. 升级市场合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeableV2.initializeV2.selector
        );
        
        UUPSUpgradeable(marketProxyAddress).upgradeToAndCall(
            address(marketImplementationV2),
            marketInitData
        );
        console.log("Market contract upgraded successfully");
        
        vm.stopBroadcast();
        
        console.log("=======================");
        console.log("Upgrade Summary:");
        console.log("- NFT Proxy Address:", nftProxyAddress);
        console.log("- NFT V2 Implementation Contract:", address(nftImplementationV2));
        console.log("- Market Proxy Address:", marketProxyAddress);
        console.log("- Market V2 Implementation Contract:", address(marketImplementationV2));
        console.log("=======================");
        console.log("Upgrade completed successfully!");
        console.log("You can now use the new V2 features:");
        console.log("1. Use permit for NFT authorization");
        console.log("2. Use signature for NFT listing");
        console.log("3. Use batch listing functionality");
        console.log("=======================");
    }
} 