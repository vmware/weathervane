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
package com.vmware.weathervane.auction.rest.representation;

import java.io.Serializable;
/**
 * @author Hal
 * 
 */
public class ImageServiceStatsRepresentation extends Representation implements
		Serializable {

	private static final long serialVersionUID = 1L;
	
	private long resizesRequested;
	private long resizesCompleted;
	private long averageResizeDelay;
	
	
	public ImageServiceStatsRepresentation() {

	}

	public long getResizesRequested() {
		return resizesRequested;
	}


	public void setResizesRequested(long resizesRequested) {
		this.resizesRequested = resizesRequested;
	}


	public long getResizesCompleted() {
		return resizesCompleted;
	}


	public void setResizesCompleted(long resizesCompleted) {
		this.resizesCompleted = resizesCompleted;
	}


	public long getAverageResizeDelay() {
		return averageResizeDelay;
	}


	public void setAverageResizeDelay(long averageResizeDelay) {
		this.averageResizeDelay = averageResizeDelay;
	}


}
