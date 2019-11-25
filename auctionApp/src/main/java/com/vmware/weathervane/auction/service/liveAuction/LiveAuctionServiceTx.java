/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service.liveAuction;

import org.springframework.transaction.annotation.Transactional;

/**
 * @author Hal
 *
 */
public interface LiveAuctionServiceTx {
	
	@Transactional
	boolean becomeMaster(Long nodeNumber);

}