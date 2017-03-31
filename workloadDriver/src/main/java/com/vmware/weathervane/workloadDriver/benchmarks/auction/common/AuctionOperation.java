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
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

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
