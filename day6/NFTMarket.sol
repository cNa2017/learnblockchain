// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
            bool r = TokenBankV2(recipient).tokensReceived(msg.sender, amount, data);//
            require(r, "No tokensReceived");
        }
        return true;
    }

}


contract TokenBankV2 {

    ERC20_Extend immutable tokenContract;
    mapping (address =>uint256) public balances;

    constructor(address _tokenAddress){
        //初始化代币
        tokenContract = ERC20_Extend(_tokenAddress);
    
    }

    function deposit(uint256 _value)public{
        require(tokenContract.allowance(msg.sender, address(this))>= _value, "deposit: transfer amount exceeds allowance TokenBank");
        tokenContract.transferFrom(msg.sender,address(this),_value);//转账
        balances[msg.sender] += _value;//增加银行余额
    }
    function withdraw(uint256 _value) public{
        require (balances[msg.sender]>=_value, "withdraw: transfer amount exceeds balance TokenBank");//取钱余额检查
        balances[msg.sender]-= _value; //减少银行余额
        tokenContract.transfer(msg.sender, _value);

    }

    function checkNaticeBalance()public view returns(uint256 ){
        uint256 balance = tokenContract.balanceOf(msg.sender);
        return balance;
    }

    function tokensReceived (address _from, uint256 _value, bytes memory _data) external returns(bool) {
        require(msg.sender == address(tokenContract),"not the expected token");//检查是否是Token合约
        balances[_from]+= _value; //增加银行余额
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