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

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

import javax.servlet.AsyncContext;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation.BiddingState;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public class ClientBidUpdater {
	private static final Logger logger = LoggerFactory.getLogger(ClientBidUpdater.class);

	private static ObjectMapper jsonMapper = new ObjectMapper();

	private Long _auctionId = null;

	private Long _currentItemId = null;
	private ItemRepresentation _currentItemRepresentation = null;

	private Queue<AsyncContext> _nextBidRequestQueue = new ConcurrentLinkedQueue<AsyncContext>();
	private final ReadWriteLock _nextBidRequestQueueRWLock = new ReentrantReadWriteLock();
	private final Lock _nextBidRequestQueueReadLock = _nextBidRequestQueueRWLock.readLock();
	private final Lock _nextBidRequestQueueWriteLock = _nextBidRequestQueueRWLock.writeLock();

	/*
	 * Map from itemId to the last bid for that item
	 */
	private Map<Long, BidRepresentation> _itemHighBidMap = new ConcurrentHashMap<Long, BidRepresentation>();
	private final ReadWriteLock _highBidRWLock = new ReentrantReadWriteLock();
	private final Lock _highBidReadLock = _highBidRWLock.readLock();
	private final Lock _highBidWriteLock = _highBidRWLock.writeLock();
	
	/*
	 * Constructs to synchronize access to currentItem so that in period
	 * between current item SOLD and the start of the next item the 
	 * getCurrentItem requests can be blocked.
	 */
	private final ReadWriteLock _curItemRWLock = new ReentrantReadWriteLock();
	private final Lock _curItemReadLock = _curItemRWLock.readLock();
	private final Lock _curItemWriteLock = _curItemRWLock.writeLock();
	private final Condition _itemAvailableCondition = _curItemWriteLock.newCondition();
	
	private HighBidDao _highBidDao;
	private ItemDao _itemDao;
	private ScheduledExecutorService _scheduledExecutorService;
	private ImageStoreFacade _imageStoreFacade;
	private RabbitTemplate _rabbitTemplate;

	private boolean _sentWakeUpBid = false;
	
	private boolean _shuttingDown = false;

	private boolean _release;

	
	public ClientBidUpdater(Long auctionId, HighBidDao highBidDao, ItemDao itemDao,
			ScheduledExecutorService scheduledExecutorService, ImageStoreFacade imageStoreFacade,
			RabbitTemplate rabbitTemplate) {
		logger.info("Creating clientBidUpdater for auction " + auctionId);
		_auctionId = auctionId;
		_itemDao = itemDao;
		_imageStoreFacade = imageStoreFacade;
		_highBidDao = highBidDao;
		_scheduledExecutorService = scheduledExecutorService;	
		_rabbitTemplate = rabbitTemplate;
		
		/*
		 * Initialize our knowledge of existing high bids for this auction so
		 * that we can handle delayed requests.
		 */
		List<HighBid> existingHighBids = _highBidDao.findByAuctionId(_auctionId);
		for (HighBid aHighBid : existingHighBids) {
			_itemHighBidMap.put(aHighBid.getItemId(), new BidRepresentation(aHighBid));
			if (!aHighBid.getState().equals(HighBidState.SOLD)) {
				_currentItemId = aHighBid.getItemId();
				if (_currentItemId != null) {
					if (_itemDao == null) {
						logger.warn("ClientBidUpdater: _itemDao is null. current itemId = " + _currentItemId + ", auctionId = " + auctionId);
					} else {
						logger.debug("ClientBidUpdater the currentItem from the itemDao. current itemId = " 
								+ _currentItemId + ", auctionId = " + auctionId);
						Item theItem = _itemDao.get(_currentItemId);
						List<ImageInfo> theImageInfos = _imageStoreFacade.getImageInfos(
								Item.class.getSimpleName(), _currentItemId);
						_currentItemRepresentation = new ItemRepresentation(theItem, theImageInfos, false);	
					}
				}
			}
		}
	}

	public void release() {
		
		this._release = true;
		
		/*
		 * If the bid completer isn't already running, schedule it for execution
		 * on the thread pool to complete any remaining outstanding bid requests
		 */
		for (Long itemId : _itemHighBidMap.keySet()) {
			_scheduledExecutorService.execute(new NextBidRequestCompleter(_itemHighBidMap
					.get(itemId)));
		}

	}

	public void handleHighBidMessage(BidRepresentation newHighBid) {

		if (!newHighBid.getAuctionId().equals(_auctionId)) {
			logger.warn("handleHighBidMessage: ClientBidUpdater for auction " + _auctionId
					+ " got a high bid message for auction " + newHighBid.getAuctionId());
			return;
		}
		
		Long itemId = newHighBid.getItemId();
		_highBidWriteLock.lock();
		try {
			BidRepresentation curHighBid = _itemHighBidMap.get(itemId);
			/*
			 * Want to ignore high bids for an item whose bidcount is lower that the current
			 * high bid. Have a special case to allow lower bid count for items that were
			 * sold without receiving any bids and are being put back up for auction.
			 */
			if ((curHighBid != null) && (newHighBid.getLastBidCount() <= curHighBid.getLastBidCount())
					&& !(curHighBid.getBiddingState().equals(BiddingState.SOLD) && (curHighBid.getLastBidCount() == 3)
							&& (newHighBid.getLastBidCount() == 1))) {
				logger.debug(
						"handleHighBidMessage: using existing bid because curBidCount {} is higher than newBidCount {}",
						curHighBid.getLastBidCount(), newHighBid.getLastBidCount());
				newHighBid = curHighBid;
			}

			logger.debug("handleHighBidMessage: got newHighBid " + newHighBid + ", itemid = " + itemId
					+ ", currentItemId = " + _currentItemId);
			_itemHighBidMap.put(itemId, newHighBid);

		} finally {
			_highBidWriteLock.unlock();
		}
		
		try {
			_curItemWriteLock.lock();
			if ((_currentItemId == null) 
					|| (newHighBid.getBiddingState().equals(BiddingState.OPEN) && (itemId.compareTo(_currentItemId) > 0))) {
				/*
				 * This highBid is for a new item. Update the current item id
				 */
				logger.info("handleHighBidMessage: Got new item for auctionId = {}, itemId = {}", _auctionId,
						itemId);
				_currentItemId = itemId;
				_currentItemRepresentation = null;
				_itemAvailableCondition.signalAll();
				_sentWakeUpBid = false;
			}
			if (newHighBid.getBiddingState().equals(BiddingState.SOLD) && newHighBid.getItemId().equals(_currentItemId)) {
				/*
				 * If this the item is SOLD, then clear out the currentItemRepresentation to
				 * force a refresh of the current item for getCurrentItem
				 */
				logger.info("handleHighBidMessage: Item sold for auctionId = {}, itemId = {}, clearing currentItemId", _auctionId,
						itemId);
				_currentItemId = null;
				_currentItemRepresentation = null;
			}
		} finally {
			_curItemWriteLock.unlock();
		}

		_scheduledExecutorService.execute(new NextBidRequestCompleter(newHighBid));

	}

	/**
	 * This method returns the most recent bid on the item identified by itemId
	 * in the auction identified by auctionId. If the bid identified by
	 * lastBidCount is the most recent bid, then this becomes an asynchronous
	 * (long pull) request, which will be completed once a new bid is received.
	 * 
	 * @author hrosenbe
	 * @throws AuthenticationException
	 */
	@Transactional(readOnly = true)
	public BidRepresentation getNextBid(Long auctionId, Long itemId, Integer lastBidCount,
			AsyncContext ac) throws InvalidStateException {
		logger.debug("getNextBid for auctionId = " + auctionId + ", itemId = " + itemId
				+ ", lastBidCount = " + lastBidCount);

		if (!auctionId.equals(_auctionId)) {
			String msg = "getNextBid request for auction " + auctionId
					+ " ended up in ClientBidUpdater for auction " + _auctionId;
			logger.warn(msg);
			throw new InvalidStateException(msg);
		}

		BidRepresentation returnBidRepresentation = null;
		_highBidReadLock.lock();
		try {
			BidRepresentation highBidRepresentation = _itemHighBidMap.get(itemId);
			/*
			 * Send the highBid back if the bidCount is 1 to tell the auctioneer
			 * to start the watchdog timer 
			 */
			if ((highBidRepresentation.getLastBidCount() == 1) && !_sentWakeUpBid) {
				_rabbitTemplate.convertAndSend(BidServiceImpl.liveAuctionExchangeName, 
						BidServiceImpl.newBidRoutingKey + highBidRepresentation.getAuctionId(), 
						highBidRepresentation);
				_sentWakeUpBid = true;
			}
			if (((highBidRepresentation != null)
					&& ((highBidRepresentation.getLastBidCount().intValue() > lastBidCount.intValue())
							|| highBidRepresentation.getBiddingState().equals(BiddingState.SOLD)))
					|| _shuttingDown || _release) {

				/*
				 * If there is a more recent high bid, or if the bidding is complete on the
				 * item, or if the service is shutting down, then just return last high bid.
				 */
				returnBidRepresentation = highBidRepresentation;
				logger.debug(
						"getNextBid: There is already a more recent bid.  Returning it.  returnBidRepresentation = "
								+ returnBidRepresentation);
			}

			if (returnBidRepresentation == null) {
				/*
				 * Need to wait for the next high bid. Place the async context on the
				 * nextBidRequest queue and return null. The nextBidRequest will be completed by
				 * the ClientBidUpdater when a new high bid is posted.
				 * This uses a read lock even though it appears to be a write because it is actually
				 * the reading/writing of the _nextBidRequestQueue reference, and not writing to the
				 * queue, that we are synchronizing.
				 */
				_nextBidRequestQueueReadLock.lock();
				try {
					logger.debug("getNextBid adding request to itemNextBidRequestQueue for auctionId = " + auctionId
							+ ", itemId = " + itemId + ", lastBidCount = " + lastBidCount);
					_nextBidRequestQueue.add(ac);					
				} finally {
					_nextBidRequestQueueReadLock.unlock();
				}

			}
		} finally {
			_highBidReadLock.unlock();
		}
		
		return returnBidRepresentation;

	}

	private String getJsonBidRepresentation(BidRepresentation bidRepresentation) {
		StringWriter jsonWriter;

		jsonWriter = new StringWriter();
		try {
			jsonMapper.writeValue(jsonWriter, bidRepresentation);
		} catch (Exception ex) {
			logger.error("Exception when translating to json: " + ex);
		}
		return jsonWriter.toString();
	}

	public ItemRepresentation getCurrentItem(long auctionId) {
		/*
		 * Fast path.  As long as curItemid and curItemRepresentation are set,
		 * they are valid and we can return the curItemRepresentation.
		 */
		try {
			_curItemReadLock.lock();
			if ((_currentItemId != null) && (_currentItemRepresentation != null)) {
				logger.warn("getCurrentItem: Returning currentItemRepresentation with itemId = {} for auctionId = {}",
						_currentItemRepresentation.getId(), auctionId);
				return _currentItemRepresentation;
			}
		} finally {
			_curItemReadLock.unlock();
		}
		
		ItemRepresentation itemToReturn = null;
		try {
			_curItemWriteLock.lock();
			while (_currentItemId == null) {
				/*
				 * Need to wait for the current item to be set
				 */
				logger.info("getCurrentItem: currentItemId is null for auctionid = {}", auctionId);
				_itemAvailableCondition.await();
			}
			if (_currentItemRepresentation == null) {
				/*
				 * Update the current item
				 */
				if (_itemDao == null) {
					logger.warn("getCurrentItem: _itemDao is null. current itemId = " + _currentItemId
							+ ", auctionId = " + auctionId);
					return _currentItemRepresentation;
				}
				logger.info("getCurrentItem: Getting the currentItem from the itemDao. current itemId = "
						+ _currentItemId + ", auctionId = " + auctionId);
				Item theItem = _itemDao.get(_currentItemId);
				List<ImageInfo> theImageInfos = _imageStoreFacade.getImageInfos(Item.class.getSimpleName(),
						_currentItemId);
				_currentItemRepresentation = new ItemRepresentation(theItem, theImageInfos, false);
			}
			itemToReturn = _currentItemRepresentation;
		} catch (InterruptedException e) {
			logger.warn("getCurrentItem: _itemAvailableCondition.await() interrupted");
		} finally {
			_curItemWriteLock.unlock();
		}

		logger.info("getCurrentItem: returning itemToReturn with itemId = {}, auctionid = {}", 
				itemToReturn.getId(), auctionId);
		return itemToReturn;
	}

	public void shutdown() {
		this._shuttingDown = true;
		
		/*
		 * Start the NextBidRequestCompleter to complete all of the 
		 * outstanding requests.
		 */
		for (Long itemId : _itemHighBidMap.keySet()) {
			_scheduledExecutorService.execute(new NextBidRequestCompleter(_itemHighBidMap
					.get(itemId)));
		}

	}
	
	protected class NextBidRequestCompleter implements Runnable {

		private BidRepresentation theHighBid;

		public NextBidRequestCompleter(BidRepresentation highBid) {
			theHighBid = highBid;
		}

		@Override
		public void run() {
			logger.debug("nextBidRequestCompleter run for auction " + _auctionId + " got highBid: "
					+ theHighBid.toString());
			if ((_nextBidRequestQueue == null) || (_nextBidRequestQueue.isEmpty())) {
				// No client is actually waiting
				logger.debug("nextBidRequestCompleter run return due to empty queue for auction " 
						+ _auctionId);
				return;
			}

			/*
			 *  Get the current nextBidRequestQueue replace it with an empty queue
			 */
			Long itemId = theHighBid.getItemId();
			Queue<AsyncContext> nextBidRequestQueue;
			_nextBidRequestQueueWriteLock.lock();
			try {
				nextBidRequestQueue = _nextBidRequestQueue;
				_nextBidRequestQueue = new ConcurrentLinkedQueue<AsyncContext>();
				
			} finally {
				_nextBidRequestQueueWriteLock.unlock();
			}

			String jsonResponse = getJsonBidRepresentation(theHighBid);
			AsyncContext theAsyncContext = nextBidRequestQueue.peek();
			while (theAsyncContext != null) {
				logger.debug("ClientBidUpdater run nextQueueEntry is " + theAsyncContext);

				theAsyncContext = nextBidRequestQueue.poll();
				if (theAsyncContext == null) {
					_release = false;
					return;
				}

				// get the response from the async context
				HttpServletResponse response = (HttpServletResponse) theAsyncContext.getResponse();
				if (response.isCommitted()) {
					logger.warn("Found an asyncContext whose response has already been committed for auctionId = "
							+_auctionId + ", itemId = " + itemId + ". ");
				} else {

					// Fill in the content
					response.setContentType("application/json");

					PrintWriter out;
					try {
						out = response.getWriter();
						out.print(jsonResponse);
					} catch (IOException ex) {
						logger.error("Exception when getting writer from response: " + ex);
					}

					HttpServletRequest request = (HttpServletRequest) theAsyncContext.getRequest();
					logger.debug("Completing asyncContext with URL " + request.getRequestURL().toString()
							+ " with response: " + jsonResponse.toString());
					// Complete the async request
					theAsyncContext.complete();

				}

				theAsyncContext = nextBidRequestQueue.peek();

			}
			_release = false;

		}
	}
}
