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
