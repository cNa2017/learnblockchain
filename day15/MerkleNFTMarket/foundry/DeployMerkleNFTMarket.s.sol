// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {AirdropMerkleNFTMarket, ERC20_Extend, ERC721_cna} from "../src/AirdropMerkleNFTMarket.sol";

contract DeployMerkleNFTMarket is Script {
    // 白名单用户地址
    address[] public whitelistAddresses = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
    ];

    // 计算默克尔树叶子节点
    function getLeaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    // 计算默克尔树根
    function generateMerkleRoot() internal view returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](whitelistAddresses.length);
        
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            leaves[i] = getLeaf(whitelistAddresses[i]);
        }

        return buildMerkleTree(leaves);
    }

    // 计算两个节点的哈希值（使用与OpenZeppelin相同的方法）
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a);
    }

    // 高效的keccak256实现，不进行内存分配
    function efficientKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    // 构建默克尔树并返回根
    function buildMerkleTree(bytes32[] memory elements) internal pure returns (bytes32) {
        require(elements.length > 0, "No elements");
        
        // 如果只有一个元素，直接返回
        if (elements.length == 1) {
            return elements[0];
        }

        // 递归构建树
        uint256 length = elements.length;
        uint256 levelLength = (length + 1) / 2;
        bytes32[] memory nextLevel = new bytes32[](levelLength);
        
        for (uint256 i = 0; i < length; i += 2) {
            if (i + 1 < length) {
                nextLevel[i/2] = hashPair(elements[i], elements[i+1]);
            } else {
                nextLevel[i/2] = elements[i];
            }
        }
        
        return buildMerkleTree(nextLevel);
    }

    function run() external {
        uint256 sellerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        address seller = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        // 计算默克尔树根
        bytes32 merkleRoot = generateMerkleRoot();
        console.log("Merkle Root: ");
        console.logBytes32(merkleRoot);

        uint256 deployerPrivateKey = vm.envUint("LOCAL_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署合约
        ERC20_Extend token = new ERC20_Extend(500 * 10**18);
        ERC721_cna nft = new ERC721_cna(msg.sender);
        AirdropMerkleNFTMarket market = new AirdropMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );
        console.log("Market deployed at: ", address(market));
        console.log("Token deployed at: ", address(token));
        console.log("NFT deployed at: ", address(nft));

        uint256 tokenId = nft.awardItem(seller, "https://example.com/nft/1");

        vm.stopBroadcast();

                // 卖家的广播
        vm.startBroadcast(sellerPrivateKey);
        nft.approve(address(market), 0);
        market.list(0, 1000 * 10**18);
        vm.stopBroadcast();
    }
} 