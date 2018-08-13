/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

}