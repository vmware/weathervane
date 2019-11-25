/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;
import java.io.PrintWriter;

import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.vmware.weathervane.auction.rest.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.UserService;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionService;

@Controller
@RequestMapping(value = "/live/auction")
public class LiveAuctionController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(LiveAuctionController.class);

	private static long activeAuctionGets = 0;
	
	/*
	 * Method to print stats for cache misses at end of runs
	 */
	@PreDestroy
	private void printAuctionCacheStats() {
		double auctionGetMissRate = liveAuctionService.getActiveAuctionsMisses() / (double) activeAuctionGets;
				
		logger.warn("ActiveAuctions Cache Stats: ");
		logger.warn("ActiveAuctions.  Gets = " + activeAuctionGets + ", misses = " + liveAuctionService.getActiveAuctionsMisses() + ", miss rate = " + auctionGetMissRate);
	}

	private LiveAuctionService liveAuctionService;
	private UserService userService;

	public LiveAuctionService getLiveAuctionService() {
		return liveAuctionService;
	}

	@Inject
	@Named("liveAuctionService")
	public void setLiveAuctionService(LiveAuctionService liveAuctionService) {
		this.liveAuctionService = liveAuctionService;
	}

	public UserService getUserService() {
		return userService;
	}

	@Inject
	@Named("userService")
	public void setUserService(UserService userService) {
		this.userService = userService;
	}
	
	@RequestMapping(value="/isMaster", method = RequestMethod.GET)
	public @ResponseBody Boolean getIsMaster()  {
		return liveAuctionService.isMaster();
	}

	@RequestMapping(value="/prepareForShutdown", method = RequestMethod.GET)
	public @ResponseBody Boolean shutdown()  {
		liveAuctionService.prepareForShutdown();
		return true;
	}

	/**
	 * Tell LiveAuctionService to release all pending async requests
	 * (GetNextBid)
	 * 
	 * @return
	 */
	@RequestMapping(value="/release", method = RequestMethod.GET)
	public @ResponseBody Boolean release()  {
		liveAuctionService.releaseGetNextBid();
		return true;
	}

	@RequestMapping(method = RequestMethod.GET)
	public @ResponseBody
			CollectionRepresentation<AuctionRepresentation> getActiveAuctions(
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize) {
		
		activeAuctionGets++;
		CollectionRepresentation<AuctionRepresentation> auctionsPage = liveAuctionService.getActiveAuctions(page, pageSize);
		if ((auctionsPage.getResults() != null) && (auctionsPage.getResults().size() > 0)) {
			logger.info("LiveAuctionController::getActiveAuctions.  Page = {}, PageSize = {}, returning totalRecords = {}"
					+ ", first auctionId = {}, missRate = {}", page, pageSize, auctionsPage.getTotalRecords(),
					auctionsPage.getResults().get(0).getId(), liveAuctionService.getActiveAuctionsMisses() / (double) activeAuctionGets);
		} else {
			logger.info("LiveAuctionController::getActiveAuctions.  LiveAuctionService returned null totalRecords");
		}
		
		return auctionsPage;
	}

	@RequestMapping(method = RequestMethod.POST)
	public @ResponseBody
	AttendanceRecordRepresentation joinAuction(@RequestBody AttendanceRecordRepresentation record,
			HttpServletResponse response) {

		logger.info("LiveAuctionController::joinAuction userId = " + record.getUserId() + " joined auctionId = "
				+ record.getAuctionId());
		
		this.getSecurityUtil().checkAccount(record.getUserId());

		AttendanceRecordRepresentation recordRepresentation = null;
		while (recordRepresentation == null) {
			try {
				// Join the auction
				recordRepresentation = liveAuctionService.joinAuction(record);

				logger.debug("LiveAuctionController:joinAuction auctionId=" + recordRepresentation.getAuctionId());
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.debug("LiveAuctionController:joinAuction: got ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage());
			} catch (CannotAcquireLockException ex) {
				logger.warn("LiveAuctionController:joinAuction: got CannotAcquireLockException with message "
						+ ex.getMessage());
			} catch (InvalidStateException ex) {
				logger.warn("LiveAuctionController:joinAuction: got InvalidStateException with message "
						+ ex.getMessage());
				response.setStatus(HttpServletResponse.SC_CONFLICT);
				response.setContentType("text/html");
				try {
					PrintWriter responseWriter = response.getWriter();
					responseWriter.print("IllegalState");
					responseWriter.close();
				} catch (IOException e1) {
					logger.warn("LiveAuctionController:joinAuction: got IOException when writing IllegalState message to reponse"
							+ e1.getMessage());
				}
				return null;
			} catch (AuctionNotActiveException e) {
				logger.warn("LiveAuctionController:joinAuction: got AuctionCompleteException with message "
						+ e.getMessage());
				response.setStatus(HttpServletResponse.SC_GONE);
				response.setContentType("text/html");
				try {
					PrintWriter responseWriter = response.getWriter();
					responseWriter.print("AuctionComplete");
					responseWriter.close();
				} catch (IOException e1) {
					logger.warn("LiveAuctionController:joinAuction: got IOException when writing AuctionComplete message to reponse"
							+ e1.getMessage());
				}
				return null;
			}
		}

		return recordRepresentation;
	}

	@RequestMapping(value="{auctionId}", method = RequestMethod.DELETE)
	public @ResponseBody
	AttendanceRecordRepresentation leaveAuction(@PathVariable long auctionId, HttpServletResponse response) {
		
		long userId = this.getSecurityUtil().getAccountFromPrincipal();

		logger.info("leaveAuction userId = " + userId + " left auctionId = " + auctionId);

		AttendanceRecordRepresentation currentRecord = null;
		try {
			currentRecord = liveAuctionService.leaveAuction(userId, auctionId);
		} catch (InvalidStateException e) {
			response.setStatus(HttpServletResponse.SC_CONFLICT);
		}
		
		return currentRecord;
	}
}
