/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;

public interface AuctionService {

	public CollectionRepresentation<AuctionRepresentation> getAuctions(Integer page, Integer pageSize);		

	public AuctionRepresentation getAuction(Long auctionId);

	long getAuctionMisses();
			
}
