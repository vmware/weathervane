/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.List;

import javax.persistence.LockModeType;
import javax.persistence.Query;

import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.statsModel.FixedTimeOffset;

@Repository("fixedTimeOffsetDao")
@Transactional
public class FixedTimeOffsetDaoJpa extends GenericDaoJpa<FixedTimeOffset, Long> implements FixedTimeOffsetDao {

	public FixedTimeOffsetDaoJpa() {
		super(FixedTimeOffset.class);
		
		logger.info("FixedTimeOffset constructor");
	}

	@Override
	@Transactional
	public int deleteAll() {
		logger.info("deleteAll");
		
		Query theQuery = entityManager
				.createQuery("DELETE from FixedTimeOffset b");

		int numDeleted = theQuery.executeUpdate();
		
		return numDeleted;

	}

	@Override
	public long testAndSetOffset(long myOffset) {
		/*
		 *  Find out if there is already an offset in the db.  Lock the table
		 *  until we are done.
		 */
		List<FixedTimeOffset> timeOffsets = entityManager.createQuery("select o from " +
				FixedTimeOffset.class.getName() + " o").setLockMode(LockModeType.PESSIMISTIC_WRITE).getResultList();
		
		if ((timeOffsets == null) || (timeOffsets.size() <= 0)) {
			// No existing records.  Save myOffset
			FixedTimeOffset fixedTimeOffset = new FixedTimeOffset();
			fixedTimeOffset.setTimeOffset(myOffset);
			this.save(fixedTimeOffset);
		} else {
			myOffset = timeOffsets.get(0).getTimeOffset();
		}
		
		return myOffset;
	
	}

}
