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
package com.vmware.weathervane.auction.service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.AsyncContext;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation.BiddingState;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public class BidServiceImpl implements BidService {

	private static final Logger logger = LoggerFactory.getLogger(BidServiceImpl.class);

	public static final String auctionManagementGroupName = "liveAuctionMgmtGroup";
	public static final String auctionAssignmentMapName = "liveAuctionAssignmentMap";

	public static final String liveAuctionExchangeName = "liveAuctionMgmtExchange";
	public static final String newBidRoutingKey = "newBid.";

	// The longest that an auction can go (in seconds) without a bid before the
	// state of the current item is changed to either LASTCALL or SOLD
	private int auctionMaxIdleTime = 30;

	private int _numClientUpdateExecutorThreads = 1;
	private ScheduledThreadPoolExecutor _clientUpdateExecutorService;

	/*
	 * Set to true when exiting 
	 */
	private boolean _exiting = false;
	
	/**
	 * The auctions that are currently active, with map from auctionId to the
	 * auction
	 */
	private Map<Long, ClientBidUpdater> _clientBidUpdaterMap = new ConcurrentSkipListMap<Long, ClientBidUpdater>();

	@Inject
	@Named("liveAuctionRabbitTemplate")
	RabbitTemplate liveAuctionRabbitTemplate;

	@Inject
	@Named("itemDao")
	private ItemDao _itemDao;

	@Inject
	@Named("highBidDao")
	private HighBidDao _highBidDao;

	@Inject
	ImageStoreFacade imageStoreFacade;

	public BidServiceImpl() {
	}
	
	@PostConstruct
	private void initialize() throws Exception {

		_clientUpdateExecutorService = (ScheduledThreadPoolExecutor) Executors.newScheduledThreadPool(_numClientUpdateExecutorThreads, new ThreadFactory() {
			private final AtomicInteger counter = new AtomicInteger();

			@Override
			public Thread newThread(Runnable r) {
				final String threadName = String.format("clientUpdateThread-%d", counter.incrementAndGet());
				Thread newThread = new Thread(r, threadName);
				return newThread;
			}
		});
		_clientUpdateExecutorService.setRemoveOnCancelPolicy(true);
		
		// Create ClientBidUpdaters for auctions that are already running
		logger.info("Create ClientBidUpdaters for auctions that are already running");
		List<HighBid> highBids = _highBidDao.getActiveHighBids();
		for (HighBid aHighBid : highBids) {
			_clientBidUpdaterMap.put(aHighBid.getAuctionId(),
					new ClientBidUpdater(aHighBid.getAuctionId(), _highBidDao, _itemDao, _clientUpdateExecutorService, imageStoreFacade));
		}

	}

	@PreDestroy
	private void cleanup() {
		
		if (!_exiting) {
			prepareForShutdown();
		}
		
		_clientUpdateExecutorService.shutdown();

		try {
			_clientUpdateExecutorService.awaitTermination(30, TimeUnit.SECONDS);
		} catch (InterruptedException e) {
			logger.debug("Awaiting termination on executorService was interrupted");
		}
	}
	
	@Override
	public void releaseGetNextBid() {
		/*
		 * Tell all of the ClientBidUpdaters to complete any outstanding async requests
		 */
		for (Long auctionId : _clientBidUpdaterMap.keySet()) {
			ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);
			clientBidUpdater.release();
		}

	}

	@Override
	public void prepareForShutdown() {
		if (!_exiting) {
			_exiting = true;
			logger.warn("Received prepareForShutdown message");
			
			/*
			 * Tell all of the ClientBidUpdaters to stop accepting new requests
			 * and to complete any outstanding async requests
			 */
			for (Long auctionId : _clientBidUpdaterMap.keySet()) {
				ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);
				clientBidUpdater.shutdown();
			}
			
			this.releaseGetNextBid();
		}
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see com.vmware.liveAuction.services.BidService#postNewBid(com.vmware.
	 * liveAuction .liveModel.LiveBid)
	 */
	@Override
	public BidRepresentation postNewBid(BidRepresentation theBid) throws InvalidStateException {

		logger.debug("postNewBid propagating bid " + theBid);
		liveAuctionRabbitTemplate.convertAndSend(liveAuctionExchangeName, newBidRoutingKey + theBid.getAuctionId(), theBid);

		theBid.setBiddingState(BiddingState.ACCEPTED);
		theBid.setMessage(BiddingState.ACCEPTED.toString());
		return theBid;
	}

	/**
	 * This method returns the most recent bid on the item identified by itemId
	 * in the auction identified by auctionId. If the bid identified by
	 * lastBidCount is the most recent bid, then this becomes an asynchronous
	 * (long pull) request, which will be completed by a liveBidRequestCompleter
	 * thread once a new bid is placed.
	 * 
	 * @author hrosenbe
	 * @throws AuthenticationException
	 */
	@Override
	public BidRepresentation getNextBid(Long auctionId, Long itemId, Integer lastBidCount, AsyncContext ac)
			throws InvalidStateException, AuthenticationException {

		logger.debug("LiveAuctionServiceImpl:getNextBid for auctionId = " + auctionId + ", itemId = " + itemId + ", lastBidCount = " + lastBidCount);

		ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);

		if (clientBidUpdater == null) {
			String msg = "Got next bid request for auction " + auctionId + " which is not being tracked by this node. " + " The auction may have ended.";
			logger.warn(msg);
			throw new InvalidStateException(msg);
		}

		return clientBidUpdater.getNextBid(auctionId, itemId, lastBidCount, ac);

	}

	@Override
	public void handleHighBidMessage(BidRepresentation newHighBid) {
		logger.debug("handleHighBidMessage got highBid " + newHighBid);
		newHighBid.setReceivingNode(0L);
		Long auctionId = newHighBid.getAuctionId();
		if (auctionId == null) {
			logger.warn("handleHighBidMessage got highBid " + newHighBid + " with no auctionId.");
			return;
		}
		
		logger.debug("handleHighBidMessage: auctionId = " + auctionId);
		ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);

		if (clientBidUpdater == null) {
			// Create a ClientBidUpdater for this auction
			logger.warn("handleHighBidMessage creating ClientBidUpdater for highBid " + newHighBid);
			clientBidUpdater = new ClientBidUpdater(newHighBid.getAuctionId(), _highBidDao, _itemDao, _clientUpdateExecutorService, imageStoreFacade);

			_clientBidUpdaterMap.put(auctionId, clientBidUpdater);
		}

		clientBidUpdater.handleHighBidMessage(newHighBid);
	}

	@Override
	public ItemRepresentation getCurrentItem(long auctionId) throws AuctionNotActiveException {
		logger.debug("getCurrentItem for auction " + auctionId);

		ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);
		if (clientBidUpdater == null) {
			String msg = "Got getCurrentItem request for auction " + auctionId + " which is not being tracked by this node. " + " The auction may have ended.";
			logger.warn(msg);
			throw new AuctionNotActiveException(msg);
		}

		return clientBidUpdater.getCurrentItem(auctionId);

	}
		
	public int getNumClientUpdateExecutorThreads() {
		return _numClientUpdateExecutorThreads;
	}

	public void setNumClientUpdateExecutorThreads(int _numClientUpdateExecutorThreads) {
		this._numClientUpdateExecutorThreads = _numClientUpdateExecutorThreads;
	}

	@Override
	public int getAuctionMaxIdleTime() {
		return auctionMaxIdleTime;
	}

	public void setAuctionMaxIdleTime(int auctionMaxIdleTime) {
		this.auctionMaxIdleTime = auctionMaxIdleTime;
	}

}
