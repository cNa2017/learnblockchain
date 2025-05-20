// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/**
 * @title ERC20_Extend、ERC721_cna、AirdropMerkleNFTMarket
 * @dev 这是一个NFT市场合约，用于测试NFT使用ERC20Token来交易，实现了ERC20_Extend、ERC721_cna、AirdropMerkleNFTMarket三个合约。
        基于 Merkel 树验证某用户是否在白名单中,白名单用户可以半价购买NFT
        Token 支持 permit 授权
        使用openzeppelin的 Multicall 来一次性执行多个交易
 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

contract ERC20_Extend is ERC20Permit {

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, initialSupply);
    }

}

// NFT合约实现
contract ERC721_cna is ERC721URIStorage,Ownable {
    uint256 private _nextTokenId;

    constructor(address owner) ERC721("NFT_cna7_7", "cna7_7")  Ownable(owner){}

    function awardItem(address player, string memory tokenURI) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(player, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}

// NFT市场合约
contract AirdropMerkleNFTMarket is Multicall {
    // 使用库
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // 事件定义
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price);

    ERC20_Extend private _token;
    ERC721_cna private _nft;
    /** 
      *  白名单用户
      *  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
      *  0x70997970C51812dc3A010C7d01b50e0d17dc79C8
      *  0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
      *  0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
      */
    bytes32 public _merkleRoot;// 默克尔树根

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }
    
    // NFT ID => Listing信息
    mapping(uint256 => Listing) public listings;
    
    constructor(address tokenAddress, address nftAddress, bytes32 merkleRoot) {
        _token = ERC20_Extend(tokenAddress);
        _nft = ERC721_cna(nftAddress);
        _merkleRoot = merkleRoot;//0xca7a481464fd97c8919a4469dbfac0f8b9d7b8afb8195bf912610537e4f6b7c5
    }
    
    // 上架NFT
    function list(uint256 tokenId, uint256 price) external {
        require(_nft.ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(price > 0, "Price must be greater than 0");
        
        // 将NFT转移到市场合约
        _nft.transferFrom(msg.sender, address(this), tokenId);
        
        // 创建上架信息
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });
        
        // 触发上架事件
        emit Listed(tokenId, msg.sender, price);
    }
    
    // 普通购买NFT功能
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.active, "NFT not listed for sale");
        
        // 转移代币
        require(_token.transferFrom(msg.sender, listing.seller, listing.price), "Token transfer failed");
        
        // 转移NFT
        _nft.transferFrom(address(this), msg.sender, tokenId);
        
        // 更新上架状态
        listings[tokenId].active = false;
        
        // 触发购买事件
        emit Bought(tokenId, msg.sender, listing.price);
    }

    // permit token的 permit 进行授权
    function permitPrePay(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp <= deadline, "Permit expired");
        // 授权
        _token.permit(msg.sender, address(this), amount, deadline, v, r, s);
    }

    // 通过默克尔树验证某用户是否在白名单中，白名单用户可以半价购买NFT
    function claimNFT(uint256 tokenId, bytes32[] calldata proof) external {
        Listing memory listing = listings[tokenId];
        require(listing.active, "NFT not listed for sale");
        
        // 计算用户的叶子节点值
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        
        // 验证默克尔树
        uint256 price;
        if (MerkleProof.verify(proof, _merkleRoot, leaf)) {
            // 白名单用户半价
            price = listing.price / 2;
        } else {
            // 非白名单用户全价
            price = listing.price;
        }

        // 转移代币
        require(_token.transferFrom(msg.sender, listing.seller, price), "Token transfer failed");
        
        // 转移NFT
        _nft.transferFrom(address(this), msg.sender, tokenId);
        
        // 更新上架状态
        listings[tokenId].active = false;
        
        // 触发购买事件
        emit Bought(tokenId, msg.sender, price);
    }

    // 使用继承的Multicall接口，不需要再单独实现multicall方法
}
