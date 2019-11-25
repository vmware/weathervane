/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.vmware.weathervane.auction.data.model.Bid;
import com.vmware.weathervane.auction.data.model.Bid.BidKey;

@Repository
public interface BidRepository extends CrudRepository<Bid, BidKey>, BidRepositoryCustom {

}
