// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ERC20_Extend, ERC721_cna_upgradeable, NFTMarket_upgradeable} from "../src/NFTMarketExchange_upgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title 可升级NFT市场部署脚本
 * @dev 该脚本用于部署可升级NFT市场合约到Sepolia测试网，并进行开源验证
 * 运行方式：
 * 1. 首先设置环境变量: 
 *    export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_KEY"
 *    export SEPOLIA_PRIVATE_KEY="your_private_key_without_0x_prefix"
 *    export ETHERSCAN_API_KEY="your_etherscan_api_key"
 * 2. 运行部署命令:
 *    forge script script/DeployNFTMarketUpgradeable.s.sol:DeployNFTMarketUpgradeableScript --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY --chain-id 11155111 --broadcast --verify 
 */
contract DeployNFTMarketUpgradeableScript is Script {
    // 合约实例
    ERC20_Extend public token;
    ERC721_cna_upgradeable public nftImplementation;
    NFTMarket_upgradeable public marketImplementation;
    
    // 代理合约地址
    address public nftProxyAddress;
    address public marketProxyAddress;
    
    // 初始供应量
    uint256 public initialSupply = 1_000_000 ether;
    
    function setUp() public {}
    
    function run() public {
        // 获取部署者地址
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Starting deployment of upgradeable NFT marketplace contracts...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署ERC20代币合约
        token = new ERC20_Extend(initialSupply);
        console.log("ERC20 token contract deployed:", address(token));
        
        // 2. 部署NFT实现合约
        nftImplementation = new ERC721_cna_upgradeable();
        console.log("NFT implementation contract deployed:", address(nftImplementation));
        
        // 3. 部署NFT代理合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721_cna_upgradeable.initialize.selector,
            "UpgradeableNFT",
            "UNFT",
            deployer
        );
        
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImplementation),
            nftInitData
        );
        nftProxyAddress = address(nftProxy);
        console.log("NFT proxy contract deployed:", nftProxyAddress);
        
        // 4. 部署市场实现合约
        marketImplementation = new NFTMarket_upgradeable();
        console.log("Market implementation contract deployed:", address(marketImplementation));
        
        // 5. 部署市场代理合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket_upgradeable.initialize.selector,
            address(token),
            nftProxyAddress
        );
        
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketImplementation),
            marketInitData
        );
        marketProxyAddress = address(marketProxy);
        console.log("Market proxy contract deployed:", marketProxyAddress);
        
        // 包装代理以便调用
        ERC721_cna_upgradeable nft = ERC721_cna_upgradeable(nftProxyAddress);
        NFTMarket_upgradeable market = NFTMarket_upgradeable(marketProxyAddress);
        
        // 6. 铸造一个样例NFT
        uint256 tokenId = nft.awardItem(deployer, "https://example.com/nft/1");
        console.log("Sample NFT minted, tokenId:", tokenId);
        
        // 7. 上架样例NFT用于展示
        nft.approve(marketProxyAddress, tokenId);
        market.list(tokenId, 0.1 ether);
        console.log("Sample NFT listed, price: 0.1 ether");
        
        vm.stopBroadcast();
        
        console.log("=======================");
        console.log("Deployment Summary:");
        console.log("- ERC20 Token Contract:", address(token));
        console.log("- NFT Implementation Contract:", address(nftImplementation));
        console.log("- NFT Proxy Contract:", nftProxyAddress);
        console.log("- Market Implementation Contract:", address(marketImplementation));
        console.log("- Market Proxy Contract:", marketProxyAddress);
        console.log("=======================");
        console.log("Next steps for upgrade:");
        console.log("1. Deploy V2 implementation contracts");
        console.log("2. Call upgradeToAndCall method on the proxy contracts");
        console.log("3. Use signature features after upgrade");
        console.log("=======================");
    }
} 