/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.util.Date;

import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;

public interface BidService {
	
	public CollectionRepresentation<BidRepresentation> getBidsForUser(Long userId,
			Date fromDate, Date toDate, Integer page, Integer pageSize);
		
}
