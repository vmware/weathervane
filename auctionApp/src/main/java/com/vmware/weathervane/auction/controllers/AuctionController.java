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

import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.AuctionService;

@Controller
@RequestMapping(value = "/auction")
public class AuctionController extends BaseController{
	private static final Logger logger = LoggerFactory
			.getLogger(AuctionController.class);

	private static long auctionGets = 0;
	
	/*
	 * Method to print stats for cache misses at end of runs
	 */
	@PreDestroy
	private void printAuctionCacheStats() {
		double auctionGetMissRate = auctionService.getAuctionMisses() / (double) auctionGets;
		
		logger.warn("Auction Cache Stats: ");
		logger.warn("Auction.  Gets = " + auctionGets + ", misses = " + auctionService.getAuctionMisses() + ", miss rate = " + auctionGetMissRate);
	}

	private AuctionService auctionService;

	@Inject
	@Named("auctionService")
	public void setAuctionService(AuctionService auctionService) {
		this.auctionService = auctionService;
	}

	@RequestMapping(value = "/{id}", method = RequestMethod.GET)
	public @ResponseBody
	AuctionRepresentation getAuction(@PathVariable long id, HttpServletResponse response) {
		AuctionRepresentation theAuction;
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("AuctionController::getAuction id = " + id + ", username = " + username);
		try {
			auctionGets++;
			theAuction = auctionService.getAuction(id);
		} catch (IndexOutOfBoundsException ex) {
			theAuction = null;
			if (response != null) {
				response.setStatus(404);				
			}

		}
		return theAuction;

	}

	@RequestMapping(method = RequestMethod.GET)
	public @ResponseBody
	CollectionRepresentation<AuctionRepresentation> getAuctions(
			@RequestParam(value = "page", required = false) Integer page,
			@RequestParam(value = "pageSize", required = false) Integer pageSize) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("AuctionController::getAuctions, username = " + username);

		CollectionRepresentation<AuctionRepresentation> auctionsPage = auctionService.getAuctions(
				page, pageSize);
		if (auctionsPage.getResults() != null) {
			logger.info("AuctionController::getAuctions.  AuctionService returned totalRecords = "
					+ auctionsPage.getTotalRecords()
					+ ", numresults = "
					+ auctionsPage.getResults().size());
		} else {
			logger.info("AuctionController::getAuctions.  AuctionService returned null totalRecords");
		}
		return auctionsPage;
	}
	

}
