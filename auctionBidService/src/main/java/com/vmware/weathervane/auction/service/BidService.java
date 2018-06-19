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
