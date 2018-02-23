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
package com.vmware.weathervane.auction.dbloader;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import javax.inject.Inject;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.DbBenchmarkInfoDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.Condition;
import com.vmware.weathervane.auction.data.model.DbBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.NosqlBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordState;
import com.vmware.weathervane.auction.data.model.Auction.AuctionState;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;
import com.vmware.weathervane.auction.data.model.Item.ItemState;
import com.vmware.weathervane.auction.data.model.User.UserState;
import com.vmware.weathervane.auction.data.repository.AttendanceRecordRepository;
import com.vmware.weathervane.auction.data.repository.BidRepository;
import com.vmware.weathervane.auction.data.repository.NosqlBenchmarkInfoRepository;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

@Repository(value = "dbLoaderDao")
public class DbLoaderDao {

	private static final Logger logger = LoggerFactory.getLogger(DbLoaderDao.class);

	@Inject
	private AuctionDao auctionDao;

	@Inject
	private UserDao userDao;

	@Inject
	private BidRepository bidRepository;

	@Inject
	private HighBidDao highBidDao;

	@Inject
	private ImageStoreFacade imageStore;

	@Inject
	private NosqlBenchmarkInfoRepository nosqlBenchmarkInfoRepository;

	@Inject
	private DbBenchmarkInfoDao dbBenchmarkInfoDao;

	@Inject
	private AttendanceRecordRepository attendanceRecordRepository;

	private Random randGen = new Random();

	private static final String FIRSTNAME = "John";
	private static final String LASTNAME = "Doe";
	private static final String PASSWORD = "password";
	private static final String DOMAIN = "foobar.xyz";

	private static List<String> auctionNames;
	private static List<String> auctionCategories;

	// Constants for history creation
	private static int historyMinPerItem = 5;
	private static float historyBidIncrement = (float) 20.0;

	private static boolean firstUserInterval = true; 
	private static boolean firstHistoryInterval = true; 
	private static boolean firstFutureInterval = true; 
	private static boolean firstCurrentInterval = true; 
	private static long totalWork = 0;

	private static long userWorkRemaining = 0;
	private static long historyWorkRemaining = 0;
	private static long futureWorkRemaining = 0;
	private static long currentWorkRemaining = 0;

	private static DbLoaderWorkEstimate originalDbLoaderWorkEstimate;
	private static DbLoaderWorkEstimate dbLoaderWorkEstimate;

	/*
	 * What time was it when the last gave a completion estimate.
	 */
	private static long updateIntervalStartTimeMillis = 0;
	/*
	 * When should we give the next update.
	 */
	private static long nextUpdateTimeMillis = 0;
	/*
	 * How much work was left when the current interval was started.
	 */
	private static long userWorkRemainingCurIntervalStart = 0;
	private static long historyWorkRemainingCurIntervalStart = 0;
	private static long currentWorkRemainingCurIntervalStart = 0;
	private static long futureWorkRemainingCurIntervalStart = 0;
	/*
	 * Start by printing completion updates every 5 minutes after initial 2
	 * minutes. The first two minutes are ignored when making a time estimate.We
	 * change this to be 10% of the estimated remaining time every time we print
	 * an update.
	 */
	private static long updateIntervalMillis = 300000;

	private enum Epochs {
		USER, HISTORY, CURRENT, FUTURE
	};

	private GregorianCalendar calendar = FixedOffsetCalendarFactory.getCalendar();

	public DbLoaderDao() {
		auctionCategories = new ArrayList<String>();
		auctionCategories.add("Antiques");
		auctionCategories.add("Automotive");
		auctionCategories.add("Kitchen Sinks");
		auctionCategories.add("Toys");
		auctionCategories.add("Cameras");
		auctionCategories.add("Fruit");
		auctionCategories.add("Gardening");
		auctionCategories.add("Computers");

		auctionNames = new ArrayList<String>();
		auctionNames.add("Super Auction");
		auctionNames.add("Massive Auction");
		auctionNames.add("A-1 Auction");
		auctionNames.add("Elite Auction");
		auctionNames.add("Great Stuff Auction");
		auctionNames.add("Junky Auction");

	}

	public static void setTotalWork(DbLoaderWorkEstimate theWorkEstimate, long userWork,
			long historyWork, long futureWork, long currentWork, String messageString) {

		originalDbLoaderWorkEstimate = theWorkEstimate;
		dbLoaderWorkEstimate = new DbLoaderWorkEstimate();
		dbLoaderWorkEstimate.setUserWork(originalDbLoaderWorkEstimate.getUserWork());
		dbLoaderWorkEstimate.setHistoryWork(originalDbLoaderWorkEstimate.getHistoryWork());
		dbLoaderWorkEstimate.setFutureWork(originalDbLoaderWorkEstimate.getFutureWork());
		dbLoaderWorkEstimate.setCurrentWork(originalDbLoaderWorkEstimate.getCurrentWork());

		totalWork = userWork + currentWork + futureWork + historyWork;

		userWorkRemainingCurIntervalStart = userWorkRemaining = userWork;
		historyWorkRemainingCurIntervalStart = historyWorkRemaining = historyWork;
		futureWorkRemainingCurIntervalStart = futureWorkRemaining = futureWork;
		currentWorkRemainingCurIntervalStart = currentWorkRemaining = currentWork;

		updateIntervalStartTimeMillis = System.currentTimeMillis();
		nextUpdateTimeMillis = updateIntervalStartTimeMillis + updateIntervalMillis;

		double workForUsers = userWork * dbLoaderWorkEstimate.getUserWork();
		double workForHistory = historyWork * dbLoaderWorkEstimate.getHistoryWork();
		double workForFuture = futureWork * dbLoaderWorkEstimate.getFutureWork();
		double workForCurrent = currentWork * dbLoaderWorkEstimate.getCurrentWork();
		double totalWork = workForUsers + workForHistory + workForFuture + workForCurrent;

		DateFormat dateFormat = new SimpleDateFormat("E MMM d HH:mm:ss z yyyy");
		Date date = new Date();
		long duration = Math.round(totalWork * 1000);
		String durationString = String.format(
				"Loading data -- Initial estimate of total load time is %d hours, %d min, %d sec. ",
				TimeUnit.MILLISECONDS.toHours(duration),
				TimeUnit.MILLISECONDS.toMinutes(duration)
						- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(duration)),
				TimeUnit.MILLISECONDS.toSeconds(duration)
						- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(duration)));
		System.out.println(dateFormat.format(date) + ": " + durationString + messageString);

	}

	private static synchronized void logWorkDone(Epochs typeOfWork, long workDone, String messageString) {

		double epochWorkRemaining = 0;
		boolean firstInterval = false;
		switch (typeOfWork) {
		case USER:
			userWorkRemaining -= workDone;
			epochWorkRemaining = userWorkRemaining;
			firstInterval = firstUserInterval;
			firstUserInterval = false;
			break;
		case HISTORY:
			historyWorkRemaining -= workDone;
			epochWorkRemaining = historyWorkRemaining;
			firstInterval = firstHistoryInterval;
			firstHistoryInterval = false;
			break;
		case CURRENT:
			currentWorkRemaining -= workDone;
			epochWorkRemaining = currentWorkRemaining;
			firstInterval = firstCurrentInterval;
			firstCurrentInterval = false;
			break;
		case FUTURE:
			futureWorkRemaining -= workDone;
			epochWorkRemaining = futureWorkRemaining;
			firstInterval = firstFutureInterval;
			firstFutureInterval = false;
			break;
		}

		/*
		 * If the update interval has passed, or if we have completed all of the
		 * work for this type of work, then print an update and start a new
		 * interval
		 */
		long now = System.currentTimeMillis();
		if ((now >= nextUpdateTimeMillis) || (epochWorkRemaining == 0)) {
			long intervalDuration = now - updateIntervalStartTimeMillis;

			long totalWorkRemaining = userWorkRemaining + historyWorkRemaining
					+ futureWorkRemaining + currentWorkRemaining;
			logger.debug("At end of interval: totalWorkRemaining = " + totalWorkRemaining
					+ ", totalWork = " + totalWork + ", updateIntervalMillis = "
					+ updateIntervalMillis);
			double pctDone = 100.0 - ((totalWorkRemaining / (totalWork * 1.0)) * 100.0);

			/*
			 * Update the work-per-item estimates for all types of work, but
			 * only if there is still work to do.
			 */
			double workAdjustmentPct = 1.0;
			double newWorkEstimate;
			// Don't update estimates on last or first update of a kind of work
			if ((epochWorkRemaining != 0) && !firstInterval) {
				switch (typeOfWork) {
				case USER:
					// Loading users is so quick we can't get a good estimate of
					// the adjustment
					break;
				case HISTORY:
					newWorkEstimate = (intervalDuration / 1000.0)
							/ (historyWorkRemainingCurIntervalStart - historyWorkRemaining);
					workAdjustmentPct = newWorkEstimate
							/ originalDbLoaderWorkEstimate.getHistoryWork();
					break;
				case CURRENT:
					newWorkEstimate = (intervalDuration / 1000.0)
							/ (currentWorkRemainingCurIntervalStart - currentWorkRemaining);
					workAdjustmentPct = newWorkEstimate
							/ originalDbLoaderWorkEstimate.getCurrentWork();
					break;
				case FUTURE:
					newWorkEstimate = (intervalDuration / 1000.0)
							/ (futureWorkRemainingCurIntervalStart - futureWorkRemaining);
					workAdjustmentPct = newWorkEstimate
							/ originalDbLoaderWorkEstimate.getFutureWork();
					break;
				}

				if (userWorkRemaining != 0) {
					newWorkEstimate = workAdjustmentPct
							* originalDbLoaderWorkEstimate.getUserWork();
					dbLoaderWorkEstimate.setUserWork(newWorkEstimate);
					logger.debug("Updating workPerItem estimate for User"
							+ ", userWorkRemaining = " + userWorkRemaining
							+ ", userWorkRemainingCurIntervalStart = "
							+ userWorkRemainingCurIntervalStart + ", newWorkEstimate = "
							+ newWorkEstimate);
				}
				if (historyWorkRemaining != 0) {
					newWorkEstimate = workAdjustmentPct
							* originalDbLoaderWorkEstimate.getHistoryWork();
					dbLoaderWorkEstimate.setHistoryWork(newWorkEstimate);
					logger.debug("Updating workPerItem estimate for History"
							+ ", historyWorkRemaining = " + historyWorkRemaining
							+ ", historyWorkRemainingCurIntervalStart = "
							+ historyWorkRemainingCurIntervalStart + ", newWorkEstimate = "
							+ newWorkEstimate);
				}
				if (futureWorkRemaining != 0) {
					newWorkEstimate = workAdjustmentPct
							* originalDbLoaderWorkEstimate.getFutureWork();
					dbLoaderWorkEstimate.setFutureWork(newWorkEstimate);
					logger.debug("Updating workPerItem estimate for Future"
							+ ", futureWorkRemaining = " + futureWorkRemaining
							+ ", futureWorkRemainingCurIntervalStart = "
							+ futureWorkRemainingCurIntervalStart + ", newWorkEstimate = "
							+ newWorkEstimate);
				}
				if (currentWorkRemaining != 0) {
					newWorkEstimate = workAdjustmentPct
							* originalDbLoaderWorkEstimate.getCurrentWork();
					dbLoaderWorkEstimate.setCurrentWork(newWorkEstimate);
					logger.debug("Updating workPerItem estimate for Current"
							+ ", currentWorkRemaining = " + currentWorkRemaining
							+ ", currentWorkRemainingCurIntervalStart = "
							+ currentWorkRemainingCurIntervalStart + ", newWorkEstimate = "
							+ newWorkEstimate);
				}

			}
			userWorkRemainingCurIntervalStart = userWorkRemaining;
			historyWorkRemainingCurIntervalStart = historyWorkRemaining;
			futureWorkRemainingCurIntervalStart = futureWorkRemaining;
			currentWorkRemainingCurIntervalStart = currentWorkRemaining;

			double workForUsers = userWorkRemaining * dbLoaderWorkEstimate.getUserWork();
			double workForHistory = historyWorkRemaining * dbLoaderWorkEstimate.getHistoryWork();
			double workForFuture = futureWorkRemaining * dbLoaderWorkEstimate.getFutureWork();
			double workForCurrent = currentWorkRemaining * dbLoaderWorkEstimate.getCurrentWork();
			double totalTimeRemaining = workForUsers + workForHistory + workForFuture
					+ workForCurrent;

			DateFormat dateFormat = new SimpleDateFormat("E MMM dd HH:mm:ss z yyyy");
			Date date = new Date();
			long duration = Math.round(totalTimeRemaining * 1000);
			String durationString = String
					.format("Loading is %.1f%% complete.  Current estimate of remaining load time is %d hours, %d min, %d sec. ",
							pctDone,
							TimeUnit.MILLISECONDS.toHours(duration),
							TimeUnit.MILLISECONDS.toMinutes(duration)
									- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS
											.toHours(duration)),
							TimeUnit.MILLISECONDS.toSeconds(duration)
									- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS
											.toMinutes(duration)));
			System.out.println(dateFormat.format(date) + ": " + durationString + messageString);

			/*
			 * Adjust the time between updates to be 10% of the estimated
			 * remaining time as long as the amount of remaining time is > 5
			 * minutes. The interval is never more than 10 minutes or less than
			 * 2 minutes.
			 */
			if (duration > 300000) {
				updateIntervalMillis = (long) Math.floor(duration * 0.10);
				if (updateIntervalMillis > 600000) {
					updateIntervalMillis = 600000;
				} else if (updateIntervalMillis < 120000) {
					updateIntervalMillis = 120000;
				}
			}
			updateIntervalStartTimeMillis = System.currentTimeMillis();
			nextUpdateTimeMillis = now + updateIntervalMillis;
		}
	}

	/*
	 * Method to convert the number of image sizes into an array of ImageSize
	 */
	public static ImageSize[] convertNumSizesToImageSizes(int numImageSizes) {
		ImageSize[] imageSizes;
		switch (numImageSizes) {
		case 0:
			imageSizes = new ImageSize[] {};
			break;

		case 1:
			imageSizes = new ImageSize[] { ImageSize.THUMBNAIL };
			break;

		case 2:
			imageSizes = new ImageSize[] { ImageSize.THUMBNAIL, ImageSize.PREVIEW };
			break;

		case 3:
			imageSizes = new ImageSize[] { ImageSize.THUMBNAIL, ImageSize.PREVIEW, ImageSize.FULL };
			break;

		default:
			throw new RuntimeException(
					numImageSizes
							+ " is not a valid number of image sizes for Weathervane.  Nust be an integer from 1 to 3.");
		}
		return imageSizes;
	}

	public void saveBenchmarkInfo(long maxUsers, int numNosqlShards, int numNosqlReplicas, 
								String imageStoreType, Long maxDuration) {

		// Save the load info in the NoSQL Data store
		NosqlBenchmarkInfo nosqlBenchmarkInfo = new NosqlBenchmarkInfo();
		nosqlBenchmarkInfo.setMaxusers(maxUsers);
		nosqlBenchmarkInfo.setNumShards(numNosqlShards);
		nosqlBenchmarkInfo.setNumReplicas(numNosqlReplicas);
		nosqlBenchmarkInfo.setImageStoreType(imageStoreType);
		nosqlBenchmarkInfoRepository.save(nosqlBenchmarkInfo);

		// Save the load info in the database
		DbBenchmarkInfo dbBenchmarkInfo = new DbBenchmarkInfo();
		dbBenchmarkInfo.setMaxusers(maxUsers);
		dbBenchmarkInfo.setImagestoretype(imageStoreType);
		dbBenchmarkInfo.setNumnosqlreplicas(new Long(numNosqlReplicas));
		dbBenchmarkInfo.setNumnosqlshards(new Long(numNosqlShards));
		dbBenchmarkInfo.setMaxduration(maxDuration);
		dbBenchmarkInfoDao.save(dbBenchmarkInfo);

		// Save the load info as a file in the image store
		ImageStoreBenchmarkInfo imageStoreBenchmarkInfo = new ImageStoreBenchmarkInfo();
		imageStoreBenchmarkInfo.setMaxusers(maxUsers);
		imageStoreBenchmarkInfo.setImageStoreType(imageStoreType);
		imageStore.setBenchmarkInfo(imageStoreBenchmarkInfo);

	}

	@Transactional
	public void storeUser(User aUser) {
		userDao.save(aUser);
	}

	@Transactional
	public void storeAuction(Auction anAuction, long auctioneerId) {

		logger.info(Thread.currentThread().getName() + ": Storing auction for auctioneer "
				+ auctioneerId);
		// Get the User and make them the quctioneer
		User theAuctioneer = null;
		try {
			theAuctioneer = userDao.get(auctioneerId);
		} catch (Exception ex) {
			logger.error("Caught exception trying to get User for auctioneerId " + auctioneerId
					+ " : " + ex.getMessage());
		}

		theAuctioneer.addAuction(anAuction);

		for (Item anItem : anAuction.getItems()) {
			anItem.setAuctioneer(theAuctioneer);
		}

		auctionDao.save(anAuction);

	}

	@Transactional
	public void loadUsers(DbLoadSpec dbLoadSpec) {

		// Create some users
		try {
			long maxUserNumber = dbLoadSpec.getNumUsersToCreate() + dbLoadSpec.getStartUserNumber();
			for (long j = dbLoadSpec.getStartUserNumber(); j < maxUserNumber; j++) {
				User aUser = new User();
				Float creditLimit;
				do {
					creditLimit = new Float(randGen.nextGaussian()
							* dbLoadSpec.getStdDevCreditLimit() + dbLoadSpec.getAvgCreditLimit());
				} while (creditLimit <= 0);
				aUser.setCreditLimit(creditLimit);
				aUser.setFirstname(FIRSTNAME + j);
				aUser.setLastname(LASTNAME);
				aUser.setPassword(PASSWORD);
				aUser.setEnabled(true);
				aUser.setLoggedin(false);
				aUser.setAuthorities("watcher");
				aUser.setState(UserState.REGISTERED);
				aUser.setEmail(FIRSTNAME.toLowerCase() + LASTNAME.toLowerCase() + j + "@" + DOMAIN);
				storeUser(aUser);
			}

			if (dbLoadSpec.getStartUserNumber() == 1) {
				// first thread creates some guest and system users
				User aUser = new User();
				aUser.setCreditLimit(new Float(1000000.0));
				aUser.setFirstname("A");
				aUser.setLastname("Guest");
				aUser.setPassword("guest");
				aUser.setEnabled(true);
				aUser.setLoggedin(false);
				aUser.setAuthorities("watcher");
				aUser.setState(UserState.REGISTERED);
				aUser.setEmail("guest@foobar.xyz");
				storeUser(aUser);

				aUser = new User();
				aUser.setCreditLimit(new Float(1000000.0));
				aUser.setFirstname("An");
				aUser.setLastname("Admin");
				aUser.setPassword("admin");
				aUser.setEnabled(true);
				aUser.setLoggedin(false);
				aUser.setAuthorities("watcher");
				aUser.setState(UserState.REGISTERED);
				aUser.setEmail("admin@auction.xyz");
				storeUser(aUser);
				
				for (Integer index = 1; index <= 40; index++) {
					String email = "warmer" + index + "@auction.xyz";
					aUser = new User();
					aUser.setCreditLimit(new Float(1000000.0));
					aUser.setFirstname(index.toString());
					aUser.setLastname("Warmer");
					aUser.setPassword("warmer");
					aUser.setEnabled(true);
					aUser.setLoggedin(false);
					aUser.setAuthorities("watcher");
					aUser.setState(UserState.REGISTERED);
					aUser.setEmail(email);
					storeUser(aUser);
				}

				aUser = new User();
				aUser.setCreditLimit(new Float(1000000.0));
				aUser.setFirstname("un");
				aUser.setLastname("sold");
				aUser.setPassword("unsold");
				aUser.setEnabled(true);
				aUser.setLoggedin(false);
				aUser.setAuthorities("watcher");
				aUser.setState(UserState.REGISTERED);
				aUser.setEmail("unsold@auction.xyz");
				storeUser(aUser);
			}

		} catch (Exception ex) {
			System.out.println("In loadUsers, threw exception: " + ex.getMessage() + ". " + dbLoadSpec.getMessageString());
			throw new RuntimeException(ex);
		}

		logWorkDone(Epochs.USER, dbLoadSpec.getNumUsersToCreate(), dbLoadSpec.getMessageString());

	}

	@Transactional
	public void loadAuctionsChunk(Long numAuctions, DbLoadSpec dbLoadSpec, JSONArray itemDescr,
			List<List<ImagesHolder>> allItemImages) throws JSONException, IOException {

		/*
		 * When pre-loading current auctions, set them to start one year from
		 * now. This will be changed when the dbPreparer sets up for the run.
		 */
		GregorianCalendar currentTime = FixedOffsetCalendarFactory.getCalendar();
		currentTime.add(Calendar.YEAR, 1);
		Date startTime = currentTime.getTime();

		int numImages = dbLoadSpec.getMaxImagesPerCurrentItem();
		ImageSize[] imageSizes = convertNumSizesToImageSizes(dbLoadSpec
				.getNumImageSizesPerCurrentItem());
		long numItems = dbLoadSpec.getItemsPerCurrentAuction();

		// Mock up some auctions
		for (int i = 1; i <= numAuctions; i++) {
			int auctioneerId = randGen.nextInt(dbLoadSpec.getTotalUsers()) + 1;
			Auction anAuction = new Auction();
			anAuction.setCategory(auctionCategories.get(randGen.nextInt(auctionCategories.size())));
			anAuction.setName(auctionNames.get(randGen.nextInt(auctionNames.size())));
			anAuction.setCurrent(true);
			anAuction.setActivated(false);

			// Determine the start time
			anAuction.setStartTime(startTime);

			/*
			 * First add empty items to the auction. We will fill the item in
			 * once we have the unique id, which we will use to select the item
			 * description
			 */
			for (int j = 1; j <= numItems; j++) {

				addItemForAuction(anAuction);

			}
			anAuction.setState(AuctionState.FUTURE);

			storeAuction(anAuction, auctioneerId);

			/*
			 * Now update the items with the full description
			 */
			for (Item anItem : anAuction.getItems()) {
				updateItemForAuction(anAuction, anItem, itemDescr, ItemState.INAUCTION, dbLoadSpec);
			}
			
			logger.debug("loadAuctions calling addImagesForItems.  numImages = " + numImages);
			addImagesForItems(anAuction, dbLoadSpec, imageSizes, numImages, allItemImages,
					itemDescr);
		}

		logWorkDone(Epochs.CURRENT, numAuctions * numItems, dbLoadSpec.getMessageString());

	}

	/*
	 * This method creates the auctions, items, bids, and attendence records for
	 * the past history. The history is created in chunks of auctions, each of
	 * historyChunkSize. This allows us to control the amount of data per
	 * commit. More auctions per commit gives less disk activity, but requires
	 * more memory.
	 */
	@Transactional
	public void loadHistoryChunk(DbLoadSpec dbLoadSpec, JSONArray itemDescr, long numAuctions,
			GregorianCalendar auctionTime, int interAuctionTimeMillis,
			List<List<ImagesHolder>> allItemImages) throws JSONException, IOException {
		String threadName = Thread.currentThread().getName();
		int itemsPerAuction = dbLoadSpec.getHistoryItemsPerAuction();
		int numImages = dbLoadSpec.getMaxImagesPerHistoryItem();
		ImageSize[] imageSizes = convertNumSizesToImageSizes(dbLoadSpec
				.getNumImageSizesPerHistoryItem());

		// Mock up some auctions
		for (int i = 1; i <= numAuctions; i++) {
			logger.info(threadName + ":loadHistoryChunk.  Creating auction " + i);
			// Select a random user to be the auctioneer
			int auctioneerId = randGen.nextInt(dbLoadSpec.getTotalUsers()) + 1;

			Auction anAuction = new Auction();
			anAuction.setCategory(auctionCategories.get(randGen.nextInt(auctionCategories.size())));
			anAuction.setName(auctionNames.get(randGen.nextInt(auctionNames.size())));
			anAuction.setCurrent(false);

			// Set the start time
			anAuction.setStartTime(auctionTime.getTime());

			// determine the end time at historyMinPerItem minutes per item
			int auctionDurationMillis = itemsPerAuction * historyMinPerItem * 60 * 1000;
			Date endTime = new Date(auctionTime.getTimeInMillis() + auctionDurationMillis);
			anAuction.setEndTime(endTime);

			for (int j = 1; j <= itemsPerAuction; j++) {
				logger.info(threadName + ":loadHistory.  Adding item " + j + " to auction " + i);

				addItemForAuction(anAuction);
			}
			anAuction.setState(AuctionState.COMPLETE);

			/*
			 * Save the auction and items. Need to do this now because we need
			 * the auction to have an id before we can add attendance records or
			 * images
			 */
			storeAuction(anAuction, auctioneerId);

			/*
			 * Now update the items with the full description. Also create the
			 * HighBid entries for each item
			 */
			long itemStartTimeMillis = auctionTime.getTimeInMillis();
			for (Item anItem : anAuction.getItems()) {
				long itemEndTimeMillis = itemStartTimeMillis + historyMinPerItem * 60 * 1000 - 1;
				HighBid highBid = new HighBid();
				highBid.setBiddingStartTime(new Date(itemStartTimeMillis));
				highBid.setBiddingEndTime(new Date(itemEndTimeMillis));
				highBid.setAuction(anAuction);
				highBid.setItem(anItem);
				highBid.setPreloaded(true);
				highBidDao.save(highBid);
				// Set winning bid attributes when creating bids

				updateItemForAuction(anAuction, anItem, itemDescr, ItemState.SHIPPED, dbLoadSpec);
				anItem.setHighbid(highBid);

				itemStartTimeMillis += historyMinPerItem * 60 * 1000;

			}

			/*
			 * Add the images for the items to the image store
			 */
			addImagesForItems(anAuction, dbLoadSpec, imageSizes, numImages, allItemImages,
					itemDescr);

			// For simplicity, attended entire auction
			Set<Long> attendeeIds = new HashSet<Long>();
			int numAttendanceRecords = dbLoadSpec.getHistoryAttendeesPerAuction();
			for (int j = 0; j < numAttendanceRecords; j++) {
				// Select a random user not already selected to be the attendee
				Long attendeeId;
				do {
					attendeeId = new Long(randGen.nextInt(dbLoadSpec.getTotalUsers()) + 1);
				} while (attendeeIds.contains(attendeeId));
				attendeeIds.add(attendeeId);

				AttendanceRecord anAttendanceRecord = new AttendanceRecord();
				anAttendanceRecord.setTimestamp(endTime);
				anAttendanceRecord.setState(AttendanceRecordState.AUCTIONCOMPLETE);
				anAttendanceRecord.setUserId(attendeeId);
				anAttendanceRecord.setAuctionId(anAuction.getId());
				anAttendanceRecord.setAuctionName(anAuction.getName());
				
				attendanceRecordRepository.save(anAttendanceRecord);
			}

			/*
			 * Now create a number of bids for each item. The last bid is the
			 * winning bid and has the purchaser.
			 */
			Object[] attendeeIdsArray = attendeeIds.toArray();
			int historyBidsPerItem = dbLoadSpec.getHistoryBidsPerItem();
			long milliSecPerBid = ((historyMinPerItem - 1) * 60 * 1000) / historyBidsPerItem;
			for (Item anItem : anAuction.getItems()) {
				HighBid highBid = anItem.getHighbid();
				Long lastBidderId = (Long) attendeeIdsArray[0];
				long bidTime = highBid.getBiddingStartTime().getTime() + 1;
				float bidAmount = anItem.getStartingBidAmount();

				Bid aBid = null;
				for (int j = 0; j < historyBidsPerItem; j++) {
					// Choose a bidder from users who attended auction
					Long bidderId;
					do {
						bidderId = (Long) attendeeIdsArray[randGen.nextInt(attendeeIdsArray.length)];
					} while (bidderId.equals(lastBidderId));
					lastBidderId = bidderId;

					aBid = new Bid();
					aBid.setReceivingNode(0L);
					aBid.setBidCount(j + 1);
					aBid.setAmount(bidAmount);
					bidAmount += historyBidIncrement;

					aBid.setBidTime(new Date(bidTime));
					bidTime += milliSecPerBid;

					// Only creating history of high bids
					aBid.setState(Bid.BidState.HIGH);
					aBid.setAuctionId(anAuction.getId());
					aBid.setItemId(anItem.getId());
					aBid.setBidderId(lastBidderId);

					bidRepository.save(aBid);
				}

				// Last bid is the winning bid
				User purchaser = userDao.get(lastBidderId);
				if (aBid.getAmount() != null) {
					highBid.setAmount(aBid.getAmount());
				} else {
					highBid.setAmount(0.0F);
				}
				highBid.setBidder(purchaser);
				highBid.setBidCount(historyBidsPerItem + 2);
				highBid.setCurrentBidTime(aBid.getBidTime());
				highBid.setBidId(aBid.getId().toString());
				highBid.setState(HighBidState.SOLD);
			}

			// Add the interval to get the start time of the next auction
			auctionTime.add(Calendar.MILLISECOND, interAuctionTimeMillis);

		}

		logWorkDone(Epochs.HISTORY, numAuctions * itemsPerAuction, dbLoadSpec.getMessageString());

	}

	@Transactional
	public void loadFutureChunk(DbLoadSpec dbLoadSpec, JSONArray itemDescr, long numAuctions,
			GregorianCalendar auctionTime, int interAuctionTimeMillis,
			List<List<ImagesHolder>> allItemImages) throws JSONException, IOException {
		String threadName = Thread.currentThread().getName();
		int numImages = dbLoadSpec.getMaxImagesPerFutureItem();
		ImageSize[] imageSizes = convertNumSizesToImageSizes(dbLoadSpec
				.getNumImageSizesPerFutureItem());
		int itemsPerAuction = dbLoadSpec.getFutureItemsPerAuction();
		
		DateFormat dateFormatter = DateFormat.getDateInstance();
		
		logger.debug("loadFutureChunk loading " + numAuctions + " starting at time " 
				+ dateFormatter.format(auctionTime.getTime()) 
				+", interAuctionTimeMiilis = " + interAuctionTimeMillis);
		
		
		// Mock up some auctions
		for (int i = 1; i <= numAuctions; i++) {
			logger.info(threadName + ":loadFuture.  Creating auction " + i);
			// Select a random user to be the auctioneer
			int auctioneerId = randGen.nextInt(dbLoadSpec.getTotalUsers()) + 1;

			Auction anAuction = new Auction();
			anAuction.setCategory(auctionCategories.get(randGen.nextInt(auctionCategories.size())));
			anAuction.setName(auctionNames.get(randGen.nextInt(auctionNames.size())));
			anAuction.setCurrent(false);

			// Set the start time
			anAuction.setStartTime(auctionTime.getTime());

			for (int j = 1; j <= itemsPerAuction; j++) {
				logger.info(threadName + ":loadFuture.  Adding item " + j + " to auction " + i);

				addItemForAuction(anAuction);

			}
			anAuction.setState(AuctionState.FUTURE);

			/*
			 * Save the auction and items. Need to do this now because we need
			 * the auction to have an id before we can add attendance records
			 */
			storeAuction(anAuction, auctioneerId);

			/*
			 * Now update the items with the full description
			 */
			for (Item anItem : anAuction.getItems()) {
				updateItemForAuction(anAuction, anItem, itemDescr, ItemState.INAUCTION, dbLoadSpec);
			}

			addImagesForItems(anAuction, dbLoadSpec, imageSizes, numImages, allItemImages,
					itemDescr);

			// Add the interval to get the start time of the next auction
			auctionTime.add(Calendar.MILLISECOND, interAuctionTimeMillis);
		}

		logWorkDone(Epochs.FUTURE, numAuctions * itemsPerAuction, dbLoadSpec.getMessageString());

	}

	protected void addImagesForItems(Auction anAuction, DbLoadSpec dbLoadSpec, ImageSize[] sizes,
			int numImages, List<List<ImagesHolder>> allItemImages, JSONArray itemDescr)
			throws JSONException, IOException {
		Set<Item> items = anAuction.getItems();

		List<ImageInfo> imageInfos = new ArrayList<ImageInfo>();
		List<BufferedImage> imageFulls = new ArrayList<BufferedImage>();
		List<BufferedImage> imageThumbnails = new ArrayList<BufferedImage>();
		List<BufferedImage> imagePreviews = new ArrayList<BufferedImage>();

		for (Item anItem : items) {

			logger.debug("addImagesForItems.  adding  " + numImages + " images for item " + anItem.getId() 
					+ " in auction " + anAuction.getId());
			int descNum = (int) (anItem.getId() % itemDescr.length());
			JSONObject itemDescrObj = itemDescr.getJSONObject(descNum);

			JSONArray imageNames = itemDescrObj.getJSONArray("images");

			List<ImagesHolder> itemImages = allItemImages.get(descNum);

			int imagesToLoad = imageNames.length();
			if (imagesToLoad > numImages) {
				imagesToLoad = numImages;
			}

			if (imagesToLoad > itemImages.size()) {
				imagesToLoad = itemImages.size();
			}

			logger.debug("addImagesForItems.  imagesToLoad = " + imagesToLoad);

			for (int k = 0; k < imagesToLoad; k++) {
				ImagesHolder imagesHolder = itemImages.get(k);

				ImageInfo theImageInfo = new ImageInfo();
				theImageInfo.setFormat(imageStore.getImageFormat());
				theImageInfo.setName(imageNames.getString(k));
				theImageInfo.setEntityid(anItem.getId());
				theImageInfo.setEntitytype(Item.class.getSimpleName());
				theImageInfo.setPreloaded(true);
				theImageInfo.setImagenum(new Long(k + 1));
				theImageInfo.setDateadded(calendar.getTime());
				imageInfos.add(theImageInfo);
				if (dbLoadSpec.isLoadImages()) {
					for (ImageSize size : sizes) {
						if (size.equals(ImageSize.FULL)) {
							imageFulls.add(imagesHolder.getFullSize());
						} else if (size.equals(ImageSize.PREVIEW)) {
							imagePreviews.add(imagesHolder.getPreviewSize());
						} else if (size.equals(ImageSize.THUMBNAIL)) {
							imageThumbnails.add(imagesHolder.getThumbnailSize());
						}
					}
				}
			}
		}
		imageStore.addImages(imageInfos, imageFulls, imagePreviews, imageThumbnails);

	}

	protected void addItemForAuction(Auction anAuction) {

		Item anItem = new Item();
		anAuction.addItemToAuction(anItem);

	}

	/**
	 * Used after an item has been added to the database and we have the unique
	 * id of the item, which we can use to pick the item description from the
	 * JSONArray of descriptions. Using the id modulo the number of items
	 * ensures that each item number always gets the same item description and
	 * images.
	 */
	protected void updateItemForAuction(Auction anAuction, Item anItem, JSONArray itemDescr,
			ItemState state, DbLoadSpec dbLoadSpec) throws JSONException {

		logger.debug("updateItemForAuction.  Updating item " + anItem.getId() + " for auction " + anAuction.getId());
		
		int descNum = (int) (anItem.getId() % itemDescr.length());

		JSONObject itemDescrObj = itemDescr.getJSONObject(descNum);

		// Calendar for setting item creation dates
		GregorianCalendar calend = FixedOffsetCalendarFactory.getCalendar();
		int curYear = calend.get(Calendar.YEAR);

		Condition[] conditions = Condition.values();

		anItem.setState(state);

		float startingBid = 0;
		float stdDevStartingBid = dbLoadSpec.getStdDevStartingBid();
		float avgStartingBid = dbLoadSpec.getAvgStartingBid();
		do {
			startingBid = (float) (randGen.nextGaussian() * stdDevStartingBid) + avgStartingBid;
			// Reduce the range in cases where the selected starting bid is < 0
			if (startingBid < 0) {
				stdDevStartingBid /= 2;
				avgStartingBid /=2;
			}
		} while (startingBid < 0);
		anItem.setStartingBidAmount(startingBid);
		anItem.setManufacturer(itemDescrObj.getString("manufacturer"));

		anItem.setShortDescription(itemDescrObj.getString("shortDescription"));
		anItem.setLongDescription(itemDescrObj.getString("longDescription"));
		if (itemDescrObj.has("condition")) {
			Condition itemCondition = Condition.valueOf(itemDescrObj.getString("condition"));
			anItem.setCondition(itemCondition);
		} else {
			anItem.setCondition(conditions[randGen.nextInt(conditions.length)]);
		}

		/*
		 * Set the creation date of the item to a random year up to 100 years
		 * agp
		 */
		calend.set(Calendar.YEAR, curYear - randGen.nextInt(100));
		anItem.setDateOfOrigin(calend.getTime());

		// Set a flag so this item isn't deleted between runs
		anItem.setPreloaded(true);

	}
}
