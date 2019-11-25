/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

public interface AttendanceRecordRepositoryCustom {
			
	void deleteByAuctionId(Long auctionId);

}
