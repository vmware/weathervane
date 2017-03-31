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

public class DbLoadSpec {
	
	private int totalUsers;
	private int historyDays;
	private int futureDays;
	
	private long numAuctions;
	private float avgStartingBid;
	private float stdDevStartingBid;
	private float avgCreditLimit;
	private float stdDevCreditLimit;
	
	private long numUsersToCreate;
	private long startUserNumber;
	
	private double historyAuctionsPerDay;
	private int historyItemsPerAuction;
	private int historyBidsPerItem;
	private int historyAttendeesPerAuction;
	private int maxImagesPerHistoryItem;
	private int numImageSizesPerHistoryItem;

	private double futureAuctionsPerDay;
	private int futureItemsPerAuction;
	private int maxImagesPerFutureItem;
	private int numImageSizesPerFutureItem;

	private int itemsPerCurrentAuction;
	private int maxImagesPerCurrentItem;
	private int numImageSizesPerCurrentItem;
	
	private boolean loadImages;
	private boolean loadItemImages;
	private String imageDir;
	
	private String messageString;
	
	public DbLoadSpec() {
		
	}
	
	public DbLoadSpec(DbLoadSpec that) {
		this.numAuctions = that.numAuctions;
		this.avgStartingBid = that.avgStartingBid;
		this.stdDevStartingBid = that.stdDevStartingBid;
		this.avgCreditLimit = that.avgCreditLimit;
		this.stdDevCreditLimit = that.stdDevCreditLimit;
		
		this.totalUsers = that.totalUsers;
		this.numUsersToCreate = that.numUsersToCreate;
		this.startUserNumber = that.startUserNumber;
		
		this.historyDays = that.historyDays;
		this.historyAuctionsPerDay = that.historyAuctionsPerDay;
		this.historyItemsPerAuction = that.historyItemsPerAuction;
		this.historyBidsPerItem = that.historyBidsPerItem;
		this.historyAttendeesPerAuction = that.historyAttendeesPerAuction;
		this.maxImagesPerHistoryItem = that.maxImagesPerHistoryItem;
		this.numImageSizesPerHistoryItem = that.numImageSizesPerHistoryItem;
		
		this.futureDays = that.futureDays;
		this.futureAuctionsPerDay = that.futureAuctionsPerDay;
		this.futureItemsPerAuction = that.futureItemsPerAuction;
		this.maxImagesPerFutureItem = that.maxImagesPerFutureItem;
		this.numImageSizesPerFutureItem = that.numImageSizesPerFutureItem;
		
		this.itemsPerCurrentAuction = that.itemsPerCurrentAuction;
		this.maxImagesPerCurrentItem = that.maxImagesPerCurrentItem;
		this.numImageSizesPerCurrentItem = that.numImageSizesPerCurrentItem;
		
		this.imageDir = that.imageDir;
		this.loadImages = that.loadImages;
	}
	
	public long getNumAuctions() {
		return numAuctions;
	}
	public void setNumAuctions(long numAuctions) {
		this.numAuctions = numAuctions;
	}

	public long getNumUsersToCreate() {
		return numUsersToCreate;
	}
	public void setNumUsersToCreate(long numUsers) {
		this.numUsersToCreate = numUsers;
	}
	public float getAvgStartingBid() {
		return avgStartingBid;
	}
	public void setAvgStartingBid(float avgStartingBid) {
		this.avgStartingBid = avgStartingBid;
	}
	public float getStdDevStartingBid() {
		return stdDevStartingBid;
	}
	public void setStdDevStartingBid(float stdDevStartingBid) {
		this.stdDevStartingBid = stdDevStartingBid;
	}
	public float getAvgCreditLimit() {
		return avgCreditLimit;
	}
	public void setAvgCreditLimit(float avgCreditLimit) {
		this.avgCreditLimit = avgCreditLimit;
	}
	public float getStdDevCreditLimit() {
		return stdDevCreditLimit;
	}
	public void setStdDevCreditLimit(float stdDevCreditLimit) {
		this.stdDevCreditLimit = stdDevCreditLimit;
	}
	public long getStartUserNumber() {
		return startUserNumber;
	}
	public void setStartUserNumber(long startUserNumber) {
		this.startUserNumber = startUserNumber;
	}
	public int getTotalUsers() {
		return totalUsers;
	}
	public void setTotalUsers(int totalUsers) {
		this.totalUsers = totalUsers;
	}
	public double getHistoryAuctionsPerDay() {
		return historyAuctionsPerDay;
	}
	public void setHistoryAuctionsPerDay(double historyAuctionsPerDay) {
		this.historyAuctionsPerDay = historyAuctionsPerDay;
	}
	public int getHistoryDays() {
		return historyDays;
	}
	public void setHistoryDays(int historyDays) {
		this.historyDays = historyDays;
	}
	public int getHistoryAttendeesPerAuction() {
		return historyAttendeesPerAuction;
	}
	public void setHistoryAttendeesPerAuction(int historyAttendeesPerAuction) {
		this.historyAttendeesPerAuction = historyAttendeesPerAuction;
	}
	public int getHistoryItemsPerAuction() {
		return historyItemsPerAuction;
	}
	public void setHistoryItemsPerAuction(int historyItemsPerAuction) {
		this.historyItemsPerAuction = historyItemsPerAuction;
	}
	public int getHistoryBidsPerItem() {
		return historyBidsPerItem;
	}
	public void setHistoryBidsPerItem(int historyBidsPerItem) {
		this.historyBidsPerItem = historyBidsPerItem;
	}
	public double getFutureAuctionsPerDay() {
		return futureAuctionsPerDay;
	}
	public void setFutureAuctionsPerDay(double futureAuctionsPerDay) {
		this.futureAuctionsPerDay = futureAuctionsPerDay;
	}
	public int getFutureDays() {
		return futureDays;
	}
	public void setFutureDays(int futureDays) {
		this.futureDays = futureDays;
	}
	public int getFutureItemsPerAuction() {
		return futureItemsPerAuction;
	}
	public void setFutureItemsPerAuction(int futureItemsPerAuction) {
		this.futureItemsPerAuction = futureItemsPerAuction;
	}

	public boolean isLoadImages() {
		return loadImages;
	}

	public void setLoadImages(boolean loadImages) {
		this.loadImages = loadImages;
	}

	public String getImageDir() {
		return imageDir;
	}

	public void setImageDir(String imageDir) {
		this.imageDir = imageDir;
	}

	public boolean isLoadItemImages() {
		return loadItemImages;
	}

	public void setLoadItemImages(boolean loadItemImages) {
		this.loadItemImages = loadItemImages;
	}

	public int getItemsPerCurrentAuction() {
		return itemsPerCurrentAuction;
	}

	public void setItemsPerCurrentAuction(int itemsPerCurrentAuction) {
		this.itemsPerCurrentAuction = itemsPerCurrentAuction;
	}

	public int getMaxImagesPerCurrentItem() {
		return maxImagesPerCurrentItem;
	}

	public void setMaxImagesPerCurrentItem(int maxImagesPerCurrentItem) {
		this.maxImagesPerCurrentItem = maxImagesPerCurrentItem;
	}

	public int getMaxImagesPerHistoryItem() {
		return maxImagesPerHistoryItem;
	}

	public void setMaxImagesPerHistoryItem(int maxImagesPerHistoryItem) {
		this.maxImagesPerHistoryItem = maxImagesPerHistoryItem;
	}

	public int getMaxImagesPerFutureItem() {
		return maxImagesPerFutureItem;
	}

	public void setMaxImagesPerFutureItem(int maxImagesPerFutureItem) {
		this.maxImagesPerFutureItem = maxImagesPerFutureItem;
	}

	public int getNumImageSizesPerHistoryItem() {
		return numImageSizesPerHistoryItem;
	}

	public void setNumImageSizesPerHistoryItem(int numImageSizesPerHistoryItem) {
		this.numImageSizesPerHistoryItem = numImageSizesPerHistoryItem;
	}

	public int getNumImageSizesPerFutureItem() {
		return numImageSizesPerFutureItem;
	}

	public void setNumImageSizesPerFutureItem(int numImageSizesPerFutureItem) {
		this.numImageSizesPerFutureItem = numImageSizesPerFutureItem;
	}

	public int getNumImageSizesPerCurrentItem() {
		return numImageSizesPerCurrentItem;
	}

	public void setNumImageSizesPerCurrentItem(int numImageSizesPerCurrentItem) {
		this.numImageSizesPerCurrentItem = numImageSizesPerCurrentItem;
	}

	public String getMessageString() {
		return messageString;
	}

	public void setMessageString(String messageString) {
		this.messageString = messageString;
	}

}
