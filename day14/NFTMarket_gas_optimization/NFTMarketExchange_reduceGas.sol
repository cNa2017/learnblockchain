// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/**
 * @title ERC20_Extend、ERC721_cna、NFTMarket
 * @dev 这是一个NFT市场合约，用于测试NFT使用ERC20Token来交易，实现了ERC20_Extend、ERC721_cna、NFTMarket三个合约。

 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract ERC20_Extend is ERC20Permit {

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, initialSupply);
    }

    function transferWithCallback(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        _transfer(msg.sender, recipient, amount);//从用户账号转给合约
        if (recipient.code.length>0) {//判断是否合约
            bool r = NFTMarket2(recipient).tokensReceived(msg.sender, amount, data);//
            require(r, "No tokensReceived");
        }
        return true;
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
contract NFTMarket2  {
    // 使用库
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // 事件定义
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TokensReceived(uint256 indexed tokenId, address indexed buyer, uint256 price, uint256 amount);
    event WhitelistPurchase(uint256 indexed tokenId, address indexed buyer, uint256 price);

    error NotOwnerOfNFT();
    error PriceMustBeGreaterThanZero();
    error NFTNotListedForSale();
    error TokenTransferFailed();
    error PermitExpired();
    error InvalidSignature();
    error NotFromOurTokenContract();    

    ERC20_Extend private _token;
    ERC721_cna private _nft;
    address public immutable projectSigner; // 项目方签名者地址
    // NFT购买意图标识
    bytes4 private constant BUY_NFT_SELECTOR = bytes4(keccak256("buyNFT(uint256)"));
    
    struct Listing {
        address seller;
        bool active;
        uint256 price;
    }
    
    // NFT ID => Listing信息
    mapping(uint256 => Listing) public listings;
    
    
    constructor(address tokenAddress, address nftAddress, address _projectSigner) {
        _token = ERC20_Extend(tokenAddress);
        _nft = ERC721_cna(nftAddress);
        projectSigner = _projectSigner;
    }
    
    // 上架NFT
    function list(uint256 tokenId, uint256 price) external {
        address seller = msg.sender;
        if (_nft.ownerOf(tokenId) != seller) revert NotOwnerOfNFT();
        if (price == 0) revert PriceMustBeGreaterThanZero();
        
        // 将NFT转移到市场合约
        _nft.transferFrom(seller, address(this), tokenId);
        
        // 创建上架信息
        listings[tokenId] = Listing({
            seller: seller,
            active: true,
            price: price
        });
        
        // 触发上架事件
        emit Listed(tokenId, seller, price);
    }
    
    // 普通购买NFT功能
    function buyNFT(uint256 tokenId) external {
        // Listing memory listing = listings[tokenId];
        if (!listings[tokenId].active) revert NFTNotListedForSale();
        
        // 转移代币
        if (!_token.transferFrom(msg.sender, listings[tokenId].seller, listings[tokenId].price)) revert TokenTransferFailed();
        
        // 转移NFT
        _nft.transferFrom(address(this), msg.sender, tokenId);
        
        // 更新上架状态
        listings[tokenId].active = false;
        
        // 触发购买事件
        emit Bought(tokenId, msg.sender, listings[tokenId].price);
    }
    
    // 白名单授权购买NFT
    function permitBuy(
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline) revert PermitExpired();
        
        // Listing memory listing = listings[tokenId];
        if (!listings[tokenId].active) revert NFTNotListedForSale();
        
        // 构建消息哈希：买家地址 + tokenId + deadline
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, tokenId, deadline));// 可能有坑 ，可能使用encodePacked
        bytes32 message = hash.toEthSignedMessageHash();
        
        // 验证签名是否来自项目方
        address recoveredSigner = message.recover(v, r, s);
        if (recoveredSigner != projectSigner) revert InvalidSignature();
        
        // 转移代币
        if (!_token.transferFrom(msg.sender, listings[tokenId].seller, listings[tokenId].price)) revert TokenTransferFailed();
        
        // 转移NFT
        _nft.transferFrom(address(this), msg.sender, tokenId);
        
        // 更新上架状态
        listings[tokenId].active = false;
        
        // 触发白名单购买事件
        emit WhitelistPurchase(tokenId, msg.sender, listings[tokenId].price);
    }

    // 实现tokensReceived回调函数
    function tokensReceived(address from, uint256 amount, bytes memory data) external returns (bool) {
        if (msg.sender != address(_token)) revert NotFromOurTokenContract();
        
        // 解析data参数，确定是否为购买NFT的操作
        if (data.length >= 4) {
            bytes4 selector;
            assembly {
                selector := mload(add(data, 32))
            }
            
            if (selector == BUY_NFT_SELECTOR && data.length >= 36) {
                // 解析tokenId
                uint256 tokenId;
                assembly {
                    tokenId := mload(add(data, 36))
                }
                
                // Listing memory listing = listings[tokenId];
                require(listings[tokenId].active, "NFT not listed for sale");
                require(amount >= listings[tokenId].price, "Insufficient payment");
                
                // 如果支付金额超过价格，退还多余的代币
                if (amount > listings[tokenId].price) {
                    uint256 refund = amount - listings[tokenId].price;
                    require(_token.transfer(from, refund), "Refund failed");
                }
                
                // 将代币转给卖家
                require(_token.transfer(listings[tokenId].seller, listings[tokenId].price), "Payment to seller failed");
                
                // 转移NFT
                _nft.transferFrom(address(this), from, tokenId);
                
                // 更新上架状态
                listings[tokenId].active = false;
                
                // 触发代币接收事件
                emit TokensReceived(tokenId, from, listings[tokenId].price, amount);
            }
        }
        
        return true;
    }

}

// contract abiUtils{
//     function getSelector(uint tokenId) public pure returns (bytes memory){
//         bytes4 selector = NFTMarket.buyNFT.selector;
//         return abi.encodeWithSelector(selector,tokenId);
//     }
// }