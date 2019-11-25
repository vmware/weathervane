/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.liveAuction;

import javax.servlet.AsyncContext;

import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.service.liveAuction.message.StartAuctioneer;

public interface LiveAuctionService {
	
	public CollectionRepresentation<AuctionRepresentation> getActiveAuctions(Integer page, Integer pageSize);

	/**
	 * @param record
	 * @return
	 * @throws InvalidStateException 
	 * @throws AuthenticationException 
	 */
	public AttendanceRecordRepresentation joinAuction(AttendanceRecordRepresentation record) throws InvalidStateException, AuctionNotActiveException;

	public AttendanceRecordRepresentation leaveAuction(long userId, long auctionId) throws InvalidStateException;
	
	public ItemRepresentation getCurrentItem(long auctionId) throws AuctionNotActiveException;
	
	long getActiveAuctionsMisses();

	void handleAuctionEndedMessage(AuctionRepresentation anAuction);
	void handleHighBidMessage(BidRepresentation newHighBid);
	void handleNewBidMessage(BidRepresentation theBid);

	int getAuctionMaxIdleTime();
	
	BidRepresentation getNextBid(Long auctionId, Long itemId, Integer lastBidCount, AsyncContext ac) throws InvalidStateException, AuthenticationException;	
	BidRepresentation postNewBid(BidRepresentation theBid) throws InvalidStateException;

	Boolean isMaster();

	void handleStartAuctioneerMessage(StartAuctioneer startAuction);

	void prepareForShutdown();

	public void releaseGetNextBid();

}
