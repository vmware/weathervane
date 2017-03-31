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

import java.awt.Graphics;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.GregorianCalendar;
import java.util.List;

import org.json.JSONArray;
import org.json.JSONException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;


public class DbLoaderThread implements Runnable {

	private static final Logger logger = LoggerFactory.getLogger(DbLoaderThread.class);

	private DbLoaderDao dbLoaderDao;
				
	private JSONArray itemDescr;
		
	private DbLoadSpec dbLoadSpec;
	
	private List<List<ImagesHolder>> allItemImages;
	
	private static int currentChunkSize = 1;
	private static int historyChunkSize = 1;
	
	public DbLoaderThread() {
	}
		
	public void loadUsers(DbLoadSpec dbLoadSpec) {
		dbLoaderDao.loadUsers(dbLoadSpec);
	}

	public void loadAuctions(DbLoadSpec dbLoadSpec) throws JSONException, IOException {
		long totalAuctions = dbLoadSpec.getNumAuctions();
		String threadName = Thread.currentThread().getName();
		logger.info("Loading auctions for thread " + threadName + ". totalAuctions = " + totalAuctions );

		while (totalAuctions > 0) {
			long numAuctionsToCreate = currentChunkSize;
			if (numAuctionsToCreate > totalAuctions) {
				numAuctionsToCreate = totalAuctions;
			}
			dbLoaderDao.loadAuctionsChunk(numAuctionsToCreate, dbLoadSpec, itemDescr, allItemImages);
			
			totalAuctions -= numAuctionsToCreate;	
		}

	}
	
	private void loadHistory(DbLoadSpec dbLoadSpec) throws JSONException, IOException {
		String threadName = Thread.currentThread().getName();
		logger.info("Loading history for thread " + threadName + ". AuctionsPerDay = " + dbLoadSpec.getHistoryAuctionsPerDay());

		GregorianCalendar auctionTime = FixedOffsetCalendarFactory.getCalendar();
		// Set the time to be the start of the history
		auctionTime.add(Calendar.HOUR, 0 - (dbLoadSpec.getHistoryDays() * 24));
		
		long totalAuctions = (long) Math.ceil(dbLoadSpec.getHistoryAuctionsPerDay() * dbLoadSpec.getHistoryDays());
		long historySpanMillis = dbLoadSpec.getHistoryDays() * 24L * 60 * 60 * 1000; 
		int interAuctionTimeMillis = (int) (historySpanMillis / totalAuctions);  
		logger.info("Loading history for thread " + threadName + ". totalAuctions = " + totalAuctions + ", historySpanMillis = " + historySpanMillis + ", interactionTimeMillis = " + interAuctionTimeMillis);

		while (totalAuctions > 0) {
			long numAuctionsToCreate = historyChunkSize;
			if (numAuctionsToCreate > totalAuctions) {
				numAuctionsToCreate = totalAuctions;
			}
			dbLoaderDao.loadHistoryChunk(dbLoadSpec, itemDescr, numAuctionsToCreate, auctionTime, interAuctionTimeMillis, allItemImages);
			
			totalAuctions -= numAuctionsToCreate;	
		}

	}

	private void loadFuture(DbLoadSpec dbLoadSpec) throws JSONException, IOException {
		String threadName = Thread.currentThread().getName();

		GregorianCalendar auctionTime = FixedOffsetCalendarFactory.getCalendar();
		
		// future auctions start next day
		auctionTime.add(Calendar.HOUR, 24);
			
		long totalAuctions = (long) Math.ceil(dbLoadSpec.getFutureAuctionsPerDay() * dbLoadSpec.getFutureDays());
		long futureSpanMillis = dbLoadSpec.getFutureDays() * 24L * 60 * 60 * 1000; 
		int interAuctionTimeMillis = (int) (futureSpanMillis / totalAuctions);  
		if (interAuctionTimeMillis < 0) {
			interAuctionTimeMillis = 86400000; // One day
		}

		logger.info("Loading future auctions for thread " + threadName
				+ " totalAuctions = " + totalAuctions
				+ ", futureSpanMillis = " + futureSpanMillis
				+ ", interAuctionTimeMillis = " + interAuctionTimeMillis);

		while (totalAuctions > 0) {
			long numAuctionsToCreate = historyChunkSize;
			if (numAuctionsToCreate > totalAuctions) {
				numAuctionsToCreate = totalAuctions;
			}
			dbLoaderDao.loadFutureChunk(dbLoadSpec, itemDescr, numAuctionsToCreate, auctionTime, interAuctionTimeMillis, allItemImages);
			
			totalAuctions -= numAuctionsToCreate;	
		}
	}

	public List<List<ImagesHolder>> getAllItemImages() {
		return allItemImages;
	}


	public void setAllItemImages(List<List<ImagesHolder>> allItemImages) {
		/*
		 * Clone all of the images so that each thread has its own set
		 * to work with.  This is done because when the images are later 
		 * randomized, the randomization is done in the original 
		 * images.  We want to avoid having multiple threads modifying the 
		 * same image.  This is an optimization to avoid making a copy for each
		 * image written or require locking on the images.   
		 */
		this.allItemImages = new ArrayList<List<ImagesHolder>>();
		for (List<ImagesHolder> itemImageList : allItemImages) {
			List<ImagesHolder> itemImages = new ArrayList<ImagesHolder>();
			this.allItemImages.add(itemImages);
			
			for (ImagesHolder imagesHolder : itemImageList) {
				ImagesHolder itemImage = new ImagesHolder();
				
				BufferedImage originalImage = imagesHolder.getFullSize();
				BufferedImage copyImage = new BufferedImage(originalImage.getWidth(), originalImage.getHeight(), 
												originalImage.getType());
				Graphics graphics = copyImage.getGraphics();
				graphics.drawImage(originalImage, 0, 0, null);
				graphics.dispose();
				itemImage.setFullSize(copyImage);
				
				originalImage = imagesHolder.getPreviewSize();
				copyImage = new BufferedImage(originalImage.getWidth(), originalImage.getHeight(), 
												originalImage.getType());
				graphics = copyImage.getGraphics();
				graphics.drawImage(originalImage, 0, 0, null);
				graphics.dispose();
				itemImage.setPreviewSize(copyImage);
				
				originalImage = imagesHolder.getThumbnailSize();
				copyImage = new BufferedImage(originalImage.getWidth(), originalImage.getHeight(), 
												originalImage.getType());
				graphics = copyImage.getGraphics();
				graphics.drawImage(originalImage, 0, 0, null);
				graphics.dispose();
				itemImage.setThumbnailSize(copyImage);
								
				itemImages.add(itemImage);
			}
		}
				
	}


	public void run() {
		if (dbLoadSpec.getNumUsersToCreate() > 0) {
			loadUsers(dbLoadSpec);
		}
		try {
			if (dbLoadSpec.getNumAuctions() > 0) {
				loadAuctions(dbLoadSpec);
			}
		} catch (JSONException e) {
			System.err.println("Caught JSONException from loadAuctions: " + e.getMessage());
			return;
		} catch (IOException e) {
			System.err.println("Caught IOException from loadAuctions: " + e.getMessage());
			return;
		}
		
		try {
			if (dbLoadSpec.getHistoryAuctionsPerDay() > 0) {
				loadHistory(dbLoadSpec);
			}
		} catch (JSONException e) {
			System.err.println("Caught JSONException from loadHistory: " + e.getMessage());
			return;
		} catch (IOException e) {
			System.err.println("Caught IOException from loadHistory: " + e.getMessage());
			return;
		}
		try {
			if (dbLoadSpec.getFutureAuctionsPerDay() > 0) {
				loadFuture(dbLoadSpec);
			}
		} catch (JSONException e) {
			System.err.println("Caught JSONException from loadFuture: " + e.getMessage());
			return;
		} catch (IOException e) {
			System.err.println("Caught IOException from loadFuture: " + e.getMessage());
			return;
		}
	}

	public void setDbLoadSpec(DbLoadSpec dbLoadSpec) {
		this.dbLoadSpec = dbLoadSpec;
	}
	
	public JSONArray getItemDescription() {
		return itemDescr;
	}

	public void setItemDescription(JSONArray itemDescr) {
		this.itemDescr = itemDescr;
	}

	public DbLoaderDao getDbLoaderDao() {
		return dbLoaderDao;
	}


	public void setDbLoaderDao(DbLoaderDao dbLoaderDao) {
		this.dbLoaderDao = dbLoaderDao;
	}

}
