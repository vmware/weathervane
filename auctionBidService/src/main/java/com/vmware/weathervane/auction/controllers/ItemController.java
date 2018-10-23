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
