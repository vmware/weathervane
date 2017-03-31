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
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Date;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.AsyncContext;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.mvc.AsyncDispatcherServletListener;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.BidService;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionService;

@Controller
@RequestMapping(value = "/bid")
public class BidController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(BidController.class);

	private BidService bidService;

	@Inject
	@Named("bidService")
	public void setBidService(BidService bidService) {
		this.bidService = bidService;
	}

	private LiveAuctionService liveAuctionService;

	@Inject
	@Named("liveAuctionService")
	public void setLiveAuctionService(LiveAuctionService liveAuctionService) {
		this.liveAuctionService = liveAuctionService;
	}

	@Inject
	@Named("jacksonObjectMapper")
	private ObjectMapper objectMapper;

	@RequestMapping(value = "/user/{userId}", method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<BidRepresentation> getBidsForUser(
			@PathVariable long userId,
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize,
			@RequestParam(value = "fromDate", required = false) Date fromDate,
			@RequestParam(value = "toDate", required = false) Date toDate,
			HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("BidController::getBidsForUser userId = " + userId + ", username = " + username);
		
		// Can only get history for the authenticated user
		try {
			this.getSecurityUtil().checkAccount(userId);
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;	
		}

		CollectionRepresentation<BidRepresentation> bidsPage = bidService.getBidsForUser(userId, fromDate, toDate, page, pageSize);
		return bidsPage;
	}

	@RequestMapping(method = RequestMethod.POST)
	public @ResponseBody
	BidRepresentation postNewBid(@RequestBody BidRepresentation theBid, HttpServletResponse response) {

		logger.info("BidController::postNewBid : " + theBid.toString() + ", userId = " + theBid.getUserId());

		// Make sure this bid is being posted by the authenticated user
		try {
			this.getSecurityUtil().checkAccount(theBid.getUserId());
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;	
		}
		
		BidRepresentation bidRepresentation = null;
		while (bidRepresentation == null) {
			try {
				// Post the new bid
				bidRepresentation = liveAuctionService.postNewBid(theBid);

				logger.info("BidController:postNewBid itemId=" + bidRepresentation.getItemId() + " userId="
						+ bidRepresentation.getUserId() + " got Bid from bidService with id "
						+ bidRepresentation.getId());
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.info("BidController:postNewBid: got ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage());
			} catch (CannotAcquireLockException ex) {
				logger.warn("BidController:postNewBid: got CannotAcquireLockException with message "
						+ ex.getMessage());
			} catch (InvalidStateException ex) {
				// Create a bidepresentation with the error message
				bidRepresentation = new BidRepresentation(null, null);
				bidRepresentation.setId("error");
				bidRepresentation.setMessage(ex.getMessage());
				break;
			}
		}

		return bidRepresentation;
	}

	@RequestMapping(value = "/auction/{auctionId}/item/{itemId}/count/{bidCount}", method = RequestMethod.GET)
	public void getNextBid(@PathVariable long auctionId, @PathVariable long itemId, @PathVariable int bidCount,
			HttpServletRequest request, HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("BidController::getNextBid for auction " + auctionId + " item " + itemId + " lastBidCount "
				+ bidCount + ", username = " + username);
		AsyncContext ac = request.startAsync(request, response);

		/*
		 * Get the delay between auction updates (in minutes) and set the
		 * asyncContext timeout to twice that value ( to leave room for
		 * something being delayed).
		 */
		int maxIdleTime = liveAuctionService.getAuctionMaxIdleTime();
		ac.setTimeout(4 * maxIdleTime * 1000);
		ac.addListener(new AsyncDispatcherServletListener());

		BidRepresentation bidRepresentation = null;
		boolean completedSucesssfully = false;
		while (!completedSucesssfully) {
			try {
				// Queue up the aync request for the next bid
				bidRepresentation = liveAuctionService.getNextBid(auctionId, itemId, bidCount, ac);
				completedSucesssfully = true;
			} catch (ObjectOptimisticLockingFailureException ex) {
				logger.info("BidController:getNextBid: got ObjectOptimisticLockingFailureException with message "
						+ ex.getMessage());
			} catch (CannotAcquireLockException ex) {
				logger.warn("BidController:getNextBid: got CannotAcquireLockException with message "
						+ ex.getMessage());
			} catch (InvalidStateException ex) {
				logger.warn("BidController:getNextBid: got InvalidStateException with message "
						+ ex.getMessage());
				bidRepresentation = new BidRepresentation(null);
				bidRepresentation.setId("error");
				bidRepresentation.setMessage(ex.getMessage());
				break;
			} catch (AuthenticationException e) {
				logger.warn("BidController:getNextBid: got AuctionCompleteException with message "
						+ e.getMessage());
				response.setStatus(HttpServletResponse.SC_GONE);
				response.setContentType("text/html");
				try {
					PrintWriter responseWriter = response.getWriter();
					if (responseWriter != null) {
						responseWriter.print("AuctionComplete");
						responseWriter.close();
					}
				} catch (IOException e1) {
					logger.warn("BidController:getNextBid: got IOException when writing AuctionComplete message to reponse"
							+ e1.getMessage());
				}
				return;
			}
		}

		// If we got null back without an exception, then just return as
		// the request will be completed asynchronously later.
		if (bidRepresentation == null) {
			logger.trace("BidController:getNextBid: CompletedSuccessfully bidRepresentation = null ");
			return;
		} else {
			logger.trace("BidController:getNextBid: CompletedSuccessfully bidRepresentation = "
					+ bidRepresentation.toString());
		}

		// Complete the request ourselves. This is part of a workaround since
		// Spring 3.1 can't handle async servlets.
		completeAsyncGetNextBid(bidRepresentation, ac);

	}

	public void completeAsyncGetNextBid(BidRepresentation theBid, AsyncContext theAsyncContext) {
		/**
		 * This method is used to complete a getNextBid request immediately
		 * rather than adding it to a nextBidQueue.
		 * 
		 */
		StringWriter jsonWriter;
		String jsonResponse;

		// Get a JSON representation of the BidRepresentation
		jsonWriter = new StringWriter();
		try {
			objectMapper.writeValue(jsonWriter, theBid);
		} catch (Exception ex) {
			logger.error("Exception when translating to json: " + ex);
		}
		jsonResponse = jsonWriter.toString();
		
		// get the response from the async context
		HttpServletResponse response = (HttpServletResponse) theAsyncContext.getResponse();

		// Fill in the content
		response.setContentType("application/json");
		PrintWriter out;
		try {
			out = response.getWriter();
			out.print(jsonResponse);
		} catch (IOException ex) {
			logger.error("Exception when getting writer from response: " + ex);
		}

		// Complete the async request
		theAsyncContext.complete();

	}

}
