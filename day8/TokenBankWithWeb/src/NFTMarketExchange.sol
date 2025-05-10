// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
 * @title ERC20_Extend、ERC721_cna、NFTMarket
 * @dev 这是一个NFT市场合约，用于测试NFT使用ERC20Token来交易，实现了ERC20_Extend、ERC721_cna、NFTMarket三个合约。

 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract ERC20_Extend is ERC20 {

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        _mint(msg.sender, initialSupply);
    }

    function transferWithCallback(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        _transfer(msg.sender, recipient, amount);//从用户账号转给合约
        if (recipient.code.length>0) {//判断是否合约
            bool r = NFTMarket(recipient).tokensReceived(msg.sender, amount, data);//
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
contract NFTMarket  {
    // 事件定义
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TokensReceived(uint256 indexed tokenId, address indexed buyer, uint256 price, uint256 amount);

    ERC20_Extend private _token;
    ERC721_cna private _nft;
    
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }
    
    // NFT ID => Listing信息
    mapping(uint256 => Listing) public listings;
    
    // NFT购买意图标识
    bytes4 private constant BUY_NFT_SELECTOR = bytes4(keccak256("buyNFT(uint256)"));
    
    constructor(address tokenAddress, address nftAddress) {
        _token = ERC20_Extend(tokenAddress);
        _nft = ERC721_cna(nftAddress);
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
    

    
    // 实现tokensReceived回调函数
    function tokensReceived(address from, uint256 amount, bytes memory data) external returns (bool) {
        require(msg.sender == address(_token), "Not from our token contract");
        
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
                
                Listing memory listing = listings[tokenId];
                require(listing.active, "NFT not listed for sale");
                require(amount >= listing.price, "Insufficient payment");
                
                // 如果支付金额超过价格，退还多余的代币
                if (amount > listing.price) {
                    uint256 refund = amount - listing.price;
                    require(_token.transfer(from, refund), "Refund failed");
                }
                
                // 将代币转给卖家
                require(_token.transfer(listing.seller, listing.price), "Payment to seller failed");
                
                // 转移NFT
                _nft.transferFrom(address(this), from, tokenId);
                
                // 更新上架状态
                listings[tokenId].active = false;
                
                // 触发代币接收事件
                emit TokensReceived(tokenId, from, listing.price, amount);
            }
        }
        
        return true;
    }

    
}

contract abiUtils{
    function getSelector(uint tokenId) public pure returns (bytes memory){
        bytes4 selector = NFTMarket.buyNFT.selector;
        return abi.encodeWithSelector(selector,tokenId);
    }
}