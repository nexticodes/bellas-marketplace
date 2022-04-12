// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// security guard, protect transactions that are actually talking to contract to prevent somebody from hitting this address with multiple transactions (reentry attacks)
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    // keep track of # items sold
    // arrays in solidity cannot be dynamically linked.
    Counters.Counter private _itemsSold;

    // want to determine who the owner of the contract is as they will earn commission on txns(listing fee)
    address payable owner;
    // Ether can be considered as MATIC in this case.
    uint256 listingPrice = 0.025 ether;

    // owner of the contract is the person deploying it.
    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    // hashmap (itemId: marketItem)
    mapping(uint256 => MarketItem) private idToMarketItem;

    // Event for when MarketItem is created.
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    // function for creating market item.
    // nonreentrant "modifier" prevents reentry attacks
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        // Require price to be more than 0, otherwise display message.
        require(price > 0, "Price must be at least 1 wei");
        // require the user sending txn to pass in required listing price.
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        // Add to mapping
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            // Pass empty address for owner
            payable(address(0)),
            price,
            false
        );

        // Transfer NFT ownership from seller to the NFT contract.
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    function createMarketSale(
        address nftContract,
        uint256 itemId
    ) public payable nonReentrant {
        // Get a reference to the price and tokenId (for extra verification) by getting the mapping we created above.
        uint price = idToMarketItem[itemId].price;
        uint tokenId = idToMarketItem[itemId].tokenId;

        // require that txn sender provides same price.
        require(msg.value == price, "Please submit the asking price in order to complete the purchase.");

        // Transfer value of transaction to the seller.
        idToMarketItem[itemId].seller.transfer(msg.value);
        // transfer ownership of digital good from contract address to the buyer.
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        // set local owner to the msg sender.
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
        // Transfer the amount defined by listingPrice, set by seller, to the contract owner (commission part).
        payable(owner).transfer(listingPrice);
    }

    // View functions that return items
    function fetchMarketItems() public view returns (MarketItem[] memory){
        uint itemCount = _itemIds.current();
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        // create unsoldItems array w length of unsoldItemCount.
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++){
            // if address(0), means no address
            // check to see if this market item has no address. Meaning unowned.
            // if unowned, include in array of unsold items.
            if (idToMarketItem[i + 1].owner == address(0)){
                uint currentId = idToMarketItem[i+1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }
}
