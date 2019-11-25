/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.util.Date;

import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;

public interface AttendanceService {

	public CollectionRepresentation<AttendanceRecordRepresentation> getAttendanceRecordsForUser(long userId,
			Date fromDate, Date toDate, Integer page, Integer pageSize);
}
