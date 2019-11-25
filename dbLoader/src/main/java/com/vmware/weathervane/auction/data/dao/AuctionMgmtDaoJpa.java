/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import javax.persistence.LockModeType;
import javax.persistence.TypedQuery;

import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.AuctionMgmt;


@Repository("auctionMgmtDao")
@Transactional
public class AuctionMgmtDaoJpa extends GenericDaoJpa<AuctionMgmt, Long> implements AuctionMgmtDao {
	
	public AuctionMgmtDaoJpa() {
		super(AuctionMgmt.class);
		
		logger.info("AuctionMgmtDaoJpa constructor");
	}

	@Override
	public AuctionMgmt findByIdForUpdate(Long id) {
		logger.info("findByIdForUpdate. id = " + id);

		String theQueryString  = "SELECT e FROM AuctionMgmt e "
				+ "WHERE e.id = :id ";
		
		TypedQuery<AuctionMgmt> theQuery = entityManager.createQuery(theQueryString, AuctionMgmt.class)
				.setParameter("id", id).setLockMode(LockModeType.PESSIMISTIC_WRITE);
				
		return (AuctionMgmt) theQuery.getSingleResult();
	}

	@Override
	public void deleteEntry(Long id) {

		AuctionMgmt auctionMgmt = this.get(id);
		
		if (auctionMgmt != null) {
			this.delete(auctionMgmt);
		}
	}

	@Override
	public void resetMasterNodeId(Long id) {
		AuctionMgmt auctionMgmt = new AuctionMgmt(id, null);
		this.save(auctionMgmt);
	}

}
