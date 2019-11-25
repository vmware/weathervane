/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.comparator;

import java.util.Comparator;

import com.vmware.weathervane.auction.rest.representation.BidRepresentation;

public class BidTimeComparator implements Comparator<BidRepresentation> {

	@Override
	public int compare(BidRepresentation arg0, BidRepresentation arg1) {
	
		return arg0.getBidTime().compareTo(arg1.getBidTime());
	
	}

}
