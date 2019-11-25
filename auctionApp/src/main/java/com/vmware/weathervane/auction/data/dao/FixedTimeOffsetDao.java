/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import com.vmware.weathervane.auction.data.statsModel.FixedTimeOffset;

public interface FixedTimeOffsetDao extends GenericDao<FixedTimeOffset, Long> {
	int deleteAll();

	long testAndSetOffset(long myOffset);
}
