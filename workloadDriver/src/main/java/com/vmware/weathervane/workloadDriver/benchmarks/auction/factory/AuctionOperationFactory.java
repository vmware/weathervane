/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.factory;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.AddImageForItemOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.AddItemOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetActiveAuctionsOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetAttendanceHistoryOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetAuctionDetailOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetBidHistoryOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetCurrentItemOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetImageForItemOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetItemDetailOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetNextBidOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetPurchaseHistoryOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.GetUserProfileOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.HomePageOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.JoinAuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.LeaveAuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.LoginOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.LogoutOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.NoOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.PlaceBidOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.RegisterOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.operations.UpdateUserProfileOperation;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.target.HttpTarget;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.factory.OperationFactory;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class AuctionOperationFactory implements OperationFactory {
	private static final Logger logger = LoggerFactory.getLogger(AuctionOperationFactory.class);
	
	public AuctionOperationFactory() {
		
	}
	
	@Override
	public List<Operation> getOperations(StatsCollector statsCollector, User user, Behavior behavior, 
													Target target) {
		
		if (behavior != null) {
			logger.debug("getOperations for behavior " + behavior.getBehaviorId());
		}
		
		List<Operation> operations = new ArrayList<Operation>();
		
		HttpTarget httpTarget;
		String hostname;
		Integer httpPort;
		String httpScheme;
		Integer httpsPort;
		String httpsScheme;
		if (target != null) {
			httpTarget = (HttpTarget) target;
			hostname = httpTarget.getHostname();
			httpTarget.getHttpPort();
			httpScheme = httpTarget.getHttpScheme();
			if (httpTarget.getSslEnabled()) {
				logger.debug("SSL is enabled.  Setting HTTPS scheme to https");
				httpsPort = httpTarget.getHttpsPort();
				httpsScheme = httpTarget.getHttpsScheme();
			} else {
				logger.debug("SSL is disabled.  Setting HTTPS scheme to http");
				httpsPort = httpTarget.getHttpPort();
				httpsScheme = httpTarget.getHttpScheme();
			}
		} else {
			 hostname = "";
			 httpPort = 80;
			 httpScheme = "http";
			 httpsPort = 443;
			 httpsScheme = "https";
		}
		Operation operation = new HomePageOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, null, null));
		operations.add(operation);
		
		operation = new RegisterOperation(user, behavior, target, statsCollector);
		operations.add(operation);

		operation = new LoginOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/login", null));
		operations.add(operation);

		operation = new GetActiveAuctionsOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, 
				"auction/live/auction", "pageSize={pageSize}&page={pageNumber}"));
		operations.add(operation);

		operation = new GetAuctionDetailOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/auction/{auctionId}", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,	
				"auction/item/auction/{auctionId}", "pageSize={pageSize}&page=0"));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new GetUserProfileOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/user/{userId}", null));
		operations.add(operation);

		operation = new UpdateUserProfileOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/user/{userId}", null));
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/user/{userId}", null));
		operations.add(operation);

		operation = new JoinAuctionOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/live/auction/", null));
		operation
				.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/auction/{auctionId}", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/item/current/auction/{auctionId}", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/bid/auction/{auctionId}/item/{itemId}/count/0",
				null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new GetCurrentItemOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/item/current/auction/{auctionId}", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/bid/auction/{auctionId}/item/{itemId}/count/0", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new GetNextBidOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, 
				"auction/bid/auction/{auctionId}/item/{itemId}/count/{bidCount}", null));
		operations.add(operation);

		operation = new PlaceBidOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/bid/", null));
		operations.add(operation);

		operation = new LeaveAuctionOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/live/auction/{auctionId}", null));
		operations.add(operation);

		operation = new GetBidHistoryOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/bid/user/{userId}",
				"pageSize={pageSize}&page={pageNumber}"));
		operations.add(operation);

		operation = new GetAttendanceHistoryOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/attendance/user/{userId}", "pageSize={pageSize}&page={pageNumber}"));
		operations.add(operation);

		operation = new GetPurchaseHistoryOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null,
				"auction/item/user/{userId}/purchased", "pageSize={pageSize}&page={pageNumber}"));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new GetItemDetailOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/item/{itemId}", null));
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new GetImageForItemOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, 
				null, "auction/{imageUrl}", "size={size}"));
		operations.add(operation);

		operation = new AddItemOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/item", null));
		operations.add(operation);

		operation = new AddImageForItemOperation(user, behavior, target, statsCollector);
		operation.addPostUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/item/{itemId}/image",
				null));
		operations.add(operation);

		operation = new LogoutOperation(user, behavior, target, statsCollector);
		operation.addGetUrl(new SimpleUri(httpsScheme, hostname, httpsPort, null, "auction/logout", null));
		operations.add(operation);

		operation = new NoOperation(user, behavior, target, statsCollector);
		operations.add(operation);

		for (int index = 0; index < operations.size(); index++) {
			operations.get(index).setOperationIndex(index);
		}
		
		return operations;	
		
	}
}
