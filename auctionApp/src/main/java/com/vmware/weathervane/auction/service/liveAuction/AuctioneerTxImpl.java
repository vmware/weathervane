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

import java.util.Calendar;
import java.util.Date;

import javax.inject.Inject;
import javax.inject.Named;
import javax.persistence.NonUniqueResultException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.BidCompletionDelayDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.Auction.AuctionState;
import com.vmware.weathervane.auction.data.model.Bid.BidState;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;
import com.vmware.weathervane.auction.data.model.Item.ItemState;
import com.vmware.weathervane.auction.data.statsModel.BidCompletionDelay;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNoItemsException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

/**
 * @author Hal
 * 
 */
public class AuctioneerTxImpl implements AuctioneerTx {

	private static final Logger logger = LoggerFactory.getLogger(AuctioneerTxImpl.class);

	@Inject
	@Named("auctionDao")
	private AuctionDao auctionDao;

	@Inject
	@Named("itemDao")
	private ItemDao itemDao;

	@Inject
	@Named("userDao")
	private UserDao userDao;

	@Inject
	@Named("highBidDao")
	private HighBidDao highBidDao;

	@Inject
	@Named("bidCompletionDelayDao")
	private BidCompletionDelayDao bidCompletionDelayDao;
	
	private Long nodeNumber = Long.getLong("nodeNumber", -1L);

	@Override
	@Transactional
	public HighBid makeForwardProgress(HighBid curHighBid) {
		Long auctionId = curHighBid.getAuctionId();
		Long itemId = curHighBid.getItemId();
		logger.info("makeForwardProgress: auctionId = " + auctionId);
		Date now = FixedOffsetCalendarFactory.getCalendar().getTime();
		
		HighBid highBid = highBidDao.findByItemId(itemId);

		/*
		 * Move the auction along.
		 */
		if (highBid.getState() == HighBidState.OPEN) {
			logger.debug("MakeForwardProgress: auctionId = " + auctionId + ". Moving item " + itemId + " to LASTCALL");

			/*
			 * Move the item into the LASTCALL state. Post a dummy
			 * bidRepresentation with state==LASTCALL on the acceptedBidQueue.
			 */
			highBid.setState(HighBidState.LASTCALL);

			/*
			 * Even a dummy bid should increment the bid count so that clients
			 * requesting the nextBid will see the update.
			 */
			highBid.setBidCount(highBid.getBidCount() + 1);
			
			// Set the time on this bid to now so that the
			// bidCompletionDelay calculations are correct
			highBid.setCurrentBidTime(now);
			
			return highBid;

		} else if (highBid.getState() == HighBidState.LASTCALL) {
			logger.debug("MakeForwardProgress: auctionId = " + auctionId + ". Moving item " + itemId + " to SOLD");

			/*
			 * Since there has been no forward progress since the item was
			 * placed in LASTCALL state, the item should be marked SOLD. 
			 */

			/*
			 * Even a dummy bid should increment the bid count so that clients
			 * requesting the nextBid will see the update.
			 */
			highBid.setBidCount(highBid.getBidCount() + 1);

			// Set the time on this bid to now so that the
			// bidCompletionDelay calculations are correct
			highBid.setCurrentBidTime(now);

			User purchaser = highBid.getBidder();
			Item currentItem = highBid.getItem();
			highBid.setBiddingEndTime(now);
			highBid.setCurrentBidTime(now);
			
			highBid.setState(HighBidState.SOLD);
			currentItem.setState(ItemState.SOLD);

			// Don't adjust the credit limit of the unsold user
			if (!purchaser.getEmail().equals("unsold@auction.xyz")) {
				purchaser.setCreditLimit(purchaser.getCreditLimit() - highBid.getAmount());
			}			
			return highBid;
			
		} else {
			// Shouldn't get here
			return null;
		}
	}

	@Override
	@Transactional
	public HighBid startNextItem(HighBid curHighBid) {
		Date now = FixedOffsetCalendarFactory.getCalendar().getTime();

		Item currentItem = curHighBid.getItem();
		Auction currentAuction = curHighBid.getAuction();
		
		logger.info("startNextItem: auctionId = " + currentAuction.getId());

		// Get the next item for the auction.
		Item nextItem = null;
		try {
			nextItem = auctionDao.getNextItem(currentAuction, currentItem.getId());
			logger.info("startNextItem: found nextItem " + nextItem.getId() + " for auction "
					+ currentAuction.getId());
		} catch (EmptyResultDataAccessException ex) {
			/*
			 * There are no more items. The auction is complete.
			 */
			logger.info("startNextItem:  auction " + currentAuction.getId() + " is complete");
			// Pull the auction into the persistence context
			currentAuction = auctionDao.get(currentAuction.getId());
			currentAuction.setState(AuctionState.COMPLETE);
			currentAuction.setEndTime(now);
			
			return null;
		} catch (NonUniqueResultException ex) {
			throw new RuntimeException(
					"In startNextItem: Got multiple next items for auction "
							+ currentAuction.getId() + " and item " + currentItem.getId());
		}

		logger.debug("startNextItem: Making item " + nextItem.getId()
				+ " the current item for Auction " + currentAuction.getId());

		/*
		 * Check the item's state. If INAUCTION, set to ACTIVE, otherwise throw
		 * exception
		 */
		if (nextItem.getState() != ItemState.INAUCTION) {
			throw new RuntimeException("In startNextItem: Next Item state is "
					+ nextItem.getState() + " for auction " + currentAuction.getId());
		}
		nextItem.setState(ItemState.ACTIVE);
		
		
		/*
		 * Get the unsold User. This is the user that is associated with all
		 * starting bids, and therefore will be the winning bidder if there are
		 * no real bids on the Item
		 */
		User unsoldUser = userDao.getUserByName("unsold@auction.xyz");
		
		/*
		 * Create the HighBid record for this auction and item.  The current,
		 * and eventually final, state of bidding on this item is always 
		 * tracked in this record
		 */
		HighBid newHighBid = new HighBid();
		newHighBid.setAmount(nextItem.getStartingBidAmount());
		newHighBid.setBidCount(1);
		newHighBid.setState(HighBidState.OPEN);
		newHighBid.setBiddingStartTime(now);
		newHighBid.setAuction(currentAuction);
		newHighBid.setItem(nextItem);
		newHighBid.setBidder(unsoldUser);
		newHighBid.setPreloaded(false);
		newHighBid.setCurrentBidTime(now);
		
		/*
		 * No persistent Bid entry for starting bids
		 */
		newHighBid.setBidId(null);		
		
		nextItem.setHighbid(newHighBid);
		
		highBidDao.save(newHighBid);
		
		return newHighBid;

	}

	@Override
	@Transactional
	public void storeBidCompletionDelay(BidRepresentation acceptedBid, long numCompletedBids) {
		
		Calendar now = FixedOffsetCalendarFactory.getCalendar();
		BidCompletionDelay delayRecord = new BidCompletionDelay();
		delayRecord.setBidId(acceptedBid.getId());
		delayRecord.setNumCompletedBids(numCompletedBids);
		delayRecord.setTimestamp(now.getTime());
		delayRecord.setBiddingState(acceptedBid.getBiddingState().name());
		delayRecord.setReceivingNode(acceptedBid.getReceivingNode());
		delayRecord.setBidTime(acceptedBid.getBidTime());
		delayRecord.setCompletingNode(nodeNumber);
		
		long delay = now.getTimeInMillis() - acceptedBid.getBidTime().getTime();
		logger.info("BidServiceTxImpl::storeBidCompletionDelay bidId = " + acceptedBid.getId()
				+ ", auctionId = " + acceptedBid.getAuctionId() + ", itemId = " + acceptedBid.getItemId()
				+ ", delay = " + delay + ", numCompletedBids = " + numCompletedBids);
		/*
		 * The delay is between the bid creation time and now. We use the delay
		 * from the bid representation because this may have been a dummy bid
		 * with an updated bid time.
		 */
		delayRecord.setDelay(delay);
		
		bidCompletionDelayDao.save(delayRecord);
	}

	@Override
	@Transactional
	public HighBid postNewHighBidTx(Bid theBid) throws InvalidStateException {

		Long auctionId = theBid.getAuctionId();
		Long itemId = theBid.getItemId();
		Long bidderId = theBid.getBidderId();

		/* 
		 * Get the HighBid
		 */
		HighBid curHighBid = highBidDao.findByItemId(itemId);
		
		logger.info("postNewHighBidTx auctionId=" + auctionId + " itemId="
				+ itemId + " userId=" + bidderId + " amount=" + theBid.getAmount());
				
		User theUser = userDao.get(bidderId);
		if (theUser == null) {
			logger.warn("PostNewBidTx: Attempt to post a bid for a nonexistant user with ID "
					+ theBid.getBidderId());
			throw new InvalidStateException("Attempt to post a bid for a nonexistant user with ID "
					+ theBid.getBidderId());
		}

		// Determine the status of the new bid
		if (theUser.getCreditLimit().floatValue() < theBid.getAmount().floatValue()) {
			theBid.setState(BidState.INSUFFICIENTFUNDS);
		} else if (curHighBid.getState().equals(HighBidState.SOLD)) { 
			theBid.setState(BidState.ITEMSOLD);
		} else {
			/*
			 * At this point, we know that the auction is running, the item is
			 * up for sale, and the user can afford the bid.
			 */
			theBid.setState(BidState.HIGH);

			/*
			 * The new bid is a new high bid. Make the appropriate changes to
			 * the highBid state.
			 */
			curHighBid.setBidCount(curHighBid.getBidCount() + 1);
			curHighBid.setAmount(theBid.getAmount());
			curHighBid.setBidder(theUser);
			curHighBid.setBidId(theBid.getId().toString());
			curHighBid.setState(HighBidState.OPEN);
			curHighBid.setCurrentBidTime(theBid.getBidTime());

		}

		return curHighBid;
	}
		
	@Override
	@Transactional
	public Auction pendAuction(long auctionId) throws InvalidStateException {

		/*
		 * Get the auction again to make sure that it is up to date and to
		 * put it into the persistence context
		 */
		Auction anAuction = auctionDao.get(auctionId);

		// Check the current state of the auction
		if (anAuction.getState() != AuctionState.FUTURE) {
			logger.info("Not pending auction: Auction state is " + anAuction.getState() + " for auction " + anAuction.getId());
			throw new InvalidStateException("Auction state is " + anAuction.getState() + " for auction "
					+ anAuction.getId());
		}

		anAuction.setState(AuctionState.PENDING);
		logger.info("Set state to PENDING for auction \n" + anAuction.toString());

		return anAuction;

	}

	@Override
	@Transactional
	public void invalidateAuction(long auctionId) {
		/*
		 * Get the auction again to make sure that it is up to date and to
		 * put it into the persistence context
		 */
		Auction theAuction = auctionDao.getForUpdate(auctionId);

		theAuction.setState(AuctionState.INVALID);

	}

	@Override
	@Transactional
	public HighBid startAuction(long auctionId) throws InvalidStateException, AuctionNoItemsException {
		Date now = FixedOffsetCalendarFactory.getCalendar().getTime();
		/*
		 * Get the auction again to make sure that it is up to date and to
		 * put it into the persistence context
		 */
		Auction theAuction = auctionDao.getForUpdate(auctionId);
		if (theAuction == null) {
			logger.warn("Trying to start an auction that is not in the database.");
			throw new InvalidStateException("Trying to start an auction that is not in the database.");
		}

		// Check the current state of the auction
		if (theAuction.getState() != AuctionState.PENDING) {
			logger.info("Didn't start auction: Auction state is " + theAuction.getState() + " for auction "
					+ theAuction.getId());
			throw new InvalidStateException("Auction state is " + theAuction.getState() + " for auction "
					+ theAuction.getId());
		}

		Item firstItem = null;
		try {
			firstItem = auctionDao.getFirstItem(theAuction);
			logger.info("startAuction: got first item " + firstItem.toString() + " for auction "
					+ theAuction.toString());
		} catch (EmptyResultDataAccessException ex) {
			throw new AuctionNoItemsException("Can't start auction " + theAuction.getId() + ". It has no items.");
		} catch (NonUniqueResultException ex) {
			throw new RuntimeException("In StartAuction: Got multiple first items for auction "
					+ theAuction.getId());
		}

		/*
		 *  Check the item's state. If INAUCTION, set to ACTIVE, otherwise throw exception
		 */
		if (firstItem.getState() != ItemState.INAUCTION) {
			logger.info("Problem starting auction: First Item state is " + firstItem.getState() + " for auction "
					+ theAuction.getId());
			throw new InvalidStateException("First Item state is " + firstItem.getState() + " for auction "
					+ theAuction.getId());
		}		
		// This is really here to force the loading of the Auction field of firstItem
		if (!firstItem.getAuction().getId().equals(theAuction.getId())) {
			logger.info("Problem starting auction: First Item is in auction " + firstItem.getAuction().getId() + " not auction "
					+ theAuction.getId());
			throw new InvalidStateException("Problem starting auction: First Item is in auction " + firstItem.getAuction().getId() + " not auction "
					+ theAuction.getId());
		}
		firstItem.setState(ItemState.ACTIVE);

		// Set the auction's current item to be the first item
		theAuction.setState(AuctionState.RUNNING);
		logger.info("Started auction " + theAuction.getId());
		
		/*
		 * Get the unsold User. This is the user that is associated with all
		 * starting bids, and therefore will be the winning bidder if there are
		 * no real bids on the Item
		 */
		User unsoldUser = userDao.getUserByName("unsold@auction.xyz");
		
		/*
		 * Create the HighBid record for this auction and item.  The current,
		 * and eventually final, state of bidding on this item is always 
		 * tracked in this record
		 */
		HighBid newHighBid = new HighBid();
		newHighBid.setAmount(firstItem.getStartingBidAmount());
		newHighBid.setBidCount(1);
		newHighBid.setState(HighBidState.OPEN);
		newHighBid.setBiddingStartTime(now);
		newHighBid.setAuction(theAuction);
		newHighBid.setItem(firstItem);
		newHighBid.setBidder(unsoldUser);
		newHighBid.setPreloaded(false);
		newHighBid.setCurrentBidTime(now);
		
		
		/*
		 * No persistent Bid entry for starting bids
		 */
		newHighBid.setBidId(null);		
		
		firstItem.setHighbid(newHighBid);
		
		highBidDao.save(newHighBid);
		
		return newHighBid;

	}
	
}
