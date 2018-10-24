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

import java.util.Date;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.Bid.BidState;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;
import com.vmware.weathervane.auction.data.repository.BidRepository;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.service.exception.AuctionNoItemsException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

public class AuctioneerImpl implements Auctioneer, Runnable {

	private static final Logger logger = LoggerFactory.getLogger(AuctioneerImpl.class);
	private final Long nodeNumber;

	private static final String liveAuctionExchangeName = "liveAuctionMgmtExchange";
	private static final String highBidRoutingKey = "highBid.";
	private static final String auctionEndedRoutingKey = "auctionEnded.";

	private Long _auctionId;

	private ScheduledExecutorService _scheduledExecutorService = null;
	private ScheduledFuture<?> _watchdogTaskScheduledFuture = null;

	private HighBid _highBid = null;

	private BlockingQueue<BidRepresentation> _newBidMessageQueue = new LinkedBlockingQueue<BidRepresentation>();
	private final Semaphore _isRunning = new Semaphore(1);
	private final Semaphore _isWatchdogRunning = new Semaphore(1);
	private AuctioneerTx _auctioneerTx;
	private HighBidDao _highBidDao;
	private BidRepository _bidRepository;
	private AuctionDao _auctionDao;
	private RabbitTemplate _liveAuctionRabbitTemplate;
	
	private long _auctionMaxIdleTime;
	private boolean _shuttingDown;
	
	public AuctioneerImpl(Long auctionId, ScheduledExecutorService scheduledExecutorService,
			AuctioneerTx auctioneerTx, HighBidDao highBidDao, BidRepository bidRepository,
			AuctionDao auctionDao, RabbitTemplate rabbitTemplate, long auctionMaxIdleTime,
			Long nodeNumber) {
		logger.info("Starting auction with auctionId " + auctionId);
		_auctionId = auctionId;
		_scheduledExecutorService = scheduledExecutorService;
		_auctioneerTx = auctioneerTx;
		_highBidDao = highBidDao;
		_bidRepository = bidRepository;
		_auctionDao = auctionDao;
		_liveAuctionRabbitTemplate = rabbitTemplate;
		_auctionMaxIdleTime = auctionMaxIdleTime;
		this.nodeNumber = nodeNumber;

		// Get the latest info about the auction
		Auction theAuction = _auctionDao.get(_auctionId);

		/*
		 * If the auction is not pended, set the auction state to PENDING and
		 * then schedule a task to start the auction at the right time.
		 */
		if (theAuction.getState().equals(Auction.AuctionState.FUTURE)) {
			boolean setPending = false;
			while (!setPending) {
				try {
					// Set the auction state to pending
					theAuction = _auctioneerTx.pendAuction(theAuction.getId());
					setPending = true;
				} catch (ObjectOptimisticLockingFailureException ex) {
					logger.info("AuctioneerImpl:run: pendAuction got ObjectOptimisticLockingFailureException with message "
							+ ex.getMessage());
				} catch (CannotAcquireLockException ex) {
					logger.warn("AuctioneerImpl:run: pendAuction got CannotAcquireLockException with message "
							+ ex.getMessage());
				} catch (InvalidStateException ex) {
					logger.info("Didn't pend auction " + theAuction.toString() + ". "
							+ ex.getMessage());
					setPending = true;
				}
			}

			Date now = FixedOffsetCalendarFactory.getCalendar().getTime();
			_scheduledExecutorService.schedule(new StartAuctionTask(), theAuction.getStartTime()
					.getTime() - now.getTime(), TimeUnit.MILLISECONDS);
		} else if (theAuction.getState().equals(Auction.AuctionState.PENDING)) {
			Date now = FixedOffsetCalendarFactory.getCalendar().getTime();
			_scheduledExecutorService.schedule(new StartAuctionTask(), theAuction.getStartTime()
					.getTime() - now.getTime(), TimeUnit.MILLISECONDS);
		} else if (theAuction.getState().equals(Auction.AuctionState.RUNNING)) {
			/*
			 * Get the current item and highBid for this auction so that I can
			 * handle bids
			 */
			_highBid = _highBidDao.getActiveHighBid(_auctionId);
						
			/*
			 * We don't know how long it took to switch ownership of this auction, so
			 * resend the current high bid, with an updated nextBidCount, in order to be sure that
			 * there are no timeouts waiting for a next bid
			 */
			Bid newBid = new Bid();
			newBid.setAmount(_highBid.getAmount());
			newBid.setAuctionId(_highBid.getAuctionId());
			newBid.setBidderId(_highBid.getBidderId());
			newBid.setItemId(_highBid.getItemId());
			newBid.setBidTime(FixedOffsetCalendarFactory.getCalendar().getTime());
			newBid.setReceivingNode(nodeNumber);
			newBid.setState(BidState.PROVISIONALLYHIGH);
			logger.debug("newBidMessageQueue saving provisionallyHigh bid in bid repository: "
					+ newBid);
			newBid = _bidRepository.save(newBid);

			try {
				_highBid = _auctioneerTx.postNewHighBidTx(newBid);
				logger.debug("Saved new highBid: " + _highBid.toString());
			} catch (InvalidStateException e) {
				/*
				 * Get this if the user doesn't exist. Shouldn't get
				 * here because the user's authentication is checked
				 * in the controller
				 */
				logger.debug("Got InvalidStateException when saving updated high-bid: " + e.getMessage());
				newBid.setState(BidState.NOSUCHUSER);
				_bidRepository.save(newBid);
			} catch (Exception e) {
				logger.debug("Caught exception " + e.getCause() + " from postNewHighBid: " + e.getMessage());
			}
			
			propagateNewHighBid(_highBid);
			
			boolean auctionCompleted = false;
			long watchdogStartDelay = _auctionMaxIdleTime * 1000; 
			if (_highBid.getState() == HighBidState.SOLD) {
				/*
				 * The last thing that the previous manager did was mark the item
				 * as sold.  Need to start the next item
				 */
				auctionCompleted = startNextItem(_highBid);
			} else if (_highBid.getState() == HighBidState.LASTCALL) {
				/*
				 * Only want to have waited auctionMaxIdleTime from lastcall start
				 */
				long lastBidTimeMillis = _highBid.getCurrentBidTime().getTime();
				long now = System.currentTimeMillis();
				long delay = now - lastBidTimeMillis;
				if (delay > watchdogStartDelay) {
					watchdogStartDelay = 0;
				} else {
					watchdogStartDelay -= delay;					
				}
			}
			
			/*
			 * Don't start the watchdog if the auction is complete or if there are no
			 * bids yet for the item
			 */
			if (!auctionCompleted && (_highBid.getBidCount() > 1)) {
				// Schedule a watchdog task
				_watchdogTaskScheduledFuture = _scheduledExecutorService.schedule(new WatchdogTask(_highBid),
						watchdogStartDelay, TimeUnit.MILLISECONDS);
			}
		}
	}

	@Override
	public void shutdown() {
		logger.debug("shutdown for auctioneer for auctionId " + _auctionId);
		
		this._shuttingDown = true;	
		this.cleanup();
	}
	
	@Override
	public void cleanup() {
		
		if (_watchdogTaskScheduledFuture != null) {
			logger.debug("Cleanup cancelling watchdogTask for auctionId " + _auctionId);
			_watchdogTaskScheduledFuture.cancel(true);
		}
	}

	@Override
	public void handleNewBidMessage(BidRepresentation theBid) {
		logger.debug("handleNewBidMessage before synchronized got new bid " + theBid);
		
		
		if (_shuttingDown) {
			/*
			 * When the node is shutting down, don't handle new bids, just put them back on 
			 * the queue for the new owner 
			 */
			logger.debug("handleNewBidMessage: shutting down and so propagating bid " + theBid);
			_liveAuctionRabbitTemplate.convertAndSend(liveAuctionExchangeName, 
					LiveAuctionServiceImpl.newBidRoutingKey + theBid.getAuctionId(), theBid);
			return;
		}
		
		synchronized (_newBidMessageQueue) {
			_newBidMessageQueue.add(theBid);
			logger.debug("handleNewBidMessage got new bid " + theBid + ". isRunning = "
					+ _isRunning.availablePermits());
			/*
			 * If we can acquire the semaphore, then the newBid handler is not
			 * running. If it is not running, then start it up.
			 */
			boolean isNotRunning = _isRunning.tryAcquire();
			if (isNotRunning) {
				logger.debug("handleNewBidMessage scheduling newBid consumer for bid " + theBid);
				_scheduledExecutorService.execute(this);
				_isRunning.release();
			} else {
				logger.debug("handleNewBidMessage newBid consumer already running for bid "
						+ theBid);
			}
		}
	}

	/**
	 * The run method of the Auctioneer handles starting the auction. This is a
	 * runnable so that the initialization can be performed on a separate thread
	 * from the StartAuctioneer message reception.
	 */
	@Override
	public void run() {

		/*
		 * Don't start until hold the semaphore which signals that this consumer
		 * is running.
		 */
		try {
			_isRunning.acquire();
			_isWatchdogRunning.acquire();
		} catch (InterruptedException e1) {
			logger.warn("Auctioneer for auction " + _auctionId + " consume NewBid run interrupted.");
			return;
		}

		boolean moreMessages;
		synchronized (_newBidMessageQueue) {
			logger.debug("Checking whether newBidMessageQueue has a new bid for auction "
					+ _auctionId);
			moreMessages = !_newBidMessageQueue.isEmpty();
			if (!moreMessages) {
				logger.debug("newBidMessageQueue has no new bids for auction " + _auctionId);
				_isWatchdogRunning.release();
				_isRunning.release();
				return;
			}
		}

		while (moreMessages) {
			BidRepresentation theBid = _newBidMessageQueue.poll();

			if (theBid == null) {
				_isWatchdogRunning.release();
				_isRunning.release();
				return;
			}

			if (_shuttingDown) {
				/*
				 * When the node is shutting down, don't handle new bids, just put them back on 
				 * the queue for the new owner 
				 */
				logger.debug("run: shutting down and so propagating bid " + theBid);
				_liveAuctionRabbitTemplate.convertAndSend(liveAuctionExchangeName, 
						LiveAuctionServiceImpl.newBidRoutingKey + theBid.getAuctionId(), theBid);
				continue;
			}

			Long itemId = theBid.getItemId();

			if (!theBid.getAuctionId().equals(_auctionId)) {
				logger.warn("auctioneer run for auction " + _auctionId
						+ " received bid for wrong auction:  " + theBid.getAuctionId());
			} else if (!itemId.equals(_highBid.getItemId())) {
				logger.info("auctioneer run for auction " + _auctionId + " received bid for item "
						+ itemId + " which is not active.");
			} else {

				logger.debug("auctioneer run auctionId = " + _auctionId + " itemId=" + itemId
						+ " userId=" + theBid.getUserId() + " amount=" + theBid.getAmount());

				if (theBid.getAmount().floatValue() > _highBid.getAmount().floatValue()) {

					/*
					 * Save the bid in the NoSQL data store. Need to do this
					 * here to get a bidId to place in the highBid
					 */
					Bid newBid = new Bid();
					newBid.setAmount(theBid.getAmount());
					newBid.setAuctionId(theBid.getAuctionId());
					newBid.setBidderId(theBid.getUserId());
					newBid.setItemId(theBid.getItemId());
					newBid.setBidTime(FixedOffsetCalendarFactory.getCalendar().getTime());
					newBid.setBidCount(theBid.getLastBidCount());
					newBid.setReceivingNode(nodeNumber);
					newBid.setState(BidState.PROVISIONALLYHIGH);
					logger.debug("newBidMessageQueue saving provisionallyHigh bid in bid repository: "
							+ newBid);
					newBid = _bidRepository.save(newBid);

					/*
					 * We still need to validate this bid and save it to the
					 * database. Only when it is committed to the database is it
					 * an accepted high bid.
					 */
					HighBid returnedBid = null;
					BidState originalState = newBid.getState();
					while (returnedBid == null) {
						try {
							returnedBid = _auctioneerTx.postNewHighBidTx(newBid);
						} catch (ObjectOptimisticLockingFailureException ex) {
							logger.info("auctioneer run: got ObjectOptimisticLockingFailureException with message "
									+ ex.getMessage() + " newBid = " + newBid);
						} catch (CannotAcquireLockException ex) {
							logger.info("auctioneer run: got CannotAcquireLockException with message "
									+ ex.getMessage()
									+ ", auctionId="
									+ theBid.getAuctionId()
									+ " itemId="
									+ theBid.getItemId()
									+ " userId="
									+ theBid.getUserId() + " amount=" + theBid.getAmount());
						} catch (PessimisticLockingFailureException ex) {
							logger.info("auctioneer run: got PessimisticLockingFailureException with message "
									+ ex.getMessage()
									+ ", auctionId="
									+ theBid.getAuctionId()
									+ " itemId="
									+ theBid.getItemId()
									+ " userId="
									+ theBid.getUserId() + " amount=" + theBid.getAmount());
						} catch (InvalidStateException e) {
							/*
							 * Get this if the user doesn't exist. Shouldn't get
							 * here because the user's authentication is checked
							 * in the controller
							 */
							newBid.setState(BidState.NOSUCHUSER);
							_bidRepository.save(newBid);
							_isWatchdogRunning.release();
							_isRunning.release();
							return;
						}

						if (newBid.getState().equals(Bid.BidState.HIGH)) {
							logger.info("auctioneer run auctionId = "
									+ _auctionId
									+ " itemId="
									+ itemId
									+ " bid returned from _auctioneerTx.postNewHighBidTx was a new high bid");

							_highBid = returnedBid;

							// Cancel and reschedule the watchdog task
							if (_watchdogTaskScheduledFuture != null) {
								_watchdogTaskScheduledFuture.cancel(true);
							}
							_watchdogTaskScheduledFuture = _scheduledExecutorService.schedule(
									new WatchdogTask(_highBid), _auctionMaxIdleTime, TimeUnit.SECONDS);

							// Propagate the new high bid
							propagateNewHighBid(returnedBid);
						}

						if (newBid.getState() != originalState) {
							/*
							 * The state of the bid has changed. Update it in the repository
							 */
							_bidRepository.save(newBid);
						}
					}
				} else {
					logger.debug("The bid is not a new high bid: " + theBid);
					/*
					 * No watchDog is running, so start one
					 */
					if (_watchdogTaskScheduledFuture == null) {
						_watchdogTaskScheduledFuture = _scheduledExecutorService.schedule(
								new WatchdogTask(_highBid), _auctionMaxIdleTime, TimeUnit.SECONDS);
					}
				}
			}
			
			synchronized (_newBidMessageQueue) {
				logger.debug("Checking whether newBidMessageQueue has more new bids for auction "
						+ _auctionId);
				moreMessages = !_newBidMessageQueue.isEmpty();
				if (!moreMessages) {
					logger.debug("newBidMessageQueue has no new bids for auction " + _auctionId);
					_isWatchdogRunning.release();
					_isRunning.release();
					return;
				}
			}
		}
	}

	protected void propagateNewHighBid(HighBid newHighBid) {
		logger.info("propagating new high bid " + newHighBid);
		_liveAuctionRabbitTemplate.convertAndSend(liveAuctionExchangeName, highBidRoutingKey
				+ _auctionId, new BidRepresentation(newHighBid));
	}

	private boolean startNextItem(HighBid curHighBid) {
		boolean auctionCompleted = false;
		HighBid nextHighBid = null;
		boolean nextSuceeded = false;
		while (!nextSuceeded) {
			try {
				nextHighBid = _auctioneerTx.startNextItem(curHighBid);
				nextSuceeded = true;
				if (nextHighBid != null) {
					_highBid = nextHighBid;
					logger.debug("startNextItem propagating item start bid " + _highBid);
					propagateNewHighBid(_highBid);

				} else {
					/*
					 * The auction has ended. Send the auction
					 * ended message so other nodes can update
					 * their activeAuction lists
					 */
					auctionCompleted = true;
					_liveAuctionRabbitTemplate.convertAndSend(
							liveAuctionExchangeName, auctionEndedRoutingKey
									+ _auctionId, new AuctionRepresentation(
									curHighBid.getAuction()));

				}
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.info("startNextItem threw ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage()
						+ ", auctionId = "
						+ _auctionId
						+ ", itemId = " + curHighBid.getItem().getId());
			} catch (CannotAcquireLockException ex) {
				logger.warn("startNextItem threw CannotAcquireLockException with message "
						+ ex.getMessage()
						+ ", auctionId = "
						+ _auctionId
						+ ", itemId = " + curHighBid.getItem().getId());

			}
		}
		return auctionCompleted;
	}

	protected class StartAuctionTask implements Runnable {

		@Override
		public void run() {
			boolean suceeded = false;
			while (!suceeded) {
				try {
					logger.debug("StartAuctionTask: trying to start auction " + _auctionId);
					_highBid = _auctioneerTx.startAuction(_auctionId);
					logger.debug("StartAuctionTask: Started auction " + _auctionId);

					// Notify interested parties of the new high bid
					propagateNewHighBid(_highBid);

					suceeded = true;

				} catch (InvalidStateException ex) {
					logger.info("Didn't start auction " + _auctionId + ". " + ex.getMessage());
					break;
				} catch (AuctionNoItemsException ex) {
					logger.warn("Didn't start auction " + _auctionId + ". " + ex.getMessage());
					Boolean suceeded1 = false;
					while (!suceeded1) {
						try {
							_auctioneerTx.invalidateAuction(_auctionId);
							suceeded1 = true;
						} catch (ObjectOptimisticLockingFailureException exc) {
							// Optimistic lock exception means someone
							// invalidated the auction before us
							logger.info("PendingAuctionQueueReceiver:run invalidateAuction: got ObjectOptimisticLockingFailureException with message "
									+ exc.getMessage());
							break;
						} catch (CannotAcquireLockException exc) {
							logger.warn("PendingAuctionQueueReceiver:run InvalidateAuction: got CannotAcquireLockException with message "
									+ exc.getMessage());

						}
					}
					break;
				} catch (ObjectOptimisticLockingFailureException exc) {
					/*
					 * Optimistic lock exception means someone changed the state
					 * of the auction at the same time we were trying to. Need
					 * to retry in case change was something other than starting
					 * the auction
					 */
					logger.info("PendingAuctionQueueReceiver:run startAuction: got ObjectOptimisticLockingFailureException with message "
							+ exc.getMessage() + " when starting auction " + _auctionId);
				} catch (CannotAcquireLockException exc) {
					logger.warn("PendingAuctionQueueReceiver:run startAuction: got CannotAcquireLockException with message "
							+ exc.getMessage() + " when starting auction " + _auctionId);

				}
			}
		}

	}

	protected class WatchdogTask implements Runnable {
		
		HighBid _lastHighBid;
		
		public WatchdogTask(HighBid highBid) {
			_lastHighBid = highBid;
		}

		/*
		 * Every time the BidWatchdogTask runs, it goes through the last
		 * received bids for all active auctions and checks whether they were
		 * placed more than auctionMaxIdleTime seconds ago. If so, it makes
		 * forward progress on the auction by moving along the state of the
		 * item, and possibly the auction.
		 */
		@Override
		public void run() {

			logger.debug("bidwatchdogtask:run auction = " + _auctionId
					+ " last bid was longer than auctionMaxIdleTime ago.");
			boolean auctionCompleted = false;

			/*
			 * Don't start until hold the semaphore which signals that this
			 * consumer is running.
			 */
			try {
				_isWatchdogRunning.acquire();
			} catch (InterruptedException e1) {
				logger.info("bidwatchdogtask:run for auction " + _auctionId + " run interrupted.");
				return;
			}

			if (!_lastHighBid.equals(_highBid)) {
				// Bid has changed already.  Don't run watchdog
				_isWatchdogRunning.release();
				return;
			}
			
			HighBid curHighBid = null;
			Boolean suceeded = false;
			while (!suceeded && !_shuttingDown) {
				try {
					curHighBid = _auctioneerTx.makeForwardProgress(_highBid);
					logger.info("bidwatchdogtask:run for auction " + _auctionId + ". makeForwardProgress returned highbid: " + curHighBid);
					if (_shuttingDown) {
						/*
						 * If shutting down, don't try to send messages or start the next
						 * item.  The next auction owner will do that.
						 */
						return;
					}
					
					if (curHighBid == null) {
						/*
						 * Auction state was not OPEN or LASTCALL
						 */
						logger.warn("bidwatchdogtask:run Auction " + _auctionId
								+ " state was not OPEN or LASTCALL.");
						break;
					}
					_highBid = curHighBid;

					if (curHighBid.getState().equals(HighBidState.LASTCALL)) {
						/*
						 * Send a dummy bid for the move to lastcall
						 */
						logger.debug("bidwatchdogtask:run propagating lastcall bid " + _highBid);
						propagateNewHighBid(_highBid);
					} else if (curHighBid.getState().equals(HighBidState.SOLD)) {

						logger.debug("bidwatchdogtask:run propagating sold bid " + _highBid);
						propagateNewHighBid(_highBid);

						/*
						 * Since the item was sold. Need to start the next item
						 * in the auction (if any)
						 */
						auctionCompleted = startNextItem(curHighBid);

					}

					suceeded = true;
				} catch (ObjectOptimisticLockingFailureException ex) {
					logger.info("BidWatchdogTask:run makeForwardProgress threw ObjectOptimisticLockingFailureException with message "
							+ ex.getMessage() + ", auctionId = " + _auctionId);
				} catch (CannotAcquireLockException ex) {
					logger.warn("BidWatchdogTask:run makeForwardProgress threw CannotAcquireLockException with message "
							+ ex.getMessage() + ", auctionId = " + _auctionId);
				} catch (Throwable e) {
					logger.warn("BidWatchdogTask:run makeForwardProgress threw "
							+ e.getClass().getSimpleName() + " with message " + e.getMessage()
							+ ", auctionId = " + _auctionId);
					e.printStackTrace();
					_isWatchdogRunning.release();
					throw new RuntimeException(e.getMessage());
				} 

			}

			if (!auctionCompleted && !_shuttingDown && (_highBid.getBidCount() > 1)) {
				// Schedule a new watchdog task
				_watchdogTaskScheduledFuture = _scheduledExecutorService.schedule(
						new WatchdogTask(_highBid), _auctionMaxIdleTime, TimeUnit.SECONDS);
			} else {
				_watchdogTaskScheduledFuture = null;
			}
			_isWatchdogRunning.release();
		}

	}
}
