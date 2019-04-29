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
import java.util.GregorianCalendar;
import java.util.List;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.repository.event.AttendanceRecordRepository;
import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

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

		Page<AttendanceRecord> queryResults = null;
		Pageable pageRequest = new PageRequest(realPage, realPageSize, Sort.Direction.ASC, "id");
		if (fromDate == null) 
			if (toDate == null)
				queryResults = attendanceRecordRepository.findByUserId(userId, pageRequest);
			else 
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampLessThanEqual(userId, toDate, pageRequest);
		else 
			if (toDate == null)
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampGreaterThanEqual(userId, fromDate, pageRequest);
		else
				queryResults = attendanceRecordRepository.findByUserIdAndTimestampBetween(userId, fromDate, toDate, pageRequest);
			
		
		ArrayList<AttendanceRecordRepresentation> liveAttendanceRecords = new ArrayList<AttendanceRecordRepresentation>();
		for (AttendanceRecord anAttendanceRecord : queryResults.getContent()) {
			liveAttendanceRecords.add( new AttendanceRecordRepresentation(anAttendanceRecord));
		}

		CollectionRepresentation<AttendanceRecordRepresentation> colRep = new CollectionRepresentation<AttendanceRecordRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(queryResults.getTotalElements());
		colRep.setResults(liveAttendanceRecords);

		return colRep;
	}

	@Override
	public void updateAttendanceRecord(long userId, long auctionId) throws InvalidStateException {
		GregorianCalendar now = FixedOffsetCalendarFactory.getCalendar();
		attendanceRecordRepository.updateLastActiveTime(userId, auctionId, now.getTime());
	}
	
}
