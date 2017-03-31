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
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.Date;

import javax.inject.Inject;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.repository.BidRepository;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;

/**
 * @author Hal
 * 
 */
public class BidServiceImpl implements BidService {

	private static final Logger logger = LoggerFactory.getLogger(BidServiceImpl.class);

	@Inject
	private BidRepository bidRepository;

	public BidServiceImpl() {
	}

	/*
	 * (non-Javadoc)
	 * 
	 * 
	 * @see com.vmware.liveAuction.services.BidService#getBid(java.lang.Long)
	 */
	@Override
	public BidRepresentation getBid(String bidId) {

		Bid theBid = bidRepository.findOne(bidId);
		return new BidRepresentation(theBid, null);
	}

	@Override
	@Transactional(readOnly = true)
	public CollectionRepresentation<BidRepresentation> getBidsForUser(Long userId, Date fromDate,
			Date toDate, Integer page, Integer pageSize) {

		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants.getCollectionPageSize(pageSize);

		logger.info("BidServiceImpl::getBidsForUser page = " + realPage + ", pageSize = "
				+ realPageSize);

		Pageable pageRequest = new PageRequest(realPage, realPageSize, Sort.Direction.ASC, "id");
		Page<Bid> queryResults = null;
		if (fromDate == null)
			if (toDate == null)
				queryResults = bidRepository.findByBidderId(userId, pageRequest);
			else
				queryResults = bidRepository.findByBidderIdAndBidTimeLessThanEqual(userId, toDate,
						pageRequest);
		else if (toDate == null)
			queryResults = bidRepository.findByBidderIdAndBidTimeGreaterThanEqual(userId, fromDate,
					pageRequest);
		else
			queryResults = bidRepository.findByBidderIdAndBidTimeBetween(userId, fromDate, toDate,
					pageRequest);

		ArrayList<BidRepresentation> liveBids = new ArrayList<BidRepresentation>();
		for (Bid aBid : queryResults.getContent()) {
			liveBids.add(new BidRepresentation(aBid, null));
		}

		CollectionRepresentation<BidRepresentation> colRep = new CollectionRepresentation<BidRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(queryResults.getTotalElements());
		colRep.setResults(liveBids);

		return colRep;
	}

}
