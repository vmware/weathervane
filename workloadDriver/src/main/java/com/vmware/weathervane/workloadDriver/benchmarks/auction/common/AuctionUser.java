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
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AddedItemIdListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AddedItemIdProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendanceHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendanceHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionIdToLeaveListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionIdToLeaveProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AvailableAsyncIdsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.BidHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.BidHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ChoosesBidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAddedItemId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAttendanceHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAuctionIdToLeave;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAuctionItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsBidHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsDetailItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsFirstAuctionId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsPurchaseHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.FirstAuctionIdListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.FirstAuctionIdProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.GlobalOrderingIdProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAddedItemId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAttendanceHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAuctionIdToLeave;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAuctionItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAvailableAsyncIds;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsBidHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsBidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBids;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsDetailItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsFirstAuctionId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsGlobalOrderingId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPassword;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPersonNames;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPersons;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPurchaseHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUsersPerAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PasswordProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PersonNameProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PersonProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PurchaseHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PurchaseHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UsersPerAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.factory.AuctionOperationFactory;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.factory.AuctionTransitionChooserFactory;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.CollectionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.ItemRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.LoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.UserRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.BidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.RandomBidStrategy;
import com.vmware.weathervane.workloadDriver.common.chooser.Chooser;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.XHolderProvider;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.util.Holder;
import com.vmware.weathervane.workloadDriver.common.util.ResponseHolder;

/**
 * @author Hal
 * 
 */
public class AuctionUser extends User {

	private static final Logger logger = LoggerFactory.getLogger(AuctionUser.class);

	/* 
	 * The _workload of which this user is an active member
	 */
	private AuctionWorkload _workload;
	
	//************** Data passing from a transition chooser to a User

	/**
	 * This is a holder for the auction selected to be left on a LeaveAuction
	 * operation
	 */
	private Holder<Long> _auctionIdToLeave = new Holder<Long>();
	
	//************** Data passing from an operation to another operation or transition chooser

	/**
	 * This is used to hold the auctionIds of the auctions that the user is
	 * currently attending. This supplements the _currentAuctions map, which
	 * holds the complete auction profile and makes it easier to check whether
	 * the user is already attending an auction.
	 */
	private Set<Long> _attendedAuctions = new HashSet<Long>();

	/**
	 * This holds the itemId from the last item added by this user
	 */
	private Holder<Long> _addedItemId = new Holder<Long>();
	
	/**
	 * This holds the id of the first active auction. It is used when forming
	 * the id for the auctions to join.
	 */
	private Holder<Long> _firstAuctionId = new Holder<Long>();
	
	private ResponseHolder<String, CollectionRepresentation<AuctionRepresentation>> _activeAuctions 
		= new ResponseHolder<String, CollectionRepresentation<AuctionRepresentation>>();

	/*
	 * Use a Holder to hold the reference to the current User, etc. The holder
	 * is needed because the data listeners and strategy choosers need a place
	 * to put the results that will be accessible to the generator. Don't use a
	 * list since there is only one of these at any given time.
	 */
	private ResponseHolder<String, UserRepresentation> _userProfile = new ResponseHolder<String, UserRepresentation>();

	/**
	 * This is used to hold the authToken returned by the application when the
	 * user logs in.
	 */
	private ResponseHolder<String, LoginResponse> _loginResponse = new ResponseHolder<String, LoginResponse>();

	/**
	 * This holds the information returned by the last GetBidHistory operation.
	 * It is needed by subsequent GetBidHistory operations.
	 */
	private ResponseHolder<String, CollectionRepresentation<BidRepresentation>> _bidHistoryInfo = new ResponseHolder<String, CollectionRepresentation<BidRepresentation>>();

	/**
	 * This holds the information returned by the last GetAttendanceHistory
	 * operation. It is needed by subsequent GetAttendanceHistory operations.
	 */
	private ResponseHolder<String, CollectionRepresentation<AttendanceRecordRepresentation>> _attendanceHistoryInfo 
		= new ResponseHolder<String, CollectionRepresentation<AttendanceRecordRepresentation>>();

	/**
	 * This holds the information returned by the last GetPurchaseHistory
	 * operation. It is needed by subsequent GetPurchaseHistory operations.
	 */
	private ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> _purchaseHistoryInfo 
		= new ResponseHolder<String, CollectionRepresentation<ItemRepresentation>>();

	/**
	 * This holds the information returned by the last GetAuctionDetail
	 * operation. It is needed by subsequent GetItemDetail operations.
	 */
	private ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> _auctionItems 
		= new ResponseHolder<String, CollectionRepresentation<ItemRepresentation>>();

	/**
	 * This holds the information returned by the last GetItemDetail
	 * operation. It is needed by subsequent GetItemImage operations.
	 */
	private ResponseHolder<String, ItemRepresentation> _detailItem = new ResponseHolder<String, ItemRepresentation>();

	// There is one of these for the main thread and one for each possible async
	// behavior
	private Map<UUID, ResponseHolder<String, AuctionRepresentation>> _currentAuctions 
		= new HashMap<UUID, ResponseHolder<String, AuctionRepresentation>>();
	private Map<UUID, ResponseHolder<String, ItemRepresentation>> _currentItems 
		= new HashMap<UUID, ResponseHolder<String, ItemRepresentation>>();
	private Map<UUID, ResponseHolder<String, BidRepresentation>> _currentBids 
		= new HashMap<UUID, ResponseHolder<String, BidRepresentation>>();

	private Holder<BidStrategy> _currentBidStrategy = new Holder<BidStrategy>();

	// These lists of available strategies are initialized in the configuration
	private List<BidStrategy> _allBidStrategies = new ArrayList<BidStrategy>();

	private Random _randomGenerator;

	public AuctionUser(Long id, Long orderingId, Long globalOrderingId, String behaviorSpecName, Target target, AuctionWorkload workload) {
		super(id, orderingId, globalOrderingId, behaviorSpecName, target);
		this.setWorkload(workload);
		this.setOperationFactory(new AuctionOperationFactory());
		this.setTransitionChooserFactory(new AuctionTransitionChooserFactory());

		_randomGenerator = new Random();

		_allBidStrategies.add(new RandomBidStrategy());
	}

	@Override
	public void start(long activeUsers) {

		super.start(activeUsers);
	}

	@Override
	public StateManagerStructs getStateManager() {
		return new AuctionStateManagerStructs();
	}

	@Override
	protected void prepareData(Object theObject, UUID idForNeeds,
			UUID idForContains) {
		logger.debug("In prepareData for " + theObject.toString()
				+ ", idForNeeds = " + idForNeeds + ", idForContains = " + idForContains);
		Random random = _randomNumberGenerator;

		if (theObject instanceof ContainsActiveAuctions) {
			((ContainsActiveAuctions) theObject)
					.registerActiveAuctionListener(new ActiveAuctionListener(_activeAuctions));
		}
		if (theObject instanceof ContainsDetailItem) {
			((ContainsDetailItem) theObject)
			.registerDetailItemListener(new DetailItemListener(_detailItem));
		}
		if (theObject instanceof ContainsUserProfile) {
			((ContainsUserProfile) theObject)
					.registerUserProfileListener(new UserProfileListener(_userProfile));
		}
		if (theObject instanceof ContainsLoginResponse) {
			((ContainsLoginResponse) theObject)
					.registerLoginResponseListener(new LoginResponseListener(_loginResponse));
		}
		if (theObject instanceof ContainsAttendedAuctions) {
			((ContainsAttendedAuctions) theObject)
					.registerAttendedAuctionsListener(new AttendedAuctionsListener(
							_attendedAuctions, (ContainsAttendedAuctions) theObject));
		}
		if (theObject instanceof ContainsAuctionIdToLeave) {
			logger.debug("populateNeedsProvidesChooses ContainsAuctionIdToLeave.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
			((ContainsAuctionIdToLeave) theObject)
					.registerAuctionIdToLeaveListener(new AuctionIdToLeaveListener(
							_auctionIdToLeave, (ContainsAuctionIdToLeave) theObject));
		}
		if (theObject instanceof ContainsBidHistoryInfo) {
			((ContainsBidHistoryInfo) theObject)
					.registerBidHistoryInfoListener(new BidHistoryInfoListener(_bidHistoryInfo));
		}
		if (theObject instanceof ContainsPurchaseHistoryInfo) {
			((ContainsPurchaseHistoryInfo) theObject)
					.registerPurchaseHistoryInfoListener(new PurchaseHistoryInfoListener(
							_purchaseHistoryInfo));
		}
		if (theObject instanceof ContainsAttendanceHistoryInfo) {
			((ContainsAttendanceHistoryInfo) theObject)
					.registerAttendanceHistoryInfoListener(new AttendanceHistoryInfoListener(
							_attendanceHistoryInfo));
		}
		if (theObject instanceof ContainsAuctionItems) {
			((ContainsAuctionItems) theObject)
					.registerAuctionItemsListener(new AuctionItemsListener(_auctionItems));
		}
		if (theObject instanceof ContainsAddedItemId) {
			((ContainsAddedItemId) theObject).registerAddedItemIdListener(new AddedItemIdListener(
					_addedItemId, (ContainsAddedItemId) theObject));
		}
		if (theObject instanceof ContainsFirstAuctionId) {
			((ContainsFirstAuctionId) theObject).registerFirstAuctionIdListener(new FirstAuctionIdListener(
					_firstAuctionId, (ContainsFirstAuctionId) theObject));
		}

		if (theObject instanceof NeedsLoginResponse) {
			((NeedsLoginResponse) theObject)
					.registerLoginResponseProvider(new LoginResponseProvider(_loginResponse));
		}
		if (theObject instanceof NeedsDetailItem) {
			((NeedsDetailItem) theObject).registerDetailItemProvider(new DetailItemProvider(_detailItem, random));
		}
		if (theObject instanceof NeedsAttendedAuctions) {
			((NeedsAttendedAuctions) theObject)
					.registerAttendedAuctionsProvider(new AttendedAuctionsProvider(
							_attendedAuctions, random));
		}
		if (theObject instanceof NeedsCurrentItems) {
			((NeedsCurrentItems) theObject).registerCurrentItemsProvider(new CurrentItemsProvider(
					_currentItems, random));
		}
		if (theObject instanceof NeedsCurrentBids) {
			((NeedsCurrentBids) theObject).registerCurrentBidsProvider(new CurrentBidsProvider(
					_currentBids, random));
		}
		if (theObject instanceof NeedsUserProfile) {
			((NeedsUserProfile) theObject).registerUserProfileProvider(new UserProfileProvider(
					_userProfile));
		}
		if (theObject instanceof NeedsPersons) {
			((NeedsPersons) theObject).registerPersonProvider(new PersonProvider(_workload.getAllPersons(),
					random));
		}
		if (theObject instanceof NeedsPersonNames) {
			((NeedsPersonNames) theObject).registerPersonNameProvider(new PersonNameProvider(
					_workload.getAvailablePersonNames(), random));
		}
		if (theObject instanceof NeedsPassword) {
			((NeedsPassword) theObject).registerPasswordProvider(new PasswordProvider(_workload.getAllPersons(),
					random));
		}
		if (theObject instanceof NeedsBidStrategy) {
			((NeedsBidStrategy) theObject)
					.registerBidStrategyProvider(new XHolderProvider<BidStrategy>(
							_currentBidStrategy));
		}
		if (theObject instanceof NeedsPageSize) {
			((NeedsPageSize) theObject).registerPageSizeProvider(new PageSizeProvider(_workload.getPageSizeHolder()));
		}
		if (theObject instanceof NeedsUsersPerAuction) {
			((NeedsUsersPerAuction) theObject).registerUsersPerAuctionProvider(new UsersPerAuctionProvider(_workload.getUsersPerAuctionHolder()));
		}
		if (theObject instanceof NeedsAuctionIdToLeave) {
			((NeedsAuctionIdToLeave) theObject)
					.registerAuctionIdToLeaveProvider(new AuctionIdToLeaveProvider(
							_auctionIdToLeave));
		}
		if (theObject instanceof NeedsBidHistoryInfo) {
			((NeedsBidHistoryInfo) theObject)
					.registerBidHistoryInfoProvider(new BidHistoryInfoProvider(_bidHistoryInfo,
							_randomGenerator));
		}
		if (theObject instanceof NeedsPurchaseHistoryInfo) {
			((NeedsPurchaseHistoryInfo) theObject)
					.registerPurchaseHistoryInfoProvider(new PurchaseHistoryInfoProvider(
							_purchaseHistoryInfo, _randomGenerator));
		}
		if (theObject instanceof NeedsAttendanceHistoryInfo) {
			((NeedsAttendanceHistoryInfo) theObject)
					.registerAttendanceHistoryInfoProvider(new AttendanceHistoryInfoProvider(
							_attendanceHistoryInfo, _randomGenerator));
		}
		if (theObject instanceof NeedsAuctionItems) {
			((NeedsAuctionItems) theObject)
					.registerAuctionItemsProvider(new AuctionItemsProvider(_auctionItems,
							random));
		}
		if (theObject instanceof NeedsAddedItemId) {
			((NeedsAddedItemId) theObject).registerAddedItemIdProvider(new AddedItemIdProvider(
					_addedItemId));
		}
		if (theObject instanceof NeedsFirstAuctionId) {
			((NeedsFirstAuctionId) theObject).registerFirstAuctionIdProvider(new FirstAuctionIdProvider(
					_firstAuctionId));
		}
		if (theObject instanceof NeedsGlobalOrderingId) {
			((NeedsGlobalOrderingId) theObject).registerGlobalOrderingIdProvider(new GlobalOrderingIdProvider(
					new Holder<Long>(_globalOrderingId)));
		}

		if (theObject instanceof ChoosesBidStrategy) {
			((ChoosesBidStrategy) theObject).registerBidStrategyChooser(new Chooser<BidStrategy>(
					_allBidStrategies, _currentBidStrategy, random));
		}
		
		logger.debug("Leaving prepareData for " + theObject.toString()
		+ ", idForNeeds = " + idForNeeds + ", idForContains = " + idForContains);


	}

	@Override
	protected void prepareSharedData(Object theObject, UUID idForNeeds,
			UUID idForContains) {
		logger.debug("In prepareSharedData for " + theObject.toString()
				+ ", idForNeeds = " + idForNeeds + ", idForContains = " + idForContains);
		
		Random random = _randomNumberGenerator;

		if (theObject instanceof ContainsCurrentAuction) {
			ResponseHolder<String, AuctionRepresentation> currentAuction;
			if (!_currentAuctions.containsKey(idForContains)) {
				currentAuction = new ResponseHolder<String, AuctionRepresentation>();
				_currentAuctions.put(idForContains, currentAuction);
			} else {
				currentAuction = _currentAuctions.get(idForContains);
			}
			((ContainsCurrentAuction) theObject)
					.registerCurrentAuctionListener(new CurrentAuctionListener(currentAuction));
		}
		if (theObject instanceof ContainsCurrentItem) {
			logger.debug("populateNeedsProvidesChooses ContainsCurrentItem.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
			ResponseHolder<String, ItemRepresentation> _currentItem;
			if (!_currentItems.containsKey(idForContains)) {
				_currentItem = new ResponseHolder<String, ItemRepresentation>();
				_currentItems.put(idForContains, _currentItem);
			} else {
				_currentItem = _currentItems.get(idForContains);
			}

			((ContainsCurrentItem) theObject)
					.registerCurrentItemListener(new CurrentItemListener(_currentItem));
		}
		if (theObject instanceof ContainsCurrentBid) {
			ResponseHolder<String, BidRepresentation> currentBid;
			if (!_currentBids.containsKey(idForContains)) {
				currentBid = new ResponseHolder<String, BidRepresentation>();
				_currentBids.put(idForContains, currentBid);
				// System.out.println("Initializing an object that ContainsCurrentBidLinks, idForContains =  "
				// + idForContains
				// + ". Creating a new Holder");
			} else {
				currentBid = _currentBids.get(idForContains);
				// System.out.println("Initializing an object that ContainsCurrentBidLinks, idForContains =  "
				// + idForContains
				// + ". Using an existing holder");
			}

			((ContainsCurrentBid) theObject).registerCurrentBidListener(new CurrentBidListener(
					currentBid));
		}
		if (theObject instanceof NeedsActiveAuctions) {
			logger.debug("populateNeedsProvidesChooses NeedsActiveAuctions.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
			((NeedsActiveAuctions) theObject).registerActiveAuctionProvider(new ActiveAuctionProvider(
					_activeAuctions, random));
			logger.debug("populateNeedsProvidesChooses finished NeedsActiveAuctions.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
		}
		if (theObject instanceof NeedsCurrentAuction) {
			ResponseHolder<String, AuctionRepresentation> currentAuction = _currentAuctions.get(idForNeeds);
			if (currentAuction == null) {
				currentAuction = _currentAuctions.get(idForContains);
				if (currentAuction == null) {
					throw new RuntimeException("populateNeedsProvidesChooses NeedsCurrentAuction but can't" 
							+ " get holder from idForNeeds or idForContains");
				}
			}
			((NeedsCurrentAuction) theObject)
					.registerCurrentAuctionProvider(new CurrentAuctionProvider(currentAuction));
		}
		if (theObject instanceof NeedsCurrentItem) {
			logger.debug("populateNeedsProvidesChooses NeedsCurrentItem.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
			ResponseHolder<String, ItemRepresentation> currentItem = _currentItems.get(idForNeeds);
			if (currentItem == null) {
				currentItem = _currentItems.get(idForContains);
				if (currentItem == null) {
					throw new RuntimeException("populateNeedsProvidesChooses NeedsCurrentItem but can't" 
							+ " get holder from idForNeeds or idForContains");
				}
			}
			((NeedsCurrentItem) theObject).registerCurrentItemProvider(new CurrentItemProvider(currentItem));
		}
		if (theObject instanceof NeedsCurrentBid) {
			logger.debug("populateNeedsProvidesChooses NeedsCurrentBid.  idForNeeds = " 
					+ idForNeeds + ", idForContains = " + idForContains);
			ResponseHolder<String, BidRepresentation> currentBid = _currentBids.get(idForNeeds);
			if (currentBid == null) {
				currentBid = _currentBids.get(idForContains);
				if (currentBid == null) {
					throw new RuntimeException("populateNeedsProvidesChooses NeedsCurrentBid but can't" 
							+ " get holder from idForNeeds or idForContains");
				}
			}
			((NeedsCurrentBid) theObject).registerCurrentBidProvider(new CurrentBidProvider(currentBid));
		}
		if (theObject instanceof NeedsAvailableAsyncIds) {
			// This needs to be non-empty if there are not already
			// maxAsyncBehaviors running.
			logger.debug("populateNeedsProvidesChooses.  NeedsAvailableAsyncIds.  For behaviorID = "
					+ _behavior.getBehaviorId());
			Queue<UUID> availableAsyncIds = new LinkedList<UUID>();
			int numActiveAsyncBehaviors = _behavior.getActiveSubBehaviors().size();
			int maxNumAsyncBehaviors = _behavior.getBehaviorSpec().getMaxNumAsyncBehaviors();
			logger.debug("populateNeedsProvidesChooses.  NeedsAvailableAsyncIds.  For behaviorID = "
					+ _behavior.getBehaviorId()
					+ " there are "
					+ numActiveAsyncBehaviors
					+ " active async behavior and maxNumAsyncBehviors is " + maxNumAsyncBehaviors);
			if (numActiveAsyncBehaviors < maxNumAsyncBehaviors) {
				availableAsyncIds.add(UUID.randomUUID());
			}
			((NeedsAvailableAsyncIds) theObject)
					.registerAvailableAsyncIdsProvider(new AvailableAsyncIdsProvider(
							availableAsyncIds, random));
		}
		
		logger.debug("Leaving prepareSharedData for " + theObject.toString()
		+ ", idForNeeds = " + idForNeeds + ", idForContains = " + idForContains);

	}

	/*
	 * Clear the remembered operations when we log out, otherwise an operation
	 * which requires a previous login may think that we're logged in. Also
	 * clear the remembered people/events/tags or the driver will slowly run out
	 * of memory
	 */
	@Override
	protected void resetState() {

		logger.info("resetState: behaviorId = " + _behavior.getBehaviorId());
		
		/*
		 * Only return the username to the available usernames if
		 * the user has sucessfully logged in and received a username.
		 * For the auction workload the username will be an email 
		 * address with an @
		 */
		if ((getUserName() != null) && (getUserName().contains("@"))) {
			synchronized (_workload.getAvailablePersonNames()) {
				// Remove the current user from the static list of all logged in
				// users
				logger.info("resetState: behaviorId = " + _behavior.getBehaviorId() + " returning "
						+ getUserName() + " to availablePersonNames");
				_workload.getAvailablePersonNames().add(getUserName());
				setUserName(Long.toString(getId()));
			}
		}
		_activeAuctions.clear();
		_bidHistoryInfo.clear();
		_attendanceHistoryInfo.clear();
		_purchaseHistoryInfo.clear();
	}

	public Random getRandomGenerator() {
		return _randomGenerator;
	}

	public void setRandomGenerator(Random _randomGenerator) {
		this._randomGenerator = _randomGenerator;
	}

	@Override
	protected void clearBehaviorState(UUID behaviorId) {
		logger.info("clearBehaviorState for behaviorId = " + behaviorId);
		_currentAuctions.remove(behaviorId);
		_currentItems.remove(behaviorId);
		_currentBids.remove(behaviorId);
	}

	public AuctionWorkload getWorkload() {
		return _workload;
	}

	public void setWorkload(AuctionWorkload workload) {
		this._workload = workload;
	}

}
