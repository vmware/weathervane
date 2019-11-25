/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import com.vmware.weathervane.auction.data.model.AuctionMgmt;

public interface AuctionMgmtDao extends GenericDao<AuctionMgmt, Long> {

	AuctionMgmt findByIdForUpdate(Long id);

	void resetMasterNodeId(Long id);

	void deleteEntry(Long id);
}
