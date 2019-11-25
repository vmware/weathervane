/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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
