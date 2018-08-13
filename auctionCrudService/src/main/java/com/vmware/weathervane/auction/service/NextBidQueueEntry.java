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
