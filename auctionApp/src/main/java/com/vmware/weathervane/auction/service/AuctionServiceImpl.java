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
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.List;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;

public class AuctionServiceImpl implements AuctionService {

	private static final Logger logger = LoggerFactory
			.getLogger(AuctionServiceImpl.class);

	private static long auctionMisses = 0;

	@Inject
	@Named("auctionDao")
	AuctionDao auctionDao;

	public CollectionRepresentation<AuctionRepresentation> getAuctions(Integer page, Integer pageSize) {
		logger.info("AuctionServiceImpl::GetAuctions");
		ArrayList<AuctionRepresentation> liveAuctions = new ArrayList<AuctionRepresentation>();

		// Get the total number of auctions
		Long totalRecords = auctionDao.getCount();
		
		// Get all auctions and convect them to AuctionRepresentations
		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants.getCollectionPageSize(pageSize);
		logger.info("AuctionServiceImpl::GetAuctions totalRecords = " + totalRecords + ", page = " + realPage + ", pageSize = " + realPageSize);

		List<Auction> auctionList = auctionDao.getPage(realPage, realPageSize);
		logger.info("AuctionServiceImpl::GetAuctions Got " +  auctionList.size() + " records back.");

		for (Auction anAuction : auctionList) {
			liveAuctions.add(new AuctionRepresentation(anAuction));
		}

		CollectionRepresentation<AuctionRepresentation> colRep = new CollectionRepresentation<AuctionRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(totalRecords);
		colRep.setResults(liveAuctions);
		
		return colRep;

	}

	@Cacheable(value="auctionRepresentationCache")
	public AuctionRepresentation getAuction(Long id) {

		logger.info("LiveAuctionController::getAuction id = " + id
				+ "; intvalue = " + id.intValue());
		auctionMisses++;
		Auction anAuction = auctionDao.get(id);

		return new AuctionRepresentation(anAuction);
	}

	@Override
	public long getAuctionMisses() {
		return auctionMisses;
	}

}
