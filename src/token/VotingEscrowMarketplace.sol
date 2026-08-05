// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IVotingEscrow} from "./IVotingEscrow.sol";
import {INodeProperties} from "../node/INodeProperties.sol";

contract VotingEscrowMarketplace is ReentrancyGuard {
    using Address for address payable;

    struct FixedListing {
        address seller;
        uint256 price;
    }

    struct Auction {
        address seller;
        uint256 endTime;
        uint256 reservePrice;
        uint256 minBidIncrement;
        uint256 highestBid;
        address highestBidder;
    }

    struct Offer {
        uint256 tokenId;
        address buyer;
        uint256 amount;
        uint256 expiry;
        bool active;
    }

    uint256 internal constant MIN_AUCTION_DURATION = 1 hours;
    uint256 internal constant MAX_AUCTION_DURATION = 30 days;
    uint256 internal constant ANTI_SNIPE_WINDOW = 10 minutes;
    uint256 internal constant ANTI_SNIPE_EXTENSION = 10 minutes;
    uint256 internal constant NO_OFFER_EXCLUSION = type(uint256).max;

    address public veAddr;

    mapping(uint256 => FixedListing) public fixedListings;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => uint256[]) internal _offerIdsByToken;
    mapping(address => uint256) public proceeds;

    uint256 public nextOfferId;

    event ItemListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event ItemBought(address indexed buyer, uint256 indexed tokenId, uint256 price);
    event ItemCanceled(address indexed seller, uint256 indexed tokenId);
    event SaleCompleted(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event AuctionStarted(
        address indexed seller, uint256 indexed tokenId, uint256 endTime, uint256 reservePrice, uint256 minBidIncrement
    );
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionSettled(uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event AuctionCanceled(address indexed seller, uint256 indexed tokenId);
    event OfferMade(
        uint256 indexed offerId, uint256 indexed tokenId, address indexed buyer, uint256 amount, uint256 expiry
    );
    event OfferCanceled(address indexed buyer, uint256 indexed offerId);
    event OfferAccepted(
        address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 offerId, uint256 amount
    );

    error PriceMustBeAboveZero();
    error NotApprovedForMarketplace();
    error AlreadyListed();
    error NotListed();
    error NotOwner();
    error PriceNotMet();
    error NoProceeds();
    error TokenAttachedToNode();
    error AuctionActive();
    error FixedListingActive();
    error NoActiveAuction();
    error AuctionEnded();
    error AuctionStillLive();
    error BidTooLow();
    error InvalidDuration();
    error InvalidMinBidIncrement();
    error AuctionHasBids();
    error OfferNotActive();
    error OfferExpired();
    error NotOfferBuyer();
    error CannotOfferOnOwnToken();
    error OfferAmountZero();
    error InvalidOfferExpiry();

    modifier notFixedListed(uint256 tokenId) {
        if (fixedListings[tokenId].price > 0) revert AlreadyListed();
        _;
    }

    modifier onlyFixedListed(uint256 tokenId) {
        if (fixedListings[tokenId].price == 0) revert NotListed();
        _;
    }

    modifier isOwner(uint256 tokenId, address spender) {
        if (IERC721(veAddr).ownerOf(tokenId) != spender) revert NotOwner();
        _;
    }

    constructor(address _ve) {
        veAddr = _ve;
    }

    // -------------------------------------------------------------------------
    // Method A (seller) / Method C (buyer) — fixed-price listing
    // -------------------------------------------------------------------------

    function listItem(uint256 tokenId, uint256 price) external notFixedListed(tokenId) isOwner(tokenId, msg.sender) {
        if (price <= 0) revert PriceMustBeAboveZero();
        if (_hasAuction(tokenId)) revert AuctionActive();
        _requireApproved(msg.sender, tokenId);
        _requireNotNodeAttached(tokenId);

        fixedListings[tokenId] = FixedListing(msg.sender, price);
        emit ItemListed(msg.sender, tokenId, price);
    }

    function buyItem(uint256 tokenId) external payable onlyFixedListed(tokenId) nonReentrant {
        FixedListing memory listing = fixedListings[tokenId];
        if (msg.value < listing.price) revert PriceNotMet();

        _completeSale(tokenId, listing.seller, msg.sender, listing.price, NO_OFFER_EXCLUSION);

        if (msg.value > listing.price) {
            payable(msg.sender).sendValue(msg.value - listing.price);
        }
        emit ItemBought(msg.sender, tokenId, listing.price);
    }

    function cancelListing(uint256 tokenId) external isOwner(tokenId, msg.sender) onlyFixedListed(tokenId) {
        delete fixedListings[tokenId];
        emit ItemCanceled(msg.sender, tokenId);
    }

    // -------------------------------------------------------------------------
    // Method B (seller) / Method B (buyer) — English auction
    // -------------------------------------------------------------------------

    function startAuction(uint256 tokenId, uint256 duration, uint256 reservePrice, uint256 minBidIncrement)
        external
        notFixedListed(tokenId)
        isOwner(tokenId, msg.sender)
    {
        if (_hasAuction(tokenId)) revert AuctionActive();
        if (duration < MIN_AUCTION_DURATION || duration > MAX_AUCTION_DURATION) revert InvalidDuration();
        if (minBidIncrement == 0) revert InvalidMinBidIncrement();
        _requireApproved(msg.sender, tokenId);
        _requireNotNodeAttached(tokenId);

        uint256 endTime = block.timestamp + duration;
        auctions[tokenId] = Auction({
            seller: msg.sender,
            endTime: endTime,
            reservePrice: reservePrice,
            minBidIncrement: minBidIncrement,
            highestBid: 0,
            highestBidder: address(0)
        });

        emit AuctionStarted(msg.sender, tokenId, endTime, reservePrice, minBidIncrement);
    }

    function placeBid(uint256 tokenId) external payable nonReentrant {
        Auction storage auction = auctions[tokenId];
        if (auction.seller == address(0)) revert NoActiveAuction();
        if (block.timestamp >= auction.endTime) revert AuctionEnded();

        if (auction.highestBidder == address(0)) {
            if (msg.value == 0) revert BidTooLow();
            if (auction.reservePrice > 0 && msg.value < auction.reservePrice) revert BidTooLow();
        } else {
            if (msg.value < auction.highestBid + auction.minBidIncrement) revert BidTooLow();
        }

        address previousBidder = auction.highestBidder;
        uint256 previousBid = auction.highestBid;

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        if (auction.endTime - block.timestamp <= ANTI_SNIPE_WINDOW) {
            auction.endTime += ANTI_SNIPE_EXTENSION;
        }

        if (previousBidder != address(0)) {
            payable(previousBidder).sendValue(previousBid);
        }

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    function settleAuction(uint256 tokenId) external nonReentrant {
        Auction memory auction = auctions[tokenId];
        if (auction.seller == address(0)) revert NoActiveAuction();
        if (block.timestamp < auction.endTime) revert AuctionStillLive();

        delete auctions[tokenId];

        if (auction.highestBidder != address(0) && auction.highestBid >= auction.reservePrice) {
            _completeSale(tokenId, auction.seller, auction.highestBidder, auction.highestBid, NO_OFFER_EXCLUSION);
            emit AuctionSettled(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            if (auction.highestBidder != address(0)) {
                payable(auction.highestBidder).sendValue(auction.highestBid);
            }
            emit AuctionCanceled(auction.seller, tokenId);
        }
    }

    function cancelAuction(uint256 tokenId) external isOwner(tokenId, msg.sender) {
        Auction storage auction = auctions[tokenId];
        if (auction.seller == address(0)) revert NoActiveAuction();
        if (auction.highestBid != 0) revert AuctionHasBids();

        delete auctions[tokenId];
        emit AuctionCanceled(msg.sender, tokenId);
    }

    // -------------------------------------------------------------------------
    // Method C (seller) / Method A (buyer) — buyer offers
    // -------------------------------------------------------------------------

    function makeOffer(uint256 tokenId, uint256 expiry) external payable nonReentrant {
        if (msg.value == 0) revert OfferAmountZero();
        if (IERC721(veAddr).ownerOf(tokenId) == msg.sender) revert CannotOfferOnOwnToken();
        if (expiry != 0 && expiry <= block.timestamp) revert InvalidOfferExpiry();

        uint256 offerId = ++nextOfferId;
        offers[offerId] = Offer({tokenId: tokenId, buyer: msg.sender, amount: msg.value, expiry: expiry, active: true});
        _offerIdsByToken[tokenId].push(offerId);

        emit OfferMade(offerId, tokenId, msg.sender, msg.value, expiry);
    }

    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotOfferBuyer();
        if (offer.expiry != 0 && block.timestamp > offer.expiry) revert OfferExpired();

        offer.active = false;
        payable(offer.buyer).sendValue(offer.amount);
        emit OfferCanceled(msg.sender, offerId);
    }

    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (!offer.active) revert OfferNotActive();
        if (offer.expiry != 0 && block.timestamp > offer.expiry) revert OfferExpired();
        if (IERC721(veAddr).ownerOf(offer.tokenId) != msg.sender) revert NotOwner();

        _requireApproved(msg.sender, offer.tokenId);

        offer.active = false;
        uint256 tokenId = offer.tokenId;
        address buyer = offer.buyer;
        uint256 amount = offer.amount;

        _completeSale(tokenId, msg.sender, buyer, amount, offerId);
        emit OfferAccepted(msg.sender, buyer, tokenId, offerId, amount);
    }

    // -------------------------------------------------------------------------
    // Proceeds
    // -------------------------------------------------------------------------

    function withdrawProceeds() external nonReentrant {
        uint256 _proceeds = proceeds[msg.sender];
        if (_proceeds == 0) revert NoProceeds();
        proceeds[msg.sender] = 0;
        payable(msg.sender).sendValue(_proceeds);
    }

    // -------------------------------------------------------------------------
    // View helpers
    // -------------------------------------------------------------------------

    function listings(uint256 tokenId) external view returns (uint256 price, address seller) {
        FixedListing storage listing = fixedListings[tokenId];
        return (listing.price, listing.seller);
    }

    function getListing(uint256 tokenId) external view returns (FixedListing memory) {
        return fixedListings[tokenId];
    }

    function getFixedListing(uint256 tokenId) external view returns (FixedListing memory) {
        return fixedListings[tokenId];
    }

    function getAuction(uint256 tokenId) external view returns (Auction memory) {
        return auctions[tokenId];
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getOffersForToken(uint256 tokenId) external view returns (uint256[] memory activeOfferIds) {
        uint256[] storage offerIds = _offerIdsByToken[tokenId];
        uint256 count;
        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage offer = offers[offerIds[i]];
            if (offer.active && (offer.expiry == 0 || block.timestamp <= offer.expiry)) {
                count++;
            }
        }
        activeOfferIds = new uint256[](count);
        uint256 index;
        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage offer = offers[offerIds[i]];
            if (offer.active && (offer.expiry == 0 || block.timestamp <= offer.expiry)) {
                activeOfferIds[index++] = offerIds[i];
            }
        }
    }

    function getProceeds(address seller) external view returns (uint256) {
        return proceeds[seller];
    }

    function isTokenIdListed(uint256 tokenId) external view returns (bool) {
        return fixedListings[tokenId].price > 0;
    }

    function isFixedListed(uint256 tokenId) external view returns (bool) {
        return fixedListings[tokenId].price > 0;
    }

    function isAuctionActive(uint256 tokenId) external view returns (bool) {
        Auction storage auction = auctions[tokenId];
        return auction.seller != address(0) && block.timestamp < auction.endTime;
    }

    function hasAuction(uint256 tokenId) external view returns (bool) {
        return _hasAuction(tokenId);
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _hasAuction(uint256 tokenId) internal view returns (bool) {
        return auctions[tokenId].seller != address(0);
    }

    function _requireApproved(address seller, uint256 tokenId) internal view {
        IERC721 nft = IERC721(veAddr);
        if (nft.getApproved(tokenId) != address(this) && !nft.isApprovedForAll(seller, address(this))) {
            revert NotApprovedForMarketplace();
        }
    }

    function _requireNotNodeAttached(uint256 tokenId) internal view {
        address nodeProperties = IVotingEscrow(veAddr).nodeProperties();
        if (INodeProperties(nodeProperties).attachedNodeId(tokenId) != bytes32("")) {
            revert TokenAttachedToNode();
        }
    }

    function _completeSale(uint256 tokenId, address seller, address buyer, uint256 price, uint256 exceptOfferId)
        internal
    {
        _requireNotNodeAttached(tokenId);
        delete fixedListings[tokenId];
        delete auctions[tokenId];
        _refundOffers(tokenId, exceptOfferId);

        IERC721(veAddr).safeTransferFrom(seller, buyer, tokenId);
        proceeds[seller] += price;
        emit SaleCompleted(seller, buyer, tokenId, price);
    }

    function _refundOffers(uint256 tokenId, uint256 exceptOfferId) internal {
        uint256[] storage offerIds = _offerIdsByToken[tokenId];
        for (uint256 i = 0; i < offerIds.length; i++) {
            uint256 offerId = offerIds[i];
            if (offerId == exceptOfferId) continue;

            Offer storage offer = offers[offerId];
            if (!offer.active) continue;

            offer.active = false;
            payable(offer.buyer).sendValue(offer.amount);
            emit OfferCanceled(offer.buyer, offerId);
        }
        delete _offerIdsByToken[tokenId];
    }
}
