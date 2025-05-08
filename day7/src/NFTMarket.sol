// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyERC20
 * @dev 一个简单的ERC20代币合约，用于NFT市场交易
 */
contract MyERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }
}

/**
 * @title MyNFT
 * @dev 一个简单的NFT合约，支持铸造和设置URI
 */
contract MyNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @dev 铸造新的NFT
     * @param to 接收NFT的地址
     * @param uri NFT的元数据URI
     * @return 新铸造的NFT的tokenId
     */
    function mint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }
}

/**
 * @title NFTMarket
 * @dev NFT市场合约，支持使用ERC20代币购买NFT
 */
contract NFTMarket {
    using SafeERC20 for IERC20;

    // NFT上架信息结构
    struct Listing {
        address seller;
        address tokenAddress;  // ERC20代币地址
        uint256 price;
        bool active;
    }

    // NFT ID => Listing信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 事件定义
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, address tokenAddress, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address seller, address buyer, address tokenAddress, uint256 price);
    event NFTListingCancelled(address indexed nftContract, uint256 indexed tokenId, address indexed seller);

    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param tokenAddress ERC20代币地址（用于支付）
     * @param price NFT价格（以ERC20代币计价）
     */
    function listNFT(address nftContract, uint256 tokenId, address tokenAddress, uint256 price) external {
        require(price > 0, "Price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(IERC721(nftContract).getApproved(tokenId) == address(this) || 
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)), 
                "Market not approved to transfer this NFT");

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            tokenAddress: tokenAddress,
            price: price,
            active: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, tokenAddress, price);
    }

    /**
     * @dev 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function buyNFT(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "NFT not listed for sale");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        // 更新上架状态
        listings[nftContract][tokenId].active = false;

        // 转移ERC20代币从买家到卖家
        IERC20(listing.tokenAddress).safeTransferFrom(msg.sender, listing.seller, listing.price);

        // 转移NFT从卖家到买家
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        emit NFTSold(nftContract, tokenId, listing.seller, msg.sender, listing.tokenAddress, listing.price);
    }

    /**
     * @dev 取消NFT上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "NFT not listed for sale");
        require(listing.seller == msg.sender, "Not the seller of this NFT");

        listings[nftContract][tokenId].active = false;

        emit NFTListingCancelled(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev 获取NFT上架信息
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @return 上架信息
     */
    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }
}