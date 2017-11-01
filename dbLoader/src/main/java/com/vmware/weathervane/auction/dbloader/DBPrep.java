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
import com.vmware.weathervane.auction.data.dao.BidCompletionDelayDao;
import com.vmware.weathervane.auction.data.dao.DbBenchmarkInfoDao;
import com.vmware.weathervane.auction.data.dao.FixedTimeOffsetDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.NoBenchmarkInfoException;
import com.vmware.weathervane.auction.data.imageStore.NoBenchmarkInfoNeededException;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.DbBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.ImageStoreBenchmarkInfo;
import com.vmware.weathervane.auction.data.model.NosqlBenchmarkInfo;
import com.vmware.weathervane.auction.data.repository.NosqlBenchmarkInfoRepository;

/**
 * Hello world!
 *
 */
public class DBPrep {

	private static String numThreadsDefault = "30";
	private static String maxUsersDefault = "120";
	private static String maxDurationDefault = "0";
	private static String numNosqlShardsDefault = "0";
	private static String numNosqlReplicasDefault = "0";
	private static List<Thread> threadList = new ArrayList<Thread>();

	private static ImageStoreFacade imageStore;

	private static AuctionDao auctionDao;
	private static ItemDao itemDao;
	private static HighBidDao highBidDao;
	private static AuctionMgmtDao auctionMgmtDao;
	private static BidCompletionDelayDao bidCompletionDelayDao;
	private static FixedTimeOffsetDao fixedTimeOffsetDao;

	private static final Logger logger = LoggerFactory.getLogger(DBPrep.class);

	public static void usage() {

		System.out.println("Usage information for the Auction DBPrep:");

	}

	public static void main(String[] args) throws InterruptedException, IOException, JSONException {

		Option u = new Option("u", "users", true,
				"Number of active users to be supported in this run.");
		Option m = new Option("m", "shards", true,
				"Number of NoSQL shards in the configuration. This is used only for storing in the benchmarkInfo");
		Option p = new Option("p", "replicas", true,
				"Number of NoSQL replicas in the configuration. This is used only for storing in the benchmarkInfo");
		Option c = new Option("c", "check", false,
				"Only check whether the database is loaded with the proper number of users and then exit.");
		Option a = new Option("a", "auctions", true,
				"Number of auctions to be active in current run.");
		a.setRequired(true);
		Option t = new Option("t", "threads", true, "Number of threads for dbprep");
		Option f = new Option("f", "maxduration", true,
				"Max duration in seconds to be supported by the data.");

		Options cliOptions = new Options();
		cliOptions.addOption(u);
		cliOptions.addOption(m);
		cliOptions.addOption(p);
		cliOptions.addOption(a);
		cliOptions.addOption(c);
		cliOptions.addOption(t);
		cliOptions.addOption(f);

		CommandLine cliCmd = null;
		CommandLineParser cliParser = new PosixParser();
		try {
			cliCmd = cliParser.parse(cliOptions, args);
		} catch (ParseException ex) {
			imageStore.stopServiceThreads();
			System.err.println("DBPrep.  Caught ParseException " + ex.getMessage());
			return;
		}

		String auctionsString = cliCmd.getOptionValue('a');
		String numThreadsString = cliCmd.getOptionValue('t', numThreadsDefault);

		String usersString = cliCmd.getOptionValue('u', maxUsersDefault);
		int users = Integer.valueOf(usersString);

		String maxDurationString = cliCmd.getOptionValue('f', maxDurationDefault);
		long maxDuration = Long.valueOf(maxDurationString);

		String numNosqlShardsString = cliCmd.getOptionValue('m', numNosqlShardsDefault);
		int numNosqlShards = Integer.valueOf(numNosqlShardsString);

		String numNosqlReplicasString = cliCmd.getOptionValue('p', numNosqlReplicasDefault);
		int numNosqlReplicas = Integer.valueOf(numNosqlReplicasString);

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
		if (springProfilesActive.contains("Filesystem")) {
			imageStoreType = "filesystem";
		} else if (springProfilesActive.contains("Mongo")) {
			imageStoreType = "mongodb";
		} else {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"The spring.profiles.active property be either imagesInMongo or imagesInFilesystem for DBPrep.");
		}

		ApplicationContext context = new ClassPathXmlApplicationContext(new String[] {
				"dbprep-context.xml", "datasource-context.xml", "jpa-context.xml",
				"mongo-context.xml" });
		imageStore = (ImageStoreFacade) context.getBean("imageStoreFacade");
		NosqlBenchmarkInfoRepository nosqlBenchmarkInfoRepository = (NosqlBenchmarkInfoRepository) context
				.getBean("nosqlBenchmarkInfoRepository");
		DbBenchmarkInfoDao dbBenchmarkInfoDao = (DbBenchmarkInfoDao) context
				.getBean("dbBenchmarkInfoDao");
		auctionDao = (AuctionDao) context.getBean("auctionDao");
		itemDao = (ItemDao) context.getBean("itemDao");
		highBidDao = (HighBidDao) context.getBean("highBidDao");
		auctionMgmtDao = (AuctionMgmtDao) context.getBean("auctionMgmtDao");
		bidCompletionDelayDao = (BidCompletionDelayDao) context.getBean("bidCompletionDelayDao");
		fixedTimeOffsetDao = (FixedTimeOffsetDao) context.getBean("fixedTimeOffsetDao");

		/*
		 * Make sure that database is loaded at correctly
		 */
		logger.debug("Checking whether database has benchmark info");
		List<DbBenchmarkInfo> dbBenchmarkInfoList = dbBenchmarkInfoDao.getAll();
		if ((dbBenchmarkInfoList == null) || (dbBenchmarkInfoList.size() < 1)) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"Cannot find benchmarkInfo in database.  Make sure that data is preloaded.");
		}

		DbBenchmarkInfo dbBenchmarkInfo = dbBenchmarkInfoList.get(0);
		logger.info("Got DB benchmarkInfo: " + dbBenchmarkInfo);
		try {
			long infoMaxUsers = dbBenchmarkInfo.getMaxusers();
			if (infoMaxUsers < users) {
				throw new RuntimeException(
						"MaxUsers supported by database does not match desired number of users   Users =  "
								+ users + ", Found " + infoMaxUsers
								+ ". Make sure that correct data is loaded.");
			}
			if ((maxDuration > 0) && (dbBenchmarkInfo.getMaxduration() < maxDuration)) {
				throw new RuntimeException(
						"MaxDuration supported by database is not long enough for desired duration. Need maxDuration =  "
								+ maxDuration + ", Found " + dbBenchmarkInfo.getMaxduration()
								+ ". Make sure that correct data is loaded.");
			}
			if (!dbBenchmarkInfo.getImagestoretype().equals(imageStoreType)) {
				throw new RuntimeException(
						"ImageStoreType in database does not match desired type. Needed "
								+ imageStoreType + ", Found " + dbBenchmarkInfo.getImagestoretype()
								+ ", Make sure that correct data is loaded.");
			}
			if (!dbBenchmarkInfo.getNumnosqlshards().equals(Long.valueOf(numNosqlShards))) {
				throw new RuntimeException(
						"Number of shards in NoSQL datastore does not match current configuration in database.  Needed "
								+ numNosqlShards + ", Found " + dbBenchmarkInfo.getNumnosqlshards()
								+ ". Make sure that correct data is loaded.");
			}
			if (!dbBenchmarkInfo.getNumnosqlreplicas().equals(Long.valueOf(numNosqlReplicas))) {
				throw new RuntimeException(
						"Number of replicas in NoSQL datastore does not match current configuration in database.  Needed "
								+ numNosqlReplicas + ", Found "
								+ dbBenchmarkInfo.getNumnosqlreplicas()
								+ ". Make sure that correct data is loaded.");
			}
		} finally {
			imageStore.stopServiceThreads();
		}

		/*
		 * Make sure that NoSQL store is loaded at correctly
		 */
		logger.debug("Checking whether NoSQL Data-Store has benchmark info");
		List<NosqlBenchmarkInfo> nosqlBenchmarkInfoList = nosqlBenchmarkInfoRepository.findAll();
		if ((nosqlBenchmarkInfoList == null) || (nosqlBenchmarkInfoList.size() < 1)) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"Cannot find benchmarkInfo in NoSQL store.  Make sure that data is preloaded.");
		}

		NosqlBenchmarkInfo nosqlBenchmarkInfo = nosqlBenchmarkInfoList.get(0);
		logger.info("Got NoSQL benchmarkInfo: " + nosqlBenchmarkInfo );
		long infoMaxUsers = nosqlBenchmarkInfo.getMaxusers();
		if (infoMaxUsers < users) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"MaxUsers supported by NoSQL datastore does not match desired number of users   Users =  "
							+ users + ", Found " + infoMaxUsers
							+ ". Make sure that correct data is loaded.");
		}
		
		if (!nosqlBenchmarkInfo.getNumShards().equals(numNosqlShards)) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"Number of shards in NoSQL datastore does not match current configuration.  Needed "
							+ numNosqlShards + ", Found " + nosqlBenchmarkInfo.getNumShards()
							+ ". Make sure that correct data is loaded.");
		}

		if (!nosqlBenchmarkInfo.getNumReplicas().equals(numNosqlReplicas)) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"Number of replicas in NoSQL datastore does not match current configuration.  Needed "
							+ numNosqlReplicas + ", Found " + nosqlBenchmarkInfo.getNumReplicas()
							+ ". Make sure that correct data is loaded.");
		}

		if (!nosqlBenchmarkInfo.getImageStoreType().equals(imageStoreType)) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"ImageStoreType in database does not match desired type. Needed "
							+ imageStoreType + ", Found " + nosqlBenchmarkInfo.getImageStoreType()
							+ ", Make sure that correct data is loaded.");
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
				throw new RuntimeException(
						"MaxUsers supported by imageStore does not match desired number of users   Users =  "
								+ users + ", Found " + infoMaxUsers
								+ ". Make sure that correct data is loaded.");
			}
			if (!imageStoreBenchmarkInfo.getImageStoreType().equals(imageStoreType)) {
				imageStore.stopServiceThreads();
				throw new RuntimeException(
						"ImageStoreType in imageStore does not match desired type. Needed "
								+ imageStoreType + ", Found "
								+ imageStoreBenchmarkInfo.getImageStoreType()
								+ ", Make sure that correct data is loaded.");
			}

		} catch (NoBenchmarkInfoException e) {
			imageStore.stopServiceThreads();
			throw new RuntimeException(
					"No benchmark info stored in imageStore.  Make sure that correct data is loaded.");
		} catch (NoBenchmarkInfoNeededException e) {
			// Some imageStore types always have the proper load
			logger.info("Got a NoBenchmarkInfoNeededException exception from the imageStore.  Continuing");
		}

		// If only wanted to check for loaded data, then return here
		if (cliCmd.hasOption("c")) {
			logger.info("Benchmark is loaded correctly. Exiting cleanly.");
			imageStore.stopServiceThreads();
			return;
		}

		/*
		 * Clear out the images that were added on the last run.
		 */
		logger.debug("Clearing non-preloaded images");
		imageStore.clearNonpreloadedImages();

		/*
		 * Clear out the bidCompletionDelay table
		 */
		logger.info("Clear out the bidCompletionDelay table\n");
		bidCompletionDelayDao.deleteAll();

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
			Thread dbPrepThread = new Thread(dbPrepService, "dbPrepService" + j);
			threadList.add(dbPrepThread);
			dbPrepThread.start();
			startIndex += numAuctionsToReset;
			numRemainingAuctions -= numAuctionsToReset;
		}

		// Wait for all threads to complete
		for (Thread thread : threadList) {
			thread.join();
		}

		// Need to run this after all auctions have been reset
		logger.info("Deleting preloaded highBids\n");
		highBidDao.deleteByPreloaded(false);

		/*
		 * Set the correct number of auctions to start during this run
		 */
		logger.info("Finding auctions with current flag set\n");
		List<Auction> auctionsToActivate = auctionDao.findByCurrent(true, numAuctions);

		auctionsPerThread = (int) Math.ceil(auctionsToActivate.size() / (1.0 * numThreads));
		logger.info("Found " + auctionsToActivate.size()
				+ " auctions to activate in this run. auctionsPerThread = " + auctionsPerThread
				+ "\n");
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
			Thread dbPrepThread = new Thread(dbPrepService, "dbPrepService" + j);
			threadList.add(dbPrepThread);
			dbPrepThread.start();

			startIndex += numAuctionsToReset;
			numRemainingAuctions -= numAuctionsToReset;
		}

		// Wait for all threads to complete
		for (Thread thread : threadList) {
			thread.join();
		}

		/*
		 * Delete items that were added during the last run
		 */
		logger.info("Deleting non-preloaded items\n");
		int numDeleted = itemDao.deleteByPreloaded(false);
		logger.info("Deleted " + numDeleted + " non-preloaded items\n");

		/*
		 * Clear the masterNodeNum in the AuctionMgmt table so that a node
		 * can become master at the start of the next run.
		 */
		auctionMgmtDao.deleteEntry(0L);
		auctionMgmtDao.resetMasterNodeId(0L);
		imageStore.stopServiceThreads();

		fixedTimeOffsetDao.deleteAll();

	}
}
