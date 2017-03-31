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
	private boolean resetAuctions;
	private AuctionDao auctionDao;
	private HighBidDao highBidDao;
	
	public void run() {
		logger.debug("run: startIndex = " + prepStartIndex + ", endIndex = " + prepEndIndex + 
				", auctionsToPrep.size = " + auctionsToPrep.size() +
				", resetAuctions = " + resetAuctions);
		for (int i = prepStartIndex; i < prepEndIndex; i++) {
			if (resetAuctions) {
				auctionDao.resetToFuture(auctionsToPrep.get(i));
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

}
