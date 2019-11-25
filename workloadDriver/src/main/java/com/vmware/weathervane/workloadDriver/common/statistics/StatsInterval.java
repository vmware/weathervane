/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics;

public class StatsInterval {
	private Long duration = null;
	
	public StatsInterval() {}

	public StatsInterval(long duration) {
		this.duration = duration;
	}

	public Long getDuration() {
		return duration;
	}

	public void setDuration(Long duration) {
		this.duration = duration;
	}
}
