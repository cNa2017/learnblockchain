// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {AirdropMerkleNFTMarket, ERC20_Extend, ERC721_cna} from "../src/AirdropMerkleNFTMarket.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MerkleNFTMarketTest is Test {
    ERC20_Extend public token;
    ERC721_cna public nft;
    AirdropMerkleNFTMarket public market;
    bytes32 public merkleRoot;

    // 测试账户
    address public deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public seller = address(1);
    address public buyer1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public buyer2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public buyer3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public buyer4 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address public buyer5 = address(2);
    // 白名单地址
    address[] public whitelistAddresses = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
    ];

    // 计算叶子节点
    function getLeaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
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

    // 计算默克尔树根
    function generateMerkleRoot() internal view returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](whitelistAddresses.length);
        
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            leaves[i] = getLeaf(whitelistAddresses[i]);
        }

        return buildMerkleTree(leaves);
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

    // 生成白名单地址的merkle证明
    function getProof(address account) internal view returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](whitelistAddresses.length);
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            leaves[i] = getLeaf(whitelistAddresses[i]);
        }

        // 找到账户在叶子节点中的位置
        uint256 index;
        bool found = false;
        bytes32 targetLeaf = getLeaf(account);
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == targetLeaf) {
                index = i;
                found = true;
                break;
            }
        }

        require(found, "Address not in whitelist");

        // 计算证明所需的元素数量
        uint256 count = whitelistAddresses.length;
        uint256 layers = 0;
        while (count > 1) {
            count = (count + 1) / 2;
            layers++;
        }
        
        // 临时存储证明元素
        bytes32[] memory tempProof = new bytes32[](layers);
        uint256 proofIndex = 0;
        
        // 构建默克尔证明
        bytes32[] memory currentLevel = leaves;
        
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                uint256 nextIndex = i / 2;
                
                if (i + 1 < currentLevel.length) {
                    // 计算这一层的哈希
                    nextLevel[nextIndex] = hashPair(currentLevel[i], currentLevel[i+1]);
                    
                    // 如果当前索引是我们寻找的叶子节点的索引，添加相邻节点到证明中
                    if (i == index || i + 1 == index) {
                        tempProof[proofIndex] = (i == index) ? currentLevel[i+1] : currentLevel[i];
                        proofIndex++;
                    }
                } else {
                    nextLevel[nextIndex] = currentLevel[i];
                }
            }
            
            // 更新索引以跟踪下一层中的位置
            index = index / 2;
            currentLevel = nextLevel;
        }
        
        // 创建正确大小的数组
        bytes32[] memory proof = new bytes32[](proofIndex);
        for (uint256 i = 0; i < proofIndex; i++) {
            proof[i] = tempProof[i];
        }
        
        return proof;
    }

    function setUp() public {
        vm.startPrank(deployer);
        
        // 生成默克尔树根
        merkleRoot = generateMerkleRoot();
        console.log("Merkle Root: ");
        console.logBytes32(merkleRoot);
        
        // 部署合约
        token = new ERC20_Extend(1000000 * 10**18);
        nft = new ERC721_cna(deployer);
        market = new AirdropMerkleNFTMarket(address(token), address(nft), merkleRoot);
        
        // 设置卖家
        token.transfer(seller, 10000 * 10**18);
        
        // 铸造NFT给卖家
        uint256 tokenId = nft.awardItem(seller, "https://example.com/nft/1");
        
        vm.stopPrank();
        
        // 卖家上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(0, 1000 * 10**18);
        vm.stopPrank();
        
        // 给白名单用户转账代币
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            vm.prank(deployer);
            token.transfer(whitelistAddresses[i], 2000 * 10**18);
        }
        
        // 给非白名单买家转账代币
        vm.prank(deployer);
        token.transfer(buyer5, 2000 * 10**18);
    }

    function test_WhitelistUserCanClaimWithHalfPrice() public {
        address whitelistUser = whitelistAddresses[0];
        
        // 获取白名单用户的默克尔证明
        bytes32[] memory proof = getProof(whitelistUser);
        
        // 验证证明是否有效
        bytes32 leaf = keccak256(abi.encodePacked(whitelistUser));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        assertTrue(isValid, "Merkle proof should be valid");
        
        // 白名单用户授权并购买NFT
        vm.startPrank(whitelistUser);
        token.approve(address(market), 2000 * 10**18);
        
        // 记录购买前的余额
        uint256 balanceBefore = token.balanceOf(whitelistUser);
        
        // 白名单用户购买NFT
        market.claimNFT(0, proof);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(0), whitelistUser);
        
        // 验证白名单用户支付了半价
        uint256 balanceAfter = token.balanceOf(whitelistUser);
        assertEq(balanceBefore - balanceAfter, 500 * 10**18, "Whitelist user should pay half price");
        
        vm.stopPrank();
    }

    function test_NonWhitelistUserPaysFullPrice() public {
        // 非白名单用户购买NFT
        bytes32[] memory emptyProof = new bytes32[](0);
        
        // 验证空证明是否无效
        bytes32 leaf = keccak256(abi.encodePacked(buyer5));
        bool isValid = MerkleProof.verify(emptyProof, merkleRoot, leaf);
        assertFalse(isValid, "Empty proof should be invalid for non-whitelist user");
        
        // 买家授权并购买NFT
        vm.startPrank(buyer5);
        token.approve(address(market), 2000 * 10**18);
        
        // 记录购买前的余额
        uint256 balanceBefore = token.balanceOf(buyer5);
        
        // 非白名单用户使用空证明购买NFT
        market.claimNFT(0, emptyProof);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(0), buyer5);
        
        // 验证非白名单用户支付了全价
        uint256 balanceAfter = token.balanceOf(buyer5);
        assertEq(balanceBefore - balanceAfter, 1000 * 10**18, "Non-whitelist user should pay full price");
        
        vm.stopPrank();
    }
    // 测试multicall，完成permitPrePay、claimNFT两步操作
    function test_MulticallPermitAndClaimNFT() public {
        // 重新铸造NFT和上架，因为前面的测试已经使用了原来的NFT
        vm.startPrank(deployer);
        uint256 tokenId = nft.awardItem(seller, "https://example.com/nft/2");
        vm.stopPrank();
        
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(1, 1000 * 10**18);
        vm.stopPrank();
        
        // 使用第0个白名单用户
        address whitelistUser = whitelistAddresses[0];
        
        // 获取白名单用户的默克尔证明
        bytes32[] memory proof = getProof(whitelistUser);
        
        // 验证证明是否有效
        bytes32 leaf = keccak256(abi.encodePacked(whitelistUser));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        assertTrue(isValid, "Merkle proof should be valid");
        
        // 使用指定的私钥
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        // 验证私钥对应的地址就是白名单用户
        address derivedAddress = vm.addr(privateKey);
        assertEq(derivedAddress, whitelistUser, "Private key does not match the whitelist user's address");
        
        // 准备permit参数
        uint256 permitAmount = 500 * 10**18; // 半价
        uint256 deadline = block.timestamp + 1 hours;
        
        // 计算permit签名
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("MyToken")),
                keccak256(bytes("1")),
                block.chainid,
                address(token)
            )
        );
        
        bytes32 permitTypeHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                permitTypeHash,
                whitelistUser,
                address(market),
                permitAmount,
                token.nonces(whitelistUser),
                deadline
            )
        );
        
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 创建multicall调用数据
        bytes[] memory multicallData = new bytes[](2);
        
        // 1. permitPrePay调用数据
        multicallData[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            permitAmount,
            deadline,
            v,
            r,
            s
        );
        
        // 2. claimNFT调用数据
        multicallData[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            1,  // 使用新铸造的NFT ID 1
            proof  // 使用白名单用户的证明
        );
        
        // 执行multicall
        vm.startPrank(whitelistUser);
        
        // 记录购买前的余额
        uint256 balanceBefore = token.balanceOf(whitelistUser);
        
        // 通过multicall同时执行permitPrePay和claimNFT
        market.multicall(multicallData);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(1), whitelistUser);
        
        // 验证白名单用户支付了半价
        uint256 balanceAfter = token.balanceOf(whitelistUser);
        assertEq(balanceBefore - balanceAfter, 500 * 10**18, "Whitelist user should pay half price via multicall");
        
        vm.stopPrank();
    }

    
} 