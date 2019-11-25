/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.UUID;

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
import org.springframework.web.bind.annotation.ResponseBody;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.auction.mvc.AsyncDispatcherServletListener;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.service.BidService;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

@Controller
@RequestMapping(value = "/bid")
public class BidController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(BidController.class);

	@Inject
	@Named("bidService")
	private BidService bidService;

	@Inject
	@Named("jacksonObjectMapper")
	private ObjectMapper objectMapper;

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
				bidRepresentation = bidService.postNewBid(theBid);

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
				// Create a bidrepresentation with the error message
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
		 * asyncContext timeout to 1.5x that value ( to leave room for
		 * something being delayed).
		 */
		int maxIdleTime = bidService.getAuctionMaxIdleTime();
		ac.setTimeout(Math.round(1.5 * maxIdleTime * 1000));
		ac.addListener(new AsyncDispatcherServletListener());

		BidRepresentation bidRepresentation = null;
		boolean completedSucesssfully = false;
		while (!completedSucesssfully) {
			try {
				// Queue up the aync request for the next bid
				bidRepresentation = bidService.getNextBid(auctionId, itemId, bidCount, ac);
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
			logger.debug("BidController:getNextBid: CompletedSuccessfully bidRepresentation = null ");
			return;
		} else {
			logger.debug("BidController:getNextBid: CompletedSuccessfully bidRepresentation = "
					+ bidRepresentation.toString());
		}

		// Complete the request ourselves. This is part of a workaround since
		// Spring 3.1 can't handle async servlets.
		completeAsyncGetNextBid(bidRepresentation, ac);

	}

	@RequestMapping(value="/prepareForShutdown", method = RequestMethod.GET)
	public @ResponseBody Boolean shutdown()  {
		bidService.prepareForShutdown();
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
		bidService.releaseGetNextBid();
		return true;
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
