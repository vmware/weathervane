/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;
import java.io.PrintWriter;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.BidService;
import com.vmware.weathervane.auction.service.exception.AuctionNotActiveException;

@Controller
@RequestMapping(value = "/item")
public class ItemController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(ItemController.class);

	@Inject
	@Named("bidService")
	private BidService bidService;


	@RequestMapping(value = "/current/auction/{auctionId}", method = RequestMethod.GET)
	public @ResponseBody
	ItemRepresentation getCurrentItem(@PathVariable long auctionId, HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("ItemController::getCurrentItem auctionId = " + auctionId + ", username = " + username);

		ItemRepresentation returnItem = null;
		try {
			returnItem = bidService.getCurrentItem(auctionId);
		} catch (AuctionNotActiveException ex) {
			response.setStatus(HttpServletResponse.SC_GONE);
			response.setContentType("text/html");
			try {
				PrintWriter responseWriter = response.getWriter();
				responseWriter.print("AuctionComplete");
				responseWriter.close();
				return null;
			} catch (IOException e1) {
				logger.warn("ItemController::getCurrentItem: got IOException when writing AuctionComplete message to reponse"
						+ e1.getMessage());
			}
		}
		
		if (returnItem == null) {
			response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
		}
		
		return returnItem;
	}

}
