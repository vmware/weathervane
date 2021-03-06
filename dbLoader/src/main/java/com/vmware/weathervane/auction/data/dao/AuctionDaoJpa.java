/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.text.DateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;

import javax.inject.Inject;
import javax.persistence.Query;
import javax.persistence.TemporalType;
import javax.persistence.TypedQuery;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.Keyword;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.Auction.AuctionState;
import com.vmware.weathervane.auction.data.model.Item.ItemState;
import com.vmware.weathervane.auction.data.repository.event.AttendanceRecordRepository;
import com.vmware.weathervane.auction.data.repository.event.BidRepository;
import com.vmware.weathervane.auction.data.repository.image.ImageFullRepository;
import com.vmware.weathervane.auction.data.repository.image.ImageInfoRepository;
import com.vmware.weathervane.auction.data.repository.image.ImagePreviewRepository;
import com.vmware.weathervane.auction.data.repository.image.ImageThumbnailRepository;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

@Repository("auctionDao")
@Transactional
public class AuctionDaoJpa extends GenericDaoJpa<Auction, Long> implements AuctionDao {

	protected static final Logger logger = LoggerFactory.getLogger(AuctionDaoJpa.class);

	@Inject
	AttendanceRecordRepository attendanceRecordRepository;

	@Inject
	BidRepository bidRepository;

	@Inject
	ImageInfoRepository imageInfoRepository;

	@Inject
	ImageFullRepository imageFullRepository;

	@Inject
	ImagePreviewRepository imagePreviewRepository;

	@Inject
	ImageThumbnailRepository imageThumbnailRepository;
	
	@Inject
	HighBidDao highBidDao;

	public AuctionDaoJpa() {
		super(Auction.class);

		logger.info("AuctionDaoJpa constructor");
	}

	@Override
	@Transactional(readOnly = true)
	public Long getCountWithState(Auction.AuctionState state) {

		Query theQuery = entityManager
				.createQuery("select count(o) from Auction o WHERE o.state = :state ");
		theQuery.setParameter("state", state);

		return (Long) theQuery.getResultList().get(0);

	}

	/**
	 * 
	 * Method to fetch all auctions starting at a time at or after startTime but
	 * before endTime
	 * 
	 * @author hrosenbe
	 */
	@Override
	@Transactional(readOnly = true)
	public List<Auction> getAuctionsToStart(Date endTime) {

		logger.info("getAuctionsToStart. endTime = "
				+ DateFormat.getDateTimeInstance().format(endTime));

		String theQueryString = "SELECT e FROM Auction e " + "WHERE e.startTime < :end "
				+ "AND e.state = :state " + "ORDER BY e.startTime ASC";

		logger.info("getAuctionsToStart. theQueryString = " + theQueryString);

		TypedQuery<Auction> theQuery = entityManager.createQuery(theQueryString, Auction.class)
				.setParameter("end", endTime, TemporalType.TIMESTAMP)
				.setParameter("state", Auction.AuctionState.FUTURE);

		return theQuery.getResultList();

	}

	/**
	 * 
	 * Method to fetch all auctions which are currently running
	 * 
	 * @author hrosenbe
	 */
	@Override
	@Transactional(readOnly = true)
	public List<Auction> getActiveAuctions() {

		logger.info("getActiveAuctions.");

		String theQueryString = "SELECT e FROM Auction e " + "WHERE e.state = :state "
				+ "ORDER BY e.id ASC";

		logger.info("getActiveAuctions. theQueryString = " + theQueryString);

		TypedQuery<Auction> theQuery = entityManager.createQuery(theQueryString, Auction.class)
				.setParameter("state", AuctionState.RUNNING);

		return theQuery.getResultList();

	}

	public Long getItemCountforAuction(Auction theAuction) {
		logger.info("getItemCountForAuction. ");

		Query theQuery = entityManager
				.createQuery("select count(o) from Item o WHERE o.auction = :auction ");
		theQuery.setParameter("auction", theAuction);

		return (Long) theQuery.getResultList().get(0);

	}

	@Override
	@Transactional(readOnly = true)
	public List<Item> getItemPageForAuction(Auction theAuction, int page, int pageSize) {
		logger.info("getItemPageForAuction. auctionId = " + theAuction.getId());

		String theQueryString = "SELECT e FROM Item e " + "WHERE e.auction = :auction "
				+ "ORDER BY e.id ASC";

		logger.info("getItemsForAuction. theQueryString = " + theQueryString);

		TypedQuery<Item> theQuery = entityManager.createQuery(theQueryString, Item.class)
				.setParameter("auction", theAuction);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);

		return theQuery.getResultList();

	}

	@Override
	@Transactional(readOnly = true)
	public List<Item> getItemsForAuction(Long auctionId) {
		logger.info("getItemsForAuction. auctionId = " + auctionId);
		Auction theAuction = this.get(auctionId);

		String theQueryString = "SELECT e FROM Item e " + "WHERE e.auction = :auction "
				+ "ORDER BY e.id ASC";

		logger.info("getItemsForAuction. theQueryString = " + theQueryString);

		TypedQuery<Item> theQuery = entityManager.createQuery(theQueryString, Item.class)
				.setParameter("auction", theAuction);

		return theQuery.getResultList();

	}

	@Override
	@Transactional(readOnly = true, noRollbackFor = { EmptyResultDataAccessException.class })
	public Item getFirstItem(Auction theAuction) {
		logger.info("getFirstItem. auctionId = " + theAuction.getId());

		String theQueryString = "SELECT e FROM Item e " + "WHERE e.auction = :auction "
				+ "ORDER BY e.id ASC";

		logger.info("getFirstItem. theQueryString = " + theQueryString);

		Query theQuery = entityManager.createQuery(theQueryString)
				.setParameter("auction", theAuction).setMaxResults(1);

		return (Item) theQuery.getSingleResult();
	}

	@Override
	@Transactional(readOnly = true, noRollbackFor = { EmptyResultDataAccessException.class })
	public Item getNextItem(Auction theAuction, Long itemId) {
		logger.info("getNextItem. auctionId = " + theAuction.getId() + " itemId = " + itemId);

		String theQueryString = "SELECT e FROM Item e "
				+ "WHERE e.auction = :auction  and e.id > :itemId " + "ORDER BY e.id ASC";

		logger.info("getNextitem. theQueryString = " + theQueryString);

		Query theQuery = entityManager.createQuery(theQueryString)
				.setParameter("auction", theAuction).setParameter("itemId", itemId)
				.setMaxResults(1);

		return (Item) theQuery.getSingleResult();

	}

	@Override
	@Transactional(readOnly = true, noRollbackFor = { EmptyResultDataAccessException.class })
	public List<Auction> getAuctionsPage(int page, int pageSize, Auction.AuctionState state) {

		logger.info("getAuctionsPage. state = " + state);

		String theQueryString = "SELECT e FROM Auction e " + "WHERE e.state = :state "
				+ "ORDER BY e.id ASC";

		logger.info("getAuctionsPage. theQueryString = " + theQueryString);

		TypedQuery<Auction> theQuery = entityManager.createQuery(theQueryString, Auction.class)
				.setParameter("state", state);
		theQuery.setMaxResults(pageSize);
		theQuery.setFirstResult(page * pageSize);

		return theQuery.getResultList();

	}

	@Override
	public Auction addAuctionForAuctioneer(Auction anAuction, Long userId) {
		logger.info("addAuctionForAuctioneer. ");

		User theUser = entityManager.find(User.class, userId);

		theUser.addAuction(anAuction);

		this.save(anAuction);

		return anAuction;
	}

	@Override
	public Long countByCurrent(Boolean current) {
		logger.info("countByCurrent. ");

		Query theQuery = entityManager
				.createQuery("select count(a) from Auction a WHERE a.current = :current ");
		theQuery.setParameter("current", current);
		Long count = (Long) theQuery.getSingleResult();
		return count;
	}

	@Override
	public Long countByCurrentAndActivated(Boolean current, Boolean activated) {
		logger.info("countByCurrentAndActivated. ");

		Query theQuery = entityManager
				.createQuery("select count(a) from Auction a WHERE a.current = :current "
						+ " and a.activated = :activated");
		theQuery.setParameter("current", current);
		theQuery.setParameter("activated", activated);
		Long count = (Long) theQuery.getSingleResult();
		return count;
	}

	@Override
	public List<Auction> findByCurrent(Boolean current, int numDesired) {
		logger.info("findByCurrent. ");

		TypedQuery<Auction> theQuery = entityManager.createQuery(
				"select a from Auction a WHERE a.current = :current " + " ORDER BY a.id ASC ",
				Auction.class);
		theQuery.setParameter("current", current);
		theQuery.setMaxResults(numDesired);
		theQuery.setFirstResult(0);

		List<Auction> theAuctions = theQuery.getResultList();
		return theAuctions;
	}

	@Override
	public List<Auction> findByCurrentAndActivated(Boolean current, Boolean activated) {
		logger.info("findByCurrentAndActivated. ");

		TypedQuery<Auction> theQuery = entityManager.createQuery(
				"select a from Auction a WHERE a.current = :current "
						+ " and a.activated = :activated ORDER BY a.id ASC", Auction.class);
		theQuery.setParameter("current", current);
		theQuery.setParameter("activated", activated);

		List<Auction> theAuctions = theQuery.getResultList();
		return theAuctions;
	}

	@Override
	public void resetToFuture(Auction auction) {
		logger.info("resetToFuture. auctionId = " + auction.getId());
		GregorianCalendar calendar = FixedOffsetCalendarFactory.getCalendar();
		calendar.add(Calendar.YEAR, 1);
		Date startTime = calendar.getTime();

		// Bring the auction back into the context
		Auction theAuction = this.get(auction.getId());

		/*
		 * reset the fields of the Auction that are changed when the auction is
		 * run
		 */
		theAuction.setActivated(false);
		theAuction.setStartTime(startTime);
		theAuction.setEndTime(null);
		theAuction.setState(AuctionState.FUTURE);

		logger.info("resetToFuture. auctionId = " + auction.getId()
				+ ". Delete the attendance records.");

		/*
		 * Delete all of the attendance records for this auction
		 */
		attendanceRecordRepository.deleteByAuctionId(theAuction.getId());

		/*
		 * Now reset all items in the auction
		 */
		logger.info("resetToFuture. auctionId = " + auction.getId() + ". Reset the items.");
		for (Item anItem : theAuction.getItems()) {
			anItem.setState(ItemState.INAUCTION);

			// Delete all bids for the item
			logger.info("resetToFuture. auctionId = " + auction.getId()
					+ ". Delete the bids for item " + anItem.getId());
			bidRepository.deleteByItemId(anItem.getId());

			logger.info("resetToFuture. auctionId = " + auction.getId() + ". Clear highbid for item " + anItem.getId());
			anItem.setHighbid(null);
		}
	}


	@Override
	public void pretouchImages(Auction auction) {
		logger.info("pretouchImages. auctionId = " + auction.getId());
		// Bring the auction back into the context
		Auction theAuction = this.get(auction.getId());

		/*
		 * Get images for all items
		 */
		logger.info("pretouchImages. auctionId = " + auction.getId());
		for (Item anItem : theAuction.getItems()) {
			/*
			 * Preload the images for this item.  Get the image_infos for each 
			 * item, and then get the different image sizes using the image_id
			 */
			Iterable<ImageInfo> imageInfos = imageInfoRepository.findByKeyEntityid(anItem.getId());
			imageInfos.forEach(new Consumer<ImageInfo>() {

				@Override
				public void accept(ImageInfo ii) {
					//imageFullRepository.findByKeyImageId(ii.getKey().getImageId());
					//imagePreviewRepository.findByKeyImageId(ii.getKey().getImageId());
					imageThumbnailRepository.findByKeyImageId(ii.getKey().getImageId());
				}
			});
		}
	}

	@Transactional
	public Set<Keyword> getKeywordsForAuction(Auction anAuction) {

		Auction theAuction = this.get(anAuction.getId());

		return theAuction.getKeywords();
	}

	@Override
	public void setToActivated(Auction auction) {
		logger.info("setToActivated. ");

		// Bring the auction back into the context
		Auction theAuction = this.get(auction.getId());
		theAuction.setActivated(true);
		theAuction.setStartTime(FixedOffsetCalendarFactory.getSimulatedStartDate());

	}

}
