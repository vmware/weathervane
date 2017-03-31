/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.Date;
import java.util.List;

import javax.persistence.LockModeType;
import javax.persistence.Query;
import javax.persistence.TypedQuery;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;

@Repository("highBidDao")
@Transactional
public class HighBidDaoJpa extends GenericDaoJpa<HighBid, Long> implements HighBidDao {
	protected static final Logger logger = LoggerFactory.getLogger(HighBidDaoJpa.class);

	public HighBidDaoJpa() {
		super(HighBid.class);
		
		logger.info("HighBidDaoJpa constructor");
	}
	
	@Override
	@Transactional(readOnly=true)
	public List<HighBid> getActiveHighBids() {
				
		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE e.state = :state1 OR  e.state = :state2 "
				+ "ORDER BY e.id ASC";
		
		logger.info("getActiveHighBids. theQueryString = " + theQueryString);
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("state1", HighBidState.OPEN)
				.setParameter("state2", HighBidState.LASTCALL);
				
		return theQuery.getResultList();

	}
	
	@Override
	@Transactional(readOnly=true)
	public HighBid getActiveHighBid(Long auctionId) {
				
		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE (e.state = :state1 OR  e.state = :state2) "
				+ " AND auction_id = :auctionid ";
		
		logger.info("getActiveHighBid for auction " + auctionId + ". theQueryString = " + theQueryString);
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("state1", HighBidState.OPEN)
				.setParameter("state2", HighBidState.LASTCALL)
				.setParameter("auctionid", auctionId);
				
		return theQuery.getSingleResult();

	}
	
	@Override
	@Transactional
	public int deleteByPreloaded(Boolean preloaded) {
		logger.info("deleteByPreloaded");
		
		Query theQuery = entityManager
				.createQuery("DELETE from HighBid b where b.preloaded = :preloaded");
		theQuery.setParameter("preloaded", preloaded);

		int numDeleted = theQuery.executeUpdate();
		
		return numDeleted;
	
	}

	@Override
	public HighBid findByAuctionIdAndItemIdForUpdate(Long auctionId, Long itemId) {
		logger.info("findByAuctionIdAndItemId. auctionId = " + auctionId + ", itemId = " + itemId);

		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE auction_id = :auctionid AND  item_id = :itemid ";
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("auctionid", auctionId)
				.setParameter("itemid", itemId).setLockMode(LockModeType.PESSIMISTIC_WRITE);
				
		return (HighBid) theQuery.getSingleResult();
	}

	@Override
	public HighBid findByAuctionIdAndItemId(Long auctionId, Long itemId) {
		logger.info("findByAuctionIdAndItemId. auctionId = " + auctionId + ", itemId = " + itemId);

		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE auction_id = :auctionid AND  item_id = :itemid ";
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("auctionid", auctionId)
				.setParameter("itemid", itemId);
				
		return (HighBid) theQuery.getSingleResult();
	}

	@Override
	public List<HighBid> findByAuctionId(Long auctionId) {
		logger.info("findByAuctionId. auctionId = " + auctionId );

		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE auction_id = :auctionid";
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("auctionid", auctionId);
				
		return  theQuery.getResultList();
	}

	@Override
	public HighBid findByItemIdForUpdate(Long itemId) {
		logger.info("findByItemIdForUpdate. itemId = " + itemId);

		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE item_id = :itemid ";
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("itemid", itemId).setLockMode(LockModeType.PESSIMISTIC_WRITE);
				
		return (HighBid) theQuery.getSingleResult();
	}

	@Override
	public HighBid findByItemId(Long itemId) {
		logger.info("findByItemIdForUpdate. itemId = " + itemId);

		String theQueryString  = "SELECT e FROM HighBid e "
				+ "WHERE item_id = :itemid ";
		
		TypedQuery<HighBid> theQuery = entityManager.createQuery(theQueryString, HighBid.class)
				.setParameter("itemid", itemId);
				
		return (HighBid) theQuery.getSingleResult();
	}

	@Override
	@Transactional(readOnly=true)
	public Long getPurchasedItemCountforUser(Long userId) {
		logger.info("getPurchasedItemCountforUser. ");
		
		Query theQuery = entityManager.createQuery("select count(o) from HighBid o WHERE o.state = :state AND bidder_id = :userid ");
		theQuery.setParameter("state", HighBidState.SOLD);
		theQuery.setParameter("userid", userId);
		
		return (Long) theQuery.getResultList().get(0);
	}

	@Override
	@Transactional(readOnly=true)
	public List<Item> getPurchasedItemsPageForUser(Long userId, Integer page,
			Integer pageSize) {
		
		TypedQuery<Item> theQuery = entityManager.createQuery("select h.item from HighBid h " 
				+ "WHERE h.state = :state AND bidder_id = :userid order by h.biddingEndTime ASC", Item.class);
		theQuery.setParameter("state", HighBidState.SOLD);
		theQuery.setParameter("userid", userId);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		List<Item> resultList = theQuery.getResultList();
		
		
		return resultList;
	}

	@Override
	@Transactional(readOnly=true)
	public List<Item> getPurchasedItemsPageForUserFromDate(Long userId,
			Date fromDate, Integer page, Integer pageSize) {

		Query theQuery = entityManager.createQuery("select h.item from HighBid h where h.state = :state AND bidder_id = :userid and h.biddingEndTime >= :fromDate order by h.biddingEndTime ASC" );
		theQuery.setParameter("state", HighBidState.SOLD);
		theQuery.setParameter("userid", userId);
		theQuery.setParameter("fromDate", fromDate);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		List<Item> resultList = theQuery.getResultList();
		return resultList;
	}

	@Override
	@Transactional(readOnly=true)
	public List<Item> getPurchasedItemsPageForUserToDate(Long userId,
			Date toDate, Integer page, Integer pageSize) {

		Query theQuery = entityManager.createQuery("select h.item from HighBid h where h.state = :state AND bidder_id = :userid and h.biddingEndTime <= :toDate order by h.biddingEndTime ASC" );
		theQuery.setParameter("state", HighBidState.SOLD);
		theQuery.setParameter("userid", userId);
		theQuery.setParameter("toDate", toDate);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		List<Item> resultList = theQuery.getResultList();
		return resultList;
	}

	@Override
	@Transactional(readOnly=true)
	public List<Item> getPurchasedItemsPageForUserFromDateToDate(Long userId,
			Date fromDate, Date toDate, Integer page, Integer pageSize) {

		Query theQuery = entityManager.createQuery("select h.item from HighBid h where h.state = :state AND bidder_id = :userid and h.biddingEndTime >= :fromDate and h.biddingEndTime <= :toDate order by h.biddingEndTime ASC" );
		theQuery.setParameter("state", HighBidState.SOLD);
		theQuery.setParameter("userid", userId);
		theQuery.setParameter("fromDate", fromDate);
		theQuery.setParameter("toDate", toDate);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		List<Item> resultList = theQuery.getResultList();
		return resultList;
	}


}
