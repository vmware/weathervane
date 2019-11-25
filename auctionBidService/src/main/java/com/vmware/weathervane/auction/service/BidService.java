/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import javax.servlet.AsyncContext;

import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public interface BidService {
	
	public ItemRepresentation getCurrentItem(long auctionId) throws AuctionNotActiveException;

	void handleHighBidMessage(BidRepresentation newHighBid);
	
	BidRepresentation getNextBid(Long auctionId, Long itemId, Integer lastBidCount, AsyncContext ac) throws InvalidStateException, AuthenticationException;	
	BidRepresentation postNewBid(BidRepresentation theBid) throws InvalidStateException;

	void prepareForShutdown();

	public void releaseGetNextBid();

	public int getAuctionMaxIdleTime();

}
