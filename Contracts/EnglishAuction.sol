// SPDX-License-Identifier: MIT


pragma solidity ^0.8.7;

interface IERC721 {

    function transferFrom(

        address from,

        address to, uint nftId

        ) external;

}

contract EnglishAuction{

    event Start();

    event Bid(address indexed sender, uint amount);

    event Withdraw(address indexed bidder, uint amount);

    event End(address highestBidder, uint amount);

    // NFT STATE VARIABLES

    IERC721 public immutable nft;

    uint public immutable nftId;

    // STATE VARIABLES FOR AUCTION INFORMATION

    address payable public immutable seller;

    uint32 public endAuction;

    bool public hasStarted;

    bool public hasEnded;

    // STATE VARIABLES RELEVANT TO BIDDERS

    address public highestBidder;

    uint public highestBid;

    mapping(address => uint) public totalBids;

    constructor(address _nft, uint _nftId, uint _startingPrice){

        nft = IERC721(_nft);

        nftId = _nftId;

        seller = payable(msg.sender);

        highestBid = _startingPrice;

    }

    function startAuction(uint32 durationInSeconds) external{

        require(msg.sender == seller, "You are unauthorized to start this auction.");

        require(!hasStarted, "The auction has started");

        hasStarted = true;

        // SET AUCTION END SATE TO 7 DAYS

        endAuction = uint32(block.timestamp + durationInSeconds);


        // TRANSFER OWNERSHIP OF NFT FROM SELLER TO CONTRACT

        nft.transferFrom(seller, address(this), nftId);

        emit Start();

    }

    function bidPrice() external payable{

        require(hasStarted, "English auction has not started");

        require(block.timestamp < endAuction, "English auction has ended");

        require(msg.value>highestBid, "You cannot bid a lower amount. This is an English auction");

        // KEEP RECORD OF TOTAL BIDS THAT ARE NOT THE HIGHEST BID

        if (highestBidder != address(0)){

            totalBids[highestBidder] += highestBid;

        }

        // ASSIGN HIGHEST BID

        highestBid = msg.value;

        // ASSIGN HIGHEST BIDDER

        highestBidder = msg.sender;

        emit Bid(msg.sender, msg.value);

    }

    function withdrawBids() external{

        uint balances = totalBids[msg.sender];

        // RESET THE AMOUNT TOTAL BIDS BEFORE TRANSFERRING TO PREVENT REENTRANCY

        totalBids[msg.sender] = 0;

        // TRANSFER BIDS

        payable(msg.sender).transfer(balances);

        emit Withdraw(msg.sender, balances);

    }

    function end() external{

        require(hasStarted, "The auction has not started yet");

        require(!hasEnded, "The auction is still in progress");

        require(block.timestamp>=endAuction);

        hasEnded = true;

        // CHECK IF SOMEONE BIDDED FOR THE NFT AND WHO THE HIGHEST BIDDER IS

        if(highestBidder != address(0)){

            nft.transferFrom(address(this), highestBidder, nftId);

            seller.transfer(highestBid);

        }else{

            nft.transferFrom(address(this), seller, nftId);

        }

        emit End(highestBidder, highestBid);

    }

}