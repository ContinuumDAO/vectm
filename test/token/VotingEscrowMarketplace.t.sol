// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {VotingEscrowMarketplace} from "../../src/token/VotingEscrowMarketplace.sol";
import {INodeProperties} from "../../src/node/INodeProperties.sol";
import {NodeProperties} from "../../src/node/NodeProperties.sol";
import {Helpers} from "../helpers/Helpers.sol";

contract VotingEscrowMarketplaceTest is Helpers {
    VotingEscrowMarketplace marketplace;

    uint256 constant MAXTIME = 4 * 365 * 86_400;
    uint256 constant LIST_PRICE = 1 ether;
    uint256 constant AUCTION_DURATION = 1 days;
    uint256 constant MIN_BID_INCREMENT = 0.1 ether;
    uint16 _0 = uint16(0);

    NodeProperties.NodeInfo submittedNodeInfo = INodeProperties.NodeInfo(
        "@myhandle",
        "john.doe@mail.com",
        keccak256(abi.encode("Example Node ID")),
        [0, 0, 0, 0],
        [_0, _0, _0, _0, _0, _0, _0, _0],
        "Contabo",
        16_000_000_000,
        8,
        "did:key",
        "did:key:z6Mkexample",
        hex""
    );

    function setUp() public override {
        super.setUp();
        marketplace = new VotingEscrowMarketplace(address(ve));
    }

    function _createLock(address owner) internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = ve.create_lock(1000 ether, MAXTIME);
        skip(1);
    }

    function _createLockForNode(address owner) internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
    }

    function _approveMarketplace(address owner, uint256 tokenId) internal {
        vm.prank(owner);
        ve.approve(address(marketplace), tokenId);
    }

    // -------------------------------------------------------------------------
    // Fixed price
    // -------------------------------------------------------------------------

    function test_ListAndBuyWithPerTokenApproval() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        (uint256 price, address seller) = marketplace.listings(tokenId);
        assertEq(price, LIST_PRICE);
        assertEq(seller, user1);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.buyItem{value: LIST_PRICE}(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(marketplace.proceeds(user1), LIST_PRICE);
        (price,) = marketplace.listings(tokenId);
        assertEq(price, 0);
    }

    function test_ListAndBuyWithOperatorApproval() public {
        uint256 tokenId = _createLock(user1);

        vm.prank(user1);
        ve.setApprovalForAll(address(marketplace), true);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.buyItem{value: LIST_PRICE}(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
    }

    function test_BuyRefundsExcessPayment() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        uint256 overpay = LIST_PRICE + 0.5 ether;
        vm.deal(user2, overpay);
        vm.prank(user2);
        marketplace.buyItem{value: overpay}(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(user2.balance, 0.5 ether);
    }

    function test_WithdrawProceeds() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.buyItem{value: LIST_PRICE}(tokenId);

        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        marketplace.withdrawProceeds();
        assertEq(user1.balance, balanceBefore + LIST_PRICE);
    }

    function test_CancelListing() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.prank(user1);
        marketplace.cancelListing(tokenId);

        (uint256 listedPrice,) = marketplace.listings(tokenId);
        assertEq(listedPrice, 0);
    }

    function test_ListRevertsWithoutApproval() public {
        uint256 tokenId = _createLock(user1);

        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.NotApprovedForMarketplace.selector);
        marketplace.listItem(tokenId, LIST_PRICE);
    }

    function test_ListRevertsWhenNodeAttached() public {
        uint256 tokenId = _createLockForNode(user1);
        _approveMarketplace(user1, tokenId);

        vm.startPrank(user1);
        nodeProperties.attachNode(tokenId, submittedNodeInfo);
        skip(1);
        vm.expectRevert(VotingEscrowMarketplace.TokenAttachedToNode.selector);
        marketplace.listItem(tokenId, LIST_PRICE);
        vm.stopPrank();
    }

    function test_BuyRevertsWhenNodeAttachedAfterListing() public {
        uint256 tokenId = _createLockForNode(user1);
        _approveMarketplace(user1, tokenId);

        vm.startPrank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);
        nodeProperties.attachNode(tokenId, submittedNodeInfo);
        skip(1);
        vm.stopPrank();

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        vm.expectRevert(VotingEscrowMarketplace.TokenAttachedToNode.selector);
        marketplace.buyItem{value: LIST_PRICE}(tokenId);
    }

    // -------------------------------------------------------------------------
    // Auction
    // -------------------------------------------------------------------------

    function test_AuctionStartBidSettle() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        assertTrue(marketplace.isAuctionActive(tokenId));

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.placeBid{value: 1 ether}(tokenId);

        skip(AUCTION_DURATION + 1);

        vm.prank(user2);
        marketplace.settleAuction(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(marketplace.proceeds(user1), 1 ether);
        assertFalse(marketplace.hasAuction(tokenId));
    }

    function test_AuctionOutbidRefundsPreviousBidder() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.placeBid{value: 1 ether}(tokenId);

        vm.deal(voter1, 2 ether);
        vm.prank(voter1);
        marketplace.placeBid{value: 2 ether}(tokenId);

        assertEq(user2.balance, 1 ether);

        skip(AUCTION_DURATION + 1);
        marketplace.settleAuction(tokenId);
        assertEq(ve.ownerOf(tokenId), voter1);
    }

    function test_AuctionAntiSnipeExtendsEndTime() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        skip(AUCTION_DURATION - 5 minutes);

        (, uint256 endTimeBefore,,,,) = _unpackAuction(tokenId);

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.placeBid{value: 1 ether}(tokenId);

        (, uint256 endTimeAfter,,,,) = _unpackAuction(tokenId);
        assertGt(endTimeAfter, endTimeBefore);
    }

    function test_AuctionCancelWithoutBids() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        vm.prank(user1);
        marketplace.cancelAuction(tokenId);

        assertFalse(marketplace.hasAuction(tokenId));
    }

    function test_AuctionCancelRevertsWithBids() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.placeBid{value: 1 ether}(tokenId);

        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.AuctionHasBids.selector);
        marketplace.cancelAuction(tokenId);
    }

    function test_AuctionNoBidsSettleKeepsNftWithSeller() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);
        uint256 reserve = 2 ether;

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, reserve, MIN_BID_INCREMENT);

        skip(AUCTION_DURATION + 1);
        marketplace.settleAuction(tokenId);

        assertEq(ve.ownerOf(tokenId), user1);
        assertFalse(marketplace.hasAuction(tokenId));
    }

    function test_CannotListWhileAuctionActive() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.AuctionActive.selector);
        marketplace.listItem(tokenId, LIST_PRICE);
    }

    function test_CannotStartAuctionWhileFixedListed() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.AlreadyListed.selector);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);
    }

    // -------------------------------------------------------------------------
    // Offers
    // -------------------------------------------------------------------------

    function test_MakeAndAcceptOffer() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        vm.prank(user1);
        marketplace.acceptOffer(1);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(marketplace.proceeds(user1), LIST_PRICE);
    }

    function test_CancelOffer() public {
        uint256 tokenId = _createLock(user1);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        uint256 balanceBefore = user2.balance;
        vm.prank(user2);
        marketplace.cancelOffer(1);

        assertEq(user2.balance, balanceBefore + LIST_PRICE);
    }

    function test_AcceptOfferRefundsOtherOffers() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        vm.deal(voter1, LIST_PRICE);
        vm.prank(voter1);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        uint256 voter1BalanceBefore = voter1.balance;
        vm.prank(user1);
        marketplace.acceptOffer(1);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(voter1.balance, voter1BalanceBefore + LIST_PRICE);
    }

    function test_MakeOfferRevertsOnOwnToken() public {
        uint256 tokenId = _createLock(user1);

        vm.deal(user1, LIST_PRICE);
        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.CannotOfferOnOwnToken.selector);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);
    }

    function test_ExpiredOfferCannotBeAccepted() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, block.timestamp + 1 hours);

        skip(2 hours);

        vm.prank(user1);
        vm.expectRevert(VotingEscrowMarketplace.OfferExpired.selector);
        marketplace.acceptOffer(1);
    }

    function test_GetOffersForToken() public {
        uint256 tokenId = _createLock(user1);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        vm.deal(voter1, LIST_PRICE);
        vm.prank(voter1);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        uint256[] memory activeOffers = marketplace.getOffersForToken(tokenId);
        assertEq(activeOffers.length, 2);
    }

    // -------------------------------------------------------------------------
    // Coexistence
    // -------------------------------------------------------------------------

    function test_OfferCoexistsWithFixedListing() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.deal(user2, 0.5 ether);
        vm.prank(user2);
        marketplace.makeOffer{value: 0.5 ether}(tokenId, 0);

        assertTrue(marketplace.isFixedListed(tokenId));
        assertEq(marketplace.getOffersForToken(tokenId).length, 1);
    }

    function test_AcceptOfferClearsFixedListingAndAuction() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.startPrank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);
        marketplace.cancelListing(tokenId);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);
        vm.stopPrank();

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.makeOffer{value: 1 ether}(tokenId, 0);

        vm.prank(user1);
        marketplace.acceptOffer(1);

        assertEq(ve.ownerOf(tokenId), user2);
        assertFalse(marketplace.hasAuction(tokenId));
        assertFalse(marketplace.isFixedListed(tokenId));
    }

    function test_FixedBuyRefundsOutstandingOffers() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.listItem(tokenId, LIST_PRICE);

        vm.deal(voter1, LIST_PRICE);
        vm.prank(voter1);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        vm.deal(user2, LIST_PRICE);
        vm.prank(user2);
        marketplace.buyItem{value: LIST_PRICE}(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(marketplace.getOffersForToken(tokenId).length, 0);
    }

    function test_AuctionSettleRefundsOutstandingOffers() public {
        uint256 tokenId = _createLock(user1);
        _approveMarketplace(user1, tokenId);

        vm.prank(user1);
        marketplace.startAuction(tokenId, AUCTION_DURATION, 0, MIN_BID_INCREMENT);

        vm.deal(voter1, LIST_PRICE);
        vm.prank(voter1);
        marketplace.makeOffer{value: LIST_PRICE}(tokenId, 0);

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        marketplace.placeBid{value: 1 ether}(tokenId);

        skip(AUCTION_DURATION + 1);
        marketplace.settleAuction(tokenId);

        assertEq(ve.ownerOf(tokenId), user2);
        assertEq(marketplace.getOffersForToken(tokenId).length, 0);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _unpackAuction(uint256 tokenId)
        internal
        view
        returns (
            address seller,
            uint256 endTime,
            uint256 reservePrice,
            uint256 minBidIncrement,
            uint256 highestBid,
            address highestBidder
        )
    {
        VotingEscrowMarketplace.Auction memory auction = marketplace.getAuction(tokenId);
        return (
            auction.seller,
            auction.endTime,
            auction.reservePrice,
            auction.minBidIncrement,
            auction.highestBid,
            auction.highestBidder
        );
    }
}
