// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "./EnglishAuction.sol";


/**
 * @title MarketPlace
 * @dev A decentralized marketplace.
 */
//Creating a interface of english auction
interface IEnglishAuction {
    function startAuction(uint32 durationInSeconds) external;
    function bidPrice() external payable;
    function withdrawBids() external;
    function end() external;
}


contract MarketPlace is ERC721, ERC721Enumerable, Ownable{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("MarketPlace", "MP") {}

    /**
     * @dev Mint a new ERC721 token and assign it to the specified address.
     * @param to The address to receive the newly minted token.
     */
    function safeMint(address to) public {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
    }

    mapping(uint256 => string) public inscriptionMessages;

    /**
     * @dev Set an inscription message for a specific token.
     * @param tokenId The ID of the token.
     * @param message The inscription message to set.
     */
    function inscribe(uint256 tokenId, string memory message) public {
        require(_exists(tokenId), "Token does not exist");

        inscriptionMessages[tokenId] = message;

        emit Inscription(tokenId, message);
    }

    event Inscription(uint256 indexed tokenId, string message);

    /**
     * @dev Get the inscription message for a specific token.
     * @param tokenId The ID of the token.
     * @return The inscription message.
     */
    function getMessage(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        return inscriptionMessages[tokenId];
    }

    

    struct Listing {
        address seller;
        uint256 price;
        bool active;
        address contractAddress;
    }

    mapping(uint256 => Listing) private tokenListings;

    /**
     * @dev List a token for sale.
     * @param tokenId The ID of the token to list.
     * @param price The sale price of the token.
     */
    function listItem(uint256 tokenId, uint256 price) public {
        require(_exists(tokenId), "Token does not exist");

        tokenListings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true,
            contractAddress: address(this)
        });

        approve(address(this), tokenId);
    }

    /*
     * @dev Get the listing information for a specific token.
     * @param tokenId The ID of the token.
     * @return The seller's address, sale price, and listing status.
     */
    function getTokenListing(uint256 tokenId) public view returns (address seller, uint256 price, bool active) {
        require(tokenListings[tokenId].active, "Token is not listed");

        Listing memory listing = tokenListings[tokenId];

        return (listing.seller, listing.price, listing.active);
    }


    event ItemPurchased(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 paymentAmount
    );

    /**
     * @dev Purchase an item listed for sale.
     * @param tokenId The ID of the token to purchase.
     * @param paymentAmount The amount of ETH sent as payment.
     */
    function buyItem(uint256 tokenId, uint256 paymentAmount) public payable {
        Listing storage listing = tokenListings[tokenId];
        require(listing.active, "Token is not listed");
        require(msg.sender != listing.seller, "Seller cannot buy their own item");
        require(msg.value >= paymentAmount, "Insufficient payment");

        address buyer = msg.sender;
        address payable seller = payable(listing.seller);

        // Check if the contract is approved to transfer the token
        require(
            IERC721(listing.contractAddress).getApproved(tokenId) == address(this),
            "Contract is not approved to transfer the token"
        );

        // Transfer ownership of the token
        IERC721(listing.contractAddress).safeTransferFrom(seller, buyer, tokenId);

        // Remove the listing
        delete tokenListings[tokenId];

        // Transfer the payment to the seller
        seller.transfer(paymentAmount);

        emit ItemPurchased(tokenId, seller, buyer, paymentAmount);
    }

    /**
     * @dev Transfer a token from one address to another.
     * @param from The address transferring the token.
     * @param to The address receiving the token.
     * @param tokenId The ID of the token to transfer.
     */
    function transfer(address from, address to, uint256 tokenId) public {
        approve(address(this), tokenId);
        transferFrom(from, to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

     /**
     * @dev Start an auction for a specific token.
     * @param tokenId The ID of the token to start the auction for.
     * @param auctionContractAddress The address of the EnglishAuction contract.
     * @param auctionDurationInSeconds The duration of the auction in seconds.
     */

  struct Auction {
    address auctionContractAddress;
    uint32 durationInSeconds;
}

mapping(uint256 => Auction) private tokenAuctions;

function createAuction(
    uint256 tokenId,
    address auctionContractAddress,
    uint32 auctionDurationInSeconds
) public onlyOwner {
    require(_exists(tokenId), "Token does not exist");

    IEnglishAuction auction = IEnglishAuction(auctionContractAddress);

    // Start the auction for the token
    auction.startAuction(auctionDurationInSeconds);

    // Create a new Auction struct
    tokenAuctions[tokenId] = Auction({
        auctionContractAddress: auctionContractAddress,
        durationInSeconds: auctionDurationInSeconds
    });

    // Remove approval from the marketplace contract
    approve(address(0), tokenId);
}
    /**
     * @dev Place a bid on the auction for a specific token.
     * @param tokenId The ID of the token to place a bid on.
     */
 function placeBid(uint256 tokenId) public payable {
    Auction storage auction = tokenAuctions[tokenId];
    require(auction.auctionContractAddress != address(0), "Auction not created for this token");
    
    IEnglishAuction auctionContract = IEnglishAuction(auction.auctionContractAddress);
    
    // Place a bid on the auction
    auctionContract.bidPrice{value: msg.value}();
    
    // Remove approval from the marketplace contract
    approve(address(0), tokenId);
}

function withdrawBids(uint256 tokenId) public {
    Auction storage auction = tokenAuctions[tokenId];
    require(auction.auctionContractAddress != address(0), "Auction not created for this token");
    
    IEnglishAuction auctionContract = IEnglishAuction(auction.auctionContractAddress);
    
    // Withdraw the bids from the auction
    auctionContract.withdrawBids();
    
    // Restore approval to the marketplace contract
    approve(address(this), tokenId);
}

function endAuction(uint256 tokenId) public onlyOwner {
    Auction storage auction = tokenAuctions[tokenId];
    require(auction.auctionContractAddress != address(0), "Auction not created for this token");
    
    IEnglishAuction auctionContract = IEnglishAuction(auction.auctionContractAddress);
    
    // End the auction for the token
    auctionContract.end();
    
    // Remove the auction information
    delete tokenAuctions[tokenId];
    
    // Restore approval to the marketplace contract
    approve(address(this), tokenId);
}


}
