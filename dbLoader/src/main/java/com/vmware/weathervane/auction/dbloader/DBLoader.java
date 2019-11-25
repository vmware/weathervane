/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.dbloader;

import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import java.util.concurrent.TimeUnit;

import javax.imageio.ImageIO;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.io.FileUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.data.dao.AuctionMgmtDao;
import com.vmware.weathervane.auction.data.dao.FixedTimeOffsetDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;
import com.vmware.weathervane.auction.data.model.AuctionMgmt;

public class DBLoader {

	private static String numThreadsDefault = "30";
	private static String itemFileDefault = "items.json";
	private static String creditLimitDefault = "1000000";
	private static String maxUsersDefault = "120";
	private static String imageDirDefault = "images";
	private static List<Thread> threadList = new ArrayList<Thread>();

	private static DbLoaderDao dbLoaderDao;
	private static AuctionMgmtDao auctionMgmtDao;

	private static FixedTimeOffsetDao fixedTimeOffsetDao;

	private static ImageStoreFacade imageStore;

	private static List<List<ImagesHolder>> allItemImages = new ArrayList<List<ImagesHolder>>();

	private static final Logger logger = LoggerFactory.getLogger(DBLoader.class);

	public static void usage() {

		System.out.println("Usage information for the Auction DBLoader:");

	}

	public static void main(String[] args) throws InterruptedException, IOException, JSONException {

		Option c = new Option("c", "credit", true, "Credit limit to assign to users");
		Option t = new Option("t", "threads", true, "Number of threads for dbLoader");
		Option d = new Option("d", "descriptions", true, "File containing the item descriptions.");
		Option u = new Option("u", "users", true,
				"Max number of active users to be supported by the this data load.");
		Option n = new Option("n", "nocontext", false,
				"If specified, no users and historical or future auctions are loaded.");
		Option r = new Option("r", "imagedir", true,
				"The directory containing the images to be loaded into the image store");
		Option g = new Option("g", "noimages", false,
				"If specified, no images are added to the imageStore when items are created");
		Option b = new Option("b", "noDBimages", false,
				"If specified, no ItemImage entities are added to the database when items are created");
		Option e = new Option("e", "resetimages", false,
				"If specified, reset (empty) the imageStore before loading images");
		Option a = new Option("a", "message", true, "String to be included in messages from the dbLoader");

		Options cliOptions = new Options();
		cliOptions.addOption(c);
		cliOptions.addOption(t);
		cliOptions.addOption(d);
		cliOptions.addOption(u);
		cliOptions.addOption(n);
		cliOptions.addOption(r);
		cliOptions.addOption(g);
		cliOptions.addOption(e);
		cliOptions.addOption(b);
		cliOptions.addOption(a);

		CommandLine cliCmd = null;
		CommandLineParser cliParser = new PosixParser();
		try {
			cliCmd = cliParser.parse(cliOptions, args);
		} catch (ParseException ex) {
			System.err.println("DBLoader.  Caught ParseException " + ex.getMessage());
			return;
		}

		String creditLimitString = cliCmd.getOptionValue('c', creditLimitDefault);
		String numThreadsString = cliCmd.getOptionValue('t', numThreadsDefault);

		String itemFileName = cliCmd.getOptionValue('d', itemFileDefault);

		String maxUsersString = cliCmd.getOptionValue('u', maxUsersDefault);
		int maxUsers = Integer.valueOf(maxUsersString);

		String imageDirString = cliCmd.getOptionValue('r', imageDirDefault);
		String messageString = cliCmd.getOptionValue('a', "");
		Long creditLimit = Long.valueOf(creditLimitString);
		long numThreads = Long.valueOf(numThreadsString);

		/*
		 * Set the flag that controls loading of images into the image store
		 */
		boolean loadImages = false;
		if (!cliCmd.hasOption("g")) {
			loadImages = true;
		}
		/*
		 * Set the flag that controls loading of ItemImage entities into the
		 * database
		 */
		boolean loadItemImages = false;
		if (!cliCmd.hasOption("b")) {
			loadItemImages = true;
		}

		// Determine the imageStore type from the spring.profiles.active
		// property
		String springProfilesActive = System.getProperty("spring.profiles.active");
		if (springProfilesActive == null) {
			throw new RuntimeException(
					"The spring.profiles.active property must be set for the dbLoader. " + messageString);
		}
		String imageStoreType;
		if (springProfilesActive.contains("Memory")) {
			imageStoreType = "memory";
		} else if (springProfilesActive.contains("Cassandra")) {
			imageStoreType = "cassandra";
		} else {
			throw new RuntimeException(
					"The spring.profiles.active property be either imagesInCassandra or imagesInMemory for the DBLoader. " + messageString);
		}

		ApplicationContext context = new ClassPathXmlApplicationContext(new String[] {
				"application-context.xml", "datasource-context.xml", "jpa-context.xml", "cassandra-context.xml" });
		dbLoaderDao = (DbLoaderDao) context.getBean("dbLoaderDao");
    	auctionMgmtDao = (AuctionMgmtDao) context.getBean("auctionMgmtDao");
		imageStore = (ImageStoreFacade) context.getBean("imageStoreFacade");
		fixedTimeOffsetDao = (FixedTimeOffsetDao) context.getBean("fixedTimeOffsetDao");

		DbLoadParams theLoadParams = null;
		theLoadParams = (DbLoadParams) context.getBean("perUserScale");
		theLoadParams.setTotalUsers(maxUsers * theLoadParams.getUsersScaleFactor());
		
		/*
		 * Compute the basic parameters for the LoadSpec sent to the
		 * DBLoaderService
		 */
		DbLoadSpec theLoadSpec = new DbLoadSpec();
		theLoadSpec.setHistoryDays(theLoadParams.getHistoryDays());
		theLoadSpec.setFutureDays(theLoadParams.getFutureDays());
		theLoadSpec.setTotalUsers(theLoadParams.getTotalUsers());

		/*
		 * Parameters related to past and future auctions
		 */
		int totalPurchases = theLoadParams.getTotalUsers() * theLoadParams.getPurchasesPerUser();
		int totalBids = theLoadParams.getTotalUsers() * theLoadParams.getBidsPerUser();
		int totalAttendances = theLoadParams.getTotalUsers()
				* theLoadParams.getAttendancesPerUser();
		double totalAuctions = totalAttendances / theLoadParams.getAttendeesPerAuction();
		double auctionsPerDay = totalAuctions / theLoadParams.getHistoryDays();
		double itemsPerAuction = totalPurchases / totalAuctions;
		double bidsPerItem = totalBids / totalPurchases;

		theLoadSpec.setHistoryAuctionsPerDay(auctionsPerDay);
		theLoadSpec.setHistoryAttendeesPerAuction(theLoadParams.getAttendeesPerAuction());
		theLoadSpec.setHistoryBidsPerItem((int) Math.round(bidsPerItem));
		theLoadSpec.setHistoryItemsPerAuction((int) Math.round(itemsPerAuction));
		theLoadSpec.setFutureAuctionsPerDay(auctionsPerDay);
		theLoadSpec.setFutureItemsPerAuction((int) Math.round(itemsPerAuction));
		theLoadSpec.setMaxImagesPerCurrentItem(theLoadParams.getMaxImagesPerCurrentItem());
		theLoadSpec.setMaxImagesPerFutureItem(theLoadParams.getMaxImagesPerFutureItem());
		theLoadSpec.setMaxImagesPerHistoryItem(theLoadParams.getMaxImagesPerHistoryItem());
		theLoadSpec.setNumImageSizesPerCurrentItem(theLoadParams.getNumImageSizesPerCurrentItem());
		theLoadSpec.setNumImageSizesPerFutureItem(theLoadParams.getNumImageSizesPerFutureItem());
		theLoadSpec.setNumImageSizesPerHistoryItem(theLoadParams.getNumImageSizesPerHistoryItem());

		/*
		 * Parameters related to the max number of possible current auctions at
		 * this number of users.
		 */
		long maxActiveUsers = (long) Math.ceil(theLoadSpec.getTotalUsers()
				/ (1.0 * theLoadParams.getUsersScaleFactor()));
		logger.info("maxActiveUsers = {}", maxActiveUsers);
		long numAuctions = (long) Math.ceil(maxActiveUsers
				/ (1.0 * theLoadParams.getUsersPerCurrentAuction()));
		// The number of active auctions needs to be a multiple of 2
		if ((numAuctions % 2) != 0) {
			numAuctions++;
		}
		logger.info("numAuctions = {}", numAuctions);
		
		/*
		 * Read in the items file and convert it into a JSON array
		 */
		BufferedReader itemFileReader = null;
		JSONArray itemDescriptions = null;
		try {
			itemFileReader = new BufferedReader(new FileReader(itemFileName));
			String line = null;
			StringBuilder stringBuilder = new StringBuilder();
			String ls = System.getProperty("line.separator");

			while ((line = itemFileReader.readLine()) != null) {
				stringBuilder.append(line);
				stringBuilder.append(ls);
			}
			itemDescriptions = new JSONArray(stringBuilder.toString());

		} catch (IOException ex) {
			System.err.println("Couldn't open item description file: " + ex.getMessage() + ". " + messageString);
			System.exit(1);
		} catch (JSONException ex) {
			System.err.println("Couldn't create JSONArray from item description file: "
					+ ex.getMessage() + ". " + messageString);
			System.exit(1);
		} finally {
			if (itemFileReader != null)
				try {
					itemFileReader.close();
				} catch (IOException ex) {
					System.err.println("Couldn't close item description file: " + ex.getMessage() + ". " + messageString);
					System.exit(1);
				}
		}

		/*
		 * Decide whether to reset the image store
		 */
		if (!cliCmd.hasOption("g") && cliCmd.hasOption("e")) {
			imageStore.resetImageStore();
		}

		/*
		 * Read in all of the images and create all of the different sizes
		 */
		for (int j = 0; j < itemDescriptions.length(); j++) {

			// get the decription for item j
			JSONObject itemDesc = itemDescriptions.getJSONObject(j);

			// Get the names of the images for item j
			JSONArray imageNameArray = itemDesc.getJSONArray("images");
			String imageSuffix = itemDesc.getString("imageType");

			// Create a list if ImagesHolders for this item
			List<ImagesHolder> itemImages = new ArrayList<ImagesHolder>();
			allItemImages.add(itemImages);

			// Read in each image and store as byte arrays in each size
			for (int k = 0; k < imageNameArray.length(); k++) {
				ImagesHolder itemImage = new ImagesHolder();

				String filename = imageNameArray.getString(k) + "." + imageSuffix;

				File imageFile = new File(imageDirString, filename);

				byte[] imageBytes = FileUtils.readFileToByteArray(imageFile);
				BufferedImage image = ImageIO.read(new ByteArrayInputStream(imageBytes));
				itemImage.setFullSize(image);

				// Now resize to thumbnail and preview size

				// Create the preview size image
				BufferedImage previewImage = imageStore.scaleImageToSize(image, ImageSize.PREVIEW);
				itemImage.setPreviewSize(previewImage);

				// Create the thumbnail size image
				BufferedImage thumbnailImage = imageStore.scaleImageToSize(image,
						ImageSize.THUMBNAIL);
				itemImage.setThumbnailSize(thumbnailImage);

				itemImages.add(itemImage);
			}
		}

		/*
		 * In order to track the progress of the dbLoading, we calculate a value
		 * that is related to the total amount of work to be done. The amount of
		 * work left can then be updated throughout the run by the loader
		 * threads. We are using the number of items to be loaded as an
		 * indication of the total amount of work to be done as the work is
		 * mostly proportional to the number of items. Since history, future,
		 * and current items may have different numbers and sizes of images, we
		 * weight the item value by those factors. The total work is stored in
		 * the dbLoaderDao to be updated as work completes.
		 */

		/*
		 * Check to see whether there is a file with the calculated
		 * relative-work from a previous run with this imageStore type. If so,
		 * use it. Otherwise use values that were determine to be correct on a
		 * particular testbed.
		 */
		String fileName = ".dbLoaderRelativeWork." + imageStoreType + ".json";
		File outFile = new File(imageDirString, fileName);

		ObjectMapper objectMapper = new ObjectMapper();
		DbLoaderWorkEstimate dbLoaderWorkEstimate = null;
		try {
			dbLoaderWorkEstimate = objectMapper.readValue(outFile, DbLoaderWorkEstimate.class);
		} catch (Throwable ex) {
			/*
			 * If for some reason reading a relative-work record file doesn't
			 * work (it may not exist), then we will just use some default
			 * values.
			 */
		}

		if (dbLoaderWorkEstimate == null) {
			dbLoaderWorkEstimate = new DbLoaderWorkEstimate();
			if (imageStoreType.equals("cassandra")) {
				dbLoaderWorkEstimate.setUserWork(0.00005);
				dbLoaderWorkEstimate.setHistoryWork(0.0032);
				dbLoaderWorkEstimate.setFutureWork(0.001);
				dbLoaderWorkEstimate.setCurrentWork(0.04);
			} else {
				dbLoaderWorkEstimate.setUserWork(0.00005);
				dbLoaderWorkEstimate.setHistoryWork(0.0032);
				dbLoaderWorkEstimate.setFutureWork(0.001);
				dbLoaderWorkEstimate.setCurrentWork(0.04);
			}
		}

		// workPerxxxYyy determined by experimentation
		logger.info("numusers = " + theLoadSpec.getTotalUsers() + ", workPerUser = "
				+ dbLoaderWorkEstimate.getUserWork());

		long numHistoryItems = (long) Math.ceil(theLoadSpec.getHistoryDays()
				* (theLoadSpec.getHistoryAuctionsPerDay() / numThreads))
				* numThreads * theLoadSpec.getHistoryItemsPerAuction();
		logger.info("numHistoryItems = " + numHistoryItems + ", workPerHistoryItem = "
				+ dbLoaderWorkEstimate.getHistoryWork());

		long numFutureItems = (long) Math.ceil(theLoadSpec.getFutureDays()
				* (theLoadSpec.getFutureAuctionsPerDay() / numThreads))
				* numThreads * theLoadSpec.getFutureItemsPerAuction();
		logger.info("numFutureItems = " + numFutureItems + ", workPerFutureItem = "
				+ dbLoaderWorkEstimate.getFutureWork());

		// 15 is the average number of items per current auction
		long numCurrentItems = numAuctions * 15;
		logger.info("numCurrentItems = " + numCurrentItems + ", workPerCurrentItem = "
				+ dbLoaderWorkEstimate.getCurrentWork());

		DbLoaderDao.setTotalWork(dbLoaderWorkEstimate, theLoadSpec.getTotalUsers(),
				numHistoryItems, numFutureItems, numCurrentItems, messageString);

		long startTime = System.currentTimeMillis();

		/*
		 * First create all of the users. We need the user info to populate the
		 * the auctioneer, etc. fields of auctions and items
		 */
		logger.info("Loading " + theLoadSpec.getTotalUsers() + " users");
		long usersPerThread = (long) Math.ceil(theLoadSpec.getTotalUsers() / (1.0 * numThreads));
		long numRemainingUsers = theLoadSpec.getTotalUsers();
		for (int j = 0; j < numThreads; j++) {
			long usersToLoad = usersPerThread;
			if (usersToLoad > numRemainingUsers) {
				usersToLoad = numRemainingUsers;
			}
			logger.debug("Thread " + Thread.currentThread().getName() + " is loading "
					+ usersToLoad + " users");

			DbLoaderThread dbLoaderService = new DbLoaderThread();
			DbLoadSpec loadSpec = new DbLoadSpec(theLoadSpec);

			loadSpec.setNumUsersToCreate(usersToLoad);
			loadSpec.setStartUserNumber(j * usersPerThread + 1);
			loadSpec.setAvgCreditLimit(creditLimit);
			loadSpec.setStdDevCreditLimit(0);
			loadSpec.setNumAuctions(0);
			loadSpec.setFutureAuctionsPerDay(0);
			loadSpec.setHistoryAuctionsPerDay(0);
			loadSpec.setAvgStartingBid(200);
			loadSpec.setStdDevStartingBid(200);
			loadSpec.setImageDir(imageDirString);
			loadSpec.setLoadImages(loadImages);
			loadSpec.setLoadItemImages(loadItemImages);
			loadSpec.setMessageString(messageString);
			
			dbLoaderService.setDbLoadSpec(loadSpec);
			dbLoaderService.setItemDescription(itemDescriptions);
			dbLoaderService.setAllItemImages(allItemImages);

			dbLoaderService.setDbLoaderDao(dbLoaderDao);

			Thread dbLoaderThread = new Thread(dbLoaderService, "dbLoaderService" + j);
			dbLoaderThread.start();
			threadList.add(dbLoaderThread);

			numRemainingUsers -= usersToLoad;
		}

		// Wait for all threads to complete
		for (Thread thread : threadList) {
			thread.join();
		}

		long usersDoneMillis = System.currentTimeMillis();
		long duration = usersDoneMillis - startTime;
		String durationString = String.format(
				"Loading user data took %d hours, %d min, %d sec",
				TimeUnit.MILLISECONDS.toHours(duration),
				TimeUnit.MILLISECONDS.toMinutes(duration)
						- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(duration)),
				TimeUnit.MILLISECONDS.toSeconds(duration)
						- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(duration)));
		logger.info(durationString);

		/*
		 * Update the estimate of work-per-user
		 */
		dbLoaderWorkEstimate.setUserWork((duration / 1000.0) / theLoadSpec.getTotalUsers());

		/*
		 * Now create all of the auctions and items.
		 */
		long currentStartMillis = System.currentTimeMillis();
		long auctionsPerThread = (long) Math.ceil(numAuctions / (1.0 * numThreads));
		long numRemainingAuctions = numAuctions;
		for (int j = 0; j < numThreads; j++) {
			long auctionsToLoad = auctionsPerThread;
			if (auctionsToLoad > numRemainingAuctions) {
				auctionsToLoad = numRemainingAuctions;
			}

			DbLoaderThread dbLoaderService = new DbLoaderThread();
			DbLoadSpec loadSpec = new DbLoadSpec(theLoadSpec);

			loadSpec.setAvgCreditLimit(creditLimit);
			loadSpec.setStdDevCreditLimit(0);
			loadSpec.setNumAuctions(auctionsToLoad);
			loadSpec.setAvgStartingBid(200);
			loadSpec.setStdDevStartingBid(200);
			loadSpec.setImageDir(imageDirString);
			loadSpec.setLoadImages(loadImages);
			loadSpec.setLoadItemImages(loadItemImages);

			loadSpec.setNumUsersToCreate(0);
			loadSpec.setFutureAuctionsPerDay(0);
			loadSpec.setHistoryAuctionsPerDay(0);
			loadSpec.setMessageString(messageString);

			dbLoaderService.setDbLoadSpec(loadSpec);
			dbLoaderService.setItemDescription(itemDescriptions);
			dbLoaderService.setAllItemImages(allItemImages);

			dbLoaderService.setDbLoaderDao(dbLoaderDao);

			Thread dbLoaderThread = new Thread(dbLoaderService, "dbLoaderService" + j);
			dbLoaderThread.start();
			threadList.add(dbLoaderThread);

			numRemainingAuctions -= auctionsToLoad;
		}

		// Wait for all threads to complete
		for (Thread thread : threadList) {
			thread.join();
		}
		long currentDoneMillis = System.currentTimeMillis();
		duration = currentDoneMillis - currentStartMillis;
		durationString = String.format(
				"Loading current data took %d hours, %d min, %d sec",
				TimeUnit.MILLISECONDS.toHours(duration),
				TimeUnit.MILLISECONDS.toMinutes(duration)
						- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(duration)),
				TimeUnit.MILLISECONDS.toSeconds(duration)
						- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(duration)));
		logger.info(durationString);

		/*
		 * Update the estimate of work-per-current-item
		 */
		dbLoaderWorkEstimate.setCurrentWork((duration / 1000.0) / numCurrentItems);

		if (!cliCmd.hasOption("n")) {
			/*
			 * Now create all of the historical auctions and items.
			 */
			double historyAuctionsPerDayPerThread = theLoadSpec.getHistoryAuctionsPerDay()
					/ numThreads;
			for (int j = 0; j < numThreads; j++) {

				DbLoaderThread dbLoaderService = new DbLoaderThread();
				DbLoadSpec loadSpec = new DbLoadSpec(theLoadSpec);

				loadSpec.setNumUsersToCreate(0);
				loadSpec.setNumAuctions(0);
				loadSpec.setHistoryAuctionsPerDay(historyAuctionsPerDayPerThread);
				loadSpec.setFutureAuctionsPerDay(0);
				loadSpec.setAvgStartingBid(200);
				loadSpec.setStdDevStartingBid(200);
				loadSpec.setImageDir(imageDirString);
				loadSpec.setLoadImages(loadImages);
				loadSpec.setLoadItemImages(loadItemImages);
				loadSpec.setMessageString(messageString);

				dbLoaderService.setDbLoadSpec(loadSpec);
				dbLoaderService.setItemDescription(itemDescriptions);
				dbLoaderService.setAllItemImages(allItemImages);

				dbLoaderService.setDbLoaderDao(dbLoaderDao);

				Thread dbLoaderThread = new Thread(dbLoaderService, "dbLoaderService" + j);
				dbLoaderThread.start();
				threadList.add(dbLoaderThread);
			}

			// Wait for all threads to complete
			for (Thread thread : threadList) {
				thread.join();
			}

			long historyDoneMillis = System.currentTimeMillis();
			duration = historyDoneMillis - usersDoneMillis;
			durationString = String
					.format("Loading historical data took %d hours, %d min, %d sec",
							TimeUnit.MILLISECONDS.toHours(duration),
							TimeUnit.MILLISECONDS.toMinutes(duration)
									- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS
											.toHours(duration)),
							TimeUnit.MILLISECONDS.toSeconds(duration)
									- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS
											.toMinutes(duration)));
			logger.info(durationString);

			/*
			 * Update the estimate of work-per-history-item
			 */
			dbLoaderWorkEstimate.setHistoryWork((duration / 1000.0) / numHistoryItems);

			/*
			 * Now create all of the future auctions and items.
			 */
			double futureAuctionsPerDayPerThread = theLoadSpec.getFutureAuctionsPerDay()
					/ numThreads;
			for (int j = 0; j < numThreads; j++) {

				DbLoaderThread dbLoaderService = new DbLoaderThread();
				DbLoadSpec loadSpec = new DbLoadSpec(theLoadSpec);

				loadSpec.setNumUsersToCreate(0);
				loadSpec.setNumAuctions(0);
				loadSpec.setHistoryAuctionsPerDay(0);
				loadSpec.setFutureAuctionsPerDay(futureAuctionsPerDayPerThread);
				loadSpec.setAvgStartingBid(200);
				loadSpec.setStdDevStartingBid(200);
				loadSpec.setImageDir(imageDirString);
				loadSpec.setLoadImages(loadImages);
				loadSpec.setLoadItemImages(loadItemImages);
				loadSpec.setMessageString(messageString);

				dbLoaderService.setDbLoadSpec(loadSpec);
				dbLoaderService.setItemDescription(itemDescriptions);
				dbLoaderService.setAllItemImages(allItemImages);

				dbLoaderService.setDbLoaderDao(dbLoaderDao);

				Thread dbLoaderThread = new Thread(dbLoaderService, "dbLoaderService" + j);
				dbLoaderThread.start();
				threadList.add(dbLoaderThread);
			}

			// Wait for all threads to complete
			for (Thread thread : threadList) {
				thread.join();
			}

			long futureDoneMillis = System.currentTimeMillis();
			duration = futureDoneMillis - historyDoneMillis;
			durationString = String
					.format("Loading future data took %d hours, %d min, %d sec",
							TimeUnit.MILLISECONDS.toHours(duration),
							TimeUnit.MILLISECONDS.toMinutes(duration)
									- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS
											.toHours(duration)),
							TimeUnit.MILLISECONDS.toSeconds(duration)
									- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS
											.toMinutes(duration)));
			logger.info(durationString);

			/*
			 * Update the estimate of work-per-history-item
			 */
			dbLoaderWorkEstimate.setFutureWork((duration / 1000.0) / numFutureItems);
		}

		/*
		 * Stop any service threads in the image store and then wait for them to
		 * finish
		 */
		List<Thread> imageStoreThreads = imageStore.getImageWriterThreads();
		imageStore.stopServiceThreads();
		// Wait for all threads to complete
		if (imageStoreThreads != null) {
			for (Thread thread : imageStoreThreads) {
				thread.join();
			}
		}

		currentDoneMillis = System.currentTimeMillis();
		duration = currentDoneMillis - startTime;
		durationString = String.format(
				"Loading data took %d hours, %d min, %d sec",
				TimeUnit.MILLISECONDS.toHours(duration),
				TimeUnit.MILLISECONDS.toMinutes(duration)
						- TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(duration)),
				TimeUnit.MILLISECONDS.toSeconds(duration)
						- TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(duration)));
		System.out.println(durationString + ". " + messageString);

		/* save the new work estimates in a file */
		fileName = ".dbLoaderRelativeWork." + imageStoreType + ".json";
		outFile = new File(imageDirString, fileName);

		objectMapper = new ObjectMapper();
		try {
			objectMapper.writeValue(outFile, dbLoaderWorkEstimate);
		} catch (Throwable ex) {
			System.err.println("Couldn't save updated work estimates: " + ex.getMessage()+ ". " + messageString);
		}
		logger.warn("Final user work estimate: ", dbLoaderWorkEstimate.getUserWork());
		logger.warn("Final current work estimate: ", dbLoaderWorkEstimate.getCurrentWork());
		logger.warn("Final history work estimate: ", dbLoaderWorkEstimate.getHistoryWork());
		logger.warn("Final future work estimate: ", dbLoaderWorkEstimate.getFutureWork());

		AuctionMgmt auctionMgmt = new AuctionMgmt(0L, null);
		auctionMgmtDao.save(auctionMgmt);
		
		/*
		 * Save information about this benchmark load in the data services
		 */
		dbLoaderDao.saveBenchmarkInfo(maxUsers, imageStoreType);
		
		fixedTimeOffsetDao.deleteAll();
		
		System.exit(0);

	}
}
