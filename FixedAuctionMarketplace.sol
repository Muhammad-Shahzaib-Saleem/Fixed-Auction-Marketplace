// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FixedAuctionMarketplace is ERC721URIStorage {
    using SafeMath for uint256;
    uint256 public nftPrice = 0.01 ether;
    address payable owner;
    uint256 public set_time = 2 minutes;

    event NftSale(address, uint256 tokenId);
    event BuyFixedPrice(address owner, address buyer, uint256 TokenId);
    event NewBidding(uint256 indexed tokenId, uint256 indexed price);
    event BidOfferAccepted(
        uint256 indexed tokenId,
        uint256 indexed price,
        address from,
        address to
    );

    mapping(address => uint256) public bidsInfo;

    struct marketNFT {
        uint256 price;
        address owner;
        uint256 sell;
        address buyer;
        bool onsale;
    }

    struct bids {
        uint256 bidId;
        bool on_Bidding;
        uint256 openingTime;
        uint256 closingTime;
        uint256 bidPrice;
        address highestBidder;
        address[] Allbidders;
        uint256 value;
        uint256 i;
    }

    struct BidingsData {
        uint256 paid;
        bool bidded;
    }

    mapping(uint256 => marketNFT) public onSale;
    mapping(uint256 => bids) public onBidding;
    mapping(address => mapping(uint256 => BidingsData)) public bidForBidder;

    // event NftCreated(uint256 indexed tokenId,address  owner,address  buyer, uint256 price, bool sold);

    constructor() ERC721("SHAZ", "SHZ") {}

    //Create NFT with Miniting Functionality
    function createNFT(
        address to,
        string memory _tokenURI,
        uint256 _id
    ) public payable returns (uint256 id) {
        require(msg.value >= nftPrice, "Please enter the sufficient amount ");

        id = _id;
        _mint(to, id);
        _setTokenURI(id, _tokenURI);

        return id;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "only NFT owner set put on sale"
        );
        _;
    }

    //Put on sale minting NFT
    function putOnSale(uint256 _tokenId)
        public
        onlyOwner(_tokenId)
        returns (bool)
    {
        onSale[_tokenId].owner = msg.sender;
        onSale[_tokenId].onsale = true;
        emit NftSale(msg.sender, _tokenId);
        return true;
    }

    //Buy put-on Sale NFT only at Fixed Point Price
    function buyFixedPriceMarketNFT(uint256 _id) public payable returns (bool) {
        require(
            msg.value >= onSale[_id].price,
            "send fixed price amount of NFT"
        );
        require(onSale[_id].onsale, "NFT not Put on Sale");
        onSale[_id].sell = msg.value;
        onSale[_id].buyer = msg.sender;
        return true;
    }

    function onFixedPrice(uint256 _id) public returns (bool) {
        uint256 payAmount = onSale[_id].price;
        require(
            onSale[_id].buyer != (address(0)),
            "Buyer address should not 0 & should be correct"
        );

        super._safeTransfer(msg.sender, onSale[_id].buyer, _id, "0x");
        payable(onSale[_id].owner).transfer(onSale[_id].sell);
        payable(owner).transfer(payAmount);
        delete onSale[_id];
        emit BuyFixedPrice(onSale[_id].owner, msg.sender, _id);
        return true;
    }

    //Auction Functionality

    function putNFTForBidding(uint256 _id)
        public
        onlyOwner(_id)
        returns (bool)
    {
        onBidding[_id].on_Bidding = true;
        onBidding[_id].openingTime = block.timestamp;
        onBidding[_id].closingTime = block.timestamp.add(set_time);

        return true;
    }

    function onBid(uint256 _id) public payable {
        require(onBidding[_id].on_Bidding, "Bidding is not open yet");
        require(
            block.timestamp <= onBidding[_id].closingTime,
            "Bidding time is ended"
        );
        require(msg.value > 0, "Price must be non-zero");
        require(_exists(_id), "Non-existent tokenId");
        require(
            onBidding[_id].bidPrice < msg.value,
            "You are paying less price from previous bid"
        );
        onBidding[_id].bidId = onBidding[_id].bidId + 1;
        bidsInfo[msg.sender] = msg.value;
        onBidding[_id].value = msg.value;

        onBidding[_id].Allbidders.push(payable(msg.sender));

        if (onBidding[_id].Allbidders[onBidding[_id].i] != msg.sender) {
            payable(onBidding[_id].Allbidders[onBidding[_id].i]).transfer(
                onBidding[_id].value
            );
            delete onBidding[_id].Allbidders[onBidding[_id].i];
            onBidding[_id].i += 1;
        }

        onBidding[_id].bidPrice = msg.value;
        onBidding[_id].highestBidder = msg.sender;
        bidsInfo[msg.sender] = onBidding[_id].bidId;
        bidForBidder[msg.sender][onBidding[_id].bidId].paid = msg.value;
        bidForBidder[msg.sender][onBidding[_id].bidId].bidded = true;

        emit NewBidding(_id, msg.value);
    }

    function buyOnBid(uint256 _id) external payable {
        require(ownerOf(_id) == msg.sender, "acceptOffer:only owner");
        require(_exists(_id), "Non-existent tokenId");
        require(
            onBidding[_id].highestBidder != address(0),
            "There is no highest bidder address"
        );
        super._safeTransfer(
            msg.sender,
            onBidding[_id].highestBidder,
            _id,
            "0x"
        );

        address payable buyer = payable(msg.sender);
        uint256 amountFee = onBidding[_id].bidPrice;
        buyer.transfer(onBidding[_id].bidPrice.sub(amountFee));
        payable(owner).transfer(amountFee);
        delete onBidding[_id];
        emit BidOfferAccepted(
            _id,
            onBidding[_id].bidPrice,
            msg.sender,
            onBidding[_id].highestBidder
        );
    }
}
