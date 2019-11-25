/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.liveAuction;

import com.vmware.weathervane.auction.rest.representation.BidRepresentation;

public interface Auctioneer extends Runnable{

	void handleNewBidMessage(BidRepresentation bid);

	void cleanup();

	void shutdown();

}
