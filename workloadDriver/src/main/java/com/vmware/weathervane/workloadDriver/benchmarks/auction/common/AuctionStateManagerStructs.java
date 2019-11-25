/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

import java.io.IOException;
import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.CollectionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.ItemRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.LoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.Representation.RestAction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.UserRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.BidStrategy;
import com.vmware.weathervane.workloadDriver.common.chooser.Chooser;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs;
import com.vmware.weathervane.workloadDriver.common.util.Holder;
import com.vmware.weathervane.workloadDriver.common.util.ResponseHolder;

public class AuctionStateManagerStructs extends StateManagerStructs {
	private static final Logger logger = LoggerFactory
			.getLogger(AuctionStateManagerStructs.class);

	private static ObjectMapper _objectMapper;
	private static ObjectReader _bidReader;
	private static ObjectReader _bidCollectionReader;
	private static ObjectReader _auctionReader;
	private static ObjectReader _auctionCollectionReader;
	private static ObjectReader _itemReader;
	private static ObjectReader _itemCollectionReader;
	private static ObjectReader _userReader;
	private static ObjectReader _loginReader;
	private static ObjectReader _attendanceCollectionReader;
	
	static {
		_objectMapper = new ObjectMapper();
		_bidReader = _objectMapper.readerFor(BidRepresentation.class);
		_bidCollectionReader = _objectMapper.readerFor(new TypeReference<CollectionRepresentation<BidRepresentation>>() {});
		_auctionReader = _objectMapper.readerFor(AuctionRepresentation.class);
		_auctionCollectionReader = _objectMapper.readerFor(new TypeReference<CollectionRepresentation<AuctionRepresentation>>() {});
		_itemReader = _objectMapper.readerFor(ItemRepresentation.class);
		_itemCollectionReader = _objectMapper.readerFor(new TypeReference<CollectionRepresentation<ItemRepresentation>>() {});
		_userReader = _objectMapper.readerFor(UserRepresentation.class);
		_loginReader = _objectMapper.readerFor(LoginResponse.class);
		_attendanceCollectionReader = _objectMapper.readerFor(new TypeReference<CollectionRepresentation<AttendanceRecordRepresentation>>() {});
	}

	@Override
	public Class<? extends Contains> getNeedsDependencyType(Class<? extends Needs> type) {
		if (type.equals(NeedsActiveAuctions.class)) {
			return ContainsActiveAuctions.class;
		} else if (type.equals(NeedsCurrentAuction.class)) {
			return ContainsCurrentAuction.class;
		} else if (type.equals(NeedsCurrentBid.class)) {
			return ContainsCurrentBid.class;
		} else if (type.equals(NeedsUserProfile.class)) {
			return ContainsUserProfile.class;
		} else if (type.equals(NeedsLoginResponse.class)) {
			return ContainsLoginResponse.class;
		} else if (type.equals(NeedsBidHistoryInfo.class)) {
			return ContainsBidHistoryInfo.class;
		} else if (type.equals(NeedsAttendanceHistoryInfo.class)) {
			return ContainsAttendanceHistoryInfo.class;
		} else if (type.equals(NeedsPurchaseHistoryInfo.class)) {
			return ContainsPurchaseHistoryInfo.class;
		} else if (type.equals(NeedsCurrentItem.class)) {
			return ContainsCurrentItem.class;
		} else if (type.equals(NeedsAuctionItems.class)) {
			return ContainsAuctionItems.class;
		} else if (type.equals(NeedsAddedItemId.class)) {
			return ContainsAddedItemId.class;
		} else if (type.equals(NeedsAuctionIdToLeave.class)) {
			return ContainsAuctionIdToLeave.class;
		}
		return null;
	}

	/*** NEEDS INTERFACES ***/

	public interface NeedsActiveAuctions extends Needs {
		public void registerActiveAuctionProvider(ActiveAuctionProvider provider);
	}

	public interface NeedsCurrentAuction extends Needs {
		public void registerCurrentAuctionProvider(CurrentAuctionProvider provider);
	}

	public interface NeedsCurrentItem extends Needs {
		public void registerCurrentItemProvider(CurrentItemProvider provider);
	}

	public interface NeedsDetailItem extends Needs {
		public void registerDetailItemProvider(DetailItemProvider provider);
	}

	public interface NeedsCurrentBid extends Needs {
		public void registerCurrentBidProvider(CurrentBidProvider provider);
	}

	public interface NeedsAvailableAsyncIds extends NeedsStatic {
		public void registerAvailableAsyncIdsProvider(AvailableAsyncIdsProvider provider);
	}

	public interface NeedsAttendedAuctions extends NeedsStatic {
		public void registerAttendedAuctionsProvider(AttendedAuctionsProvider provider);
	}

	public interface NeedsAuctionIdToLeave extends Needs {
		public void registerAuctionIdToLeaveProvider(AuctionIdToLeaveProvider provider);
	}

	public interface NeedsCurrentItems extends Needs {
		public void registerCurrentItemsProvider(CurrentItemsProvider provider);
	}

	public interface NeedsCurrentBids extends Needs {
		public void registerCurrentBidsProvider(CurrentBidsProvider provider);
	}

	public interface NeedsUserProfile extends Needs {
		public void registerUserProfileProvider(UserProfileProvider provider);
	}

	public interface NeedsLoginResponse extends Needs {
		public void registerLoginResponseProvider(LoginResponseProvider provider);
	}

	public interface NeedsBidHistoryInfo extends Needs {
		public void registerBidHistoryInfoProvider(BidHistoryInfoProvider provider);
	}

	public interface NeedsPurchaseHistoryInfo extends Needs {
		public void registerPurchaseHistoryInfoProvider(PurchaseHistoryInfoProvider provider);
	}

	public interface NeedsAttendanceHistoryInfo extends Needs {
		public void registerAttendanceHistoryInfoProvider(AttendanceHistoryInfoProvider provider);
	}

	public interface NeedsAuctionItems extends Needs {
		public void registerAuctionItemsProvider(AuctionItemsProvider provider);
	}

	public interface NeedsAddedItemId extends Needs {
		public void registerAddedItemIdProvider(AddedItemIdProvider provider);
	}

	public interface NeedsFirstAuctionId extends Needs {
		public void registerFirstAuctionIdProvider(FirstAuctionIdProvider provider);
	}

	public interface NeedsGlobalOrderingId extends Needs {
		public void registerGlobalOrderingIdProvider(GlobalOrderingIdProvider provider);
	}

	public interface NeedsPersons extends NeedsStatic {
		public void registerPersonProvider(PersonProvider provider);
	}

	public interface NeedsPersonNames extends NeedsStatic {
		public void registerPersonNameProvider(PersonNameProvider provider);
	}

	public interface NeedsPassword extends NeedsStatic {
		public void registerPasswordProvider(PasswordProvider provider);
	}

	public interface NeedsPageSize extends NeedsStatic {
		public void registerPageSizeProvider(PageSizeProvider provider);
	}

	public interface NeedsUsersPerAuction extends NeedsStatic {
		public void registerUsersPerAuctionProvider(UsersPerAuctionProvider provider);
	}

	/*** CONTAINS INTERFACES ***/

	public interface ContainsActiveAuctions extends Contains {
		public void registerActiveAuctionListener(ActiveAuctionListener listener);

		public ActiveAuctionListenerConfig getActiveAuctionListenerConfig();
	}

	public interface ContainsAttendedAuctions extends Contains {
		public void registerAttendedAuctionsListener(AttendedAuctionsListener listener);

		public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig();
	}

	public interface ContainsAuctionIdToLeave extends Contains {
		public void registerAuctionIdToLeaveListener(AuctionIdToLeaveListener listener);

		public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig();
	}

	public interface ContainsCurrentAuction extends Contains {
		public void registerCurrentAuctionListener(CurrentAuctionListener listener);

		public CurrentAuctionListenerConfig getCurrentAuctionListenerConfig();
	}

	public interface ContainsCurrentItem extends Contains {
		public void registerCurrentItemListener(CurrentItemListener listener);

		public CurrentItemListenerConfig getCurrentItemListenerConfig();
	}

	public interface ContainsDetailItem extends Contains {
		public void registerDetailItemListener(DetailItemListener listener);

		public DetailItemListenerConfig getDetailItemListenerConfig();
	}

	public interface ContainsCurrentBid extends Contains {
		public void registerCurrentBidListener(CurrentBidListener listener);

		public CurrentBidListenerConfig getCurrentBidListenerConfig();
	}

	public interface ContainsUserProfile extends Contains {
		public void registerUserProfileListener(UserProfileListener listener);

		public UserProfileListenerConfig getUserProfileListenerConfig();
	}

	public interface ContainsLoginResponse extends Contains {
		public void registerLoginResponseListener(LoginResponseListener listener);
	}

	public interface ContainsBidHistoryInfo extends Contains {
		public void registerBidHistoryInfoListener(BidHistoryInfoListener listener);
	}

	public interface ContainsPurchaseHistoryInfo extends Contains {
		public void registerPurchaseHistoryInfoListener(PurchaseHistoryInfoListener listener);
	}

	public interface ContainsAttendanceHistoryInfo extends Contains {
		public void registerAttendanceHistoryInfoListener(AttendanceHistoryInfoListener listener);
	}

	public interface ContainsAuctionItems extends Contains {
		public void registerAuctionItemsListener(AuctionItemsListener listener);
	}

	public interface ContainsAddedItemId extends Contains {
		public void registerAddedItemIdListener(AddedItemIdListener listener);
	}

	public interface ContainsFirstAuctionId extends Contains {
		public void registerFirstAuctionIdListener(FirstAuctionIdListener listener);
	}

	/*** DATA CLASSES ***/
	public static class ActiveAuctionListenerConfig extends XListListenerConfig {
	}

	public static class CurrentAuctionListenerConfig extends XListListenerConfig {
	}

	public static class AttendedAuctionsListenerConfig extends XListListenerConfig {
	}

	public static class PersonNamesListenerConfig extends XListListenerConfig {
	}

	public static class CurrentItemListenerConfig extends XListListenerConfig {
	}

	public static class DetailItemListenerConfig extends XListListenerConfig {
	}

	public static class CurrentBidListenerConfig extends XListListenerConfig {
	}

	public static class UserProfileListenerConfig extends XListListenerConfig {
	}

	/*** LISTENER BASE CLASSES ***/

	/*** PUBLIC LISTENER CLASSES ***/

	public static class ActiveAuctionListener extends
			XResponseHolderListener<String, CollectionRepresentation<AuctionRepresentation>> {

		public ActiveAuctionListener(ResponseHolder<String, CollectionRepresentation<AuctionRepresentation>> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class AttendedAuctionsListener extends XSetListener<Long> {

		public AttendedAuctionsListener(Set<Long> data, ContainsAttendedAuctions operation) {
			super(data);
		}

		public void addAttendedAuction(long auctionId) {
			addX(auctionId);
		}

		public void removeAttendedAuction(long auctionId) {
			removeX(auctionId);
		}

		@Override
		protected Long convertStringToT(String value) {
			Long longVal;
			try {
				longVal = Long.parseLong(value);
			} catch (NumberFormatException e) {
				longVal = null;
			}

			return longVal;
		}

		@Override
		protected boolean validateValue(String value) {
			boolean retVal = true;
			try {
				Long.parseLong(value);
			} catch (NumberFormatException e) {
				retVal = false;
			}

			return retVal;
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class DetailItemListener extends XResponseHolderListener<String, ItemRepresentation> {

		public DetailItemListener(ResponseHolder<String, ItemRepresentation> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

}

	public static class CurrentBidListener extends XResponseHolderListener<String, BidRepresentation> {

		public CurrentBidListener(ResponseHolder<String, BidRepresentation> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

}

	public static class CurrentItemListener extends XResponseHolderListener<String, ItemRepresentation> {

		public CurrentItemListener(ResponseHolder<String, ItemRepresentation> data) {
			super(data);
		}
		
		@Override
		public void handleResponse(String rawResponse) {
			logger.debug("CurrentItemListener handleResponse rawResponse = " + rawResponse);
			synchronized (_data) {
				_data.setRawResponse(rawResponse);
				_data.setParsedResponse(null);
			}
		}

		@Override
		public boolean needsString() {
			return true;
		}

}

	public static class CurrentAuctionListener extends XResponseHolderListener<String, AuctionRepresentation> {

		public CurrentAuctionListener(ResponseHolder<String, AuctionRepresentation> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class UserProfileListener extends XResponseHolderListener<String, UserRepresentation> {

		public UserProfileListener(ResponseHolder<String, UserRepresentation> data) {
			super(data);
		}
		
		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class LoginResponseListener extends XResponseHolderListener<String, LoginResponse> {

		public LoginResponseListener(ResponseHolder<String, LoginResponse> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class AuctionIdToLeaveListener extends XHolderListener<Long> {

		public AuctionIdToLeaveListener(Holder<Long> data, ContainsAuctionIdToLeave operation) {
			super(data);
		}

		public void setAuctionIdToLeave(Long auctionId) {
			this.addX(auctionId);
		}

		@Override
		protected Long convertStringToT(String value) {
			return Long.getLong(value);
		}

		@Override
		protected boolean validateValue(String value) {
			return true;
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class AuctionItemsListener extends
			XResponseHolderListener<String, CollectionRepresentation<ItemRepresentation>> {

		public AuctionItemsListener(
				ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class AddedItemIdListener extends XHolderListener<Long> {

		public AddedItemIdListener(Holder<Long> data, ContainsAddedItemId operation) {
			super(data);
		}

		/**
		 * The page is returned in a JSON object by the AddItem operation.
		 * 
		 * @param response
		 */
		public void findAndSetAddedItemIdFromResponse(String response) {

			/*
			 * The holdings are in a JSON array embedded in a JSON object.
			 */
			try {
				JSONObject jsonObject = new JSONObject(response);
				Long page = jsonObject.getLong("id");
				this.addX(page);

			} catch (JSONException ex) {
				System.out
						.println("AddedItemId::findAndSetAddedItemIdFromResponse. JSONException response="
								+ response + "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}

		}

		@Override
		protected Long convertStringToT(String value) {
			return Long.getLong(value);
		}

		@Override
		protected boolean validateValue(String value) {
			return true;
		}

		@Override
		public boolean needsString() {
			return true;
		}
		
	}


	public static class FirstAuctionIdListener extends XHolderListener<Long> {

		public FirstAuctionIdListener(Holder<Long> data, ContainsFirstAuctionId operation) {
			super(data);
		}

		public void setFirstAuctionId(Long auctionId) {
			this.addX(auctionId);
		}

		@Override
		protected Long convertStringToT(String value) {
			return Long.getLong(value);
		}

		@Override
		protected boolean validateValue(String value) {
			return true;
		}

		@Override
		public boolean needsString() {
			return true;
		}
		
	}

	public static class BidHistoryInfoListener extends
			XResponseHolderListener<String, CollectionRepresentation<BidRepresentation>> {

		public BidHistoryInfoListener(ResponseHolder<String, CollectionRepresentation<BidRepresentation>> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class PurchaseHistoryInfoListener extends
			XResponseHolderListener<String, CollectionRepresentation<ItemRepresentation>> {

		public PurchaseHistoryInfoListener(
				ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	public static class AttendanceHistoryInfoListener extends
			XResponseHolderListener<String, CollectionRepresentation<AttendanceRecordRepresentation>> {

		public AttendanceHistoryInfoListener(
				ResponseHolder<String, CollectionRepresentation<AttendanceRecordRepresentation>> data) {
			super(data);
		}

		@Override
		public boolean needsString() {
			return true;
		}

	}

	/*** PUBLIC PROVIDER CLASSES ***/

	public static class ActiveAuctionProvider extends
			XResponseHolderProvider<String, CollectionRepresentation<AuctionRepresentation>> {
		Random _random;

		public ActiveAuctionProvider(ResponseHolder<String, CollectionRepresentation<AuctionRepresentation>> data,
				Random random) {
			super(data);
			logger.debug("ActiveAuctionProvider(data,random)");
			_random = random;
		}

		public List<AuctionRepresentation> getActiveAuctions() {
			return this.getResponse().getResults();
		}

		public boolean hasData() {
			synchronized (_data) {
				if ((_data.getRawResponse() == null) && (_data.getParsedResponse() == null)) {
					return false;
				} else {
					return true;
				}
			}
		}
		
		public AuctionRepresentation getRandomActiveAuction() {

			CollectionRepresentation<AuctionRepresentation> auctionCollect = this.getResponse();
			
			if ((auctionCollect != null) && (auctionCollect.getResults().size() > 0)) {
				List<AuctionRepresentation> auctions = auctionCollect.getResults();
				return auctions.get(_random.nextInt(auctions.size()));
			} else {
				throw new RuntimeException("No active auctions available to activeAuctionProvider");
			}
		}

		public int getCurrentActiveAuctionsPage() {
			CollectionRepresentation<AuctionRepresentation> auctionCollect = this.getResponse();
			if (auctionCollect == null) {
				return 0;
			}
			return auctionCollect.getPage();
		}

		public long getTotalActiveAuctions() {
			CollectionRepresentation<AuctionRepresentation> auctionCollect = this.getResponse();
			if (auctionCollect == null) {
				throw new RuntimeException(
						"getTotalActiveAuctions: No activeAuctions collection available to activeAuctionProvider");
			}
			return auctionCollect.getTotalRecords();
		}

		/**
		 * Return a random page number of active auctions, given the page size
		 * and the current page. If there is nothing being held in the
		 * TotalActiveAuctions holder, then return 0.
		 * 
		 * @param pageSize
		 * @return
		 */
		public long getRandomActiveAuctionsPage(int pageSize) {
			CollectionRepresentation<AuctionRepresentation> auctionCollect = this.getResponse();
			if (auctionCollect == null) {
				logger.debug("getRandomActiveAuctionsPage: data==null, returning 0");
				return 0;
			}

			int totalActiveAuctions = auctionCollect.getTotalRecords().intValue();
			if (totalActiveAuctions == 0) {
				logger.debug("getRandomActiveAuctionsPage: activeauctions==0, returning 0");
				return 0;
			}
			logger.debug("getRandomActiveAuctionsPage: totalActiveAuctions = "
					+ totalActiveAuctions + ", pageSize = " + pageSize);

			/*
			 * Need to select a page by first selecting an auction, and then
			 * figuring out what page it is on. This will give an even
			 * distribution even if there are unequal numbers of auctions on a
			 * page.
			 */
			int selectedAuction = _random.nextInt(totalActiveAuctions);

			int selectedPage = (int) Math.floor((float) selectedAuction / (float) pageSize);

			return selectedPage;
		}
		
		
		@Override
		protected CollectionRepresentation<AuctionRepresentation> parseResponse() {
			CollectionRepresentation<AuctionRepresentation> parsedResponse = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					parsedResponse = _auctionCollectionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("ActiveAuctionProvider::parseRawResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("ActiveAuctionProvider::parseRawResponse IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return parsedResponse;
		}

	}

	public static class AttendedAuctionsProvider extends XSetProvider<Long> {

		public AttendedAuctionsProvider(Set<Long> data, Random random) {
			super(data, random);
		}

		public Long getRandomAttendedAuction() {
			return getRandomXItem("attendedAuction");
		}

		public Set<Long> getAttendedAuctionIds() {
			return _data;
		}

		/**
		 * This method returns true if all of the auctionIds are contained in
		 * the stored set
		 * 
		 * @return
		 */
		public boolean containsAll(Set<Long> auctionIDs) {
			for (Long id : auctionIDs) {
				if (!_data.contains(id)) {
					return false;
				}
			}
			return true;
		}

		@Override
		public Long[] getArrayTypeForT() {
			return new Long[] {};
		}

	}

	public static class AvailableAsyncIdsProvider extends XQueueUUIDProvider {

		public AvailableAsyncIdsProvider(Queue<UUID> data, Random random) {
			super(data, random);
		}

	}

	public static class DetailItemProvider extends XResponseHolderProvider<String,ItemRepresentation> {

		private Random _random;
		
		public DetailItemProvider(ResponseHolder<String, ItemRepresentation> data, Random random) {
			super(data);
			_random = random;
		}

		public List<String> getItemImageLinks() {
			List<String> itemImageLinks = new ArrayList<String>();

			ItemRepresentation curItem = this.getResponse();

			Map<String, List<Map<RestAction, String>>> curItemLinks = curItem.getLinks();

			if (curItemLinks.containsKey("ItemImage")) {
				List<Map<RestAction, String>> curItemImageLinks = curItemLinks.get("ItemImage");
				for (Map<RestAction, String> imageUrlsMap : curItemImageLinks) {
					if (imageUrlsMap.containsKey(RestAction.READ)) {
						itemImageLinks.add(imageUrlsMap.get(RestAction.READ));
					} 
				}
			} else {
				logger.debug("Item has no ItemImage links.");
			}

			return itemImageLinks;
		}

		public String getRandomItemImageLink() {

			String theLink = null;
			
			ItemRepresentation curItem = this.getResponse();

			Map<String, List<Map<RestAction, String>>> curItemLinks = curItem.getLinks();
			if (logger.isDebugEnabled()) {
				StringBuilder linkString = new StringBuilder();
				for (Map.Entry<String, List<Map<RestAction, String>>> entry1 : curItemLinks.entrySet()) {
					linkString.append("ID " + entry1.getKey() +": ");
					for (Map<RestAction, String> linkMap : entry1.getValue()) {
						for (Map.Entry<RestAction, String> entry2 : linkMap.entrySet()) {
							linkString.append(entry2.getKey() + "->" + entry2.getValue() + ", ");
						}
					}
				}
				logger.debug("getRandomItemImageLink for " + curItem.getId() + ", links: " + linkString.toString());
			}
			
			if (curItemLinks.containsKey("ItemImage")) {
				List<Map<RestAction, String>> curItemImageLinks = curItemLinks.get("ItemImage");
				if (curItemImageLinks.size() > 0) {
					int randInt = _random.nextInt(curItemImageLinks.size());
					Map<RestAction, String> imageUrlsMap = curItemImageLinks.get(randInt);					
					if (imageUrlsMap.containsKey(RestAction.READ)) {
						theLink = imageUrlsMap.get(RestAction.READ);
					} 
				}
			} else {
				logger.debug("DetailItem has no ItemImage links.");
			}
			
			return theLink;
			
		}

		@Override
		protected ItemRepresentation parseResponse() {
			ItemRepresentation convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _itemReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("DetailItemListener::convertStringToT JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("DetailItemListener::convertStringToT IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}
		
	}

	public static class CurrentBidProvider extends XResponseHolderProvider<String, BidRepresentation> {

		public CurrentBidProvider(ResponseHolder<String, BidRepresentation> data) {
			super(data);
		}

		@Override
		protected BidRepresentation parseResponse() {
			BidRepresentation convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _bidReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("CurrentBidProvider::parseResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("CurrentBidProvider::parseResponse IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

		public String getBidId() {
			return this.getResponse().getId();
		}
		

		public String getMessage() {
			return this.getResponse().getMessage();
		}

	}

	public static class CurrentItemProvider extends XResponseHolderProvider<String, ItemRepresentation> {

		public CurrentItemProvider(ResponseHolder<String, ItemRepresentation> data) {
			super(data);
		}

		public List<String> getItemImageLinks() {
			logger.debug("CurrentItemProvider.getItemImageLinks");
			List<String> itemImageLinks = new ArrayList<String>();

			ItemRepresentation curItem = this.getResponse();

			if ((curItem == null) || (curItem.getLinks() == null)) {
				return null;
			}
			
			Map<String, List<Map<RestAction, String>>> curItemLinks = curItem.getLinks();

			if (curItemLinks.containsKey("ItemImage")) {
				List<Map<RestAction, String>> curItemImageLinks = curItemLinks.get("ItemImage");
				for (Map<RestAction, String> imageUrlsMap : curItemImageLinks) {
					if (imageUrlsMap.containsKey(RestAction.READ)) {
						itemImageLinks.add(imageUrlsMap.get(RestAction.READ));
					}
				}
			} else {
				logger.debug("Item has no ItemImage links.");
			}

			return itemImageLinks;
		}

		@Override
		public ItemRepresentation getResponse() {
			logger.debug("CurrentItemProvider getResponse ");
			ItemRepresentation parsedResponse = null;
			if (_data != null) {
				synchronized (_data) {
					if (_data.getParsedResponse() != null) {
						logger.debug("CurrentItemProvider getResponse response already parsed");
						parsedResponse = _data.getParsedResponse();
					} else {
						parsedResponse = parseResponse();
						_data.setParsedResponse(parsedResponse);
						_data.setRawResponse(null);
					}
				}
			} else {
				logger.error("CurrentItemProvider getResponse ERROR: data is null in  " + this.getClass().getCanonicalName());
				throw new IllegalStateException("ERROR: data is null in  " + this.getClass().getCanonicalName());
			}
			return parsedResponse;
		}
		@Override
		protected ItemRepresentation parseResponse() {
			logger.debug("CurrentItemProvider parseResponse ");
			ItemRepresentation convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					logger.debug("CurrentItemProvider parseResponse rawResponse is null");
					return null;
				}
				try {
					convertedObject = _itemReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("CurrentItemProvider::parseResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("CurrentItemProvider::parseResponse IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

		public Long getId() {
			return getResponse().getId();
		}

	}

	public static class CurrentAuctionProvider extends XResponseHolderProvider<String, AuctionRepresentation> {

		public CurrentAuctionProvider(ResponseHolder<String, AuctionRepresentation> data) {
			super(data);
		}

		@Override
		protected AuctionRepresentation parseResponse() {
			AuctionRepresentation convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _auctionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("CurrentAuctionProvider::parseResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("CurrentAuctionProvider::parseResponse IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

	}

	public static class CurrentItemsProvider extends XMapProvider<UUID, ResponseHolder<String, ItemRepresentation>> {

		public CurrentItemsProvider(Map<UUID, ResponseHolder<String, ItemRepresentation>> data, Random random) {
			super(data, random);
		}

		@Override
		public UUID[] getArrayTypeForX() {
			return new UUID[] {};
		}

		@Override
		public ResponseHolder<String, ItemRepresentation>[] getArrayTypeForT() {
			return (ResponseHolder<String, ItemRepresentation>[]) Array.newInstance(Holder.class, 1);
		}
		
		public ResponseHolder<String, ItemRepresentation> getItemHolderForBehavior(UUID key) {
			ResponseHolder<String, ItemRepresentation> responseHolder = null;
			synchronized (_data) {
				responseHolder = _data.get(key);
				if (responseHolder == null) {
					throw new RuntimeException("No ItemRepresentation for behavior with UUID " + key);
				}		
			}
			
			if (responseHolder.getParsedResponse() == null) {
				responseHolder.setParsedResponse(parseResponse(responseHolder));
			}
			
			return responseHolder;
		}

		protected ItemRepresentation parseResponse(
				ResponseHolder<String, ItemRepresentation> responseHolder) {
			ItemRepresentation convertedObject = null;
			String rawResponse = responseHolder.getRawResponse();
			if (rawResponse == null) {
				return null;
			}
			try {
				convertedObject = _itemReader.readValue(rawResponse);
			} catch (JsonProcessingException ex) {
				logger.warn("CurrentBidProvider::parseResponse JsonProcessingException value="
						+ rawResponse + " message: " + ex.getMessage());
				throw new RuntimeException(ex);
			} catch (IOException ex) {
				logger.warn("CurrentBidProvider::parseResponse IOException value=" + rawResponse
						+ " message: " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return convertedObject;
		}

	}

	public static class CurrentBidsProvider extends XMapProvider<UUID, ResponseHolder<String, BidRepresentation>> {

		public CurrentBidsProvider(Map<UUID, ResponseHolder<String, BidRepresentation>> data, Random random) {
			super(data, random);
		}

		@Override
		public UUID[] getArrayTypeForX() {
			return new UUID[] {};
		}

		@Override
		public ResponseHolder<String, BidRepresentation>[] getArrayTypeForT() {
			return (ResponseHolder<String, BidRepresentation>[]) Array.newInstance(Holder.class, 1);
		}
		
		public ResponseHolder<String, BidRepresentation> getBidHolderForBehavior(UUID key) {
			ResponseHolder<String, BidRepresentation> responseHolder = null;
			synchronized (_data) {
				responseHolder = _data.get(key);
				if (responseHolder == null) {
					throw new RuntimeException("No BidRepresentation for behavior with UUID " + key);
				}		
			}
			
			if (responseHolder.getParsedResponse() == null) {
				responseHolder.setParsedResponse(parseResponse(responseHolder));
			}
			
			return responseHolder;
		}

		protected BidRepresentation parseResponse(
				ResponseHolder<String, BidRepresentation> responseHolder) {
			BidRepresentation convertedObject = null;
			String rawResponse = responseHolder.getRawResponse();
			if (rawResponse == null) {
				return null;
			}
			try {
				convertedObject = _bidReader.readValue(rawResponse);
			} catch (JsonProcessingException ex) {
				logger.warn("CurrentBidProvider::parseResponse JsonProcessingException value="
						+ rawResponse + " message: " + ex.getMessage());
				throw new RuntimeException(ex);
			} catch (IOException ex) {
				logger.warn("CurrentBidProvider::parseResponse IOException value=" + rawResponse
						+ " message: " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return convertedObject;
		}

	}

	public static class UserProfileProvider extends XResponseHolderProvider<String, UserRepresentation> {

		public UserProfileProvider(ResponseHolder<String, UserRepresentation> data) {
			super(data);
		}

		@Override
		protected UserRepresentation parseResponse() {
			UserRepresentation convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _userReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("UserProfileProvider::parseResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("UserProfileProvider::parseResponse IOException value=" + rawResponse
							+ " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}
	}

	public static class LoginResponseProvider extends XResponseHolderProvider<String, LoginResponse> {

		public LoginResponseProvider(ResponseHolder<String, LoginResponse> data) {
			super(data);
		}

		public String getAuthToken() {
			LoginResponse theLoginResponse = getResponse();
			return theLoginResponse.getAuthToken();
		}

		public Long getUserId() {
			LoginResponse theLoginResponse = getResponse();
			return theLoginResponse.getId();
		}

		@Override
		protected LoginResponse parseResponse() {
			LoginResponse convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}

				try {
					convertedObject = _loginReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("LoginResponseListener::convertStringToT JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("LoginResponseListener::convertStringToT IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}
	}

	public static class AuctionIdToLeaveProvider extends XHolderProvider<Long> {

		public AuctionIdToLeaveProvider(Holder<Long> data) {
			super(data);
		}

	}

	public static class BidHistoryInfoProvider extends
			XResponseHolderProvider<String, CollectionRepresentation<BidRepresentation>> {

		private Random _random;

		public BidHistoryInfoProvider(ResponseHolder<String, CollectionRepresentation<BidRepresentation>> data,
				Random random) {
			super(data);
			_random = random;
		}

		public Long getTotalBidHistoryRecords() {
			CollectionRepresentation<BidRepresentation> data = this.getResponse();
			if (data == null) {
				return 0L;
			}
			return data.getTotalRecords();
		}

		public Integer getCurrentBidHistoryPage() {
			CollectionRepresentation<BidRepresentation> data = this.getResponse();
			if (data == null) {
				return 0;
			}
			return data.getPage();
		}

		/**
		 * Return a random page of BidHistoryRecords, given the page size and
		 * the current page. If there is nothing being held in the
		 * TotalActiveAuctions holder, then return 0. Never return the same page
		 * as currentPage unless currentPage == 0, and pagesize >=
		 * BidHistoryRecords;
		 * 
		 * @param pageSize
		 * @param currentPage
		 * @return
		 */
		public long getRandomBidHistoryRecordsPage(long pageSize, long currentPage) {
			CollectionRepresentation<BidRepresentation> data = this.getResponse();
			if (data == null) {
				return 0;
			}

			Long totalBidRecords = data.getTotalRecords();
			if (totalBidRecords.equals(0)) {
				return 0;
			}

			int numpages = (int) Math.ceil((float) totalBidRecords / (float) pageSize);

			if (numpages <= 1) {
				return 0;
			}

			return _random.nextInt(numpages);
		}
		
		@Override
		protected CollectionRepresentation<BidRepresentation> parseResponse() {
			CollectionRepresentation<BidRepresentation> convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _bidCollectionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("BidHistoryInfoProvider::convertStringToT JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("BidHistoryInfoProvider::convertStringToT IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

	}

	public static class PurchaseHistoryInfoProvider extends
			XResponseHolderProvider<String, CollectionRepresentation<ItemRepresentation>> {

		private Random _random;

		public PurchaseHistoryInfoProvider(
				ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> data, Random random) {
			super(data);
			_random = random;
		}

		public Long getTotalPurchaseHistoryRecords() {
			CollectionRepresentation<ItemRepresentation> data = this.getResponse();
			if (data==null) {
				return 0L;
			}
			return data.getTotalRecords();
		}

		public Integer getCurrentPurchaseHistoryPage() {
			CollectionRepresentation<ItemRepresentation> data = this.getResponse();
			if (data==null) {
				return 0;
			}
			return data.getPage();
		}

		/**
		 * Return a random page of PurchaseHistoryRecords, given the page size
		 * and the current page. If there is nothing being held in the
		 * TotalActiveAuctions holder, then return 0. Never return the same page
		 * as currentPage unless currentPage == 0, and pagesize >=
		 * PurchaseHistoryRecords;
		 * 
		 * @param pageSize
		 * @param currentPage
		 * @return
		 */
		public long getRandomPurchaseHistoryRecordsPage(long pageSize, long currentPage) {
			CollectionRepresentation<ItemRepresentation> data = this.getResponse();
			if (data==null) {
				return 0L;
			}

			Long totalEntries = data.getTotalRecords();
			if (totalEntries.equals(0)) {
				return 0;
			}

			int numpages = (int) Math.ceil((float) totalEntries / (float) pageSize);

			if (numpages <= 1) {
				return 0;
			}

			return _random.nextInt(numpages);
		}

		public List<String> getItemThumbnailLinks() {
			logger.debug("PurchaseHistoryInfoProvider.getItemThumbnailLinks");
			List<String> itemImageLinks = new ArrayList<String>();

			CollectionRepresentation<ItemRepresentation> itemsCollection = this.getResponse();
			
			List<ItemRepresentation> itemList = itemsCollection.getResults();

			for (ItemRepresentation curItem : itemList) {
				Map<String, List<Map<RestAction, String>>> curItemLinks = curItem.getLinks();

				if (curItemLinks.containsKey("ItemImage")) {
					List<Map<RestAction, String>> curItemImageLinks = curItemLinks.get("ItemImage");

					if (!curItemImageLinks.isEmpty()) {
						Map<RestAction, String> imageUrlsMap = curItemImageLinks.get(0);

						if (imageUrlsMap.containsKey(RestAction.READ)) {
							itemImageLinks.add(imageUrlsMap.get(RestAction.READ));
						} 
					}
				} else {
					logger.debug("PurchaseHistoryInfoProvider.getItemThumbnailLinks Item has no ItemImage links.");
				}
			}
			
			return itemImageLinks;
		}

		@Override
		protected CollectionRepresentation<ItemRepresentation> parseResponse() {
			CollectionRepresentation<ItemRepresentation> convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _itemCollectionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("PurchaseHistoryInfoListener::convertStringToT JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("PurchaseHistoryInfoListener::convertStringToT IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

	}

	public static class AttendanceHistoryInfoProvider extends
			XResponseHolderProvider<String, CollectionRepresentation<AttendanceRecordRepresentation>> {

		private Random _random;

		public AttendanceHistoryInfoProvider(
				ResponseHolder<String, CollectionRepresentation<AttendanceRecordRepresentation>> data, Random random) {
			super(data);
			_random = random;
		}

		public Long getTotalAttendanceHistoryRecords() {
			CollectionRepresentation<AttendanceRecordRepresentation> data = this.getResponse();
			if (data==null) {
				return 0L;
			}
			return data.getTotalRecords();
		}

		public Integer getCurrentAttendanceHistoryPage() {
			CollectionRepresentation<AttendanceRecordRepresentation> data = this.getResponse();
			if (data==null) {
				return 0;
			}

			return data.getPage();
		}

		/**
		 * Return a random page of AttendanceHistoryRecords, given the page size
		 * and the current page. If there is nothing being held in the
		 * TotalActiveAuctions holder, then return 0. Never return the same page
		 * as currentPage unless currentPage == 0, and pagesize >=
		 * AttendanceHistoryRecords;
		 * 
		 * @param pageSize
		 * @param currentPage
		 * @return
		 */
		public long getRandomAttendanceHistoryRecordsPage(long pageSize, long currentPage) {

			CollectionRepresentation<AttendanceRecordRepresentation> data = this.getResponse();
			if (data==null) {
				return 0L;
			}

			Long totalAttendanceRecords = data.getTotalRecords();
			if (totalAttendanceRecords.equals(0)) {
				return 0;
			}

			int numpages = (int) Math.ceil((float) totalAttendanceRecords / (float) pageSize);

			if (numpages <= 1) {
				return 0;
			}

			return _random.nextInt(numpages);
		}

		@Override
		protected CollectionRepresentation<AttendanceRecordRepresentation> parseResponse() {
			CollectionRepresentation<AttendanceRecordRepresentation> convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _attendanceCollectionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("AttendanceHistoryInfoListener::convertStringToT JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("AttendanceHistoryInfoListener::convertStringToT IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}

	}

	public static class AuctionItemsProvider extends
			XResponseHolderProvider<String, CollectionRepresentation<ItemRepresentation>> {

		private Random _random;

		public AuctionItemsProvider(
				ResponseHolder<String, CollectionRepresentation<ItemRepresentation>> data, Random random) {
			super(data);
			_random = random;
		}

		public List<String> getItemThumbnailLinks() {
			
			logger.debug("AuctionItemsProvider.getItemThumbnailLinks");
			List<String> itemImageLinks = new ArrayList<String>();

			CollectionRepresentation<ItemRepresentation> itemsCollection = this.getResponse();
			List<ItemRepresentation> itemList = itemsCollection.getResults();

			for (ItemRepresentation curItem : itemList) {

				Map<String, List<Map<RestAction, String>>> curItemLinks = curItem.getLinks();

				if (curItemLinks.containsKey("ItemImage")) {
					List<Map<RestAction, String>> curItemImageLinks = curItemLinks.get("ItemImage");
					if (!curItemImageLinks.isEmpty()) {
						Map<RestAction, String> imageUrlsMap = curItemImageLinks.get(0);
						if (imageUrlsMap.containsKey(RestAction.READ)) {
							itemImageLinks.add(imageUrlsMap.get(RestAction.READ));
						} 
					}
				} else {
					logger.debug("AuctionItemsProvider.getItemThumbnailLinks Item has no ItemImage links.");
				}
			}
			
			return itemImageLinks;
		}
		
		public Long getRandomItemId() {
		
			CollectionRepresentation<ItemRepresentation> itemsCollection = this.getResponse();
			List<ItemRepresentation> itemList = itemsCollection.getResults();

			int randInt = _random.nextInt(itemList.size());
			
			ItemRepresentation theItem = itemList.get(randInt);
			
			return theItem.getId();
			
		}

		@Override
		protected CollectionRepresentation<ItemRepresentation> parseResponse() {
			CollectionRepresentation<ItemRepresentation> convertedObject = null;
			synchronized (_data) {
				String rawResponse = _data.getRawResponse();
				if (rawResponse == null) {
					return null;
				}
				try {
					convertedObject = _itemCollectionReader.readValue(rawResponse);
				} catch (JsonProcessingException ex) {
					logger.warn("AuctionItemsProvider::parseResponse JsonProcessingException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				} catch (IOException ex) {
					logger.warn("AuctionItemsProvider::parseResponse IOException value="
							+ rawResponse + " message: " + ex.getMessage());
					throw new RuntimeException(ex);
				}
			}
			return convertedObject;
		}
		
	}

	public static class AddedItemIdProvider extends XHolderProvider<Long> {

		public AddedItemIdProvider(Holder<Long> data) {
			super(data);
		}

	}

	public static class FirstAuctionIdProvider extends XHolderProvider<Long> {

		public FirstAuctionIdProvider(Holder<Long> data) {
			super(data);
		}

	}

	public static class GlobalOrderingIdProvider extends XHolderProvider<Long> {

		public GlobalOrderingIdProvider(Holder<Long> data) {
			super(data);
		}

	}

	public static class PersonProvider extends XMapStringProvider {

		public PersonProvider(Map<String, String> data, Random random) {
			super(data, random);
		}

		public String getRandomPersonName(boolean mustHavePassword) {
			return getRandomXKey(mustHavePassword, "person");
		}

	}

	public static class PersonNameProvider {
		private List<String> _userNames;
		private Random _random;

		public PersonNameProvider(List<String> data, Random random) {
			_userNames = data;
			_random = random;
		}

		public String getStringAtIndex(int index, String type) {
			return _userNames.get(index);
		}

		public String getRandomPersonName() {
			String username;

			synchronized (_userNames) {
				int chosenIndex;
				if (_userNames.size() > 0) {
					chosenIndex = _random.nextInt(_userNames.size());
					username = _userNames.remove(chosenIndex);
					logger.info("getRandomPersonName: Returning " + username + " There are "
							+ _userNames.size() + " available user name");
					return username;
				} else {
					throw new RuntimeException(
							"ERROR: No known user names available to UserNameProvider! Num available user names =  "
									+ _userNames.size());

				}
			}
		}

	}

	public static class PasswordProvider extends XMapStringProvider {

		public PasswordProvider(Map<String, String> data, Random random) {
			super(data, random);
		}

		public String getPasswordForPerson(String userName) {
			return getValueForKey(userName, "password", userName);
		}
	}

	public static class PageSizeProvider extends XHolderProvider<Integer> {

		public PageSizeProvider(Holder<Integer> data) {
			super(data);
		}

	}

	public static class UsersPerAuctionProvider extends XHolderProvider<Integer> {

		public UsersPerAuctionProvider(Holder<Integer> data) {
			super(data);
		}

	}

	/*** Strategy Base Interfaces ***/
	public interface NeedsBidStrategy extends NeedsStrategy {
		public void registerBidStrategyProvider(XHolderProvider<BidStrategy> provider);
	}

	public interface ChoosesBidStrategy extends ChoosesStrategy {
		public void registerBidStrategyChooser(Chooser<BidStrategy> chooser);
	}

	/*** Removes interfaces */
	public interface RemovesActiveAuction extends Removes {

	}

	public interface RemovesActiveItem extends Removes {

	}

	public interface RemovesActiveBid extends Removes {

	}

}
