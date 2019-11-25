/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import javax.persistence.Query;

import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.statsModel.BidCompletionDelay;

@Repository("bidCompletionDelayDao")
@Transactional
public class BidCompletionDelayDaoJpa extends GenericDaoJpa<BidCompletionDelay, Long> implements BidCompletionDelayDao {

	public BidCompletionDelayDaoJpa() {
		super(BidCompletionDelay.class);
		
		logger.info("ItemDaoJpa constructor");
	}

	@Override
	@Transactional
	public int deleteAll() {
		logger.info("deleteAll");
		
		Query theQuery = entityManager
				.createQuery("DELETE from BidCompletionDelay b");

		int numDeleted = theQuery.executeUpdate();
		
		return numDeleted;

	}

}
