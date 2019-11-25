/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.dbloader;

public class DbLoadParams {
		
	private int totalUsers;
	
	private int historyDays;
	private int futureDays;

	private int purchasesPerUser;
	private int bidsPerUser;
	private int attendancesPerUser;

	private int attendeesPerAuction;
	
	private int maxImagesPerHistoryItem;
	private int numImageSizesPerHistoryItem;
	private int maxImagesPerFutureItem;
	private int numImageSizesPerFutureItem;

	private int usersPerCurrentAuction;
	private int maxImagesPerCurrentItem;
	private int numImageSizesPerCurrentItem;

	private int usersScaleFactor;

	public DbLoadParams() {
		
	}
	
	public DbLoadParams(DbLoadParams that) {
		this.historyDays = that.historyDays;
		this.futureDays = that.futureDays;
		this.purchasesPerUser = that.purchasesPerUser;
		this.bidsPerUser = that.bidsPerUser;
		this.attendancesPerUser = that.attendancesPerUser;
		this.attendeesPerAuction = that.attendeesPerAuction;
		
		this.maxImagesPerCurrentItem = that.maxImagesPerCurrentItem;
		this.maxImagesPerFutureItem = that.maxImagesPerFutureItem;
		this.maxImagesPerHistoryItem = that.maxImagesPerHistoryItem;
		
		this.numImageSizesPerCurrentItem = that.numImageSizesPerCurrentItem;
		this.numImageSizesPerFutureItem = that.numImageSizesPerFutureItem;
		this.numImageSizesPerHistoryItem = that.numImageSizesPerHistoryItem;
		
		this.usersPerCurrentAuction = that.usersPerCurrentAuction;
		
		this.usersScaleFactor = that.usersScaleFactor;
		
	}

	public int getMaxImagesPerHistoryItem() {
		return maxImagesPerHistoryItem;
	}

	public void setMaxImagesPerHistoryItem(int maxImagesPerHistoryItem) {
		this.maxImagesPerHistoryItem = maxImagesPerHistoryItem;
	}

	public int getNumImageSizesPerHistoryItem() {
		return numImageSizesPerHistoryItem;
	}

	public void setNumImageSizesPerHistoryItem(int numImageSizesPerHistoryItem) {
		this.numImageSizesPerHistoryItem = numImageSizesPerHistoryItem;
	}

	public int getMaxImagesPerFutureItem() {
		return maxImagesPerFutureItem;
	}

	public void setMaxImagesPerFutureItem(int maxImagesPerFutureItem) {
		this.maxImagesPerFutureItem = maxImagesPerFutureItem;
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

	public int getTotalUsers() {
		return totalUsers;
	}

	public void setTotalUsers(int totalUsers) {
		this.totalUsers = totalUsers;
	}

	public int getHistoryDays() {
		return historyDays;
	}

	public void setHistoryDays(int historyDays) {
		this.historyDays = historyDays;
	}

	public int getFutureDays() {
		return futureDays;
	}

	public void setFutureDays(int futureDays) {
		this.futureDays = futureDays;
	}

	public int getPurchasesPerUser() {
		return purchasesPerUser;
	}

	public void setPurchasesPerUser(int purchasesPerUser) {
		this.purchasesPerUser = purchasesPerUser;
	}

	public int getBidsPerUser() {
		return bidsPerUser;
	}

	public void setBidsPerUser(int bidsPerUser) {
		this.bidsPerUser = bidsPerUser;
	}

	public int getAttendancesPerUser() {
		return attendancesPerUser;
	}

	public void setAttendancesPerUser(int attendancesPerUser) {
		this.attendancesPerUser = attendancesPerUser;
	}

	public int getAttendeesPerAuction() {
		return attendeesPerAuction;
	}

	public void setAttendeesPerAuction(int attendeesPerAuction) {
		this.attendeesPerAuction = attendeesPerAuction;
	}
	
	public int getUsersPerCurrentAuction() {
		return usersPerCurrentAuction;
	}

	public void setUsersPerCurrentAuction(int usersPerCurrentAuction) {
		this.usersPerCurrentAuction = usersPerCurrentAuction;
	}

	public int getUsersScaleFactor() {
		return usersScaleFactor;
	}

	public void setUsersScaleFactor(int usersScaleFactor) {
		this.usersScaleFactor = usersScaleFactor;
	}

	public int getMaxImagesPerCurrentItem() {
		return maxImagesPerCurrentItem;
	}

	public void setMaxImagesPerCurrentItem(int maxImagesPerCurrentItem) {
		this.maxImagesPerCurrentItem = maxImagesPerCurrentItem;
	}

}
