// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/**
 * @title ERC20_Extend、ERC721_cna_upgradeable、NFTMarket_upgradeable
 * @dev 这是一个NFT市场合约，用于测试NFT使用ERC20Token来交易，实现了ERC721_cna_upgradeable、NFTMarket_upgradeable可升级
        1.ERC721_cna_upgradeableV2 升级了permit功能，使得可以通过线下签名的方式获取nft授权
        2.NFTMarket_upgradeableV2 升级了支持离线签名上架 NFT 功能方法（签名内容：tokenId， 价格），实现用户一次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使用签名上架（不需要再授权NFT，然后再上架）。
 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ERC20_Extend is ERC20Permit {

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, initialSupply);
    }

    function transferWithCallback(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        _transfer(msg.sender, recipient, amount);//从用户账号转给合约
        if (recipient.code.length>0) {//判断是否合约
            bool r = NFTMarket_upgradeable(recipient).tokensReceived(msg.sender, amount, data);//
            require(r, "No tokensReceived");
        }
        return true;
    }

}

// NFT合约实现
contract ERC721_cna_upgradeable is ERC721URIStorageUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, address initialOwner) public initializer {
        __ERC721_init(name, symbol);
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function awardItem(address player, string memory tokenURI) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(player, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}

contract ERC721_cna_upgradeableV2 is ERC721_cna_upgradeable {
    // 使用库
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    // 存储nonce，防止重放攻击
    mapping(address => uint256) private _nonces;
    
    // 存储域分隔符哈希
    bytes32 private _DOMAIN_SEPARATOR;
    
    // EIP712类型哈希
    bytes32 private constant _PERMIT_TYPEHASH = 
        keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    
    // 添加事件
    event PermitApproved(address indexed owner, address indexed spender, uint256 indexed tokenId, uint256 deadline);
    
    // DOMAIN_SEPARATOR计算函数
    function _calculateDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    // 初始化DOMAIN_SEPARATOR
    function initializeV2() public reinitializer(2) {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
    }
    
    // 获取当前用户的nonce值
    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner];
    }
    
    // 获取DOMAIN_SEPARATOR
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == _getChainId() ? _DOMAIN_SEPARATOR : _calculateDomainSeparator();
    }
    
    // 获取当前链ID
    function _getChainId() private view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    // 升级了permit功能，使得可以通过线下签名的方式获取nft授权
    function permit(
        address owner, 
        address spender, 
        uint256 tokenId, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");
        require(ownerOf(tokenId) == owner, "Not token owner");
        
        // 获取当前nonce
        uint256 currentNonce = _nonces[owner];
        
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                tokenId,
                currentNonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Invalid signature");
        
        // 增加nonce
        _nonces[owner] = currentNonce + 1;
        
        // 授权指定地址
        _approve(spender, tokenId, owner, true);
        
        // 触发事件
        emit PermitApproved(owner, spender, tokenId, deadline);
    }
    
    // 批量permit功能，允许一次性授权多个NFT
    function permitBatch(
        address owner, 
        address spender, 
        uint256[] calldata tokenIds, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");
        require(tokenIds.length > 0, "Empty token IDs");
        
        // 验证所有tokenId的所有者都是owner
        _validateOwnership(owner, tokenIds);
        
        // 进行批量授权验证和授权
        _verifyAndApprove(owner, spender, tokenIds, deadline, v, r, s);
    }
    
    // 验证所有tokenId的所有者都是owner
    function _validateOwnership(address owner, uint256[] calldata tokenIds) private view {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == owner, "Not token owner");
        }
    }
    
    // 验证签名并进行批量授权
    function _verifyAndApprove(
        address owner,
        address spender,
        uint256[] calldata tokenIds,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private {
        // 获取当前nonce
        uint256 currentNonce = _nonces[owner];
        
        // 计算tokenIds数组的hash
        bytes32 tokenIdsHash = keccak256(abi.encodePacked(tokenIds));
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PermitBatch(address owner,address spender,bytes32 tokenIdsHash,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                tokenIdsHash,
                currentNonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Invalid signature");
        
        // 增加nonce
        _nonces[owner] = currentNonce + 1;
        
        // 授权每个tokenId
        for(uint256 i = 0; i < tokenIds.length; i++) {
            _approve(spender, tokenIds[i], owner, true);
            emit PermitApproved(owner, spender, tokenIds[i], deadline);
        }
    }
}

// NFT市场合约
contract NFTMarket_upgradeable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 使用库
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // 事件定义
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TokensReceived(uint256 indexed tokenId, address indexed buyer, uint256 price, uint256 amount);

    ERC20_Extend public _token;
    ERC721_cna_upgradeable public _nft;
    
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }
    
    // NFT ID => Listing信息
    mapping(uint256 => Listing) public listings;
    
    // NFT购买意图标识
    bytes4 private constant BUY_NFT_SELECTOR = bytes4(keccak256("buyNFT(uint256)"));
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address tokenAddress, address nftAddress) public initializer {
        _token = ERC20_Extend(tokenAddress);
        _nft = ERC721_cna_upgradeable(nftAddress);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // 上架NFT
    function list(uint256 tokenId, uint256 price) external {
        require(_nft.ownerOf(tokenId) == msg.sender, "Not your NFT");
        require(_nft.getApproved(tokenId) == address(this) || _nft.isApprovedForAll(msg.sender, address(this)), "NFT not approved");
        require(price > 0, "Price must be > 0");
        
        _nft.transferFrom(msg.sender, address(this), tokenId);
        
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit Listed(tokenId, msg.sender, price);
    }
    
    // 购买NFT
    function buyNFT(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.active, "NFT not listed");
        
        require(_token.transferFrom(msg.sender, listing.seller, listing.price), "Payment failed");
        _nft.transferFrom(address(this), msg.sender, tokenId);
        
        listing.active = false;
        
        emit Bought(tokenId, msg.sender, listing.price);
    }
    

    
    // 从授权的ERC20合约接收代币的回调函数
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool) {
        require(msg.sender == address(_token), "Only token contract");
        require(data.length >= 4, "Invalid data");
        
        bytes4 selector;
        assembly {
            selector := calldataload(data.offset)
        }
        
        if (selector == BUY_NFT_SELECTOR) {
            require(data.length >= 36, "Invalid buy data");
            
            uint256 tokenId;
            assembly {
                tokenId := calldataload(add(data.offset, 4))
            }
            
            Listing storage listing = listings[tokenId];
            require(listing.active, "NFT not listed");
            require(amount >= listing.price, "Insufficient payment");
            
            if (amount > listing.price) {
                // 退还多余的代币
                require(_token.transfer(from, amount - listing.price), "Refund failed");
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
        
        return true;
    }

}

contract NFTMarket_upgradeableV2 is NFTMarket_upgradeable {
    // 使用库
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    // 添加签名上架事件
    event ListedWithSignature(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 nonce);
    event BatchListedWithSignature(address indexed seller, uint256[] tokenIds, uint256[] prices, uint256 nonce);
    
    // 存储NFT所有者的nonce
    mapping(address => mapping(uint256 => uint256)) private _listingNonces;
    // 存储批量上架的nonce
    mapping(address => uint256) private _batchListingNonces;
    
    // EIP712类型哈希
    bytes32 private constant _LIST_WITH_SIGNATURE_TYPEHASH = 
        keccak256("ListWithSignature(address owner,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)");
    bytes32 private constant _BATCH_LIST_WITH_SIGNATURE_TYPEHASH = 
        keccak256("BatchListWithSignature(address owner,bytes32 tokenIdsHash,bytes32 pricesHash,uint256 nonce,uint256 deadline)");
    
    // 存储域分隔符哈希
    bytes32 private _DOMAIN_SEPARATOR;
    
    // 初始化DOMAIN_SEPARATOR
    function initializeV2() public reinitializer(2) {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
    }
    
    // DOMAIN_SEPARATOR计算函数
    function _calculateDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarket")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    // 获取DOMAIN_SEPARATOR
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == _getChainId() ? _DOMAIN_SEPARATOR : _calculateDomainSeparator();
    }
    
    // 获取当前链ID
    function _getChainId() private view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
    
    // 获取指定NFT的nonce
    function listingNonces(address owner, uint256 tokenId) public view returns (uint256) {
        return _listingNonces[owner][tokenId];
    }
    
    // 获取批量上架nonce
    function batchListingNonces(address owner) public view returns (uint256) {
        return _batchListingNonces[owner];
    }
    
    // 离线签名上架 NFT 功能方法（签名内容：tokenId， 价格），实现用户一次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使用签名上架（不需要再授权NFT，然后再上架）。
    function listWithSignature(
        address owner,
        uint256 tokenId, 
        uint256 price, 
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        require(price > 0, "Price must be > 0");
        require(_nft.ownerOf(tokenId) == owner, "Not owner's NFT");
        require(_nft.isApprovedForAll(owner, address(this)), "NFT not approved for all");
        
        // 获取当前nonce
        uint256 currentNonce = _listingNonces[owner][tokenId];
        
        bytes32 structHash = keccak256(
            abi.encode(
                _LIST_WITH_SIGNATURE_TYPEHASH,
                owner,
                tokenId,
                price,
                currentNonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Invalid signature");
        
        // 增加nonce
        _listingNonces[owner][tokenId] = currentNonce + 1;
        
        // 转移NFT到市场合约
        _nft.transferFrom(owner, address(this), tokenId);
        
        // 创建上架信息
        listings[tokenId] = Listing({
            seller: owner,
            price: price,
            active: true
        });
        
        // 触发签名上架事件
        emit ListedWithSignature(tokenId, owner, price, currentNonce);
    }
    
    // 批量签名上架NFT
    function batchListWithSignature(
        address owner,
        uint256[] calldata tokenIds,
        uint256[] calldata prices,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        require(tokenIds.length > 0, "No tokens to list");
        require(tokenIds.length == prices.length, "Arrays length mismatch");
        require(_nft.isApprovedForAll(owner, address(this)), "NFT not approved for all");
        
        // 校验所有NFT归属权
        for(uint256 i = 0; i < tokenIds.length; i++) {
            require(_nft.ownerOf(tokenIds[i]) == owner, "Not owner's NFT");
            require(prices[i] > 0, "Price must be > 0");
        }
        
        // 获取当前批量上架nonce
        uint256 currentNonce = _batchListingNonces[owner];
        
        // 计算tokenIds和prices数组的hash
        bytes32 tokenIdsHash = keccak256(abi.encodePacked(tokenIds));
        bytes32 pricesHash = keccak256(abi.encodePacked(prices));
        
        bytes32 structHash = keccak256(
            abi.encode(
                _BATCH_LIST_WITH_SIGNATURE_TYPEHASH,
                owner,
                tokenIdsHash,
                pricesHash,
                currentNonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Invalid signature");
        
        // 增加批量nonce
        _batchListingNonces[owner] = currentNonce + 1;
        
        // 批量转移NFT并创建上架信息
        for(uint256 i = 0; i < tokenIds.length; i++) {
            _nft.transferFrom(owner, address(this), tokenIds[i]);
            
            // 创建上架信息
            listings[tokenIds[i]] = Listing({
                seller: owner,
                price: prices[i],
                active: true
            });
        }
        
        // 触发批量上架事件
        emit BatchListedWithSignature(owner, tokenIds, prices, currentNonce);
    }
}
