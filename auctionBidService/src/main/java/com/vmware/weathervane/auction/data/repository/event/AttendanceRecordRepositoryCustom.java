/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import java.util.Date;
import java.util.List;

import com.vmware.weathervane.auction.data.model.AttendanceRecord;

public interface AttendanceRecordRepositoryCustom {
				
	void leaveAuctionsForUser(Long userId);
	
	void deleteByAuctionId(Long auctionId);

	List<AttendanceRecord> findByUserId(Long userId);

	List<AttendanceRecord> findByUserIdAndTimestampLessThanEqual(Long userId, Date toDate);	

	List<AttendanceRecord> findByUserIdAndTimestampGreaterThanEqual(Long userId, Date fromDate);	

	List<AttendanceRecord> findByUserIdAndTimestampBetween(Long userId, Date fromDate, Date toDate);	

}
