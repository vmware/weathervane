/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.dbloader;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.model.Auction;


public class DBPrepService implements Runnable {

	private static final Logger logger = LoggerFactory.getLogger(DBPrepService.class);
	
	private List<Auction> auctionsToPrep;
	private int prepStartIndex;
	private int prepEndIndex;
	private boolean pretouch = false;
	private boolean resetAuctions = false;
	private AuctionDao auctionDao;
	private HighBidDao highBidDao;
	
	public void run() {
		logger.debug("run: startIndex = " + prepStartIndex + ", endIndex = " + prepEndIndex + 
				", auctionsToPrep.size = " + auctionsToPrep.size() +
				", resetAuctions = " + resetAuctions);
		for (int i = prepStartIndex; i < prepEndIndex; i++) {
			if (resetAuctions) {
				auctionDao.resetToFuture(auctionsToPrep.get(i));
			} else if (isPretouch()) {
				auctionDao.pretouchImages(auctionsToPrep.get(i));
			} else {
				auctionDao.setToActivated(auctionsToPrep.get(i));
			}
		}
	}

	public AuctionDao getAuctionDao() {
		return auctionDao;
	}

	public void setAuctionDao(AuctionDao auctionDao) {
		this.auctionDao = auctionDao;
	}

	public List<Auction> getAuctionsToPrep() {
		return auctionsToPrep;
	}

	public void setAuctionsToPrep(List<Auction> auctionsToPrep) {
		this.auctionsToPrep = auctionsToPrep;
	}

	public int getPrepStartIndex() {
		return prepStartIndex;
	}

	public void setPrepStartIndex(int prepStartIndex) {
		this.prepStartIndex = prepStartIndex;
	}

	public int getPrepEndIndex() {
		return prepEndIndex;
	}

	public void setPrepEndIndex(int prepEndIndex) {
		this.prepEndIndex = prepEndIndex;
	}

	public boolean isResetAuctions() {
		return resetAuctions;
	}

	public void setResetAuctions(boolean resetAuctions) {
		this.resetAuctions = resetAuctions;
	}

	public HighBidDao getHighBidDao() {
		return highBidDao;
	}

	public void setHighBidDao(HighBidDao highBidDao) {
		this.highBidDao = highBidDao;
	}

	public boolean isPretouch() {
		return pretouch;
	}

	public void setPretouch(boolean pretouch) {
		this.pretouch = pretouch;
	}

}
