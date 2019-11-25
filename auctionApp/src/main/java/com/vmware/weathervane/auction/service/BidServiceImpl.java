/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;

import javax.inject.Inject;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.repository.event.BidRepository;
import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
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

	@Override
	@Transactional(readOnly = true)
	public CollectionRepresentation<BidRepresentation> getBidsForUser(Long userId, Date fromDate,
			Date toDate, Integer page, Integer pageSize) {

		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants.getCollectionPageSize(pageSize);

		logger.info("BidServiceImpl::getBidsForUser page = " + realPage + ", pageSize = "
				+ realPageSize);

		List<Bid> queryResults = null;
		if (fromDate == null)
			if (toDate == null)
				queryResults = bidRepository.findByBidderId(userId);
			else
				queryResults = bidRepository.findByBidderIdAndBidTimeLessThanEqual(userId, toDate);
		else if (toDate == null)
			queryResults = bidRepository.findByBidderIdAndBidTimeGreaterThanEqual(userId, fromDate);
		else
			queryResults = bidRepository.findByBidderIdAndBidTimeBetween(userId, fromDate, toDate);

		List<BidRepresentation> liveBids = 
				queryResults.stream().limit(realPageSize)
					.map(r -> new BidRepresentation(r, null)).collect(Collectors.toList());
		
		CollectionRepresentation<BidRepresentation> colRep = new CollectionRepresentation<BidRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(realPageSize.longValue());
		colRep.setResults(liveBids);

		return colRep;
	}

}
