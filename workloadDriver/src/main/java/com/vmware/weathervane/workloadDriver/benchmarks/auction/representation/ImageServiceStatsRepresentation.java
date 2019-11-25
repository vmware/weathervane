/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

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
