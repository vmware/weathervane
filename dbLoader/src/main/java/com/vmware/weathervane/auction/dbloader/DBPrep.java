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

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.json.JSONException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.AuctionMgmtDao;
import com.vmware.weathervane.auction.data.dao.DbBenchmarkInfoDao;
import com.vmware.weathervane.auction.data.dao.FixedTimeOffsetDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.NoBenchmarkInfoException;
import com.vmware.weathervane.auction.data.imageStore.NoBenchmarkInfoNeededException;
import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.DbBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.NosqlBenchmarkInfo;
import com.vmware.weathervane.auction.data.repository.event.AttendanceRecordRepository;
import com.vmware.weathervane.auction.data.repository.event.BidRepository;
import com.vmware.weathervane.auction.data.repository.event.NosqlBenchmarkInfoRepository;

public class DBPrep {

	private static String numThreadsDefault = "30";
	private static String maxUsersDefault = "120";
	private static List<Thread> threadList = new ArrayList<Thread>();

	private static ImageStoreFacade imageStore;

	private static AuctionDao auctionDao;
	private static ItemDao itemDao;
	private static UserDao userDao;
	private static HighBidDao highBidDao;
	private static AuctionMgmtDao auctionMgmtDao;
	private static FixedTimeOffsetDao fixedTimeOffsetDao;
	
	private static BidRepository bidRepository;
	private static AttendanceRecordRepository attendanceRecordRepository;

	private static final Logger logger = LoggerFactory.getLogger(DBPrep.class);

	public static void usage() {

		System.out.println("Usage information for the Auction DBPrep:");

	}

	public static void main(String[] args) throws InterruptedException, IOException, JSONException {

		Option u = new Option("u", "users", true,
				"Number of active users to be supported in this run.");
		Option c = new Option("c", "check", false,
				"Only check whether the database is loaded with the proper number of users and then exit.");
		Option p = new Option("p", "pretouch", false,
				"Pretouch the data in the image and event stores.");
		Option a = new Option("a", "auctions", true,
				"Number of auctions to be active in current run.");
		a.setRequired(true);
		Option t = new Option("t", "threads", true, "Number of threads for dbprep");

		Options cliOptions = new Options();
		cliOptions.addOption(u);
		cliOptions.addOption(a);
		cliOptions.addOption(c);
		cliOptions.addOption(p);
		cliOptions.addOption(t);

		CommandLine cliCmd = null;
		CommandLineParser cliParser = new PosixParser();
		try {
			cliCmd = cliParser.parse(cliOptions, args);
		} catch (ParseException ex) {
			imageStore.stopServiceThreads();
			System.err.println("DBPrep.  Caught ParseException " + ex.getMessage());
			System.exit(1);
		}

		String auctionsString = cliCmd.getOptionValue('a');
		String numThreadsString = cliCmd.getOptionValue('t', numThreadsDefault);

		String usersString = cliCmd.getOptionValue('u', maxUsersDefault);
		int users = Integer.valueOf(usersString);

		int numAuctions = Integer.valueOf(auctionsString);
		long numThreads = Long.valueOf(numThreadsString);

		// Determine the imageStore type from the spring.profiles.active
		// property
		String springProfilesActive = System.getProperty("spring.profiles.active");
		if (springProfilesActive == null) {
			imageStore.stopServiceThreads();
			throw new RuntimeException("The spring.profiles.active property must be set for DBPrep");
		}
		String imageStoreType;
		if (springProfilesActive.contains("Memory")) {
			imageStoreType = "memory";
		} else if (springProfilesActive.contains("Cassandra")) {
			imageStoreType = "cassandra";
		} else {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"The spring.profiles.active property be either imagesInCassandra or imagesInMemory for DBPrep.");
		}

		ApplicationContext context = new ClassPathXmlApplicationContext(new String[] {
				"dbprep-context.xml", "datasource-context.xml", "jpa-context.xml", "cassandra-context.xml" });
		imageStore = (ImageStoreFacade) context.getBean("imageStoreFacade");
		NosqlBenchmarkInfoRepository nosqlBenchmarkInfoRepository = (NosqlBenchmarkInfoRepository) context
				.getBean("nosqlBenchmarkInfoRepository");
		DbBenchmarkInfoDao dbBenchmarkInfoDao = (DbBenchmarkInfoDao) context
				.getBean("dbBenchmarkInfoDao");
		auctionDao = (AuctionDao) context.getBean("auctionDao");
		itemDao = (ItemDao) context.getBean("itemDao");
		userDao = (UserDao) context.getBean("userDao");
		highBidDao = (HighBidDao) context.getBean("highBidDao");
		auctionMgmtDao = (AuctionMgmtDao) context.getBean("auctionMgmtDao");
		fixedTimeOffsetDao = (FixedTimeOffsetDao) context.getBean("fixedTimeOffsetDao");
		bidRepository = (BidRepository) context.getBean("bidRepository");
		attendanceRecordRepository = (AttendanceRecordRepository) context.getBean("attendanceRecordRepository");

		/*
		 * Make sure that database is loaded at correctly
		 */
		logger.debug("Checking whether database has benchmark info");
		List<DbBenchmarkInfo> dbBenchmarkInfoList = dbBenchmarkInfoDao.getAll();
		if ((dbBenchmarkInfoList == null) || (dbBenchmarkInfoList.size() < 1)) {
			imageStore.stopServiceThreads();
			logger.warn("Cannot find benchmarkInfo in database.  Make sure that data is preloaded.");
			System.exit(1);
		}

		DbBenchmarkInfo dbBenchmarkInfo = dbBenchmarkInfoList.get(0);
		logger.info("Got DB benchmarkInfo: " + dbBenchmarkInfo);
		try {
			long infoMaxUsers = dbBenchmarkInfo.getMaxusers();
			if (infoMaxUsers < users) {
				logger.warn(
						"MaxUsers supported by database does not match desired number of users   Users =  "
								+ users + ", Found " + infoMaxUsers
								+ ". Make sure that correct data is loaded.");
				System.exit(1);				
			}
			if (!dbBenchmarkInfo.getImagestoretype().equals(imageStoreType)) {
				logger.warn(
						"ImageStoreType in database does not match desired type. Needed "
								+ imageStoreType + ", Found " + dbBenchmarkInfo.getImagestoretype()
								+ ", Make sure that correct data is loaded.");
				System.exit(1);
			}
		} finally {
			imageStore.stopServiceThreads();
		}

		/*
		 * Make sure that NoSQL store is loaded at correctly
		 */
		logger.debug("Checking whether NoSQL Data-Store has benchmark info");
		List<NosqlBenchmarkInfo> nosqlBenchmarkInfoList = (List<NosqlBenchmarkInfo>) nosqlBenchmarkInfoRepository.findAll();
		if ((nosqlBenchmarkInfoList == null) || (nosqlBenchmarkInfoList.size() < 1)) {
			imageStore.stopServiceThreads();
			logger.warn(
					"Cannot find benchmarkInfo in NoSQL store.  Make sure that data is preloaded.");
			System.exit(1);
		}

		NosqlBenchmarkInfo nosqlBenchmarkInfo = nosqlBenchmarkInfoList.get(0);
		logger.info("Got NoSQL benchmarkInfo: " + nosqlBenchmarkInfo );
		long infoMaxUsers = nosqlBenchmarkInfo.getMaxusers();
		if (infoMaxUsers < users) {
			imageStore.stopServiceThreads();
			logger.warn(
					"MaxUsers supported by NoSQL datastore does not match desired number of users   Users =  "
							+ users + ", Found " + infoMaxUsers
							+ ". Make sure that correct data is loaded.");
			System.exit(1);
		}

		if (!nosqlBenchmarkInfo.getImageStoreType().equals(imageStoreType)) {
			imageStore.stopServiceThreads();
			logger.warn(
					"ImageStoreType in database does not match desired type. Needed "
							+ imageStoreType + ", Found " + nosqlBenchmarkInfo.getImageStoreType()
							+ ", Make sure that correct data is loaded.");
			System.exit(1);
		}

		/*
		 * Make sure that the image store is loaded at correctly
		 */
		ImageStoreBenchmarkInfo imageStoreBenchmarkInfo = null;
		try {
			imageStoreBenchmarkInfo = imageStore.getBenchmarkInfo();
			infoMaxUsers = imageStoreBenchmarkInfo.getMaxusers();
			if (infoMaxUsers < users) {
				imageStore.stopServiceThreads();
				logger.warn(
						"MaxUsers supported by imageStore does not match desired number of users   Users =  "
								+ users + ", Found " + infoMaxUsers
								+ ". Make sure that correct data is loaded.");
				System.exit(1);
			}
			if (!imageStoreBenchmarkInfo.getImageStoreType().equals(imageStoreType)) {
				imageStore.stopServiceThreads();
				logger.warn(
						"ImageStoreType in imageStore does not match desired type. Needed "
								+ imageStoreType + ", Found "
								+ imageStoreBenchmarkInfo.getImageStoreType()
								+ ", Make sure that correct data is loaded.");
				System.exit(1);
			}

		} catch (NoBenchmarkInfoException e) {
			imageStore.stopServiceThreads();
			logger.warn(
					"No benchmark info stored in imageStore.  Make sure that correct data is loaded.");
			System.exit(1);
		} catch (NoBenchmarkInfoNeededException e) {
			// Some imageStore types always have the proper load
			logger.info("Got a NoBenchmarkInfoNeededException exception from the imageStore.  Continuing");
			System.exit(1);
		}

		// If only wanted to check for loaded data, then return here
		if (cliCmd.hasOption("c")) {
			logger.info("Benchmark is loaded correctly. Exiting cleanly.");
			imageStore.stopServiceThreads();
			System.exit(0);
		}

		/*
		 * Clear out the images that were added on the last run.
		 */
		logger.debug("Clearing non-preloaded images");
		imageStore.clearNonpreloadedImages();

		/*
		 * Reset the data on all auctions that could be current in a run and
		 * that were used in a previous run
		 */
		List<Auction> preusedAuctions = auctionDao.findByCurrentAndActivated(true, true);
		logger.info("Found " + preusedAuctions.size()
				+ " auctions that were activated in a previous run\n");
		int auctionsPerThread = (int) Math.ceil(preusedAuctions.size() / (1.0 * numThreads));
		int numRemainingAuctions = preusedAuctions.size();
		int startIndex = 0;
		for (int j = 0; j < numThreads; j++) {
			if (numRemainingAuctions == 0)
				break;
			int numAuctionsToReset = auctionsPerThread;
			if (numAuctionsToReset > numRemainingAuctions) {
				numAuctionsToReset = numRemainingAuctions;
			}
			int endIndex = startIndex + numAuctionsToReset;

			DBPrepService dbPrepService = new DBPrepService();
			dbPrepService.setAuctionsToPrep(preusedAuctions);
			dbPrepService.setAuctionDao(auctionDao);
			dbPrepService.setHighBidDao(highBidDao);
			dbPrepService.setPrepStartIndex(startIndex);
			dbPrepService.setPrepEndIndex(endIndex);
			dbPrepService.setResetAuctions(true);
			dbPrepService.setPretouch(false);
			Thread dbPrepThread = new Thread(dbPrepService, "dbPrepService" + j);
			dbPrepThread.setUncaughtExceptionHandler(
					new Thread.UncaughtExceptionHandler() {
						public void uncaughtException(Thread th, Throwable ex) {
							logger.warn("Uncaught exception in dbPrepService: " + ex);
							System.exit(1);
						}
					});
			threadList.add(dbPrepThread);
			dbPrepThread.start();
			startIndex += numAuctionsToReset;
			numRemainingAuctions -= numAuctionsToReset;
		}
		// Wait for all threads to complete
		for (Thread thread : threadList) {
			thread.join();
		}
		threadList.clear();
		
		// Need to run this after all auctions have been reset
		logger.info("Deleting preloaded highBids\n");
		highBidDao.deleteByPreloaded(false);

		/*
		 * Delete items that were added during the last run
		 */
		logger.info("Deleting non-preloaded items\n");
		int numDeleted = itemDao.deleteByPreloaded(false);
		logger.info("Deleted " + numDeleted + " non-preloaded items\n");
		
		/*
		 * Reset the users
		 */
		userDao.clearAllAuthTokens();
		userDao.resetAllCreditLimits();
		userDao.clearAllLoggedIn();
		
		/*
		 * If numAuctions is greater than 0, then we are preparing for a new run
		 */
		if (numAuctions > 0) {
			/*
			 * Set the correct number of auctions to start during this run
			 */
			logger.info("Finding auctions with current flag set\n");
			List<Auction> auctionsToActivate = auctionDao.findByCurrent(true, numAuctions);

			auctionsPerThread = (int) Math.ceil(auctionsToActivate.size() / (1.0 * numThreads));
			logger.info("Found " + auctionsToActivate.size() + " auctions to activate in this run. auctionsPerThread = "
					+ auctionsPerThread + "\n");
			numRemainingAuctions = auctionsToActivate.size();
			startIndex = 0;
			for (int j = 0; j < numThreads; j++) {
				int numAuctionsToReset = auctionsPerThread;
				if (numAuctionsToReset > numRemainingAuctions) {
					numAuctionsToReset = numRemainingAuctions;
				}
				int endIndex = startIndex + numAuctionsToReset;
				logger.debug("Thread " + j + ": resetting " + numAuctionsToReset + " auctions.");
				DBPrepService dbPrepService = new DBPrepService();
				dbPrepService.setAuctionsToPrep(auctionsToActivate);
				dbPrepService.setHighBidDao(highBidDao);
				dbPrepService.setAuctionDao(auctionDao);
				dbPrepService.setPrepStartIndex(startIndex);
				dbPrepService.setPrepEndIndex(endIndex);
				dbPrepService.setResetAuctions(false);
				dbPrepService.setPretouch(false);
				Thread dbPrepThread = new Thread(dbPrepService, "dbPrepService" + j);
				dbPrepThread.setUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
					public void uncaughtException(Thread th, Throwable ex) {
						logger.warn("Uncaught exception in dbPrepService: " + ex);
						System.exit(1);
					}
				});
				threadList.add(dbPrepThread);
				dbPrepThread.start();

				startIndex += numAuctionsToReset;
				numRemainingAuctions -= numAuctionsToReset;
			}

			// Wait for all threads to complete
			for (Thread thread : threadList) {
				thread.join();
			}
			threadList.clear();

			if (cliCmd.hasOption("p")) {
				/*
				 * Pretouch the images
				 */
				List<Auction> allAuctions = auctionDao.getAll();
				auctionsPerThread = (int) Math.ceil(allAuctions.size() / (1.0 * numThreads));
				logger.info("Found " + allAuctions.size() + " auctions to preTouch in this run. auctionsPerThread = "
						+ auctionsPerThread + "\n");
				numRemainingAuctions = allAuctions.size();
				startIndex = 0;
				for (int j = 0; j < numThreads; j++) {
					int numAuctionsToTouch = auctionsPerThread;
					if (numAuctionsToTouch > numRemainingAuctions) {
						numAuctionsToTouch = numRemainingAuctions;
					}
					int endIndex = startIndex + numAuctionsToTouch;
					logger.debug("Thread " + j + ": pretouching " + numAuctionsToTouch + " auctions.");
					DBPrepService dbPrepService = new DBPrepService();
					dbPrepService.setAuctionsToPrep(allAuctions);
					dbPrepService.setHighBidDao(highBidDao);
					dbPrepService.setAuctionDao(auctionDao);
					dbPrepService.setPrepStartIndex(startIndex);
					dbPrepService.setPrepEndIndex(endIndex);
					dbPrepService.setResetAuctions(false);
					dbPrepService.setPretouch(true);
					Thread dbPrepThread = new Thread(dbPrepService, "dbPrepService" + j);
					dbPrepThread.setUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
						public void uncaughtException(Thread th, Throwable ex) {
							logger.warn("Uncaught exception in dbPrepService: " + ex);
							System.exit(1);
						}
					});
					threadList.add(dbPrepThread);
					dbPrepThread.start();

					startIndex += numAuctionsToTouch;
					numRemainingAuctions -= numAuctionsToTouch;
				}

				// Wait for all threads to complete
				for (Thread thread : threadList) {
					thread.join();
				}
				threadList.clear();

				/*
				 * Pretouch the bid and attendanceRecord data
				 */
				logger.info("Pretouching bids");
				Iterable<Bid> bids = bidRepository.findAll();
				logger.info("Pretouching attendanceRecords");
				Iterable<AttendanceRecord> attendance = attendanceRecordRepository.findAll();
			}
		}
		
		/*
		 * Clear the masterNodeNum in the AuctionMgmt table so that a node
		 * can become master at the start of the next run.
		 */
		auctionMgmtDao.deleteEntry(0L);
		auctionMgmtDao.resetMasterNodeId(0L);
		imageStore.stopServiceThreads();

		fixedTimeOffsetDao.deleteAll();

		System.exit(0);
	}
}
