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

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collection;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.Consumer;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.AsyncContext;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.Binding.DestinationType;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordState;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Auction.AuctionState;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.repository.AttendanceRecordRepository;
import com.vmware.weathervane.auction.data.repository.BidRepository;
import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation.BiddingState;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.BidService;
import com.vmware.weathervane.auction.service.GroupMembershipService;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.service.liveAuction.message.StartAuctioneer;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

public class LiveAuctionServiceImpl implements LiveAuctionService {

	private static final Logger logger = LoggerFactory.getLogger(LiveAuctionServiceImpl.class);

	public static final String auctionManagementGroupName = "liveAuctionMgmtGroup";
	public static final String auctionAssignmentMapName = "liveAuctionAssignmentMap";

	public static final String liveAuctionExchangeName = "liveAuctionMgmtExchange";
	public static final String newBidRoutingKey = "newBid.";


	// The longest that an auction can go (in seconds) without a bid before the
	// state of the current item is changed to either LASTCALL or SOLD
	private int auctionMaxIdleTime = 30;

	private int _numAuctioneerExecutorThreads = 1;
	private int _numClientUpdateExecutorThreads = 1;
	private ScheduledThreadPoolExecutor _auctioneerExecutorService;
	private ScheduledExecutorService _groupMembershipExecutorService = Executors.newScheduledThreadPool(2);
	private ScheduledExecutorService _assignmentHandlerExecutorService = Executors.newScheduledThreadPool(1);
	private ScheduledThreadPoolExecutor _clientUpdateExecutorService;

	private List<Long> _currentAuctionAssignment;
	
	MembershipChangedHandler _membershipChangedHandler = null;
	
	private ConcurrentMap<Long, Auctioneer> _auctionIdToAuctioneerMap = new ConcurrentHashMap<Long, Auctioneer>();
	private ConcurrentMap<Long, Binding> _auctionIdToBindingMap = new ConcurrentHashMap<Long, Binding>();

	/*
	 * Set to true when exiting to allow leader (if we are the leader) to exit cleanly
	 */
	private boolean _exiting = false;
	
	private boolean _isMaster = false;
	/**
	 * The auctions that are currently active, with map from auctionId to the
	 * auction
	 */
	private Map<Long, ClientBidUpdater> _clientBidUpdaterMap = new ConcurrentSkipListMap<Long, ClientBidUpdater>();

	private static long _activeAuctionsMisses = 0;

	/*
	 * When fetching pending auctions, this controls both the time period in
	 * seconds for which to fetch the next set of auctions, and the delay until
	 * the next set of auctions is fetched. It is actually used by the
	 * AuctionManager
	 */
	private int _auctionQueueUpdateDelay;

	/*
	 * The delay in seconds between sending out heartbearts
	 */
	private int _liveAuctionNodeHeartbeatDelay;

	private Long nodeNumber = Long.getLong("nodeNumber", -1L);

	private static Lock auctionAssignmentChangeLock = new ReentrantLock();

	@Inject
	@Named("liveAuctionRabbitTemplate")
	RabbitTemplate liveAuctionRabbitTemplate;

	@Inject
	private RabbitAdmin rabbitAdmin;

	@Inject
	@Named("newBidQueue")
	private Queue _newBidQueue;

	@Inject
	@Named("groupMembershipService")
	private GroupMembershipService groupMembershipService;

	@Inject
	@Named("liveAuctionServiceTx")
	private LiveAuctionServiceTx liveAuctionServiceTx;

	@Inject
	@Named("auctioneerTx")
	private AuctioneerTx _auctioneerTx;

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
	private HighBidDao _highBidDao;

	@Inject
	private BidRepository _bidRepository;

	@Inject
	private AttendanceRecordRepository attendanceRecordRepository;

	@Inject
	@Named("bidService")
	private BidService bidService;

	@Inject
	ImageStoreFacade imageStoreFacade;

	private TakeLeadershipHandler _takeLeadershipHandler;

	public LiveAuctionServiceImpl() {
	}
	
	@PostConstruct
	private void initialize() throws Exception {
		logger.info("LiveAuctionService initialize.  Creating thread pools. numAuctioneerThreads = " + _numAuctioneerExecutorThreads
				+ ", numClientUpdateThreads = " + _numClientUpdateExecutorThreads);
		_auctioneerExecutorService = (ScheduledThreadPoolExecutor) Executors.newScheduledThreadPool(_numAuctioneerExecutorThreads, new ThreadFactory() {
			private final AtomicInteger counter = new AtomicInteger();

			@Override
			public Thread newThread(Runnable r) {
				final String threadName = String.format("auctioneerThread-%d", counter.incrementAndGet());
				Thread newThread = new Thread(r, threadName);
				return newThread;
			}
		});
		_auctioneerExecutorService.setRemoveOnCancelPolicy(true);

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

		/*
		 * Schedule a task to join the auction management distributed group.
		 * Don't join immediately so we are sure that the node is fully started.
		 */
		_groupMembershipExecutorService.schedule(new Runnable() {
			@Override
			public void run() {

				try {
					/*
					 * Create a node to hold the auction assignment for this
					 * node
					 */
					logger.info("Creating node in auctionAssignmentMap");
					groupMembershipService.createNode(auctionAssignmentMapName, nodeNumber, "");

					/*
					 * Register a callback to listen for changes in the auctions
					 * assigned to this node sent to the group. When the auction
					 * assignment changes, update the auctioneers running on
					 * this node
					 */
					logger.info("Registering change callback for assigned auctions");
					groupMembershipService.registerContentsChangedCallback(auctionAssignmentMapName, nodeNumber,
							new AuctionAssignmentChangedHandler());
					_currentAuctionAssignment = new LinkedList<Long>();

					logger.info("Joining distributed group " + auctionManagementGroupName);
					groupMembershipService.joinDistributedGroup(auctionManagementGroupName);

					/*
					 * Register a callback for when this node is made leader
					 */
					logger.info("Registering callback for taking leadership of group " + auctionManagementGroupName);
					_takeLeadershipHandler = new TakeLeadershipHandler();
					groupMembershipService.registerTakeLeadershipCallback(auctionManagementGroupName,
							_takeLeadershipHandler);
					
				} catch (Exception e1) {
					logger.error("Couldn't set up group membership.  Not handling auctions: " + e1.getMessage());
					/*
					 * leave all groups
					 */
					groupMembershipService.cleanUp();
				}

			}

		}, 240, TimeUnit.SECONDS);
		
		// Create ClientBidUpdaters for auctions that are already running
		logger.info("Create ClientBidUpdaters for auctions that are already running");
		List<HighBid> highBids = _highBidDao.getActiveHighBids();
		for (HighBid aHighBid : highBids) {
			_clientBidUpdaterMap.put(aHighBid.getAuctionId(),
					new ClientBidUpdater(aHighBid.getAuctionId(), _highBidDao, itemDao, _auctioneerExecutorService, imageStoreFacade));
		}

	}

	@PreDestroy
	private void cleanup() {
		
		if (!_exiting) {
			prepareForShutdown();
		}
		
		_groupMembershipExecutorService.shutdown();
		_auctioneerExecutorService.shutdown();
		_assignmentHandlerExecutorService.shutdown();
		_clientUpdateExecutorService.shutdown();

		try {
			_groupMembershipExecutorService.awaitTermination(30, TimeUnit.SECONDS);
			_auctioneerExecutorService.awaitTermination(30, TimeUnit.SECONDS);
			_assignmentHandlerExecutorService.awaitTermination(30, TimeUnit.SECONDS);
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
			 * Remove all of the rabbitmq bindings
			 */
			for (Long auctionId : _auctionIdToBindingMap.keySet()) {
				rabbitAdmin.removeBinding(_auctionIdToBindingMap.get(auctionId));
				Auctioneer auctioneer = _auctionIdToAuctioneerMap.get(auctionId);
				auctioneer.shutdown();
			}

			/*
			 * Tell all of the ClientBidUpdaters to stop accepting new requests
			 * and to complete any outstanding async requests
			 */
			for (Long auctionId : _clientBidUpdaterMap.keySet()) {
				ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);
				clientBidUpdater.shutdown();
			}

			/*
			 * leave all groups
			 */
			groupMembershipService.cleanUp();
			
			this.releaseGetNextBid();
		}
	}

	@Override
	@Cacheable(value = "activeAuctionCache")
	public CollectionRepresentation<AuctionRepresentation> getActiveAuctions(Integer page, Integer pageSize) {
		logger.debug("GetActiveAuctions page = " + page + ", pageSize = " + pageSize);
		_activeAuctionsMisses++;

		ArrayList<AuctionRepresentation> liveAuctions = new ArrayList<AuctionRepresentation>();
		CollectionRepresentation<AuctionRepresentation> colRep = new CollectionRepresentation<AuctionRepresentation>();

		// Get the total number of active auctions
		int totalRecords = _clientBidUpdaterMap.size();

		if (totalRecords == 0) {
			colRep.setPage(0);
			colRep.setPageSize(0);
			colRep.setTotalRecords(0L);
			colRep.setResults(liveAuctions);
			return colRep;
		}

		page = LiveAuctionServiceConstants.getCollectionPage(page);
		pageSize = LiveAuctionServiceConstants.getCollectionPageSize(pageSize);

		// How many pages are there
		int numPages = (int) Math.ceil((double) totalRecords / (double) pageSize);
		logger.debug("GetActiveAuctions totalRecords = " + totalRecords + ", numPages = " + numPages);

		if (page > (numPages - 1)) {
			logger.debug("GetActiveAuctions page > (numPages - 1), page = 0 ");
			page = 0;
		}

		List<Auction> auctions = auctionDao.getAuctionsPage(page, pageSize, AuctionState.RUNNING);
		for (Auction anAuction : auctions) {
			liveAuctions.add(new AuctionRepresentation(anAuction));
		}

		colRep.setPage(page);
		colRep.setPageSize(pageSize);
		colRep.setTotalRecords((long) totalRecords);
		colRep.setResults(liveAuctions);

		return colRep;

	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * com.vmware.liveAuction.service.LiveAuctionService#joinAuction(com.vmware
	 * .liveAuction.representation.AttendanceRecordRepresentation)
	 */
	@Override
	@Transactional(readOnly = true)
	public AttendanceRecordRepresentation joinAuction(AttendanceRecordRepresentation record) throws InvalidStateException, AuctionNotActiveException {

		Auction theAuction = auctionDao.get(record.getAuctionId());
		if (theAuction == null) {
			logger.warn("Invalid attempt to join non-existent auction with id " + record.getId());
			throw new RuntimeException("In JoinAuction: no auction found with Id " + record.getAuctionId());
		}
		if (theAuction.getState().equals(Auction.AuctionState.COMPLETE)) {
			throw new AuctionNotActiveException("Auction " + theAuction.getId() + " is complete.");
		}

		if (theAuction.getState() != AuctionState.RUNNING) {
			throw new InvalidStateException("Auction is not Running.");
		}

		Date now = FixedOffsetCalendarFactory.getCalendar().getTime();
		AttendanceRecord newRecord = new AttendanceRecord();
		newRecord.setUserId(record.getUserId());
		newRecord.setTimestamp(now);
		newRecord.setAuctionId(theAuction.getId());
		newRecord.setAuctionName(theAuction.getName());
		newRecord.setState(AttendanceRecordState.ATTENDING);

		attendanceRecordRepository.save(newRecord);

		return new AttendanceRecordRepresentation(newRecord);

	}

	@Override
	@Transactional
	public AttendanceRecordRepresentation leaveAuction(long userId, long auctionId) throws InvalidStateException {
		Date now = FixedOffsetCalendarFactory.getCalendar().getTime();

		AttendanceRecord attendanceRecord = new AttendanceRecord();
		attendanceRecord.setAuctionId(auctionId);
		attendanceRecord.setUserId(userId);
		attendanceRecord.setTimestamp(now);
		attendanceRecord.setState(AttendanceRecordState.LEFT);

		attendanceRecordRepository.save(attendanceRecord);

		return new AttendanceRecordRepresentation(attendanceRecord);
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
	public void handleStartAuctioneerMessage(StartAuctioneer startAuction) {
		logger.warn("Node " + nodeNumber + " received StartAuction message for auctionId " + startAuction.getAuctionId());
		Long auctionId = startAuction.getAuctionId();

		/*
		 * Add a binding to the newBidQueue to listen for new bids for this
		 * auction.
		 */
		Binding newBidBinding = new Binding(_newBidQueue.getName(), DestinationType.QUEUE, liveAuctionExchangeName, newBidRoutingKey + auctionId, null);
		rabbitAdmin.declareBinding(newBidBinding);
		_auctionIdToBindingMap.put(auctionId, newBidBinding);

		Auctioneer auctioneer = new AuctioneerImpl(auctionId, _auctioneerExecutorService, _auctioneerTx, _highBidDao, _bidRepository, auctionDao,
				liveAuctionRabbitTemplate, auctionMaxIdleTime);
		_auctionIdToAuctioneerMap.put(auctionId, auctioneer);

	}
	
	@Override
	public void handleAuctionEndedMessage(AuctionRepresentation anAuction) {
		logger.info("auctionStarted.  Got an auction ended message for auction with id " + anAuction.getId());

		Long auctionId = anAuction.getId();
		ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);
		clientBidUpdater.shutdown();
		_clientBidUpdaterMap.remove(auctionId);

		Auctioneer auctioneer = _auctionIdToAuctioneerMap.get(auctionId);
		if (auctioneer != null) {
			/*
			 * The auction is being run on this node. Stop the auctioneer.
			 */
			auctioneer.cleanup();
			_auctionIdToAuctioneerMap.remove(auctionId);
		}

	}

	@Override
	public void handleHighBidMessage(BidRepresentation newHighBid) {
		logger.debug("handleHighBidMessage got highBid " + newHighBid);
		newHighBid.setReceivingNode(nodeNumber);
		Long auctionId = newHighBid.getAuctionId();
		if (auctionId == null) {
			logger.warn("handleHighBidMessage got highBid " + newHighBid + " with no auctionId.");
			return;
		}
		
		logger.debug("handleHighBidMessage: auctionId = " + auctionId);
		ClientBidUpdater clientBidUpdater = _clientBidUpdaterMap.get(auctionId);

		if (clientBidUpdater == null) {
			// Create a ClientBidUpdater for this auction
			logger.debug("HighBidDispatcher creating ClientBidUpdater for highBid " + newHighBid);
			clientBidUpdater = new ClientBidUpdater(newHighBid.getAuctionId(), _highBidDao, itemDao, _clientUpdateExecutorService, imageStoreFacade);

			_clientBidUpdaterMap.put(auctionId, clientBidUpdater);
		}

		clientBidUpdater.handleHighBidMessage(newHighBid);
	}

	@Override
	public void handleNewBidMessage(BidRepresentation theBid) {
		logger.debug("handleNewBidMessage got new bid " + theBid);
		Long auctionId = theBid.getAuctionId();
		Auctioneer auctioneer = _auctionIdToAuctioneerMap.get(auctionId);
		if (auctioneer != null) {
			auctioneer.handleNewBidMessage(theBid);
		} else {
			logger.warn("Received new bid for auction which is not running.  Auction ID = " + auctionId);
		}
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


	private List<Long> auctionAssignmentStringToList(String auctionAssignmentString) {
		List<Long> auctionIds = new LinkedList<Long>();
		if ((auctionAssignmentString == null) || (auctionAssignmentString.equals(""))) {
			return auctionIds;
		}
		
		String[] auctionIdStrings = auctionAssignmentString.split(",");
		for (String idString : auctionIdStrings) {
			Long id = null;
			try {
				id = Long.parseLong(idString);
			} catch (NumberFormatException e) {
				logger.warn("auctionAssignmentStringToList got numberFormatException for " + idString);
				continue;
			}
			if (id != null) {
				auctionIds.add(id);
			}
		}
		
		auctionIds.sort((x,y) -> Long.compare(x, y));
		return auctionIds;
		
	}
	
	private String auctionAssignmentListToString(List<Long> auctionIds) {
		logger.info("auctionAssignmentListToString");
		StringBuilder auctionAssignmentString = new StringBuilder();
		
		for (Long id : auctionIds) {
			auctionAssignmentString.append(id.toString() + ",");
		}
		
		// Delete last comma
		if (auctionAssignmentString.length() > 0) {
			auctionAssignmentString.deleteCharAt(auctionAssignmentString.length() - 1);
		}
		return auctionAssignmentString.toString();
	}
	
	private Map<String, List<Long>> rebalanceAuctions(Map<String, List<Long>> groupMembers) {
		logger.info("rebalanceAuctions: There are " + groupMembers.size() + " members");

		// Get the total number of auctions
		long totalNumAuctions = 0;
		for (String memberId : groupMembers.keySet()) {
			totalNumAuctions += groupMembers.get(memberId).size();
		}
		logger.info("rebalanceAuctions: There are " + totalNumAuctions + " total auctions and " + groupMembers.size() + " members,");

		/*
		 * This actually understates the number of auctions per member by the
		 * remainder, but it doesn't matter because this is just an estimate
		 * used to create the pool of auctions to reallocate.
		 */
		long auctionsPerMember = (long) Math.floor(totalNumAuctions / (groupMembers.size() * 1.0));
		logger.info("rebalanceAuctions: Want " + auctionsPerMember + " auctions per member.");

		/*
		 * If every node is already running at least auctionsPerMember auctions
		 * then we are done. We don't want to keep reassigning the few extra
		 * auctions.
		 */
		boolean needToRebalance = false;
		for (String memberId : groupMembers.keySet()) {
			if (groupMembers.get(memberId).size() < auctionsPerMember) {
				needToRebalance = true;
			}
		}
		if (!needToRebalance) {
			logger.info("All members are running the minimum needed number of auctions.  returning");
			return groupMembers;
		}
			
		/*
		 * Remove auctions from members with more than auctionsPerMember
		 */
		List<Long> unassignedAuctions = new ArrayList<Long>();
		for (String memberId : groupMembers.keySet()) {
			List<Long> auctionIds = groupMembers.get(memberId);
			logger.info("rebalanceAuctions: removing auctions. member " + memberId + " is running " + auctionIds.size() + " auctions.");
			while (auctionIds.size() > auctionsPerMember) {
				Long auctionId = auctionIds.remove(0);
				logger.info("rebalanceAuctions removing auction " + auctionId + " from AuctionManagement group member " + memberId);

				unassignedAuctions.add(auctionId);
			}

		}

		if (unassignedAuctions.size() > 0) {
			/*
			 * Add auctions to members that have fewer than auctionsPerMember
			 */
			for (String memberId : groupMembers.keySet()) {
				List<Long> auctionIds = groupMembers.get(memberId);

				logger.info("rebalanceAuctions: adding auctions. member " + memberId + " is running " + auctionIds.size() + " auctions.");

				while (auctionIds.size() < auctionsPerMember) {
					logger.info("rebalanceAuctions: removing auctionId from unassignedAuctions.  unassignedAuctions has " + unassignedAuctions.size()
							+ " auctions");
					Long auctionId = unassignedAuctions.remove(0);
					logger.info("rebalanceAuctions: got auctionId " + auctionId);
					auctionIds.add(auctionId);
					logger.info("rebalanceAuctions assigning auction " + auctionId + " to AuctionManagement group member " + memberId);
				}
			}

			/*
			 * Add remaining auctions to members round robin
			 */
			logger.info(
					"rebalanceAuctions: after assignment there are still " + unassignedAuctions.size() + " unassigned auctions.  Assigning them round-robin");
			while (!unassignedAuctions.isEmpty()) {
				for (String memberId : groupMembers.keySet()) {
					List<Long> auctionIds = groupMembers.get(memberId);
					Long auctionId = unassignedAuctions.remove(0);
					logger.info("rebalanceAuctions assigning auction " + auctionId + " to AuctionManagement group member " + memberId);
					auctionIds.add(auctionId);
					if (unassignedAuctions.isEmpty()) {
						break;
					}
				}
			}
		}
		return groupMembers;
	}
	
	private Map<String, List<Long>> getCurrentAuctionAssignmentMap() throws Exception {
		logger.info("getCurrentAuctionAssignmentMap");
		Map<String, List<Long>> assignmentMap = new HashMap<String, List<Long>>();
		
		/*
		 * Get the current group membership
		 */
		List<String> currentGroupMembersSet = groupMembershipService.getChildrenForNode(auctionAssignmentMapName);
		
		for (String memberId : currentGroupMembersSet) {
			logger.info("getCurrentAuctionAssignmentMap: Found member with id " + memberId + ".");
			Long id = null;
			try {
				id = Long.parseLong(memberId);
			} catch (NumberFormatException e) {
				logger.info("getCurrentAuctionAssignmentMap: Got NumberFormatException translating memberId " + memberId);
				continue;
			}
			
			String assignedAuctionsString = groupMembershipService.readContentsForNode(auctionAssignmentMapName, id);
			logger.debug("getCurrentAuctionAssignmentMap: For memberId " + memberId + " got assignedAuctionsString " + assignedAuctionsString);
			assignmentMap.put(memberId, auctionAssignmentStringToList(assignedAuctionsString));
		}
		
		return assignmentMap;
		
	}

	private void updateCurrentAuctionAssignment(Map<String, List<Long>> auctionAssignmentMap) throws Exception {
		logger.info("updateCurrentAuctionAssignment");
		for (String memberId : auctionAssignmentMap.keySet()) {
			logger.info("Translating auctionAssignmentListToString for member " + memberId);
			String auctionAssignmentString = auctionAssignmentListToString(auctionAssignmentMap.get(memberId));
			groupMembershipService.writeContentsForNode(auctionAssignmentMapName, Long.parseLong(memberId), auctionAssignmentString);
		}
		
	}

	/**
	 * This method assigns auctions to group members
	 * 
	 * @param groupMembers
	 * @param auctionIds
	 * @return
	 */
	private Map<String, List<Long>> assignAuctions(Map<String, List<Long>> groupMembers, Collection<Long> auctionIds) {

		if (auctionIds.size() <= 0) {
			// No auctions to assign
			logger.debug("assignAuctions: No auctions to assign.  Returning.");
			return groupMembers;
		}

		if (groupMembers.size() <= 0) {
			logger.warn("AuctionManager couldn't start auctions because there are no AuctionManagement group members");
			return groupMembers;
		}

		logger.warn("AuctionManager assignAuctions.  There are " + groupMembers.size() 
					+ " known AuctionManagement group members and " 
					+ auctionIds.size()	+ " auctions that need to be assigned.");
		
		// Add auctions to members round-robin
		List<String> groupMemberIds = new ArrayList<String>(groupMembers.keySet()); 
		int nextMemberIndex = 0;
		for (Long auctionId : auctionIds) {

			String nextMemberId = groupMemberIds.get(nextMemberIndex);
			List<Long> assignedAuctions = groupMembers.get(nextMemberId); 
			logger.warn("AuctionManager assigning auction " + auctionId + " to AuctionManagement group member " + nextMemberId);
			assignedAuctions.add(auctionId);

			nextMemberIndex++;
			if (nextMemberIndex >= groupMembers.size()) {
				nextMemberIndex = 0;
			}

		}
		logger.info("Finished assigning auctions to group members");
		return groupMembers;
	}
	
	@Override
	public Boolean isMaster() {
		return _isMaster;
	}

	
	protected class AuctionAssignmentChangedHandler implements Consumer<String> {

		@Override
		public void accept(String t) {
			logger.info("Auction assignment for node " + nodeNumber + " has changed (path = " + t + ").  Scheduling handler");
			_assignmentHandlerExecutorService.execute(new AuctionAssignmentChangedRunner());
		}
		
	}
	
	protected class AuctionAssignmentChangedRunner implements Runnable {

		@Override
		public void run() {

			String assignedAuctionString = null;
			try {
				assignedAuctionString = groupMembershipService.readContentsForNode(auctionAssignmentMapName, nodeNumber);
			} catch (Exception e1) {
				// ToDo: Should shut down the node at this point so that another node will handle the auctions 
				logger.error("Could not get current auction assignment.  This node is no longer handling assignments: " + e1.getMessage());
			}
			List<Long> newAuctionAssignment = auctionAssignmentStringToList(assignedAuctionString);
			logger.info("AuctionAssignmentChangedRunner got assignedAuctionString: " + assignedAuctionString + ". There are " + newAuctionAssignment.size()
					+ " ids in assignedAuctionIds");

			/*
			 * Go through and create lists of auctions to remove and add
			 * handling on this node
			 */
			List<Long> auctionsToRemoveList = new LinkedList<Long>(_currentAuctionAssignment);
			List<Long> auctionsToAddList = new LinkedList<Long>();
			for (Long auctionId : newAuctionAssignment) {
				if (!auctionsToRemoveList.remove(auctionId)) {
					/*
					 * This auction was not already running on this node. It
					 * needs to be added.
					 */
					auctionsToAddList.add(auctionId);
				}
			}

			/*
			 * Any auctionIds remaining in the auctionsToRemoveList are those
			 * that this node was running but should stop running.
			 */
			for (Long auctionId : auctionsToRemoveList) {
				logger.info("Auction " + auctionId + " is no longer running on this node.  Stopping auctioneer");
				// Remove the binding
				rabbitAdmin.removeBinding(_auctionIdToBindingMap.remove(auctionId));

				// Clean up the auctioneer
				_auctionIdToAuctioneerMap.remove(auctionId).cleanup();
			}

			for (Long auctionId : auctionsToAddList) {
				/*
				 * We are currently running this auction.
				 * Start an auctioneer for it.
				 */
				logger.info("Auction " + auctionId + " has been assigned to this node. Starting Auctioneer");
				/*
				 * Add a binding to the newBidQueue to listen for new bids for
				 * this auction.
				 */
				Binding newBidBinding = new Binding(_newBidQueue.getName(), DestinationType.QUEUE, liveAuctionExchangeName, newBidRoutingKey + auctionId, null);
				rabbitAdmin.declareBinding(newBidBinding);
				_auctionIdToBindingMap.put(auctionId, newBidBinding);

				Auctioneer auctioneer = new AuctioneerImpl(auctionId, _auctioneerExecutorService, _auctioneerTx, _highBidDao, _bidRepository, auctionDao,
						liveAuctionRabbitTemplate, auctionMaxIdleTime);
				_auctionIdToAuctioneerMap.put(auctionId, auctioneer);
			}

			_currentAuctionAssignment = newAuctionAssignment;

			// Reregister the callback
			try {
				groupMembershipService.registerContentsChangedCallback(auctionAssignmentMapName, nodeNumber, new AuctionAssignmentChangedHandler());
			} catch (Exception e) {
				// ToDo: Should shut down the node at this point so that another node will handle the auctions 
				logger.error("Could not register callback to track auction assignment changes.  This node is no longer handling assignments: " + e.getMessage());
			}
		}

	}
	
	protected class MembershipChangedHandler implements Consumer<String> {

		@Override
		public void accept(String t) {
			logger.info("Membership of group " + auctionManagementGroupName + " has changed.  Scheduling handler");
			_groupMembershipExecutorService.schedule(new MembershipChangedRunner(), 10, TimeUnit.SECONDS);
		}
		
	}
	
	protected class MembershipChangedRunner implements Runnable {

		/**
		 * The MembershipChangedRunner makes sure that all auctions are assigned to 
		 * a node and that the auction management is evenly balanced among the nodes
		 */
		@Override
		public void run() {
			logger.info("MembershipChangedRunner run");

			try {
				auctionAssignmentChangeLock.lock();
				logger.info("MembershipChangedRunner got auctionAssignmentChangeLock");

				/*
				 * Get the current group membership
				 */
				Set<String> currentGroupMembersSet = groupMembershipService.getGroupMembers(auctionManagementGroupName).keySet();
				logger.debug("MembershipChangedRunner: There are currently " + currentGroupMembersSet.size() + " group members");
				
				/*
				 * Get the current auction assignments
				 */
				Map<String, List<Long>> auctionAssignmentMap = getCurrentAuctionAssignmentMap();

				/*
				 * Compare current and previous group membership to determine
				 * which members have left
				 * 
				 */
				List<String> leftGroupMembers = new LinkedList<String>(auctionAssignmentMap.keySet());
				for (String groupMember : currentGroupMembersSet) {
					leftGroupMembers.remove(groupMember);
				}

				/*
				 * Get the list of all auctions that were assigned to member who have left
				 * and then remove those members from the assigned auction map.  Also
				 * delete the associated node in the global assignment structure
				 */
				List<Long> auctionsToReassign = new ArrayList<Long>();
				while (!leftGroupMembers.isEmpty()) {
					String leftMemberId = leftGroupMembers.remove(0);
					logger.debug("MembershipChangedRunner member " + leftMemberId + " left the group,");
					auctionsToReassign.addAll(auctionAssignmentMap.remove(leftMemberId));
					groupMembershipService.deleteNode(auctionAssignmentMapName, Long.parseLong(leftMemberId));
				}
				
				/*
				 * Assign the auctions previously run by the leaving member to
				 * other members
				 */
				auctionAssignmentMap = assignAuctions(auctionAssignmentMap, auctionsToReassign);

				/*
				 * Rebalance the auctions among all of the members
				 */
				auctionAssignmentMap = rebalanceAuctions(auctionAssignmentMap);
				
				/*
				 * Update the assignments in the groupManagement service
				 */
				updateCurrentAuctionAssignment(auctionAssignmentMap);
				
			} catch (Exception e) {
				logger.warn("Could not reassign auctions due to membership change: " + e.getMessage());
			} finally {
				auctionAssignmentChangeLock.unlock();
				logger.info("rebalanceAuctions released auctionAssignmentChangeLock");
			}
			
			/*
			 * Reregister the callback
			 */
			try {
				_membershipChangedHandler = new MembershipChangedHandler();
				groupMembershipService.registerChildrenChangedCallback(auctionManagementGroupName, _membershipChangedHandler);
			} catch (Exception e1) {
				logger.warn("Couldn't register childrenChanged callback to monitor membership changes.  Returning and yeilding leadership: " + e1.getMessage());				
				e1.printStackTrace();
				_membershipChangedHandler = null;
				return;
			}

		}
	}
	
	protected class TakeLeadershipHandler implements Consumer<Boolean> {

		@Override
		public void accept(Boolean t) {
			logger.warn("For group " + auctionManagementGroupName + " member " + nodeNumber + " was elected leader");
			logger.warn("This node is now master.");
			_isMaster = true;
			
			/*
			 * Check whether the membership has changed during the leadership transition.
			 * This will also register a new membership changed handler.
			 */
			MembershipChangedRunner membershipChangedRunner = new MembershipChangedRunner();
			membershipChangedRunner.run();
			if (_membershipChangedHandler == null) {
				/*
				 * There is no membershipChangedHandler pending, so this node can't 
				 * be the leader. Return.
				 */
				return;
			}
			
			/*
			 * Now run forever, checking whether there are new auctions. The
			 * leader always runs forever unless the node is shutting down or
			 * crashes.
			 */
			Calendar endTime = FixedOffsetCalendarFactory.getCalendar();

			while (!_exiting) {
				try {
					Thread.sleep(_auctionQueueUpdateDelay * 1000);
				} catch (InterruptedException e) {
					logger.warn("TakeLeadershipHandler sleep interrupted.  Exiting");
					break;
				}
				try {
					
					auctionAssignmentChangeLock.lock();
					logger.info("TakeLeadershipHandler got auctionAssignmentChangeLock");

					endTime.add(Calendar.SECOND, _auctionQueueUpdateDelay);

					/*
					 * Get the current auction assignment
					 */
					Map<String, List<Long>> auctionAssignmentMap = getCurrentAuctionAssignmentMap();
					logger.info("auctionAssignmentMap has " + auctionAssignmentMap.size() 
							+ " entries.");
					/*
					 * Get the list of all auctions running and find any that are not currently 
					 * being managed by any node.
					 */
					List<Long> allAssignedAuctions = new LinkedList<Long>();
					for (String memberId : auctionAssignmentMap.keySet()) {
						allAssignedAuctions.addAll(auctionAssignmentMap.get(memberId));
					}
					
					List<Auction> runningAuctions = auctionDao.getActiveAuctions();
					List<Long> unassignedAuctionIds = new ArrayList<Long>();
					for (Auction auction: runningAuctions) {
						if (!allAssignedAuctions.contains(auction.getId())) {
							/*
							 * This auction wasn't assigned to any node
							 */
							unassignedAuctionIds.add(auction.getId());
						}
					}
										
					/*
					 * Get list of auctions starting in next
					 * auctionQueueUpdateDelay minutes ordered by increasing
					 * time. The returned list is not inclusive of the end time.
					 */
					List<Auction> upcomingAuctions = auctionDao.getAuctionsToStart(endTime.getTime());
					for (Auction anAuction : upcomingAuctions) {
						unassignedAuctionIds.add(anAuction.getId());
					}

					if (unassignedAuctionIds.size() > 0) {
						auctionAssignmentMap = assignAuctions(auctionAssignmentMap, unassignedAuctionIds);

						/*
						 * Update the assignments in the groupManagement service
						 */
						updateCurrentAuctionAssignment(auctionAssignmentMap);
					}
				} catch (Exception e) {
					logger.warn("TakeLeadershipHandler loop failed: " + e.getMessage());
					break;
				} finally {
					auctionAssignmentChangeLock.unlock();
					logger.info("TakeLeadershipHandler released auctionAssignmentChangeLock");
				}

			}
			_membershipChangedHandler = null;
			_isMaster = false;
			logger.info("Leaving TakeLeadershipHandler.  Giving up leadership");

		}
		
	}
	
	public int getAuctionQueueUpdateDelay() {
		return _auctionQueueUpdateDelay;
	}

	public void setAuctionQueueUpdateDelay(int auctionQueueUpdateDelay) {
		this._auctionQueueUpdateDelay = auctionQueueUpdateDelay;
	}

	public int getNumAuctioneerExecutorThreads() {
		return _numAuctioneerExecutorThreads;
	}

	public void setNumAuctioneerExecutorThreads(int numScheduledExecutorThreads) {
		this._numAuctioneerExecutorThreads = numScheduledExecutorThreads;
	}

	public int getNumClientUpdateExecutorThreads() {
		return _numClientUpdateExecutorThreads;
	}

	public void setNumClientUpdateExecutorThreads(int _numClientUpdateExecutorThreads) {
		this._numClientUpdateExecutorThreads = _numClientUpdateExecutorThreads;
	}

	public int getLiveAuctionNodeHeartbeatDelay() {
		return _liveAuctionNodeHeartbeatDelay;
	}

	public void setLiveAuctionNodeHeartbeatDelay(int liveAuctionNodeHeartbeatDelay) {
		this._liveAuctionNodeHeartbeatDelay = liveAuctionNodeHeartbeatDelay;
	}

	@Override
	public int getAuctionMaxIdleTime() {
		return auctionMaxIdleTime;
	}

	public void setAuctionMaxIdleTime(int auctionMaxIdleTime) {
		this.auctionMaxIdleTime = auctionMaxIdleTime;
	}

	@Override
	public long getActiveAuctionsMisses() {
		return _activeAuctionsMisses;
	}
	
}
