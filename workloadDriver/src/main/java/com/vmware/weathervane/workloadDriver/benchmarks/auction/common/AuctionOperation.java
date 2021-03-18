/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AddedItemIdListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendanceHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.BidHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PurchaseHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListener;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

import io.netty.handler.codec.http.HttpHeaders;

public abstract class AuctionOperation extends Operation {
	private static final Logger logger = LoggerFactory.getLogger(AuctionOperation.class);

   public AuctionOperation(User userState, Behavior behavior, Target target, StatsCollector statsCollector) {
      super(userState, behavior, target, statsCollector);
   }

   @Override
   protected void parseDataFromResponse(String response, DataListener[] listeners) {
	   logger.debug("parseDataFromResponse behavior = " + getBehaviorId() + ": response = " + response + " There are " + listeners.length + " listeners");
      for (DataListener listener : listeners) {
    	  if (listener instanceof LoginResponseListener) {
              ((LoginResponseListener) listener).handleResponse(response);
    	  } else if (listener instanceof ActiveAuctionListener) {
              ((ActiveAuctionListener) listener).handleResponse(response);
          } else if (listener instanceof CurrentAuctionListener) {
              ((CurrentAuctionListener) listener).handleResponse(response);
          } else if (listener instanceof CurrentItemListener) {
              ((CurrentItemListener) listener).handleResponse(response);
          } else if (listener instanceof DetailItemListener) {
              ((DetailItemListener) listener).handleResponse(response);
          } else if (listener instanceof CurrentBidListener) {
              ((CurrentBidListener) listener).handleResponse(response);
          } else if (listener instanceof UserProfileListener) {
              ((UserProfileListener) listener).handleResponse(response);
          } else if (listener instanceof BidHistoryInfoListener) {
              ((BidHistoryInfoListener) listener).handleResponse(response);
          } else if (listener instanceof PurchaseHistoryInfoListener) {
              ((PurchaseHistoryInfoListener) listener).handleResponse(response);
          } else if (listener instanceof AttendanceHistoryInfoListener) {
              ((AttendanceHistoryInfoListener) listener).handleResponse(response);;
          } else if (listener instanceof AuctionItemsListener) {
              ((AuctionItemsListener) listener).handleResponse(response);
          } else if (listener instanceof AddedItemIdListener) {
              ((AddedItemIdListener) listener).findAndSetAddedItemIdFromResponse(response);
          }
      }
   }
   
   @Override
   protected void parseDataFromHeaders(HttpHeaders headers, DataListener[] listeners) {
   }
   
}
