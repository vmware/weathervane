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

import javax.persistence.Query;

import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.User;

@Repository("itemDao")
@Transactional
public class ItemDaoJpa extends GenericDaoJpa<Item, Long> implements ItemDao {

	public ItemDaoJpa() {
		super(Item.class);
		
		logger.info("ItemDaoJpa constructor");
	}

	@Override
	@Transactional(readOnly=true)
	public Long getItemCountForAuctioneer(long userId) {
		logger.info("getItemCountforAuctioneer. ");

		User theAuctioneer = entityManager.find(User.class, userId);
		
		Query theQuery = entityManager.createQuery("select count(o) from Item o WHERE o.auctioneer = :user ");
		theQuery.setParameter("user", theAuctioneer);
		
		return (Long) theQuery.getResultList().get(0);
	}

	@Override
	@Transactional(readOnly=true)
	public List<Item> getItemsPageForAuctioneer(long userId, Integer page,
			Integer pageSize) {
		
		User theUser = entityManager.find(User.class, userId);

		Query theQuery = entityManager.createQuery("select i from Item i where i.auctioneer = :user order by i.id ASC" );
		theQuery.setParameter("user", theUser);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);
		List<Item> resultList = theQuery.getResultList();
		return resultList;
	}

	@Override
	public Item addItemForAuctioneer(Item anItem, Long userId) {
		logger.info("addItemForAuctioneer. ");

		User theUser = entityManager.find(User.class, userId);

		anItem.setAuctioneer(theUser);
		
		this.save(anItem);
		
		return anItem;
	}

	@Override
	@Transactional(readOnly=true)
	public User getAuctioneer(Long itemId) {
		Item theItem = this.get(itemId);
		
		return theItem.getAuctioneer();
	}

	@Override
	public Item updateItem(Item updateItem) {
		
		logger.info("updateItem.  itemId = " + updateItem.getId());
		
		Item itemToUpdate = this.get(updateItem.getId());
	
		if ((updateItem.getShortDescription() != null) && (!updateItem.getShortDescription().equals(""))
				&& (!updateItem.getShortDescription().equals(itemToUpdate.getShortDescription()))) {
			itemToUpdate.setShortDescription(updateItem.getShortDescription());
		}
		if ((updateItem.getManufacturer() != null) && (!updateItem.getManufacturer().equals(""))
				&& (!updateItem.getManufacturer().equals(itemToUpdate.getManufacturer()))) {
			itemToUpdate.setManufacturer(updateItem.getManufacturer());
		}
		if ((updateItem.getLongDescription() != null) && (!updateItem.getLongDescription().equals(""))
				&& (!updateItem.getLongDescription().equals(itemToUpdate.getLongDescription()))) {
			itemToUpdate.setLongDescription(updateItem.getLongDescription());
		}
		if ((updateItem.getStartingBidAmount() != null) && (!updateItem.getStartingBidAmount().equals(""))
				&& (!updateItem.getStartingBidAmount().equals(itemToUpdate.getStartingBidAmount()))) {
			itemToUpdate.setStartingBidAmount(updateItem.getStartingBidAmount());
		}
		if ((updateItem.getCondition() != null) 
				&& (!updateItem.getCondition().equals(itemToUpdate.getCondition()))) {
			itemToUpdate.setCondition(updateItem.getCondition());
		}
		if ((updateItem.getDateOfOrigin() != null) 
				&& (!updateItem.getDateOfOrigin().equals(itemToUpdate.getDateOfOrigin()))) {
			itemToUpdate.setDateOfOrigin(updateItem.getDateOfOrigin());
		}
		
		return itemToUpdate;
	}

	@Override
	public int deleteByPreloaded(boolean preloaded) {
		logger.info("deleteByPreloaded");
		
		Query theQuery = entityManager
				.createQuery("DELETE from Item i where i.preloaded = :preloaded");
		theQuery.setParameter("preloaded", preloaded);

		int numDeleted = theQuery.executeUpdate();
		
		return numDeleted;
	}
	
}

