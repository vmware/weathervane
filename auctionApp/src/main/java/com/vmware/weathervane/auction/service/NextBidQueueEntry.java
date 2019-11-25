/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import javax.servlet.AsyncContext;

/**
 * This class is the entry for queue that holds the requests for
 * next bids.  The marker indicates whether this is a real request, 
 * or a placeholder to separate requests that arrived after the current
 * set of bid completions.
 * 
 * @author Hal
 *
 */
public class NextBidQueueEntry {

	private AsyncContext asyncCtxt;
	private Integer lastBidCount;
	private boolean isMarker;
	private Long itemId;
	/**
	 * @param asyncContext
	 * @param isMarker
	 */
	public NextBidQueueEntry(AsyncContext ac, Integer lastBidCount, boolean isMarker, Long itemId) {
		this.asyncCtxt = ac;
		this.lastBidCount = lastBidCount;
		this.isMarker =isMarker;
		this.itemId = itemId;
	}
	
	public AsyncContext getAsyncCtxt() {
		return asyncCtxt;
	}
	public void setAsyncCtxt(AsyncContext asyncCtxt) {
		this.asyncCtxt = asyncCtxt;
	}

	public Integer getLastBidCount() {
		return lastBidCount;
	}

	public void setLastBidCount(Integer lastBidCount) {
		this.lastBidCount = lastBidCount;
	}

	public boolean isMarker() {
		return isMarker;
	}

	public void setMarker(boolean isMarker) {
		this.isMarker = isMarker;
	}

	public Long getItemId() {
		return itemId;
	}

	public void setItemId(Long itemId) {
		this.itemId = itemId;
	}
	
	@Override
	public String toString() {
		return "lastBidCount = " + lastBidCount + ",itemId = " + itemId;
		
	}
	
}
