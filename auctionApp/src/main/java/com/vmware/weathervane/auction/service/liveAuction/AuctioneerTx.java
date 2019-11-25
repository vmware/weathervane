/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service.liveAuction;

import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNoItemsException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

/**
 * @author Hal
 *
 */
public interface AuctioneerTx {

	/**
	 * @param theBid
	 */
	void storeBidCompletionDelay(BidRepresentation acceptedBid, long numCompletedBids, Long nodeNumber);

	HighBid startNextItem(HighBid curHighBid);

	/**
	 * This method sets an auction to pending
	 * 
	 * @param theAuction
	 *            : the auction to start
	 * @throws AuctionStartException
	 */
	Auction pendAuction(long auctionId) throws InvalidStateException;

	/**
	 * @param nextAuction
	 */
	void invalidateAuction(long auctionId);

	/**
	 * This method starts an auction running. It does the following: - Sets
	 * the auction's state to RUNNING - Sets the auction's current item to
	 * the first item in it's item list. - Sets the current item's state to
	 * Active - Sets the current item's bidCount to 0
	 * 
	 * @param theAuction
	 *            : the auction to start
	 * @return The first item in the auction
	 * @throws
	 */
	HighBid startAuction(long auctionId) throws InvalidStateException, AuctionNoItemsException;

	HighBid postNewHighBidTx(Bid theBid) throws InvalidStateException;

	HighBid makeForwardProgress(HighBid highBid);

	void resetItems(Long auctionId);

}