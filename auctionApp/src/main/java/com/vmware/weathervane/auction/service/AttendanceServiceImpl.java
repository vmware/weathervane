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

import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;

import javax.inject.Inject;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.repository.event.AttendanceRecordRepository;
import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;

/**
 * @author Hal
 * 
 */
public class AttendanceServiceImpl implements AttendanceService {

	private static final Logger logger = LoggerFactory.getLogger(AttendanceServiceImpl.class);
	
	@Inject
	AttendanceRecordRepository attendanceRecordRepository;
	
	public AttendanceServiceImpl() {

	}

	@Override
	public CollectionRepresentation<AttendanceRecordRepresentation> getAttendanceRecordsForUser(long userId,
			Date fromDate, Date toDate, Integer page, Integer pageSize) {

		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants
				.getCollectionPageSize(pageSize);
		
		logger.info("AttendanceServiceImpl::getAttendanceRecordsForUser page = " + realPage + ", pageSize = "
				+ realPageSize);

		List<AttendanceRecord> queryResults = null;
		if (fromDate == null) 
			if (toDate == null)
				queryResults = attendanceRecordRepository.findByUserId(userId);
			else 
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampLessThanEqual(userId, toDate);
		else 
			if (toDate == null)
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampGreaterThanEqual(userId, fromDate);
		else
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampBetween(userId, fromDate, toDate);
			
		List<AttendanceRecordRepresentation> liveAttendanceRecords = 
				queryResults.stream().limit(realPageSize)
					.map(r -> new AttendanceRecordRepresentation(r)).collect(Collectors.toList());

		CollectionRepresentation<AttendanceRecordRepresentation> colRep = new CollectionRepresentation<AttendanceRecordRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(realPageSize.longValue());
		colRep.setResults(liveAttendanceRecords);

		return colRep;
	}
	
}
